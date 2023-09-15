# those trigger regardless, this creates a webhook on the github side
# that will trigger automatically on code push on the given branch

resource "azurerm_app_service_source_control" "frontend" {
  app_id = azurerm_linux_web_app.frontend.id
  repo_url = "https://github.com/dto-btn/chatbot-frontend.git"
  branch = var.frontend_branch_name #defaults to 'main'
  lifecycle {
    ignore_changes = all
  }
}