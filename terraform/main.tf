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
  georeplication_locations = ["West Europe"]
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "helloAzureAks"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "helloAzureAks"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Production"
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "akv" {
  name                = "hellKeyvault"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "premium"
}

resource "azurerm_key_vault_access_policy" "akv_policy" {
  key_vault_id = azurerm_key_vault.akv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_kubernetes_cluster.aks.kubelet_identity.0.object_id

  key_permissions = [
    "Get", 
  ]

  secret_permissions = [
    "set", "get", "list", "delete", "purge"
  ]
}