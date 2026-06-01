# 指定 Provider (插件)
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-terraform-demo"
    storage_account_name = "tfstate20260601"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}

# 配置 Azure Provider 使用刚才创建的 SP 鉴权
provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}

# 创建资源组
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = "East Asia"
}

# 创建服务计划（App Service Plan）
resource "azurerm_service_plan" "plan" {
  name                = "azure-app-service-plan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  os_type  = "Linux" # 👈 关键：Linux 才能跑 Docker / Node
  sku_name = "B1"    # 👈 关键：定价层（钱和性能）学习/个人 cheapest 可跑 Docker,free tier不能自定义域名，不能跑 Docker 镜像
}

resource "azurerm_linux_web_app" "app" {
  name                = "app-nodejs-livestream"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.plan.id

  site_config {
    application_stack {
      docker_image_name        = var.docker_image_name
      docker_registry_url      = var.docker_registry_url
      docker_registry_username = var.docker_registry_username
      docker_registry_password = var.docker_registry_password
    }
  }

  # 私有镜像认证已移入 `site_config.application_stack`
}

resource "azurerm_storage_account" "storage" {
  name                     = "tfstate20260601"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}