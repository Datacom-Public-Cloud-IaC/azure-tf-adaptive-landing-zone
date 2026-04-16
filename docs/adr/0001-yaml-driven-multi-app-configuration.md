# ADR-0001: YAML-Driven Multi-App Configuration

**Status:** Accepted
**Date:** 2026-04-16

## Context

A shared Application Gateway serves dozens of applications owned by different teams. Each team needs to onboard their app — defining listeners, backend pools, health probes, routing rules — without learning Terraform or touching shared infrastructure code. The UC Digital implementation proved this pattern at scale (~50 apps across 6 environments), but also exposed its rough edges: naming collisions between YAML files, opaque errors when the YAML→ARM translation produced invalid configurations, and a constant temptation to add "just one more field" to the YAML schema until it became a shadow DSL for ARM.

The core tension is between **app-team autonomy** (teams own their config, submit PRs, iterate independently) and **infrastructure coherence** (all configs compile into a single Application Gateway resource with globally-unique sub-resource names, consistent naming conventions, and valid cross-references between listeners, rules, and backends).

## Decision

Application configurations are defined as individual YAML files (one per app), loaded by Terraform using `fileset()` + `yamldecode()`, and translated into the ARM sub-resource blocks that azapi expects. A JSON Schema validates each YAML file before Terraform runs, catching structural errors early.

Each YAML file declares:
- Frontend mode (`public_only`, `private_only`, `public_and_private`)
- Backend targets (IP or FQDN)
- Health probe configuration
- WAF policy overrides (if any)
- TLS certificate reference (Key Vault secret ID)

Terraform owns the translation layer: it reads all YAML files, generates deterministic resource names using a `{app_name}_{component}` convention, and assembles them into the gateway's sub-resource collections. Name uniqueness is enforced at the Terraform level by checking for collisions across all loaded YAML files before constructing the ARM payload.

## Consequences

### Positive
- App teams onboard via PR to a YAML file — no Terraform knowledge required, and code review is meaningful because reviewers can read the YAML without parsing HCL.
- Git history per YAML file gives clear audit trail of who changed what for which application.
- JSON Schema validation catches ~80% of errors before `terraform plan`, with actionable error messages that reference the YAML field, not an ARM API path.
- Adding a new application is additive — it doesn't modify existing configurations, reducing blast radius of PRs.

### Negative
- The YAML→ARM translation layer is a non-trivial piece of logic that's harder to debug than native HCL. When something fails at the ARM API level, the error references ARM resource paths that don't map obviously back to YAML fields.
- The YAML schema becomes a contract — changing it requires migration tooling or backwards-compatible evolution, similar to API versioning.
- Name uniqueness validation across files adds a pre-plan step that can confuse developers expecting `terraform plan` to be the single source of truth.

### Trade-offs
- We accept translation-layer complexity in exchange for a much lower barrier to onboarding. The alternative (teaching every app team Terraform) doesn't scale when the platform team supports 50+ application teams.
- The YAML schema will inevitably lag ARM API capabilities. We mitigate this with an escape-hatch field (`custom_properties`) but acknowledge it undermines schema validation when used.

## Alternatives Considered

### Terraform modules with for_each over tfvars maps
Keeps everything in HCL — plan output shows exactly what will change, type checking works natively, and there's no translation layer to debug. Rejected because tfvars maps are hard for non-Terraform users to author correctly (HCL map syntax is unforgiving), and a single `terraform.tfvars` file with 50 app definitions becomes an unreviable monolith. Per-app `.tfvars` files are possible but require custom loading logic that's no simpler than YAML loading.

### Terraform child modules (one module call per app)
Each app gets a module block in a root config. Clean HCL, good plan output, natural Terraform patterns. Rejected because adding an app requires modifying the root module — the platform team becomes a bottleneck for every onboarding. Also, 50 module blocks in a single root config is hard to navigate, and module versioning adds friction to what should be a simple config change.

### JSON configuration files
Structurally equivalent to YAML but harder to author by hand (no comments, strict syntax, trailing commas break parsing). JSON Schema validation would be slightly simpler (native format match). Rejected because YAML's readability advantage matters when app teams are the primary authors, and comments in YAML files serve as inline documentation that reduces support requests.
