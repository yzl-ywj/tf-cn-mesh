# Terraform variables template for terraform-azure-demo
# Put sensitive values in a local terraform.tfvars (ignored) or CI secrets.

variable "location" {
  description = "Azure region"
  type        = string
  default     = "East Asia"
}

variable "service_plan_name" {
  description = "App Service Plan name"
  type        = string
  default     = "azure-app-service-plan"
}

variable "service_plan_sku" {
  description = "App Service Plan SKU"
  type        = string
  default     = "B1"
}

variable "app_name" {
  description = "Web app name"
  type        = string
  default     = "app-nodejs-livestream"
}

variable "docker_image_name" {
  description = "Docker image including tag"
  type        = string
  default     = "ghcr.io/yzl-ywj/live-stream-nodejs-app:latest"
}

variable "docker_registry_url" {
  description = "Docker registry URL"
  type        = string
  default     = "https://ghcr.io"
}

variable "docker_registry_username" {
  description = "Docker registry username"
  type        = string
  default     = "yzl-ywj"
}

variable "docker_registry_password" {
  description = "Docker registry password (sensitive). Do NOT commit secrets."
  type        = string
  sensitive   = true
  default     = ""
}

variable "subscription_id" {
  description = "Azure subscription id (optional, can also be provided via provider or env)"
  type        = string
  default     = ""
}

variable "client_id" {
  description = "Azure service principal client id"
  type        = string
  default     = ""
}

variable "client_secret" {
  description = "Azure service principal client secret (sensitive)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "tenant_id" {
  description = "Azure tenant id"
  type        = string
  default     = ""
}
