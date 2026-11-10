resource "azurerm_private_dns_zone" "sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql" {
  name                  = "sql-private-dns-link"
  virtual_network_id    = var.vnet_id
  private_dns_zone_name = azurerm_private_dns_zone.sql.name
  registration_enabled  = false
  resource_group_name   = var.resource_group_name
}

resource "azurerm_private_endpoint" "sql" {
  name                = "pe-azure-sql"
  location            = var.location
  resource_group_name = var.resource_group_name

  subnet_id = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "sql-private-connection"
    private_connection_resource_id = var.sql_server_id

    subresource_names    = ["sqlServer"]
    is_manual_connection = false
  }

  private_dns_zone_group {
    name = "sql-dns-zone-group"

    private_dns_zone_ids = [
      azurerm_private_dns_zone.sql.id
    ]
  }
}