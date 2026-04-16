# Tutorial 04: Private Application Gateway

Deploy an internal-only App Gateway for apps that should never be internet-reachable, with backends in workload subscriptions accessed via VNet peering.

## tfvars Configuration

```hcl
location            = "australiaeast"
resource_group_name = "rg-appgw-internal"
appgw_name          = "agw-internal-aue-001"

poc_mode = false   # Enterprise mode — use vended VNet/subnet

frontend_mode      = "private_only"
private_ip_address  = "10.0.4.10"

sku_name     = "Standard_v2"
sku_tier     = "Standard_v2"
sku_capacity = 2

# Reference the pre-provisioned subnet
subnet_id = "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Network/virtualNetworks/{vnet}/subnets/snet-appgw"

app_config_path = "./apps"
```

## App YAML for Private Listener

The only difference from a public config: listeners reference `feip-private` instead of `feip-public`.

```yaml
# apps/internal-api.yaml
internal-api:
  priority: 100
  backend_address_pool:
    fqdns:
      - "workload-api.internal.example.com"
  backend_http_settings:
    port: 443
    protocol: "Https"
    request_timeout: 30
    host_name: "workload-api.internal.example.com"
    probe_name: "internal-api"
  http_listener:
    frontend_ip_configuration_name: "feip-private"   # ← private frontend
    frontend_port_name: "fp-https"
    protocol: "Https"
    host_name: "api.corp.example.com"
    ssl_certificate_name: "wildcard-corp"
  request_routing_rule:
    rule_type: "Basic"
  probe:
    protocol: "Https"
    path: "/health"
    host: "workload-api.internal.example.com"
    interval: 30
    timeout: 30
    unhealthy_threshold: 3
```

## Networking Requirements

### Subnet Sizing

The App Gateway subnet must be **/24 or larger** and **dedicated** — no other resources (VMs, Private Endpoints, etc.) can live in it. App Gateway v2 can scale to 125 instances, each consuming one IP.

### The "Phantom" Public IP

Even with `frontend_mode = "private_only"`, App Gateway v2 **always allocates a public IP** for Azure's management plane. No listeners bind to it — it's used solely for internal health checks and configuration updates. You cannot avoid this; it's a platform requirement. Your NSG and policies should reflect that this IP exists but carries no application traffic.

### VNet Peering to Workload Subscriptions

```
Hub VNet (App Gateway)  ←→  Spoke VNet (Workload)
   10.0.0.0/16                 10.1.0.0/16
   snet-appgw: 10.0.4.0/24    snet-app: 10.1.1.0/24
```

Peering checklist:
- **Allow forwarded traffic** on both peering connections
- **Allow gateway transit** if the hub has a VPN/ER gateway
- **No overlapping address spaces** between hub and spokes
- **UDRs:** If you have a firewall NVA, ensure App Gateway subnet UDR does NOT route to it — App Gateway doesn't support asymmetric routing. The return path must go directly back through the gateway.

### DNS Resolution

Backends using Private Endpoints (e.g., `*.privatelink.azurewebsites.net`) require the Private DNS Zone to be **linked to the App Gateway's VNet**. Without this, the gateway can't resolve backend FQDNs and probes fail.

```bash
# Verify DNS resolution from the gateway's perspective
az network private-dns zone show \
  -g rg-dns -n privatelink.azurewebsites.net \
  --query "virtualNetworkLinks[].virtualNetwork.id" -o tsv
# Must include the App Gateway VNet
```

### Health Probe Reachability

The gateway probes backends **from its own subnet**. Ensure:
- Backend NSGs allow inbound on the probe port from the App Gateway subnet CIDR
- No NVA or firewall blocks the probe path
- If the backend is in a different subscription, the peering + NSG rules span both subs

## Private Link (Cross-Tenant Access)

If consumers outside your tenant or region need to reach this gateway, enable Private Link:

```hcl
enable_private_link = true

private_link_configuration = {
  name      = "pl-appgw-internal"
  subnet_id = "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Network/virtualNetworks/{vnet}/subnets/snet-appgw-pl"
}
```

This exposes the gateway via a Private Link Service. Consumers create a Private Endpoint in their own VNet and connect to it — no peering or VPN required. The Private Link subnet must be **separate** from the App Gateway subnet.

## Verify

```bash
# From a VM in a peered VNet:
curl -v https://api.corp.example.com/health \
  --resolve api.corp.example.com:443:10.0.4.10

# Check backend health
az network application-gateway show-backend-health \
  -g rg-appgw-internal -n agw-internal-aue-001 \
  --query backendAddressPools[].backendHttpSettingsCollection[].servers[]
```

## Gotchas

**Private IP must be in-subnet.** The `private_ip_address` must fall within the App Gateway subnet CIDR. If the subnet is `10.0.4.0/24`, valid IPs are `10.0.4.4` through `10.0.4.254` (Azure reserves the first four and last one).

**Asymmetric routing kills App Gateway.** Never route App Gateway subnet traffic through an NVA/firewall. The return traffic must flow directly back to the client. This is the most common cause of intermittent 502s in hub-spoke topologies.

**DNS is the other common failure.** If backend health shows "Unknown" instead of "Healthy" or "Unhealthy", the gateway almost certainly can't resolve the backend FQDN. Link your Private DNS Zones to the gateway's VNet.
