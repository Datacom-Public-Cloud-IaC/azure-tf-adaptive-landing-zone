# Tutorial 02: SSL/TLS with Key Vault Integration

Add HTTPS to your gateway using a wildcard certificate stored in Azure Key Vault, with automatic HTTP→HTTPS redirection.

## The UMI → Key Vault RBAC Chain

App Gateway v2 uses a User-Assigned Managed Identity (UMI) to pull certificates from Key Vault. The wiring:

```
App Gateway → references UMI → UMI has RBAC on Key Vault → reads certificate as a secret
```

In your tfvars, tell the module which principals need Key Vault access:

```hcl
# Add to your tfvars
sku_name = "Standard_v2"
sku_tier = "Standard_v2"

ssl_certificates = {
  "wildcard-example" = {
    key_vault_secret_id = "https://kv-appgw-certs.vault.azure.net/secrets/wildcard-example-com"
  }
}

# The module creates the UMI; this grants it Key Vault Secrets User role
ssl_keyvault_principal_ids = {
  "kv-appgw-certs" = {
    key_vault_id = "/subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.KeyVault/vaults/kv-appgw-certs"
  }
}
```

**Critical:** The `key_vault_secret_id` must use the `/secrets/` path, not `/certificates/`. App Gateway reads certs as Key Vault secrets — even if you uploaded it as a certificate. Using the `/certificates/` path will fail silently.

## App YAML with HTTPS + HTTP Redirect

```yaml
# apps/webapp.yaml
webapp:
  priority: 100
  backend_address_pool:
    fqdns:
      - "webapp-backend.azurewebsites.net"
  backend_http_settings:
    port: 443
    protocol: "Https"
    request_timeout: 30
    host_name: "webapp-backend.azurewebsites.net"
    probe_name: "webapp"
  # HTTPS listener (primary)
  http_listener:
    frontend_ip_configuration_name: "feip-public"
    frontend_port_name: "fp-https"
    protocol: "Https"
    host_name: "webapp.example.com"
    ssl_certificate_name: "wildcard-example"
  request_routing_rule:
    rule_type: "Basic"
  probe:
    protocol: "Https"
    path: "/healthz"
    host: "webapp-backend.azurewebsites.net"
    interval: 30
    timeout: 30
    unhealthy_threshold: 3

# HTTP → HTTPS redirect (separate entry)
webapp-redirect:
  priority: 101
  http_listener:
    frontend_ip_configuration_name: "feip-public"
    frontend_port_name: "fp-http"
    protocol: "Http"
    host_name: "webapp.example.com"
  redirect_configuration:
    redirect_type: "Permanent"
    target_listener_name: "webapp-listener"
    include_path: true
    include_query_string: true
  request_routing_rule:
    rule_type: "Basic"
```

Notice the redirect entry (`webapp-redirect`) has no backend pool — it only redirects. The `target_listener_name` follows the convention: `{app-key}-listener`.

## Backend with Self-Signed Certs

If your backend uses a self-signed or internal CA certificate, you need a trusted root certificate so the gateway can verify the backend's TLS:

```hcl
# In tfvars
trusted_root_certificates = {
  "internal-ca" = {
    data = filebase64("certs/internal-ca.cer")   # DER-encoded .cer
  }
}
```

```yaml
# In the app YAML, reference it in backend_http_settings
backend_http_settings:
  port: 443
  protocol: "Https"
  trusted_root_certificate_names:
    - "internal-ca"
```

## Verify

```bash
# Test HTTPS
curl -v https://webapp.example.com --resolve webapp.example.com:443:$PIP

# Test HTTP redirect (should return 301)
curl -I http://webapp.example.com --resolve webapp.example.com:80:$PIP
```

## Gotchas

**Key Vault firewall.** If your Key Vault has network rules enabled, the App Gateway's outbound IPs must be allowed, or the Key Vault must be accessible via private endpoint from the App Gateway subnet. A locked-down Key Vault is the #1 cause of SSL deployment failures.

**Certificate auto-renewal.** App Gateway polls Key Vault every 4 hours for certificate updates. **Always use versionless secret IDs** (no version GUID at the end) — this way, when you renew the cert in Key Vault, the gateway picks up the new version automatically without any Terraform changes.

**Wrong secret ID format.** This is correct: `https://kv-name.vault.azure.net/secrets/cert-name`. This is wrong: `https://kv-name.vault.azure.net/certificates/cert-name`. The gateway silently fails to load the cert if you use the certificates path, and listeners fall back to no SSL.

**Priority uniqueness.** Each routing rule needs a unique priority. The redirect entry must have a different priority than the main HTTPS rule.
