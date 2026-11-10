output "private_endpoint_id" {
  value = azurerm_private_endpoint.sql.id
}

output "private_dns_zone_id" {
  value = azurerm_private_dns_zone.sql.id
}

output "private_endpoint_ip" {
  value = azurerm_private_endpoint.sql.private_service_connection[0].private_ip_address
}