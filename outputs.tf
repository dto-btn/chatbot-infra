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
    value       = azurerm_container_app.main.latest_revision_fqdn
}