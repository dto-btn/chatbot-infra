output "registry_name" {
    description = "outputs the container registry full name to be used for pushing images to it"
    value       = azurerm_container_registry.main.login_server
}