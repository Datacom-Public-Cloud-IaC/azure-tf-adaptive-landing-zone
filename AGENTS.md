# AGENTS.md — LLM context for this repository

This repository is the **engineering hub and development workspace** for the Datacom Adaptive Landing Zone platform. It vendors all constituent repositories (IaC modules, tooling, documentation) into a single workspace for AI-assisted development.

## Purpose

The Datacom ALZ platform spans 20+ repositories. This repo exists to:
1. **Vendor all repos** into `vendor/` for AI context — so agents can reason across the full platform
2. **Centralize issue tracking** — all platform issues live here, tagged by affected repo
3. **Provide development-focused agents** — for improving modules, not deploying them

> **Not for deployment.** To deploy ALZ for a customer, use [azure-tf-platform-agentic-helper](https://github.com/Datacom-Public-Cloud-IaC/azure-tf-platform-agentic-helper) directly.

## ⚠️ This repo does NOT contain module code

This is an **engineering hub**, not a code repository. Each IaC module lives in its own repo under `Datacom-Public-Cloud-IaC/`. The `vendor/` directory provides read-only copies for cross-repo AI reasoning.

**When creating a new module**, create it as a new repository — do not add code here.

### Workflow: creating a new workload module

1. **Use this repo for context** — vendor in the relevant repos to understand patterns and conventions
2. **Create the new repo** under `Datacom-Public-Cloud-IaC/` following the naming convention:
   - Platform modules: `azure-tf-platform-{domain}-{component}` (e.g., `azure-tf-platform-connectivity-hub`)
   - Workload modules: `azure-tf-workload-{name}` (e.g., `azure-tf-workload-sharedappgateway`)
3. **Follow the workload template** at [`azure-tf-workload-template`](https://github.com/Datacom-Public-Cloud-IaC/azure-tf-workload-template) for structure:
   - `iac/` — Terraform code using `main.{domain}.tf`, `variables.{domain}.tf`, `locals.{domain}.tf` pattern
   - `iac/environments/` — tfvars for PoC and enterprise deployment modes
   - `docs/adr/` — Architecture Decision Records
   - `docs/tutorials/` — Practical guides
   - `schemas/` — JSON schema for YAML validation (if applicable)
4. **Add the new repo to a manifest** in `manifests/` so it can be vendored for future development
5. **Track issues here** — file issues in this repo tagged with the new module's repo name

### What goes where

| Content | Where it lives | Example |
|---------|---------------|---------|
| Terraform module code | Own repo under `Datacom-Public-Cloud-IaC/` | `azure-tf-workload-sharedappgateway` |
| Cross-repo issues | This repo (issue tracker) | `azure-tf-adaptive-landing-zone#42` |
| Vendored read-only copies | `vendor/` (git-ignored, populated by `make`) | `vendor/workload-sharedappgateway/` |
| Vendor manifests | `manifests/*.yaml` in this repo | `development-iac.yaml` |
| Deployment guidance | `azure-tf-platform-agentic-helper` | Skills, prompts, agents |

## Quick start

```bash
# Prerequisites: dcrsync installed (see agentic-helper skill: alz-dcrsync-install)
make vendor          # Vendor IaC repos (baseline deployment set)
make vendor-iac      # Vendor all IaC repos (full development context)
make vendor-tools    # Vendor tooling repos (agentic-helper, doc-gen)
make vendor-full     # Vendor everything (IaC + tools)
```

## Repository structure

```
azure-tf-adaptive-landing-zone/
├── AGENTS.md                    # This file — AI context for development
├── Makefile                     # Vendor targets
├── manifests/                   # dcrsync manifest files
│   ├── deployment-baseline.yaml # Baseline repos for customer deployments
│   ├── development-iac.yaml     # All IaC repos for dev context
│   ├── development-tools.yaml   # Tooling repos (helper, doc-gen)
│   ├── development-full.yaml    # IaC + tools combined
│   └── *.csv                    # Naming convention templates
├── hooks/
│   └── post-checkout            # Auto-symlink vendor for worktrees
├── .github/
│   └── ISSUE_TEMPLATE/          # Centralized issue forms
└── vendor/                      # git-ignored — populated by make
    ├── platform-*/              # IaC Terraform modules
    ├── agentic-helper/          # Deployment tooling
    └── doc-gen/                 # HLD document generation
```

## Vendored repositories

The `vendor/` directory is populated by [dcrsync](https://github.com/Datacom-Public-Cloud-IaC/dcrsync) from manifest files. It is **git-ignored** and cached at `~/.cache/alz-dev-vendor` (symlinked into the repo).

### Manifest strategy

| Manifest | Purpose | When to use |
|----------|---------|-------------|
| `deployment-baseline.yaml` | Core repos needed for customer ALZ deployments | Deployment work via agentic-helper |
| `development-iac.yaml` | All IaC repos (platform + workloads + testing) | Day-to-day IaC development |
| `development-tools.yaml` | Tooling repos (agentic-helper, doc-gen) | Working on the toolchain itself |
| `development-full.yaml` | IaC + tools combined | Full cross-platform reasoning |

### Vendor cache isolation

This repo uses `~/.cache/alz-dev-vendor` — separate from the agentic-helper's `~/.cache/alz-vendor`. This prevents cache collisions when both repos are active on the same machine.

## Platform repos by domain

### Automation
| Repo | Vendor path | Description |
|------|-------------|-------------|
| azure-tf-platform-automation-azuredevops | `platform-automation-azdo` | ADO project, repos, pipelines |
| azure-tf-platform-automation-github | `platform-automation-github` | GitHub Actions equivalent |
| azure-tf-platform-automation-runners | `platform-automation-runners` | Self-hosted build agents |
| azuredevops-pipeline-templates | `pipeline-templates` | Shared pipeline templates |

### Management
| Repo | Vendor path | Description |
|------|-------------|-------------|
| azure-tf-platform-management-policy | `platform-management-policy` | Azure Policy assignments + custom definitions |
| azure-tf-platform-management-amba | `platform-management-amba` | Azure Monitor Baseline Alerts |
| azure-tf-platform-management-iaas | `platform-management-iaas` | IaaS management (DCRs, VM insights) |

### Identity
| Repo | Vendor path | Description |
|------|-------------|-------------|
| azure-tf-platform-identity-rbac | `platform-identity-rbac` | Entra groups, role assignments |
| azure-tf-platform-identity-adds | `platform-identity-adds` | Active Directory Domain Services |

### Connectivity
| Repo | Vendor path | Description |
|------|-------------|-------------|
| azure-tf-platform-connectivity-hub | `platform-connectivity-hub` | Hub VNet, firewall, VPN gateway |
| azure-tf-platform-connectivity-dns | `platform-connectivity-dns` | Private DNS zones |
| azure-tf-platform-connectivity-afw-policy | `platform-connectivity-afw-policy` | Firewall policy rules |
| azure-tf-platform-connectivity-vwan | `platform-connectivity-vwan` | Virtual WAN alternative |
| azure-tf-platform-connectivity-bastion | `platform-connectivity-bastion` | Azure Bastion |
| azure-tf-platform-connectivity-arc | `platform-connectivity-arc` | Azure Arc onboarding |

### Governance & Vending
| Repo | Vendor path | Description |
|------|-------------|-------------|
| azure-tf-governance | `governance` | Management group hierarchy |
| azure-tf-applz-vending-azuredevops | `applz-vending-azdo` | Application landing zone provisioning |

### Workloads
| Repo | Vendor path | Description |
|------|-------------|-------------|
| azure-tf-workload-virtualmachines | `workload-virtualmachines` | VM workload patterns |
| azure-tf-workload-ai-landing-zone | `workload-ai-landing-zone` | AI/ML landing zone |
| azure-tf-workload-sql-managedinstance | `workload-sql-managedinstance` | SQL Managed Instance |
| azure-tf-workload-sharedappgateway | `workload-sharedappgateway` | Shared Application Gateway (WAF, SSL, YAML-driven) |

### Tooling
| Repo | Vendor path | Description |
|------|-------------|-------------|
| azure-tf-platform-agentic-helper | `agentic-helper` | Deployment guidance (agents, prompts, skills) |
| alz-hld-doc-gen | `doc-gen` | High-level design document generation |
| azure-tf-alz-integration-testing | `alz-integration-testing` | Cross-stack integration tests |

## Issue tracking

All platform issues are tracked centrally in this repo using GitHub issue forms. Each issue specifies:
- **Primary repo**: The main repo affected
- **Affected repos**: Other repos impacted (for cross-cutting concerns)

When referencing issues from PRs in implementation repos, use the full qualified form:
```
Fixes Datacom-Public-Cloud-IaC/azure-tf-adaptive-landing-zone#123
```

## Design principles

- **Hub, not a code repo** — this repo contains no module code. It vendors code from other repos for AI context and cross-repo reasoning.
- **Read-only vendoring** — vendored repos are for AI context, not for making changes. Work in the actual repo.
- **One module = one repo** — every IaC module (platform or workload) lives in its own repo under `Datacom-Public-Cloud-IaC/`
- **Manifest-driven** — all repo lists are in YAML manifests, not hardcoded
- **Cache-isolated** — this repo and the agentic-helper use separate vendor caches
- **Purpose-named** — manifests are named by their use case, not by size

## Relationship to other repos

| Repo | Relationship |
|------|--------------|
| `azure-tf-platform-agentic-helper` | Vendored here for context; used directly for ALZ deployment |
| `alz-hld-doc-gen` | Vendored here for context; produces `.recs.json` consumed by agentic-helper |
| `dcrsync` | CLI tool used by `make vendor`; not vendored (installed separately) |
| Platform IaC repos (20+) | Vendored here for AI context; deployed via ADO/GitHub pipelines |
