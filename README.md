# Adaptive Landing Zone

Engineering hub and development workspace for the Datacom Azure Landing Zone platform.

## What is this?

The Datacom ALZ platform spans 20+ repositories (Terraform modules for connectivity, management, identity, governance, workloads, and automation). This repo aggregates them into a single workspace for AI-assisted development.

**This is not a deployable product.** To deploy ALZ for a customer, use [azure-tf-platform-agentic-helper](https://github.com/Datacom-Public-Cloud-IaC/azure-tf-platform-agentic-helper).

## Getting started

### Prerequisites

- [dcrsync](https://github.com/Datacom-Public-Cloud-IaC/dcrsync) installed
- Git access to Datacom-Public-Cloud-IaC org repos

### Vendor repos for AI context

```bash
git clone https://github.com/Datacom-Public-Cloud-IaC/azure-tf-adaptive-landing-zone.git
cd azure-tf-adaptive-landing-zone

# Choose your scope:
make vendor          # Baseline deployment repos (7 repos)
make vendor-iac      # All IaC repos (20+ repos)
make vendor-tools    # Tooling repos (agentic-helper, doc-gen)
make vendor-full     # Everything
```

The vendored repos appear in `vendor/` (symlinked to `~/.cache/alz-dev-vendor`).

### Worktree support

Install the post-checkout hook to auto-symlink vendor in worktrees:

```bash
cp hooks/post-checkout .git/hooks/ && chmod +x .git/hooks/post-checkout
```

## Manifests

| Manifest | Repos | Use case |
|----------|-------|----------|
| `deployment-baseline.yaml` | 7 | Customer ALZ deployments |
| `development-iac.yaml` | 21 | IaC module development |
| `development-tools.yaml` | 2 | Toolchain development |
| `development-full.yaml` | 23 | Full cross-platform reasoning |

## Issue tracking

All platform issues are tracked centrally here. Use the issue templates to file bugs, features, or tasks — each form includes a repo selector.

When referencing these issues from PRs in other repos:
```
Fixes Datacom-Public-Cloud-IaC/azure-tf-adaptive-landing-zone#123
```

## Related repos

| Repo | Purpose |
|------|---------|
| [azure-tf-platform-agentic-helper](https://github.com/Datacom-Public-Cloud-IaC/azure-tf-platform-agentic-helper) | ALZ deployment guidance (agents, prompts, skills) |
| [alz-hld-doc-gen](https://github.com/Datacom-Public-Cloud-IaC/alz-hld-doc-gen) | High-level design document generation |
| [dcrsync](https://github.com/Datacom-Public-Cloud-IaC/dcrsync) | Multi-repo vendoring tool |
