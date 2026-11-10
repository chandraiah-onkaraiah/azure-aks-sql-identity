resource "azurerm_mssql_server" "main" {
  name                = "sql${var.name_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location

  version = "12.0"

  administrator_login          = var.admin_username
  administrator_login_password = var.admin_password

  minimum_tls_version = "1.2"

  public_network_access_enabled = false
}

resource "azurerm_mssql_database" "main" {
  name      = var.database_name
  server_id = azurerm_mssql_server.main.id

  sku_name = "S0"
}