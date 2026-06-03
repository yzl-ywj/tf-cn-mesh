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
  default     = "yzl-ywj/live-stream-nodejs-app:latest"
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
  description = "Azure subscription id. Required for both SP and OIDC authentication (can also be provided via ARM_SUBSCRIPTION_ID environment variable)"
  type        = string
  default     = ""
}

variable "client_id" {
  description = "Azure service principal client id (App ID). Required for both SP and OIDC authentication"
  type        = string
  default     = ""
}

variable "client_secret" {
  description = "Azure service principal client secret (sensitive). Required for traditional SP authentication; leave empty when using OIDC with use_oidc = true"
  type        = string
  sensitive   = true
  default     = ""
}

variable "tenant_id" {
  description = "Azure tenant id (Directory ID). Required for both SP and OIDC authentication"
  type        = string
  default     = ""
}

variable "resource_group_name" {
  description = "Azure resource group name"
  type        = string
  default     = "rg-terraform-demo"
}