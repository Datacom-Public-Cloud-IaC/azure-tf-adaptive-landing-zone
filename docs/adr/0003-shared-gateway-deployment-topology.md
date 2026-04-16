# ADR-0003: Shared Gateway Deployment Topology

**Status:** Accepted
**Date:** 2026-04-16

## Context

Application Gateway v2 has significant fixed costs: the base SKU, public IP (required even for private-only configurations — Azure uses it for management-plane operations), WAF policy evaluation, and the operational overhead of TLS certificate rotation and health probe tuning. Deploying a dedicated gateway per workload is economically wasteful below ~5 apps and operationally burdensome at any scale because each gateway is an independent certificate, DNS, and WAF management surface.

The deployment topology decision has three dimensions:

1. **Subscription placement.** The ALZ management group hierarchy provides `Platform > Connectivity` (for hub networking) and `Corp > Shared Services` (for shared workloads). The gateway is both a network edge device and a shared workload — it doesn't fit cleanly into either.

2. **Cross-subscription networking.** Backend pools reference resources (VMs, private endpoints, internal load balancers) in workload subscriptions. The gateway must resolve backend FQDNs via private DNS zones hosted in the Connectivity subscription and route traffic through VNet peerings or Private Link.

3. **Capacity planning.** A single App Gateway v2 supports ~100 listeners (hard limit), but HTTP→HTTPS redirect pairs consume two listener slots per app, yielding a practical limit of ~50 apps. Once that limit approaches, the decision framework for splitting needs to be architectural, not reactive.

## Decision

Application Gateway is deployed as a shared service in a dedicated subscription under `Corp > Shared Services` in the management group hierarchy. The platform/connectivity team owns the gateway infrastructure (Terraform state, networking, base WAF policy), while app teams own their YAML configurations (see ADR-0001).

The gateway subnet is peered to the hub VNet for backend connectivity and linked to the private DNS zones in the Connectivity subscription for FQDN resolution. TLS certificates are stored in a Key Vault within the same subscription as the gateway (cross-subscription Key Vault access for App Gateway requires convoluted access policies and adds a cross-subscription dependency to every TLS handshake).

The module supports two deployment modes:
- **PoC mode**: Creates VNet, subnet, NSG, public IP, and managed identity — everything needed for a standalone deployment.
- **Enterprise mode**: Expects these resources to be pre-vended by the platform connectivity stack, accepting resource IDs as inputs.

Gateway splitting guidance: deploy a second gateway when approaching 40 listeners (leaving headroom), when regulatory boundaries require traffic isolation (e.g., PCI vs non-PCI), or when separate teams need independent change velocity on their gateway infrastructure.

## Consequences

### Positive
- Single point of TLS termination, WAF enforcement, and access logging for all onboarded apps — consistent security posture without per-workload configuration drift.
- Cost amortisation across apps: one WAF_v2 SKU instance (~$350/mo base) serves 30+ apps instead of each paying individually.
- Platform team maintains a single certificate rotation pipeline, health probe baseline, and WAF tuning workflow.
- The PoC/enterprise mode split means the module works for proof-of-concept demos (spin up everything) and production deployments (integrate with existing network topology) without forking.

### Negative
- Blast radius: a misconfigured listener or a bad WAF rule can affect all apps on the gateway. Mitigated by Detection-mode WAF default (see ADR-0004) and per-app WAF policy overrides, but the risk is structural.
- Cross-subscription networking adds complexity: VNet peering, NSG rules, private DNS zone links, and RBAC grants must all be coordinated. A backend in a workload subscription needs the gateway's managed identity to have network line-of-sight and DNS resolution.
- The ~50 app practical limit means capacity planning is a recurring concern. Unlike a load balancer that scales linearly, App Gateway has a hard ceiling that requires architectural intervention (adding a second gateway) rather than just scaling up.

### Trade-offs
- Shared ownership model creates a coordination cost: the platform team and app teams must agree on the YAML contract, naming conventions, and change management process. This is slower than "each team owns their own gateway" but produces more consistent outcomes.
- Placing the gateway in `Corp > Shared Services` rather than `Platform > Connectivity` means it inherits workload-tier policies rather than platform-tier policies. This is intentional — the gateway is closer to a workload concern (app routing) than a connectivity concern (network topology), even though it sits at the network edge.

## Alternatives Considered

### Per-workload Application Gateway
Each app team deploys their own gateway in their workload subscription. Maximum isolation, independent change velocity, no shared blast radius. Rejected because App Gateway v2's minimum cost (~$350/mo + WAF) is excessive for individual workloads, and the operational burden of N independent gateways (certificate management, WAF tuning, health probe configuration) doesn't scale. Appropriate for workloads with strict regulatory isolation requirements — the module doesn't prevent this, it just optimises for the shared case.

### Gateway in Platform > Connectivity subscription
Placing the gateway alongside the hub firewall and VPN gateway. Logically appealing — it's a network ingress point. Rejected because Connectivity subscription changes are high-ceremony (platform team only, strict change windows), and app onboarding via YAML PRs needs a faster change cycle. Shared Services allows a more permissive RBAC model where app teams can contribute configurations without accessing core networking.

### Azure Front Door as the shared ingress
Front Door provides global load balancing, WAF, and TLS termination as a managed service — no infrastructure to manage. Rejected as the sole ingress because Front Door doesn't support private backends without Private Link origins (added in Premium SKU at significant cost), and many enterprise workloads have backends that are only reachable via VNet-internal IPs. Front Door is complementary (global edge acceleration) rather than a replacement for App Gateway (regional L7 routing with full VNet integration). Some deployments may use both — Front Door at the edge, App Gateway for internal routing.

### App Gateway for Containers
The next-generation ingress from Microsoft, natively Kubernetes-aware and eliminating some App Gateway v2 limitations (no public IP requirement for private-only, better scaling). Rejected as premature — at the time of this decision, it was in public preview with limited feature parity (no WAF integration, limited rewrite rules). Should be re-evaluated as it reaches GA and feature parity, particularly for greenfield deployments.
