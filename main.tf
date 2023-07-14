/****************************************************
*                       RG                          *
*****************************************************/
resource "azurerm_resource_group" "main" {
  name     = "${var.name_prefix}-${var.project_name}-rg"
  location = "canadacentral"
}

/****************************************************
*                       VNET                        *
*****************************************************/
resource "azurerm_network_security_group" "main" {
  name                = "${var.name_prefix}-${var.project_name}-sg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.name_prefix}-${var.project_name}-vnet"
  location            = azurerm_resource_group.main.location
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

}

resource "azurerm_subnet_network_security_group_association" "main" {
  network_security_group_id = azurerm_network_security_group.main.id
  subnet_id = azurerm_subnet.main.id
}

/****************************************************
*                       STORAGE                     *
*****************************************************/
resource "azurerm_storage_account" "main" {
  name                     = "${var.project_name_short_lowercase}storage"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
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

/****************************************************
*                    REGISTRY                       *
*****************************************************/

resource "azurerm_container_registry" "main" {
  name                = "${var.name_prefix_lowercase}${var.project_name_lowercase}registry"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
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
    # v3.0.2 sha 0bfe783618a8a1ac515ecbf00352f89c1de32f87
    context_path         = "https://github.com/dto-btn/openai-app-poc.git#0bfe783618a8a1ac515ecbf00352f89c1de32f87"
    context_access_token = var.personal_token
    image_names          = ["${azurerm_container_registry.main.login_server}/chatbot-api:3.0.2"]
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

resource "azurerm_user_assigned_identity" "main" {
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  name                = "chatbot-app-identity"
}

/* need Owner role on SP to be able to perform this assignment */
resource "azurerm_role_assignment" "container_registry" {
    scope                 = azurerm_container_registry.main.id
    role_definition_name  = "AcrPull"
    principal_id          = azurerm_user_assigned_identity.main.principal_id
}

resource "azurerm_key_vault_access_policy" "infra" {
  key_vault_id          = data.azurerm_key_vault.infra.id
  object_id             = azurerm_user_assigned_identity.main.principal_id
  tenant_id             = azurerm_user_assigned_identity.main.tenant_id
  secret_permissions    = ["Get", "List"]
}

/****************************************************
*                 CONTAINER APP                     *
*****************************************************/
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.name_prefix_lowercase}-${var.project_name_lowercase}-ws"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "main" {
  name                       = "${var.name_prefix}-${var.project_name}-env"
  location                   = azurerm_resource_group.main.location
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
    type = "UserAssigned"
    identity_ids = [ azurerm_user_assigned_identity.main.id ]
  }

  registry {
    identity = azurerm_user_assigned_identity.main.id
    server = azurerm_container_registry.main.login_server
  }

  template {
    container {
      name   = "api"
      image  = "${azurerm_container_registry.main.login_server}/chatbot-api:3.0.2"
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

/*       env {
        name = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.pilot.name
      } */

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