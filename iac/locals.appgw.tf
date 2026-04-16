# --- Application Gateway locals ---
# Loads YAML app configs and translates them to azapi ARM format.

locals {
  # YAML loading — discover and parse all .yaml files in the app config directory
  app_config_dir = var.app_config_dir != null ? "${path.root}/${var.app_config_dir}" : "${path.root}/environments/${var.env_code}"
  app_config_files = fileset(local.app_config_dir, "**/*.yaml")

  app_config_map = {
    for f in local.app_config_files :
    replace(replace(f, ".yaml", ""), "/", "-") => yamldecode(file("${local.app_config_dir}/${f}"))
  }

  # ARM resource ID prefix for sub-resource references
  agw_id = "${local.resource_group_id}/providers/Microsoft.Network/applicationGateways/${local.agw_name}"

  # --- Shared frontend infrastructure ---

  frontend_ip_configurations = concat(
    local.has_public_frontend ? [{
      name = "feip-public"
      properties = {
        public_ip_address = { id = module.public_ip_agw[0].public_ip_id }
      }
    }] : [],
    local.has_private_frontend ? [{
      name = "feip-private"
      properties = {
        private_ip_address           = var.private_ip_address
        private_ip_allocation_method = "Static"
        subnet                       = { id = local.effective_subnet_id }
      }
    }] : []
  )

  frontend_ports = [
    { name = "fp-http", properties = { port = 80 } },
    { name = "fp-https", properties = { port = 443 } }
  ]

  gateway_ip_configurations = [{
    name = "gwip-default"
    properties = { subnet = { id = local.effective_subnet_id } }
  }]

  # --- YAML-driven sub-resources ---

  backend_address_pools = flatten([
    for filekey, contents in local.app_config_map : [
      for key, value in try(contents.backend_address_pools, {}) : {
        name = value.name
        properties = {
          backend_addresses = concat(
            [for fqdn in try(value.fqdns, []) : { fqdn = fqdn } if fqdn != ""],
            [for ip in try(value.ip_addresses, []) : { ip_address = ip } if ip != ""]
          )
        }
      }
    ]
  ])

  backend_http_settings = flatten([
    for filekey, contents in local.app_config_map : [
      for key, value in try(contents.backend_http_settings, {}) : {
        name = value.name
        properties = merge(
          {
            port                                = value.port
            protocol                            = value.protocol
            cookie_based_affinity               = try(value.cookie_based_affinity, "Disabled")
            request_timeout                     = try(value.request_timeout, 30)
            pick_host_name_from_backend_address = try(value.pick_host_name_from_backend_address, false)
          },
          try(value.host_name, null) != null ? { host_name = value.host_name } : {},
          try(value.probe_name, null) != null ? {
            probe = { id = "${local.agw_id}/probes/${value.probe_name}" }
          } : {},
          try(value.trusted_root_certificate_names, null) != null ? {
            trusted_root_certificates = [
              for cert in value.trusted_root_certificate_names : {
                id = "${local.agw_id}/trustedRootCertificates/${cert}"
              }
            ]
          } : {}
        )
      }
    ]
  ])

  http_listeners = flatten([
    for filekey, contents in local.app_config_map : [
      for key, value in try(contents.http_listener, {}) : {
        name = value.name
        properties = merge(
          {
            frontend_ip_configuration = {
              id = "${local.agw_id}/frontendIPConfigurations/${value.frontend_ip_configuration_name}"
            }
            frontend_port = {
              id = "${local.agw_id}/frontendPorts/${value.frontend_port_name}"
            }
            protocol = value.protocol
          },
          try(value.host_name, null) != null ? { host_name = value.host_name } : {},
          try(value.host_names, null) != null ? { host_names = value.host_names } : {},
          try(value.ssl_certificate_name, null) != null ? {
            ssl_certificate = {
              id = "${local.agw_id}/sslCertificates/${value.ssl_certificate_name}"
            }
          } : {},
          try(value.require_server_name_indication, null) != null ? {
            require_server_name_indication = value.require_server_name_indication
          } : {},
          # Per-listener WAF policy reference
          try(module.app_waf_policies["${filekey}-${key}"].resource_id, null) != null ? {
            firewall_policy = {
              id = module.app_waf_policies["${filekey}-${key}"].resource_id
            }
          } : {}
        )
      }
    ]
  ])

  request_routing_rules = flatten([
    for filekey, contents in local.app_config_map : [
      for key, value in try(contents.request_routing_rules, {}) : {
        name = value.name
        properties = merge(
          {
            priority      = value.priority
            rule_type     = value.rule_type
            http_listener = { id = "${local.agw_id}/httpListeners/${value.http_listener_name}" }
          },
          try(value.backend_address_pool_name, null) != null ? {
            backend_address_pool = { id = "${local.agw_id}/backendAddressPools/${value.backend_address_pool_name}" }
          } : {},
          try(value.backend_http_settings_name, null) != null ? {
            backend_http_settings = { id = "${local.agw_id}/backendHttpSettingsCollection/${value.backend_http_settings_name}" }
          } : {},
          try(value.redirect_configuration_name, null) != null ? {
            redirect_configuration = { id = "${local.agw_id}/redirectConfigurations/${value.redirect_configuration_name}" }
          } : {},
          try(value.url_path_map_name, null) != null ? {
            url_path_map = { id = "${local.agw_id}/urlPathMaps/${value.url_path_map_name}" }
          } : {}
        )
      }
    ]
  ])

  health_probes = flatten([
    for filekey, contents in local.app_config_map : [
      for key, value in try(contents.health_probes, {}) : {
        name = value.name
        properties = merge(
          {
            protocol                              = value.protocol
            port                                  = try(value.port, null)
            path                                  = value.path
            interval                              = try(value.interval, 30)
            timeout                               = try(value.timeout, 30)
            unhealthy_threshold                    = try(value.unhealthy_threshold, 3)
            pick_host_name_from_backend_http_settings = try(value.pick_host_name_from_backend_http_settings, false)
          },
          try(value.host, null) != null ? { host = value.host } : {},
          try(value.match, null) != null ? {
            match = {
              status_codes = try(value.match.status_code, ["200-399"])
              body         = try(value.match.body, null)
            }
          } : {}
        )
      }
    ]
  ])

  redirect_configurations = flatten([
    for filekey, contents in local.app_config_map : [
      for key, value in try(contents.redirect_configurations, {}) : {
        name = value.name
        properties = merge(
          {
            redirect_type = value.redirect_type
          },
          try(value.target_listener_name, null) != null ? {
            target_listener = { id = "${local.agw_id}/httpListeners/${value.target_listener_name}" }
          } : {},
          try(value.target_url, null) != null ? { target_url = value.target_url } : {},
          {
            include_path         = try(value.include_path, true)
            include_query_string = try(value.include_query_string, true)
          }
        )
      }
    ]
  ])

  ssl_certificates = flatten([
    for filekey, contents in local.app_config_map : [
      for key, value in try(contents.ssl_certificates, {}) : {
        name = value.name
        properties = {
          key_vault_secret_id = value.key_vault_secret_id
        }
      }
    ]
  ])

  trusted_root_certificates = flatten([
    for filekey, contents in local.app_config_map : [
      for key, value in try(contents.trusted_root_certificates, {}) : {
        name = value.name
        properties = {
          data = try(value.data, null)
        }
      }
    ]
  ])

  url_path_maps = flatten([
    for filekey, contents in local.app_config_map : [
      for key, value in try(contents.url_path_maps, {}) : {
        name = value.name
        properties = merge(
          {
            default_backend_address_pool  = try(value.default_backend_address_pool_name, null) != null ? { id = "${local.agw_id}/backendAddressPools/${value.default_backend_address_pool_name}" } : null
            default_backend_http_settings = try(value.default_backend_http_settings_name, null) != null ? { id = "${local.agw_id}/backendHttpSettingsCollection/${value.default_backend_http_settings_name}" } : null
          },
          {
            path_rules = [
              for rule in value.path_rules : {
                name = rule.name
                properties = merge(
                  { paths = rule.paths },
                  try(rule.backend_address_pool_name, null) != null ? {
                    backend_address_pool = { id = "${local.agw_id}/backendAddressPools/${rule.backend_address_pool_name}" }
                  } : {},
                  try(rule.backend_http_settings_name, null) != null ? {
                    backend_http_settings = { id = "${local.agw_id}/backendHttpSettingsCollection/${rule.backend_http_settings_name}" }
                  } : {},
                  try(rule.redirect_configuration_name, null) != null ? {
                    redirect_configuration = { id = "${local.agw_id}/redirectConfigurations/${rule.redirect_configuration_name}" }
                  } : {}
                )
              }
            ]
          }
        )
      }
    ]
  ])

  # --- WAF config extraction ---
  # Per-listener WAF policies defined in YAML, keyed as "{filekey}-{listener_key}"
  waf_config = merge([
    for filekey, contents in local.app_config_map :
    {
      for key, value in try(contents.waf_config, {}) :
      "${filekey}-${key}" => value
    }
  ]...)

  # Default WAF policy settings for per-app policies
  waf_policy_settings_default = {
    enabled                                   = true
    mode                                      = var.waf_mode
    request_body_check                        = true
    file_upload_limit_in_mb                   = 100
    max_request_body_size_in_kb               = 128
    request_body_inspect_limit_in_kb          = 128
    js_challenge_cookie_expiration_in_minutes = 30
  }
}
