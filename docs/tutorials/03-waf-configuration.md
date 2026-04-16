# Tutorial 03: WAF Configuration

Enable WAF protection with a global Detection-mode baseline, then add a per-listener Prevention-mode policy for a production app — including rate limiting and geo-blocking.

## Step 1: Global WAF via tfvars

Switch the SKU to WAF_v2 and set the global policy to Detection mode:

```hcl
sku_name = "WAF_v2"
sku_tier = "WAF_v2"

waf_configuration = {
  enabled            = true
  firewall_mode      = "Detection"
  rule_set_type      = "OWASP"
  rule_set_version   = "3.2"
  file_upload_limit  = 100    # MB
  max_request_body_size = 128 # KB
}
```

Detection mode logs everything WAF would block but lets all traffic through. Start here. Always.

## Step 2: Per-Listener WAF Policy in YAML

For apps that are ready for enforcement, add a `waf_policy` section to the app YAML. The key must match the app's `http_listener` key:

```yaml
# apps/prod-api.yaml
prod-api:
  priority: 200
  backend_address_pool:
    fqdns:
      - "api.internal.example.com"
  backend_http_settings:
    port: 443
    protocol: "Https"
    request_timeout: 60
    host_name: "api.internal.example.com"
    probe_name: "prod-api"
  http_listener:
    frontend_ip_configuration_name: "feip-public"
    frontend_port_name: "fp-https"
    protocol: "Https"
    host_name: "api.example.com"
    ssl_certificate_name: "wildcard-example"
  request_routing_rule:
    rule_type: "Basic"
  probe:
    protocol: "Https"
    path: "/health"
    host: "api.internal.example.com"
    interval: 30
    timeout: 30
    unhealthy_threshold: 3

  # Per-listener WAF policy — overrides the global policy for this listener
  waf_policy:
    mode: "Prevention"
    rule_set_type: "OWASP"
    rule_set_version: "3.2"

    custom_rules:
      # Rate limit: max 100 requests per minute per client IP
      - name: "RateLimitByClientIP"
        priority: 10
        rule_type: "RateLimitRule"
        rate_limit_duration: "OneMin"
        rate_limit_threshold: 100
        action: "Block"
        match_conditions:
          - match_variables:
              - variable_name: "RemoteAddr"
            operator: "IPMatch"
            negation: false
            match_values:
              - "0.0.0.0/0"

      # Geo-block: deny traffic from specific countries
      - name: "GeoBlock"
        priority: 20
        rule_type: "MatchRule"
        action: "Block"
        match_conditions:
          - match_variables:
              - variable_name: "RemoteAddr"
            operator: "GeoMatch"
            negation: false
            match_values:
              - "CN"
              - "RU"

    # Disable specific OWASP rules that cause false positives
    managed_rule_overrides:
      - rule_group_name: "REQUEST-942-APPLICATION-ATTACK-SQLI"
        rules:
          - rule_id: "942430"
            state: "Disabled"   # "Restricted SQL Character Anomaly" — fires on JSON API bodies
          - rule_id: "942440"
            state: "Disabled"   # "SQL Comment Sequence Detected" — fires on legitimate query params
      - rule_group_name: "REQUEST-920-PROTOCOL-ENFORCEMENT"
        rules:
          - rule_id: "920300"
            state: "Disabled"   # "Request Missing Accept Header" — many API clients don't send it

    # GDPR: scrub client IPs from WAF logs
    log_scrubbing:
      enabled: true
      scrubbing_rules:
        - match_variable: "RequestIPAddress"
          selector_match_operator: "EqualsAny"
```

## The Detection → Prevention Workflow

1. **Deploy with global Detection mode** — all listeners inherit it
2. **Review WAF logs** for 1-2 weeks — query `AzureDiagnostics` where `OperationName == "ApplicationGatewayFirewall"` and `action_s == "Matched"`, then summarize by `ruleId_s`
3. **Add overrides** in the per-listener WAF policy for false-positive rules
4. **Switch the per-listener policy to Prevention** — only for that app
5. **Monitor for a week**, then repeat for the next app

Never jump straight to Prevention mode globally. Each app triggers different rules.

## Verify

```bash
# Test that WAF blocks a SQL injection attempt (Prevention mode)
curl -v "https://api.example.com/search?q=1' OR '1'='1" \
  --resolve api.example.com:443:$PIP
# Should return 403 Forbidden

# Test rate limiting (send 101 requests in under a minute)
for i in $(seq 1 101); do
  curl -s -o /dev/null -w "%{http_code}\n" \
    https://api.example.com/health \
    --resolve api.example.com:443:$PIP
done
# Last requests should return 429
```

## Gotchas

**Same region and subscription.** WAF policies must be in the same region and subscription as the App Gateway. Cross-region policies silently fail to associate.

**Rule ID lookup.** To find which rules are causing false positives, you need the WAF logs — the rule IDs in `managed_rule_overrides` must exactly match what appears in `ruleId_s` in the diagnostics logs.

**Log scrubbing is policy-level.** The `log_scrubbing` config applies to the entire WAF policy, not per rule. If you enable it on a per-listener policy, it only affects logs from that listener's traffic.

**Custom rule priority ordering.** Custom rules are evaluated in priority order (lower number = first). Rate limit rules should generally have lower priority numbers than geo-block rules so you catch volumetric abuse before geographic filtering.
