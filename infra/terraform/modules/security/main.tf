terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# NOTE: Defender for Cloud pricing resources already exist in Azure at Free tier by default.
# To manage them with Terraform, they MUST be imported into state FIRST using:
#   terraform import 'module.security[0].azurerm_security_center_subscription_pricing.<resource>' '/subscriptions/<id>/providers/Microsoft.Security/pricings/<type>'
# See security/README.md for full import examples.

# Security contact
resource "azurerm_security_center_contact" "default" {
  name                = "default"
  email               = var.security_contact_email
  alert_notifications = true
  alerts_to_admins    = true
}
