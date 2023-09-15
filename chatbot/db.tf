resource "azurerm_cosmosdb_account" "db" {
  # "scdc-cio-chatbot-pilot-db"
  name                = "${var.name_prefix_lowercase}-${var.project_name_lowercase}-db"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  offer_type          = "Standard"
  kind                = "MongoDB"

  is_virtual_network_filter_enabled = true

  consistency_policy {
    consistency_level       = "Session"
    max_interval_in_seconds = 5
    max_staleness_prefix    = 100
  }

  geo_location {
    location          = azurerm_resource_group.main.location
    failover_priority = 0
  }

  virtual_network_rule {
    id = azurerm_subnet.main.id
    ignore_missing_vnet_service_endpoint = false
  }
}