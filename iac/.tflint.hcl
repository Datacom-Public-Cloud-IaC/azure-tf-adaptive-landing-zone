config {
  format     = "compact"
  plugin_dir = "~/.tflint.d/plugins"
  varfile    = ["environments/examples/poc.tfvars"]
}

plugin "terraform" {
  enabled = true
  version = "0.14.1"
  source  = "github.com/terraform-linters/tflint-ruleset-terraform"
}

plugin "azurerm" {
  enabled = true
  version = "0.30.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}

rule "terraform_comment_syntax" { enabled = true }
rule "terraform_deprecated_index" { enabled = true }
rule "terraform_deprecated_interpolation" { enabled = true }
rule "terraform_deprecated_lookup" { enabled = true }
rule "terraform_documented_outputs" { enabled = true }
rule "terraform_documented_variables" { enabled = true }
rule "terraform_empty_list_equality" { enabled = true }
rule "terraform_map_duplicate_keys" { enabled = true }
rule "terraform_module_pinned_source" { enabled = true }
rule "terraform_module_version" { enabled = true }
rule "terraform_naming_convention" { enabled = true }
rule "terraform_required_providers" { enabled = true }
rule "terraform_required_version" { enabled = true }
rule "terraform_typed_variables" { enabled = true }
rule "terraform_unused_declarations" { enabled = true }
rule "terraform_workspace_remote" { enabled = true }

# Disabled: we use main.{component}.tf pattern
rule "terraform_standard_module_structure" { enabled = false }
