# Learnings — Shared App Gateway Module

Gotchas, migration insights, and design decisions discovered while building this module. For future maintainers.

## azapi vs azurerm naming differences

The ARM REST API uses different collection names than the azurerm provider attributes. For example, the ARM property is `backend_http_settings_collection` (not `backend_http_settings`), and `probes` (not `health_probes`). When building azapi payloads from YAML, the field names in the ARM body must match the API spec exactly — not the azurerm schema. Always cross-reference the [ARM template reference](https://learn.microsoft.com/en-us/azure/templates/microsoft.network/applicationgateways) when adding new sub-resource types.

## ARM resource ID construction

Sub-resource references within the App Gateway body use the pattern `{appGatewayId}/{subResourceType}/{subResourceName}`. The sub-resource types are **camelCase** — e.g., `backendHttpSettingsCollection`, `frontendIPConfigurations`, `httpListeners`, `urlPathMaps`. Getting the casing wrong produces a successful `terraform apply` followed by a broken gateway. The `locals.appgw.tf` file centralises all ID construction to keep this consistent.

## YAML uniqueness constraint

All sub-resource names must be globally unique across every YAML file loaded into a single gateway. If two apps both define a backend pool called `beap1`, one silently overwrites the other during the map merge. Routing rule priorities must also be unique — duplicate priorities cause ARM validation failures. The `_template.yaml` documents this, but there is no compile-time check yet.

## Key Vault secret ID format

When referencing SSL certificates from Key Vault, the `key_vault_secret_id` must use the `/secrets/` path — not `/certificates/`. This is counterintuitive but is what the ARM API expects for App Gateway certificate references. Use the **versionless** URI (e.g., `https://kv.vault.azure.net/secrets/cert-name`) so the gateway automatically picks up renewed certificates.

## WAF listener key matching

Per-listener WAF policies are defined in the `waf_config` YAML section. The map key under `waf_config` **must exactly match** the corresponding key under `http_listener` for that app. This is how the module correlates WAF policies to listeners. A typo in the key silently produces an unbound WAF policy — the listener gets only the global baseline protection.

## Zones parameter

The azapi provider expects `zones` as `list(string)` (e.g., `["1", "2", "3"]`), whereas azurerm uses `set(number)`. The module accepts `list(number)` from the user and converts with `[for z in var.zones : tostring(z)]` in the azapi body. Forgetting this conversion causes a type error at plan time.

## Private IP requirement

Even for `public_only` gateways, App Gateway v2 always requires a Public IP resource for the management plane. The `frontend_mode` variable controls which frontend IP configurations are created for *traffic*, but the Public IP is always provisioned. This is an Azure platform requirement, not a module design choice.

## NSG requirements

App Gateway v2 requires an inbound NSG rule allowing `GatewayManager` service tag on ports **65200–65535**. Without this rule, the gateway's backend health probes fail and the resource shows as unhealthy in the portal. The module creates this rule automatically when provisioning a new NSG, but when using an existing NSG (`existing_network_security_group_id`), the operator must ensure this rule exists.

## Subnet sizing

Microsoft recommends a minimum **/24** subnet for App Gateway v2. The gateway consumes one private IP per instance during scaling, plus IPs during blue-green deployments. A /26 works for PoC (the example uses one), but production gateways with autoscale should use /24 to avoid IP exhaustion during scale-out events.

## Conditional references with try()

When building the ARM JSON payload, use `try()` liberally around optional field references. A `null` value in a required ARM property causes the deployment to fail with an opaque error. For example, `probe_name` is optional in backend HTTP settings — if the YAML omits it, the ARM payload must omit the `probe` sub-object entirely rather than setting it to `null`. The pattern is: `try({ probe = { id = "..." } }, {})` with merge to conditionally include the field.
