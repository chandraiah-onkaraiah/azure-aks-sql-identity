variable "subscription_id" {
  type = string
}

variable "location" {
  type    = string
  default = "Central India"
}

variable "resource_group_name" {
  type    = string
  default = "rg-private-aks"
}

variable "aks_name" {
  type    = string
  default = "aks-private-dev"
}

variable "sql_database_name" {
  type    = string
  default = "appdb"
}

variable "sql_admin_username" {
  type    = string
  default = "sqladminuser"
}

variable "sql_admin_password" {
  type      = string
  sensitive = true
}