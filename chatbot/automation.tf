resource "azurerm_automation_account" "main" {
  name                = "${var.project_name_short_lowercase}-automation"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  sku_name = "Basic"

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "runbook_permission" {
    scope                 = azurerm_container_app.main.id
    role_definition_name  = "Contributor"
    principal_id          = azurerm_user_assigned_identity.api.principal_id
}

data "template_file" "main" {
  template = file("modules/restart-container.tpl")

  vars = {
    container_name = azurerm_container_app.main.name
    resource_group = azurerm_resource_group.main.name
  }
}

resource "azurerm_automation_runbook" "main" {
  name                    = "restart-chatbot-api-container"
  location                = azurerm_resource_group.main.location
  resource_group_name     = azurerm_resource_group.main.name
  automation_account_name = azurerm_automation_account.main.name
  log_verbose             = "true"
  log_progress            = "true"
  description             = "Workbook that restart container in the containerapp space"
  runbook_type            = "PowerShell72"

  content = data.template_file.main.rendered
}

resource "azurerm_automation_schedule" "main" {
  name                    = "automation-schedule"
  resource_group_name     = azurerm_resource_group.main.name
  automation_account_name = azurerm_automation_account.main.name
  frequency               = "Week"
  interval                = 1
  timezone                = "America/New_York"
  #start_time = "yes"
  description             = "Restart containers"
  week_days               = ["Sunday"]
}