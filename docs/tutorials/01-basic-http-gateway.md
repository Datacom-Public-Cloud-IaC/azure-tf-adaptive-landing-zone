# Tutorial 01: Basic HTTP Gateway in PoC Mode

Deploy a public-facing HTTP Application Gateway with a single backend pointing to httpbin.org. No SSL, no WAF — just the simplest possible working gateway to validate your setup.

## tfvars Configuration

```hcl
# poc.tfvars
location            = "australiaeast"
resource_group_name = "rg-appgw-poc"
appgw_name          = "agw-poc-aue-001"

# PoC mode: the module creates VNet, subnet, and NSG for you
poc_mode = true
poc_vnet_address_space    = ["10.0.0.0/16"]
poc_appgw_subnet_prefix   = "10.0.4.0/24"

frontend_mode = "public_only"
sku_name      = "Standard_v2"
sku_tier      = "Standard_v2"
sku_capacity  = 1

app_config_path = "./apps"
```

## App YAML Configuration

```yaml
# apps/httpbin.yaml
httpbin:
  priority: 100
  backend_address_pool:
    fqdns:
      - "httpbin.org"
  backend_http_settings:
    port: 80
    protocol: "Http"
    request_timeout: 30
    host_name: "httpbin.org"   # Backend host header override
    probe_name: "httpbin"
  http_listener:
    frontend_ip_configuration_name: "feip-public"
    frontend_port_name: "fp-http"
    protocol: "Http"
    host_name: "httpbin.example.com"
  request_routing_rule:
    rule_type: "Basic"
  probe:
    protocol: "Http"
    path: "/get"
    host: "httpbin.org"
    interval: 30
    timeout: 30
    unhealthy_threshold: 3
    match:
      status_codes:
        - "200-399"
```

The top-level key (`httpbin`) becomes the naming prefix for all child resources — the listener becomes `httpbin-listener`, the pool becomes `httpbin-pool`, etc.

## What Gets Auto-Created in PoC Mode

The module creates an NSG on the App Gateway subnet with these critical rules:

| Priority | Direction | Port | Source | Purpose |
|----------|-----------|------|--------|---------|
| 100 | Inbound | 65200-65535 | GatewayManager | **Required.** Azure control plane health. Without this, the gateway enters a failed state. |
| 110 | Inbound | 80 | * | Client HTTP traffic |
| 120 | Inbound | 443 | * | Client HTTPS traffic (for later) |

The **GatewayManager** rule is non-negotiable. If your org's NSG baseline policy blocks these ports, the App Gateway deployment will succeed but the instance will never become healthy.

## Verify

```bash
# Get the public IP (takes 5-10 minutes after apply)
PIP=$(az network public-ip show \
  -g rg-appgw-poc \
  -n agw-poc-aue-001-pip \
  --query ipAddress -o tsv)

# Test with Host header matching your listener
curl -H "Host: httpbin.example.com" http://$PIP/get
```

You should get a JSON response from httpbin.org showing your request headers.

## Gotchas

**Provisioning time.** App Gateway v2 takes 5-10 minutes to fully provision. Terraform will sit at the `azapi_resource` step for a while — this is normal.

**Health probes must succeed.** If the backend health probe fails, the routing rule is active but all requests return 502. Check backend health in the portal under *Backend health* before debugging anything else:

```bash
az network application-gateway show-backend-health \
  -g rg-appgw-poc -n agw-poc-aue-001 \
  --query backendAddressPools[].backendHttpSettingsCollection[].servers[]
```

**host_name matters twice.** You need it in both `backend_http_settings` (so the backend receives the right Host header) and in `probe` (so health checks hit the right virtual host). Miss either one and you'll get 502s or false-unhealthy probes.
