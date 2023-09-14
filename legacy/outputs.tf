output "bot_endpoint" {
    description = "the bot endpoint that is used by the channels to communicate"
    value       = azurerm_bot_service_azure_bot.main.endpoint
}