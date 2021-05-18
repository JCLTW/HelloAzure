resource "azurerm_resource_group" "rg" {
  name     = "hello-azure-resources"
  location = "West Europe"
}

resource "azurerm_container_registry" "acr" {
  name                     = "helloAzureContainerRegistry"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  sku                      = "Premium"
  admin_enabled            = false
  georeplication_locations = ["East US", "West Europe"]
}