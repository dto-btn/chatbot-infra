/****************************************************
*                       VNET                        *
*****************************************************/
resource "azurerm_network_security_group" "main" {
  name                = "${var.name_prefix}-${var.project_name}-sg"
  location            = var.default_location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.name_prefix}-${var.project_name}-vnet"
  location            = var.default_location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [ "10.2.0.0/16" ]
  //Using Azure's Default DNS IP.
  dns_servers         = ["168.63.129.16"]

  tags = {
    environment = var.env
  }
}

resource "azurerm_subnet" "frontend" {
    name                  = "frontend"
    address_prefixes      = ["10.2.0.0/20"]
    virtual_network_name  = azurerm_virtual_network.main.name
    resource_group_name   = azurerm_resource_group.main.name

    service_endpoints = [
        "Microsoft.AzureActiveDirectory",
        "Microsoft.AzureCosmosDB",
    ]

    delegation {
      name = "Microsoft.Web.serverFarms"

      service_delegation {
        name    = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
      }
    }
}

resource "azurerm_subnet" "backend" {
    name                  = "backend"
    address_prefixes      = ["10.2.16.0/20"]
    virtual_network_name  = azurerm_virtual_network.main.name
    resource_group_name   = azurerm_resource_group.main.name

    delegation {
      name = "delegation"

      service_delegation {
        name    = "Microsoft.ContainerInstance/containerGroups"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action", "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action"]
      }
    }
}

resource "azurerm_subnet_network_security_group_association" "frontend" {
  network_security_group_id  = azurerm_network_security_group.main.id
  subnet_id                  = azurerm_subnet.frontend.id
}

resource "azurerm_subnet_network_security_group_association" "backend" {
  network_security_group_id  = azurerm_network_security_group.main.id
  subnet_id                  = azurerm_subnet.backend.id
}