.PHONY: vendor vendor-iac vendor-tools vendor-full

# Shared vendor cache for git worktrees.
# Isolated from the agentic-helper's cache (~/.cache/alz-vendor).
VENDOR_CACHE := $(HOME)/.cache/alz-dev-vendor

# --- Vendoring Targets ---
# Populate vendor cache with repos for local AI context.
# Requires: dcrsync installed (see agentic-helper skill: alz-dcrsync-install)

# Baseline repos only (customer deployments)
vendor:
	dcrsync build -m manifests/deployment-baseline.yaml -t $(VENDOR_CACHE)/
	@[ -L vendor ] || [ ! -e vendor ] && ln -sfn $(VENDOR_CACHE) vendor || echo "vendor/ exists and is not a symlink — remove it first"

# All IaC repos (development context)
vendor-iac:
	dcrsync build -m manifests/development-iac.yaml -t $(VENDOR_CACHE)/
	@[ -L vendor ] || [ ! -e vendor ] && ln -sfn $(VENDOR_CACHE) vendor || echo "vendor/ exists and is not a symlink — remove it first"

# Tooling repos only (agentic-helper, doc-gen)
vendor-tools:
	dcrsync build -m manifests/development-tools.yaml -t $(VENDOR_CACHE)/
	@[ -L vendor ] || [ ! -e vendor ] && ln -sfn $(VENDOR_CACHE) vendor || echo "vendor/ exists and is not a symlink — remove it first"

# Everything (IaC + tools — full cross-platform context)
vendor-full:
	dcrsync build -m manifests/development-full.yaml -t $(VENDOR_CACHE)/
	@[ -L vendor ] || [ ! -e vendor ] && ln -sfn $(VENDOR_CACHE) vendor || echo "vendor/ exists and is not a symlink — remove it first"
