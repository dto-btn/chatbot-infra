# those trigger regardless, this creates a webhook on the github side
# that will trigger automatically on code push on the given branch

resource "azurerm_app_service_source_control" "frontend" {
  app_id = azurerm_linux_web_app.frontend.id
  repo_url = "https://github.com/dto-btn/chatbot-frontend.git"
  branch = "main"
  lifecycle {
    ignore_changes = all
  }
}

resource "azurerm_app_service_source_control" "main" {
  app_id = azurerm_windows_web_app.main.id
  repo_url = "https://github.com/dto-btn/OpenAIPoCChatBot2.git"
  branch = "main"
  lifecycle {
    ignore_changes = all
  }
}