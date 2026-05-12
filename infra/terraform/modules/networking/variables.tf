variable "location" {
  description = "Azure region"
  type        = string
}
variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}
variable "prefix" {
  description = "Resource naming prefix"
  type        = string
}
variable "hub_address_space" {
  description = "Hub VNet address space (e.g., 10.0.0.0/16)"
  type        = string
  default     = ""
}
variable "app_subnet_delegation" {
  description = "Service delegation for the app subnet (e.g., Microsoft.Web/serverFarms for App Service, Microsoft.App/environments for Container Apps)"
  type        = string
  default     = "Microsoft.Web/serverFarms"
}

variable "enable_azure_services_forwarding_rule" {
  description = "Enable DNS forwarding rule for azure.com domain. Disabled by default because Azure DNS virtual IP is not a supported forwarding target in Private DNS Resolver rulesets."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
