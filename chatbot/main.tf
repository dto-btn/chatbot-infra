/****************************************************
*                       RG                          *
*****************************************************/
resource "azurerm_resource_group" "main" {
  name     = "${var.name_prefix}-${var.project_name}-rg"
  location = var.default_location
}

data "azurerm_client_config" "current" {}

resource "azurerm_source_control_token" "main" {
  type = "GitHub"
  token = var.personal_token
}

data "azurerm_subscription" "current" {}

/****************************************************
*                       STORAGE                     *
*****************************************************/
resource "azurerm_storage_account" "main" {
  name                     = "${var.project_name_short_lowercase}storage"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = var.default_location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = var.env
  }
}

resource "azurerm_storage_share" "main" {
  name                 = "${var.name_prefix_lowercase}-${var.project_name_lowercase}-fs"
  storage_account_name = azurerm_storage_account.main.name
  quota                = 5
}

resource "azurerm_storage_share_directory" "main" {
  for_each              = toset([for _, v in flatten(fileset(path.module, "indices/**")): dirname(trim(v, "indices/"))])
  name                  = each.key
  share_name            = azurerm_storage_share.main.name
  storage_account_name  = azurerm_storage_account.main.name
}

resource "azurerm_storage_share_file" "main" {
  for_each          = fileset(path.module, "indices/**")
  
  name              = basename(each.key)
  storage_share_id  = azurerm_storage_share.main.id
  source            = each.key
  path              = dirname(trim(each.key, "indices/"))
  depends_on = [ azurerm_storage_share_directory.main ]
}

/****************************************************
*                    REGISTRY                       *
*****************************************************/

resource "azurerm_container_registry" "main" {
  name                = "${var.name_prefix_lowercase}${var.project_name_lowercase}registry"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.default_location
  sku                 = "Standard"
  admin_enabled       = true
}

# TODO: find a better way to create an automated build, 
#       ideally this should be done via github actions..
resource "azurerm_container_registry_task" "main" {
  name                  = "build-${var.api_version_sha}"
  container_registry_id = azurerm_container_registry.main.id

  platform {
    os = "Linux"
  }

  docker_step {
    dockerfile_path      = "Dockerfile"
    context_path         = "https://github.com/dto-btn/openai-app-poc.git#${var.api_version_sha}"
    context_access_token = var.personal_token
    image_names          = ["${azurerm_container_registry.main.login_server}/chatbot-api:${var.api_version}"]
  }

}

resource "azurerm_container_registry_task_schedule_run_now" "main" {
  container_registry_task_id = azurerm_container_registry_task.main.id
}
/****************************************************
*                    Key Vault                      *
*****************************************************/
# TODO: provising this item inside the new infrastructure repository
data "azurerm_key_vault" "infra" {
  name = "ScDC-CIO-DTO-Infra-kv"
  resource_group_name = "ScDc-CIO-DTO-Infrastructure-rg"
  provider = azurerm.dev
}

/****************************************************
*                       ROLES                       *
*****************************************************/

resource "azurerm_user_assigned_identity" "api" {
  resource_group_name = azurerm_resource_group.main.name
  location            = var.default_location
  name                = "chatbot-api-identity"
}

resource "azurerm_user_assigned_identity" "frontend" {
  resource_group_name = azurerm_resource_group.main.name
  location            = var.default_location
  name                = "chatbot-frontend-identity"
}

/* need Owner role on SP to be able to perform this assignment */
resource "azurerm_role_assignment" "container_registry" {
    scope                 = azurerm_container_registry.main.id
    role_definition_name  = "AcrPull"
    principal_id          = azurerm_user_assigned_identity.api.principal_id
}

resource "azurerm_key_vault_access_policy" "infra" {
  key_vault_id          = data.azurerm_key_vault.infra.id
  object_id             = azurerm_container_app.main.identity.0.principal_id
  tenant_id             = azurerm_container_app.main.identity.0.tenant_id
  secret_permissions    = ["Get", "List"]
  provider              = azurerm.dev
}

/****************************************************
*                 CONTAINER APP                     *
*****************************************************/
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.name_prefix_lowercase}-${var.project_name_lowercase}-ws"
  location            = var.default_location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "main" {
  name                       = "${var.name_prefix}-${var.project_name}-env"
  location                   = var.default_location
  resource_group_name        = azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  infrastructure_subnet_id   = azurerm_subnet.backend.id
  internal_load_balancer_enabled = true
  depends_on = [ azurerm_container_registry_task_schedule_run_now.main ]
}

