resource "azurerm_kubernetes_cluster" "main" {
  name                = var.aks_name
  location            = var.location
  resource_group_name = var.resource_group_name

  dns_prefix = "privateaks"

  private_cluster_enabled             = true
  private_cluster_public_fqdn_enabled = false
  private_dns_zone_id                 = "System"

  sku_tier = "Free"

  default_node_pool {
    name           = "system"
    node_count     = 2
    vm_size        = "Standard_D2s_v5"
    vnet_subnet_id = var.aks_subnet_id

    os_disk_size_gb = 64
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"

    network_policy = "azure"

    pod_cidr       = "192.168.0.0/16"
    service_cidr   = "10.2.0.0/16"
    dns_service_ip = "10.2.0.10"

    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer"
  }

  tags = {
    environment = "dev"
    project     = "private-aks"
  }
  node_provisioning_profile {
    mode               = "Auto"
    default_node_pools = "Auto"
  }
}