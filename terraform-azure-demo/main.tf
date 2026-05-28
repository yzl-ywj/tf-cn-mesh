# 指定 Provider (插件)
terraform {
  required_providers {
    azurerm={
        source = "hashicorp/azurerm"
        version = "~>4.0"
    }
  }
}

# 配置 Azure Provider 使用刚才创建的 SP 鉴权
provider "azurerm" {
  features {}

  subscription_id = "50f908b5-b2a4-49ac-b74e-1d25c65a496a"
  client_id = "9ad3d96d-0e71-4cd0-b3b4-f6d9614a0431"
  client_secret = "~FG8Q~eNzHcow9mSTyMwEmRQ3QhSVFbQaV1Q3bvt"
  tenant_id = "af219abf-b9e2-49bd-8b94-6e1572a084e0"
}

# 创建资源组
resource "azurerm_resource_group" "rg" {
  name     = "rg-terraform-demo"
  location = "East Asia"
}

# 创建服务计划（App Service Plan）
resource "azurerm_service_plan" "plan" {
  name                = "azure-app-service-plan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  os_type             = "Linux"    # 👈 关键：Linux 才能跑 Docker / Node
  sku_name            = "B1"        # 👈 关键：定价层（钱和性能）学习/个人 cheapest 可跑 Docker,free tier不能自定义域名，不能跑 Docker 镜像
}

resource "azurerm_linux_web_app" "app" {
  name                = "app-nodejs-livestream"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.plan.id
  
  site_config {
    application_stack {
      docker_image_name   = "ghcr.io/yzl-ywj/live-stream-nodejs-app:latest"
      docker_registry_url = "https://ghcr.io"
      docker_registry_username = "yzl-ywj"
      docker_registry_password = "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"
    }
  }

  # 私有镜像认证已移入 `site_config.application_stack`
}