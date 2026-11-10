output "aks_cluster_name" {
  value = module.aks.cluster_name
}

output "aks_private_fqdn" {
  value = module.aks.private_fqdn
}

output "sql_server_fqdn" {
  value = module.sql.sql_server_fqdn
}

output "sql_private_endpoint_ip" {
  value = module.sql_private_endpoint.private_endpoint_ip
}