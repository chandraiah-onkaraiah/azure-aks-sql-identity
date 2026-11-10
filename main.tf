resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

module "network" {
  source = "./modules/network"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
}

module "aks" {
  source = "./modules/aks"

  aks_name            = var.aks_name
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  aks_subnet_id = module.network.aks_subnet_id
}

module "sql" {
  source = "./modules/sql"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location

  name_suffix   = random_string.suffix.result
  database_name = var.sql_database_name

  admin_username = var.sql_admin_username
  admin_password = var.sql_admin_password
}

module "sql_private_endpoint" {
  source = "./modules/sql-private-endpoint"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location

  vnet_id                    = module.network.vnet_id
  private_endpoint_subnet_id = module.network.private_endpoint_subnet_id

  sql_server_id = module.sql.sql_server_id

  depends_on = [
    module.network,
    module.sql
  ]
}