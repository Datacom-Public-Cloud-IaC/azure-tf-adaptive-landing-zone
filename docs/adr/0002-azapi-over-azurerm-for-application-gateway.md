# ADR-0002: azapi Over azurerm for Application Gateway

**Status:** Accepted
**Date:** 2026-04-16

## Context

Azure Application Gateway v2 is one of the most complex resources in the Azure control plane. It contains deeply nested sub-resources (listeners, rules, backend pools, health probes, URL path maps, rewrite rule sets, redirect configurations) that cross-reference each other by resource ID. The azurerm provider historically flattened this structure into a single Terraform resource with 40+ arguments, many of which are interdependent lists where ordering matters and Terraform's diff algorithm produces confusing plan output.

More critically, the azurerm provider consistently lagged behind the ARM API for App Gateway features — private link configurations, mutual TLS, header rewrites, and WAF policy association all shipped in ARM months before azurerm support appeared. For a shared gateway serving production traffic, waiting for provider releases to adopt security or performance features is not acceptable.

The kewalaka AVM fork wraps azapi with opinionated defaults and input validation, providing a middle ground between raw ARM payloads and the azurerm abstraction. However, this fork is not upstreamed to the official AVM registry, creating a dependency on a single maintainer.

## Decision

The Application Gateway resource and WAF policy are managed via the azapi provider (through kewalaka's AVM module fork). Supporting resources — public IP, user-assigned managed identity, NSG, subnet, and diagnostic settings — remain on azurerm.

The split is pragmatic: azapi is used where the azurerm abstraction causes friction (complex nested sub-resources, feature lag), and azurerm is used where it works well (simple, stable resource types that rarely gain new properties).

The ARM payload is constructed in Terraform using `jsonencode()` over HCL objects built from the YAML-decoded app configurations. This means the Terraform code is effectively a compiler from YAML→HCL objects→JSON→ARM API, which is verbose but explicit.

## Consequences

### Positive
- Day-zero access to any App Gateway feature the ARM API supports — no waiting for azurerm provider releases.
- The ARM payload in Terraform mirrors the Azure documentation exactly, making it easier to cross-reference with Microsoft Learn docs and Azure CLI examples.
- WAF policy association at the listener level (not just gateway level) was available via azapi before azurerm supported it, which directly enabled the two-layer WAF strategy (see ADR-0004).
- Lifecycle management of sub-resources is more predictable — azapi replaces the full resource body, avoiding the partial-update bugs that azurerm occasionally exhibited with App Gateway.

### Negative
- No plan-time type checking. A typo in an ARM property name (`backendHttpSettingsCollection` vs `backendHttpSettings`) won't fail until apply, sometimes producing cryptic ARM API errors.
- Terraform state contains raw ARM JSON, which is harder to inspect and debug than azurerm's flattened attributes.
- Contributors need ARM API familiarity in addition to Terraform knowledge — the pool of people who can confidently modify the gateway module is smaller.
- The kewalaka AVM fork is a single-maintainer dependency. If that fork is abandoned, we'd need to either upstream it, fork it again, or migrate to azurerm (a significant effort given the structural differences).

### Trade-offs
- We trade developer ergonomics (type checking, readable plan output, familiar azurerm patterns) for feature velocity and API fidelity. This is the right trade for a resource as complex and fast-evolving as App Gateway, but would be the wrong trade for a storage account or a resource group.
- The mixed provider approach (azapi for gateway, azurerm for everything else) adds cognitive load but avoids the extremes of either full-azapi (unnecessary complexity for simple resources) or full-azurerm (blocked by provider feature gaps).

## Alternatives Considered

### Pure azurerm provider
The natural default. Mature, well-documented, good plan output, type-safe. Rejected because azurerm's App Gateway resource has historically been one of its most problematic — list ordering bugs, missing feature support, and forced replacements on changes that the ARM API handles as in-place updates. The azurerm 4.0 rewrite improved some of these issues, but gaps remain for features like per-listener WAF policy association and certain rewrite rule capabilities.

### Pure azapi for all resources
Eliminates the mixed-provider cognitive load. Rejected because azapi adds unnecessary friction for simple resources (public IPs, NSGs, subnets) where azurerm is stable and ergonomic. Using azapi for a public IP means writing ARM JSON for something that's a 5-line azurerm resource — complexity without benefit.

### Upstream AVM Application Gateway module
The official Azure Verified Modules registry has an App Gateway module. Rejected at evaluation time because it lagged behind on private frontend support and WAF policy listener-level association. The kewalaka fork was already production-proven in the UC Digital deployment. We should periodically re-evaluate as the upstream AVM module matures — if it reaches feature parity, migrating to it would remove the single-maintainer risk.
