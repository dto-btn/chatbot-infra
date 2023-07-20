/****************************************************
*                       RG                          *
*****************************************************/
resource "azurerm_resource_group" "main" {
  name     = "${var.name_prefix}-${var.project_name}-rg"
  location = var.default_location
}

data "azurerm_client_config" "current" {}

/****************************************************
*                       VNET                        *
*****************************************************/
resource "azurerm_network_security_group" "main" {
  name                = "${var.name_prefix}-${var.project_name}-sg"
  location            = var.default_location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.name_prefix}-${var.project_name}-vnet"
  location            = var.default_location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [ "10.2.0.0/16" ]
  dns_servers         = ["10.2.0.4", "10.2.0.5"]

  tags = {
    environment = "Pilot"
  }
}

resource "azurerm_subnet" "main" {
    name                  = "chatbot"
    address_prefixes      = ["10.2.0.0/20"]
    virtual_network_name  = azurerm_virtual_network.main.name
    resource_group_name   = azurerm_resource_group.main.name

    # delegation {
    #   name = "delegation"

    #   service_delegation {
    #     name    = "Microsoft.ContainerInstance/containerGroups"
    #     actions = ["Microsoft.Network/virtualNetworks/subnets/join/action", "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action"]
    #   }
    # }

}

resource "azurerm_subnet_network_security_group_association" "main" {
  network_security_group_id  = azurerm_network_security_group.main.id
  subnet_id                  = azurerm_subnet.main.id
}

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
    environment = "Pilot"
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

resource "azurerm_container_registry_task" "main" {
  name                  = "build-chatbot-api"
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

data "azurerm_key_vault" "infra" {
  name = "ScDC-CIO-DTO-Infra-kv"
  resource_group_name = "ScDc-CIO-DTO-Infrastructure-rg"
}

/****************************************************
*                       ROLES                       *
*****************************************************/

resource "azurerm_user_assigned_identity" "api" {
  resource_group_name = azurerm_resource_group.main.name
  location            = var.default_location
  name                = "chatbot-api-identity"
}

resource "azurerm_user_assigned_identity" "bot" {
  resource_group_name = azurerm_resource_group.main.name
  location            = var.default_location
  name                = "chatbot-bot-identity"
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
  # commenting out for now since I need to figure subnet NS that is preventing terraform 
  # from properly provisioning env without the error: 
  #     Managed Environment Name: "ScDc-CIO-OpenAI-Chatbot-Pilot-env"): polling after CreateOrUpdate: Code="ManagedEnvironmentConnectionBlocked" 
  #     Message="Managed Cluster 'ashyriver-2c6f408f' provision failed, error code is : ManagedEnvironmentConnectionBlocked."
  #
  #infrastructure_subnet_id   = azurerm_subnet.main.id
  #internal_load_balancer_enabled = true
  depends_on = [ azurerm_container_registry_task_schedule_run_now.main ]
}

resource "azurerm_container_app_environment_storage" "main" {
  name                         = "app-fs"
  container_app_environment_id = azurerm_container_app_environment.main.id
  account_name                 = azurerm_storage_account.main.name
  share_name                   = azurerm_storage_share.main.name
  access_key                   = azurerm_storage_account.main.primary_access_key
  access_mode                  = "ReadWrite"
}

resource "azurerm_container_app" "main" {
  name                         = "${var.name_prefix_lowercase}-${var.project_name_lowercase}-app"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

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
    container {
      name   = "api"
      image  = "${azurerm_container_registry.main.login_server}/chatbot-api:${var.api_version}"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name = "KEY_VAULT_NAME"
        value = "ScDC-CIO-DTO-Infra-kv"
      }

      env {
        name = "OPENAI_ENDPOINT_NAME"
        value = "scdc-cio-dto-openai-poc-oai"
      }

      env {
        name = "OPENAI_DEPLOYMENT_NAME"
        value = "gpt-35-turbo"
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
*              COGNITIVE SERVICE(S)                 *
*****************************************************/

# UNABLE TO MIX ZONING ATM, blocked by policies, so we are keeping the one instance we have back there.

# resource "azurerm_cognitive_account" "main" {
#   name                = "${var.name_prefix}-${var.project_name}-ca"
#   location            = "eastus"
#   resource_group_name = azurerm_resource_group.main.name
#   kind                = "OpenAI"
#   sku_name            = "S0"
# }

# resource "azurerm_cognitive_deployment" "gpt" {
#   name                 = "gpt-35-turbo"
#   cognitive_account_id = azurerm_cognitive_account.main.id
#   model {
#     format  = "OpenAI"
#     name    = "gpt-35-turbo"
#     version = "0301"
#   }

#   scale {
#     type = "Standard"
#   }
# }

# resource "azurerm_cognitive_deployment" "ada" {
#   name                 = "text-embedding-ada-002"
#   cognitive_account_id = azurerm_cognitive_account.main.id
#   model {
#     format  = "OpenAI"
#     name    = "text-embedding-ada-002"
#     version = "2"
#   }

#   scale {
#     type = "Standard"
#   }
# }

/****************************************************
*              Bot/Web App/ServicePlan              *
*****************************************************/
resource "azurerm_service_plan" "main" {
  name                = "${var.name_prefix}-${var.project_name}-plan"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku_name            = "S1"
  os_type             = "Windows"
}


resource "azurerm_windows_web_app" "main" {
  name                = "${var.name_prefix}-${var.project_name}-wa"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_service_plan.main.location
  service_plan_id     = azurerm_service_plan.main.id

  site_config {}

  identity {
    type = "UserAssigned"
    identity_ids = [ azurerm_user_assigned_identity.bot.id ]
  }

  #zip_deploy_file = 
}

resource "azurerm_application_insights" "main" {
  name                = "${var.name_prefix}-${var.project_name}-appinsights"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  application_type    = "web"
}

resource "azurerm_application_insights_api_key" "main" {
  name                    = "${var.name_prefix}-${var.project_name}-appinsightsapikey"
  application_insights_id = azurerm_application_insights.main.id
  read_permissions        = ["aggregate", "api", "draft", "extendqueries", "search"]
}

resource "azurerm_bot_service_azure_bot" "main" {
  name                = "${var.name_prefix}-${var.project_name}-bot"
  resource_group_name = azurerm_resource_group.main.name
  location            = "global"
  microsoft_app_id    = data.azurerm_client_config.current.client_id
  sku                 = "F0"

  developer_app_insights_api_key        = azurerm_application_insights_api_key.main.api_key
  developer_app_insights_application_id = azurerm_application_insights.main.app_id

  tags = {
    environment = "Pilot"
  }
}