resource "azurerm_container_app_environment_storage" "main" {
  name                         = "app-fs"
  container_app_environment_id = azurerm_container_app_environment.main.id
  account_name                 = azurerm_storage_account.main.name
  share_name                   = azurerm_storage_share.main.name
  access_key                   = azurerm_storage_account.main.primary_access_key
  access_mode                  = "ReadWrite"
  depends_on = [ azurerm_storage_share_file.main  ] #indices can be big and take a while to be uploaded
}

resource "azurerm_container_app" "main" {
  name                         = "${var.name_prefix_lowercase}-${var.project_name_lowercase}-app"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"
  depends_on = [ azurerm_container_registry_task_schedule_run_now.main ]

  identity {
    type = "SystemAssigned, UserAssigned"
    identity_ids = [ azurerm_user_assigned_identity.api.id ]
  }

  registry {
    identity = azurerm_user_assigned_identity.api.id
    server = azurerm_container_registry.main.login_server
  }

  ingress {
    external_enabled = true
    target_port = 5000
    traffic_weight {
      percentage = 100
      latest_revision = true
    }
  }

  template {

    min_replicas = 1

    container {
      name   = "api"
      image  = "${azurerm_container_registry.main.login_server}/chatbot-api:${var.api_version}"
      cpu    = 2
      memory = "4Gi"

      env {
        name = "KEY_VAULT_NAME"
        value = "ScDC-CIO-DTO-Infra-kv"
      }

      env {
        name = "OPENAI_ENDPOINT_NAME"
        value = var.openai_endpoint_name
      }

      env {
        name = "OPENAI_DEPLOYMENT_NAME"
        value = var.openai_deployment_name
      }

      env {
        name = "OPENAI_KEY_NAME"
        value = var.openai_key_name
      }

      env {
        name = "CONTEXT_WINDOW"
        value = var.context_window
      }

      volume_mounts {
        name = "app-fs" 
        path = "/app/storage"

      }
    }

    volume {
      name = "app-fs"
      storage_name = "app-fs"
      storage_type = "AzureFile"
    }
  }
}

/****************************************************
*                 Azure App frontend                *
*****************************************************/
resource "azurerm_service_plan" "frontend" {
  name                = "${var.name_prefix}-${var.project_name}-frontend-plan"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku_name            = "S1"
  os_type             = "Linux"
}

resource "azurerm_linux_web_app" "frontend" {
  name                = "${var.name_prefix}-${var.project_name}-frontend-wa"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_service_plan.frontend.location
  service_plan_id     = azurerm_service_plan.frontend.id

  virtual_network_subnet_id = azurerm_subnet.main.id

  client_affinity_enabled = true
  https_only = true

  site_config {
    ftps_state = "FtpsOnly"

    application_stack {
      node_version = "18-lts"
    }
    use_32_bit_worker = false

    app_command_line = "NODE_ENV=production node server.js"
  }

  app_settings = {
    VITE_API_BACKEND        = join("", ["https://", azurerm_container_app.main.ingress[0].fqdn])
    ENABLE_ORYX_BUILD       = true
    MICROSOFT_PROVIDER_AUTHENTICATION_SECRET = var.microsoft_provider_authentication_secret
    DB_CONN = azurerm_cosmosdb_account.db.connection_strings[0]
    PORT = 8080
  }

  sticky_settings {
    app_setting_names = [ "VITE_API_BACKEND", "ENABLE_ORYX_BUILD", "MICROSOFT_PROVIDER_AUTHENTICATION_SECRET", "DB_CONN", "PORT" ]
  }

  identity {
    type = "UserAssigned"
    identity_ids = [ azurerm_user_assigned_identity.frontend.id ]
  }

  dynamic "auth_settings_v2" {
    for_each = var.enable_auth == true ? [""] : []
    content {
      auth_enabled = true
      default_provider = "azureactivedirectory"
      require_authentication = true

      active_directory_v2 {
        client_id = var.aad_client_id
        client_secret_setting_name = "MICROSOFT_PROVIDER_AUTHENTICATION_SECRET"
        tenant_auth_endpoint = var.aad_auth_endpoint
        allowed_audiences = ["api://${var.aad_client_id}"]
      }

      # apple_v2 {
      #   login_scopes = []
      # }

      # facebook_v2 {
      #   login_scopes = []
      # }

      # github_v2 {
      #   login_scopes = []
      # }

      # google_v2 {
      #   allowed_audiences = []
      #   login_scopes      = []
      # }

      login {
        token_store_enabled = true
      }
    }
  }
}