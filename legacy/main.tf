resource "azurerm_user_assigned_identity" "bot" {
  resource_group_name = azurerm_resource_group.main.name
  location            = var.default_location
  name                = "chatbot-bot-identity"
}

/****************************************************
*              COGNITIVE SERVICE(S)                 *
*****************************************************/
# quota changes makes it so I can no longer automate it .. should be added as a data in the future ..

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

  client_affinity_enabled = true
  https_only = true

  /*
  Need to ensure those 2 props are set as env variable in our case otherwise the WA won't start/connect properly.
  ```json
    "MicrosoftAppType": "UserAssignedMSI",
    "MicrosoftAppId": "xxxx-xxxx-xxxx-xxxx-xxxxxxxxxx",
    "MicrosoftAppTenantId": "xxxx-xxxx-xxxx-xxxx-xxxxxxxxxx",
  ```
  */
  site_config {
    ftps_state = "FtpsOnly"

    application_stack {
      current_stack = "dotnet"
      dotnet_version = "v6.0"
    }
    use_32_bit_worker = false
  }

  app_settings = {
    "MicrosoftAppType"         = "UserAssignedMSI",
    "MicrosoftAppId"           = azurerm_user_assigned_identity.bot.client_id,
    "MicrosoftAppTenantId"     = azurerm_user_assigned_identity.bot.tenant_id,
    "ASPNETCORE_ENVIRONMENT"   = "pilot",
    "OpenaiApiEndpoint"        = "https://${azurerm_container_app.main.ingress[0].fqdn}/query"
  }

  sticky_settings {
    app_setting_names = [ "MicrosoftAppType",
                          "MicrosoftAppId",
                          "MicrosoftAppTenantId",
                          "ASPNETCORE_ENVIRONMENT",
                          "OpenaiApiEndpoint" ]
  }

  identity {
    type = "UserAssigned"
    identity_ids = [ azurerm_user_assigned_identity.bot.id ]
  }

  #zip_deploy_file = "packages/deploy.zip"
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
  microsoft_app_id    = azurerm_user_assigned_identity.bot.client_id
  sku                 = "S1"

  developer_app_insights_api_key        = azurerm_application_insights_api_key.main.api_key
  developer_app_insights_application_id = azurerm_application_insights.main.app_id

  microsoft_app_msi_id    = azurerm_user_assigned_identity.bot.id
  microsoft_app_tenant_id = azurerm_user_assigned_identity.bot.tenant_id
  microsoft_app_type      = "UserAssignedMSI"

  tags = {
    environment = "Pilot"
  }

  endpoint = "https://${azurerm_windows_web_app.main.default_hostname}/api/messages"
}

resource "azurerm_bot_channel_ms_teams" "main" {
  bot_name            = azurerm_bot_service_azure_bot.main.name
  location            = "global"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_app_service_source_control" "main" {
  app_id = azurerm_windows_web_app.main.id
  repo_url = "https://github.com/dto-btn/OpenAIPoCChatBot2.git"
  branch = "main"
  lifecycle {
    ignore_changes = all
  }
}