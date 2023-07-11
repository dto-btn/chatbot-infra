resource "azurerm_resource_group" "pilot" {
  name     = "${var.name_prefix}-${var.project_name}-rg"
  location = "canadacentral"
}

/****************************************************
*                       VNET                        *
*****************************************************/
resource "azurerm_network_security_group" "pilot" {
  name                = "${var.name_prefix}-${var.project_name}-sg"
  location            = azurerm_resource_group.pilot.location
  resource_group_name = azurerm_resource_group.pilot.name
}

resource "azurerm_virtual_network" "pilot" {
  name                = "${var.name_prefix}-${var.project_name}-vnet"
  location            = azurerm_resource_group.pilot.location
  resource_group_name = azurerm_resource_group.pilot.name

  address_space = [ "10.2.0.0/24" ]

  tags = {
    environment = "Pilot"
  }
}

/****************************************************
*                       STORAGE                     *
*****************************************************/
resource "azurerm_storage_account" "pilot" {
  name                     = "${var.project_name_short_lowercase}storage"
  resource_group_name      = azurerm_resource_group.pilot.name
  location                 = azurerm_resource_group.pilot.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "Pilot"
  }
}

resource "azurerm_storage_share" "pilot" {
  name                 = "${var.name_prefix_lowercase}-${var.project_name_lowercase}-fs"
  storage_account_name = azurerm_storage_account.pilot.name
  quota                = 5
}

/****************************************************
*                    REGISTRY                       *
*****************************************************/

resource "azurerm_container_registry" "pilot" {
  name                = "${var.name_prefix_lowercase}${var.project_name_lowercase}containerregistry"
  resource_group_name = azurerm_resource_group.pilot.name
  location            = azurerm_resource_group.pilot.location
  sku                 = "Standard"
  admin_enabled       = true
}

/****************************************************
*                       ROLES                       *
*****************************************************/

resource "azurerm_user_assigned_identity" "pilot" {
  resource_group_name = azurerm_resource_group.pilot.name
  location            = azurerm_resource_group.pilot.location
  name                = "chatbot-app-identity"
}

/* unable to add this role to systemassigned principal .. */
resource "azurerm_role_assignment" "pilot" {
    scope                = azurerm_container_registry.pilot.id
    role_definition_name = "AcrPull"
    principal_id = azurerm_user_assigned_identity.pilot.principal_id
    depends_on = [ azurerm_user_assigned_identity.pilot ]
}

/****************************************************
*                 CONTAINER APP                     *
*****************************************************/
resource "azurerm_log_analytics_workspace" "pilot" {
  name                = "${var.name_prefix_lowercase}-${var.project_name_lowercase}-ws"
  location            = azurerm_resource_group.pilot.location
  resource_group_name = azurerm_resource_group.pilot.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "pilot" {
  name                       = "${var.name_prefix}-${var.project_name}-env"
  location                   = azurerm_resource_group.pilot.location
  resource_group_name        = azurerm_resource_group.pilot.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.pilot.id
}

resource "azurerm_container_app_environment_storage" "pilot" {
  name                         = "app-fs"
  container_app_environment_id = azurerm_container_app_environment.pilot.id
  account_name                 = azurerm_storage_account.pilot.name
  share_name                   = azurerm_storage_share.pilot.name
  access_key                   = azurerm_storage_account.pilot.primary_access_key
  access_mode                  = "ReadWrite"
}

resource "azurerm_container_app" "pilot" {
  name                         = "${var.name_prefix_lowercase}-${var.project_name_lowercase}-app"
  container_app_environment_id = azurerm_container_app_environment.pilot.id
  resource_group_name          = azurerm_resource_group.pilot.name
  revision_mode                = "Single"

  identity {
    type = "UserAssigned"
    identity_ids = [ azurerm_user_assigned_identity.pilot.id ]
  }

  registry {
    identity = azurerm_user_assigned_identity.pilot.id
    server = azurerm_container_registry.pilot.login_server
  }

  template {
    container {
      name   = "openai-chatbot-api"
      image  = "${azurerm_container_registry.pilot.login_server}/openai-app-poc:3.0.2"
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