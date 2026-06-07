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

# 配置 Azure Provider 身份验证
# 两种方案（二选一）：
# 1. 使用 OIDC（推荐）：设置 use_oidc = true 并确保 client_id、tenant_id、subscription_id 已提供
#    client_secret 可留空。需要 GitHub Actions 配置 Azure Login with OIDC。
# 2. 使用传统服务主体：设置 use_oidc = false（或删除此行）并提供 client_secret。
provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
  use_oidc        = true # 👈 关键：启用 OIDC 鉴权，配合 GitHub Actions 的 Azure Login Action 使用
}

# 创建资源组
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = "East Asia"
}

# 创建容器注册表（Azure Container Registry）以存储 Docker 镜像
resource "azurerm_container_registry" "acr" {
  name    = "tfacr20260601"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Standard"
  admin_enabled       = true # 开启管理员通道以支持 Webhook 凭据调用
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
    always_on = true # 保持应用始终运行，适合直播流等长连接场景
    application_stack {
      docker_image_name        = var.docker_image_name
      docker_registry_url      = "https://${azurerm_container_registry.acr.login_server}"
      docker_registry_username = azurerm_container_registry.acr.admin_username
      docker_registry_password = azurerm_container_registry.acr.admin_password
    }
  }

  app_settings = {
     # 启用系统内置的 Docker CI Webhook：ACR 有新镜像推入时，自动通知 App Service 拉取
    "DOCKER_ENABLE_CI" = "true"
    "WEBSITES_PORT"    = "3000" # 告知 App Service 容器内部端口
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