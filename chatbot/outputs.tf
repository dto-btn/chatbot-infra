output "registry_name" {
    description = "Container registry full name to be used for pushing images to it"
    value       = azurerm_container_registry.main.login_server
}

output "registry_task_add_image" {
    description = "shows the id of the task that will create the docker image"
    value       = azurerm_container_registry_task.main.id
}

output "ingress_endpoint" {
    description = "gives the ingress endpoint for the openai python api"
    value       = azurerm_container_app.main.ingress[0].fqdn
}

output "frontend_endpoint" {
    description = "the frontend app endpoint ..."
    value       = azurerm_linux_web_app.frontend.default_hostname
    #value        = azurerm_static_site.frontend.default_host_name
}

output "affected_subscription" {
    description = "Shows the affected subscription (aka default provider used)"
    value       = data.azurerm_subscription.current.display_name
    #sensitive = true

}