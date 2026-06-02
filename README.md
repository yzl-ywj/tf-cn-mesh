# tf-cn-mesh
terraform deploy cloud resource

## Terraform 开发指南（通用）

### 目的
为团队提供一个轻量、可复用的 Terraform 开发工作流与最佳实践，便于本项目和类似项目快速上手与维护。

### 前置条件
- 安装 Terraform（推荐 >= 1.0，生产环境请确认版本兼容性）
- 安装 Azure CLI（用于本地登录与调试）

示例命令：

```bash
terraform -version
az login
az account set --subscription <SUBSCRIPTION_ID>
```

### 项目结构建议

```
terraform-azure-demo/
	main.tf
	variables.tf      # 变量声明
	terraform.tfvars  # 环境特定变量（不要提交包含密钥的 tfvars）
	modules/          # 可复用模块
	README.md
```

### Provider 版本管理 & 锁定
- 在 `required_providers` 中声明约束（例如 `~> 4.0`）确保兼容性。
- 把 `.terraform.lock.hcl` 提交到仓库以保证可重复的 provider 解析。
- 升级 provider 步骤：

```bash
# 更新约束后
terraform init -upgrade
terraform plan
```

### 变量与敏感信息管理
- 使用 `variables.tf` + `terraform.tfvars` 管理非敏感配置。
- 严禁把明文密钥提交到仓库。推荐方案：
	- 使用 Azure Key Vault（配合托管身份）存储密钥；在 Terraform 中通过 `data.azurerm_key_vault_secret` 获取
	- 或使用 CI 的 secrets 管理并通过环境变量注入

示例（Key Vault Secret 引用）：

```hcl
data "azurerm_key_vault_secret" "sp_password" {
	name         = "sp-password"
	key_vault_id = azurerm_key_vault.example.id
}

# 使用 data.azurerm_key_vault_secret.sp_password.value
```

### 远程状态（Remote State）
- 推荐使用 Azure Blob Storage 做 backend，启用锁与版本控制。

示例 backend 配置：

```hcl
terraform {
	backend "azurerm" {
		resource_group_name  = "rg-terraform-state"
		storage_account_name = "stterraformstate"
		container_name       = "tfstate"
		key                  = "env/terraform.tfstate"
	}
}
```

### 模块化
- 将可复用资源抽成 `modules/<name>`，在根目录只做模块调用与环境配置。
- 模块应有清晰的 inputs/outputs 和说明文档。

### 格式化、校验与静态扫描
- 本地开发常用命令：

```bash
terraform fmt -recursive
terraform validate
terraform init
terraform plan -out=tfplan
```

- 推荐加入静态扫描：`tflint`, `tfsec`, `checkov` 等，纳入 CI 流程。

### CI/CD 建议（流水线步骤）
1. checkout
2. `terraform fmt` 检查
3. `terraform init`（使用 backend/工作区）
4. `terraform validate` + linter/扫描
5. `terraform plan -out`（将 plan 作为 artifact）
6. 人工审批后 `terraform apply`（或受控自动化）

### 升级 Provider 与 迁移注意
- 升级前阅读 provider CHANGELOG 与迁移文档。
- 升级步骤：修改约束 -> `terraform init -upgrade` -> `terraform plan` -> 修复弃用项 -> `terraform apply`。

### 常见陷阱
- 不要在多人协作环境下随意切换或删除远程 state
- 修改 provider 版本可能触发资源 schema 变化，先在测试环境验证
- 使用 `terraform plan -out` 并在 CI 中保存 plan，避免“即看即改”不一致

### 参考链接
- Terraform 官方文档: https://www.terraform.io/docs
- AzureRM Provider 文档: https://registry.terraform.io/providers/hashicorp/azurerm

---

如需我把同样的检查项加入 CI（GitHub Actions）或生成 `variables.tf` 模板，我可以继续添加。

## 操作手册与教程

本节把在本仓库中完成的迁移与配置操作总结为可复用的操作手册和步骤，方便开发者在本地或 CI 中复现。

**变更清单（已完成）**
- `terraform-azure-demo/main.tf`：将 `azurerm_app_service` 迁移为 `azurerm_linux_web_app`，并使用 `site_config.application_stack` 配置容器镜像。
- `terraform-azure-demo/variables.tf`：新增变量模板。
- `terraform-azure-demo/terraform.tfvars.example`：新增示例变量文件（本地填写，不要提交真实密钥）。
- `.terraform.lock.hcl`：锁定并升级到 `azurerm` v4.x 系列（确保可重复解析）。
- `.github/workflows/terraform.yml`：新增 GitHub Actions 工作流（`fmt`、`validate`，并在配置凭据时执行 `plan`）。

