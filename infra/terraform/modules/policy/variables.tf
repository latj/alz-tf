variable "location" {
  description = "Primary Azure region"
  type        = string
}
variable "allowed_locations" {
  description = "Allowed Azure regions for resource deployment"
  type        = list(string)
}
variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID"
  type        = string
}
variable "management_group_name" {
  description = "Management group name used as policy assignment scope (e.g., mg-acme-landing-zones)"
  type        = string
}
