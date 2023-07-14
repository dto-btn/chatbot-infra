output "registry_name" {
    description = "Container registry full name to be used for pushing images to it"
    value       = azurerm_container_registry.main.login_server
}

output "registry_task_add_image" {
    description = "shows the id of the task that will create the docker image"
    value       = azurerm_container_registry_task.main.id
}