**本地快速上手（开发者）**
1. 进入 Terraform 配置目录：

```bash
cd terraform-azure-demo
```

2. 初始化（并在需要时升级 provider）：

```bash
terraform init -upgrade
```

3. 格式化与校验：

```bash
terraform fmt -recursive
terraform validate
```

4. 生成并查看计划：

```bash
terraform plan -out=tfplan
terraform show -json tfplan | jq .
```

5. 应用变更：

```bash
terraform apply tfplan
```

**在 GitHub Actions 中运行**
- 在仓库 Settings → Secrets and variables → Actions 添加 `AZURE_CREDENTIALS`（值为 `az ad sp create-for-rbac --sdk-auth` 输出的 JSON）。
- 工作流 `.github/workflows/terraform.yml` 会自动运行格式化与验证；当 `AZURE_CREDENTIALS` 存在时会执行 `terraform plan` 并上传 `tfplan`。

**如何创建 `AZURE_CREDENTIALS`（Service Principal）**

```bash
az login
az ad sp create-for-rbac \
	--name "tf-cn-mesh-sp" \
	--role Contributor \
	--scopes "/subscriptions/<SUBSCRIPTION_ID>" \
	--sdk-auth
```

将命令输出的完整 JSON 粘贴为仓库 Secret `AZURE_CREDENTIALS`。

**升级 Provider 的流程**
1. 修改 `required_providers` 约束（例如改为 `~>4.0`）。
2. 运行 `terraform init -upgrade`。
3. 运行 `terraform plan`，按提示修复弃用或不兼容项（示例：把 `linux_fx_version` 替换为 `site_config.application_stack`）。
4. 在测试环境验证通过后 `terraform apply`。

**常见问题与排查**
- 状态文件被锁（state lock）错误：通常是另一个进程占用本地 `terraform.tfstate`。解决方法：关闭占用进程或编辑器，或切换为远程后端（Azure Blob）以避免本地锁；若不得已可临时使用 `-lock=false`（不推荐长期使用）。
- 敏感信息泄露：不要把 `client_secret` 或明文密钥提交到仓库。推荐使用 Azure Key Vault 或 CI Secrets 管理敏感数据。
- 资源迁移的兼容性问题：升级 provider 前先在隔离环境运行 `plan` 并人工审查。

**PR 检查清单（Reviewer）**
- `required_providers` 版本是否合适
- 仓库中是否存在明文密钥（敏感信息）
- `variables.tf` 是否覆盖必要输入且默认合理
- CI workflow 是否通过 `fmt`、`validate`
- `terraform plan` 输出是否与预期一致

---

需要我把 `main.tf` 完整改为使用 `variables.tf`（并填充示例 `terraform.tfvars`）、或用 OIDC 替代 Service Principal 配置 GitHub Actions 吗？

## ✅ OIDC 配置已完成

已成功配置 OpenID Connect (OIDC) 作为更安全的身份验证方案：

### 已完成的项目：
1. **GitHub Actions 工作流更新**：`.github/workflows/terraform.yml` 现在使用 OIDC 登录
2. **Terraform Provider 配置**：`main.tf` 中的 `azurerm` provider 已启用 `use_oidc = true`
3. **变量文档更新**：`variables.tf` 中的变量描述已更新，说明 OIDC 用法
4. **配置指南创建**：`OIDC_SETUP.md` 提供了完整的 Azure AD 配置步骤

### 后续步骤：
1. **创建 Azure AD 应用注册**：按照 `OIDC_SETUP.md` 中的步骤操作
2. **配置 GitHub Secrets**：设置 `AZURE_CLIENT_ID`、`AZURE_TENANT_ID`、`AZURE_SUBSCRIPTION_ID`
3. **测试工作流**：手动触发 GitHub Actions 验证 OIDC 认证

### 优势：
- ✅ 无需长期保存 `client_secret`
- ✅ 短期令牌（每次运行自动获取）
- ✅ 更好的安全性和审计追踪
- ✅ 遵循 Azure 和 GitHub 最佳实践

### 传统认证（回滚）：
如果需要恢复使用服务主体认证，请：
1. 从 `main.tf` 中移除 `use_oidc = true`
2. 设置 `client_secret` 变量值
3. 恢复使用 `AZURE_CREDENTIALS` Secret

> **注意**：OIDC 配置需要 Azure AD 应用注册和联合身份凭证设置。详细步骤请参考 `OIDC_SETUP.md`。
