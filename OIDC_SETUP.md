# Azure OIDC 配置指南

本指南介绍如何将 GitHub Actions 与 Azure OpenID Connect (OIDC) 集成，以替代传统的服务主体客户端密钥认证。

## 优势
- **更安全**：无需长期保存 `client_secret`
- **短期令牌**：每次工作流运行时自动获取短期访问令牌
- **审核追踪**：Azure AD 审核日志中可追踪 GitHub Actions 身份验证
- **最小权限**：可通过 Azure RBAC 精细控制权限

## 前置条件
1. Azure 订阅（拥有所有者或用户访问管理员权限）
2. GitHub 仓库（拥有设置 Secrets 的权限）
3. 已安装 [Azure CLI](https://docs.microsoft.com/cli/azure/)（可选，用于脚本配置）

## 配置步骤

### 1. 创建 Azure AD 应用注册
1. 登录 [Azure 门户](https://portal.azure.com)
2. 导航到 **Azure Active Directory** → **应用注册** → **新建注册**
3. 输入应用名称（如 `github-actions-oidc`）
4. 选择 **仅此组织目录中的帐户（仅限默认目录）**
5. 重定向 URI 留空（不需要）
6. 点击 **注册**

### 2. 配置联合身份凭证 (Federated Credentials)
1. 在应用注册页面，转到 **证书和密码** → **联合身份凭据** → **添加凭据**
2. 选择凭据类型：**GitHub Actions 部署 Azure**
3. 配置以下设置：
   - **颁发者**: `https://token.actions.githubusercontent.com`
   - **主体标识符**: `repo:<owner>/<repo>:ref:refs/heads/main`
     - 将 `<owner>/<repo>` 替换为你的 GitHub 仓库（例如 `yzl-ywj/tf-cn-mesh`）
     - 如果需要限制到特定环境，可以使用 `repo:<owner>/<repo>:environment:<environment_name>`
   - **名称**: `github-actions-main`
   - **描述**（可选）：`GitHub Actions OIDC for main branch`
4. 点击 **添加**

> **可选**：为其他分支或环境添加额外凭据：
> - 为 PR 分支：`repo:<owner>/<repo>:pull_request`
> - 为特定标签：`repo:<owner>/<repo>:ref:refs/tags/<tag>`

### 3. 分配 Azure RBAC 角色
1. 在 Azure 门户中，导航到目标资源组或订阅
2. 转到 **访问控制 (IAM)** → **添加角色分配**
3. 选择角色（如 **参与者** 或更细粒度角色）
4. 选择 **用户、组或服务主体**
5. 搜索并选择之前创建的应用注册（名称如 `github-actions-oidc`）
6. 点击 **审核并分配**

> **权限建议**：
> - **资源组级别**：如果 Terraform 仅管理特定资源组，在资源组级别分配角色
> - **订阅级别**：如果 Terraform 需要创建新资源组，在订阅级别分配角色
> - **最小权限**：考虑使用自定义角色，仅授予必要权限

### 4. 获取应用注册信息
记录以下值（后续需要设置 GitHub Secrets）：
- **应用程序（客户端）ID** → `AZURE_CLIENT_ID`
- **目录（租户）ID** → `AZURE_TENANT_ID`
- **订阅 ID** → `AZURE_SUBSCRIPTION_ID`

### 5. 配置 GitHub 仓库机密
在 GitHub 仓库中设置以下 Secrets：
1. 进入仓库 **Settings** → **Secrets and variables** → **Actions**
2. 点击 **New repository secret** 添加：
   - `AZURE_CLIENT_ID`：应用程序（客户端）ID
   - `AZURE_TENANT_ID`：目录（租户）ID
   - `AZURE_SUBSCRIPTION_ID`：Azure 订阅 ID

> **注意**：不再需要 `AZURE_CREDENTIALS` Secret，可以安全删除

### 6. 验证 Terraform 配置
确保 `terraform-azure-demo/main.tf` 中的 Azure Provider 配置已启用 OIDC：
```hcl
provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret  # 使用 OIDC 时可留空
  tenant_id       = var.tenant_id
  use_oidc        = true  # 启用 OIDC 身份验证
}
```

### 7. 配置 GitHub Actions 工作流权限
OIDC 身份验证需要作业级别的 `id-token: write` 权限。确保工作流文件包含以下配置：

#### 对于使用 OIDC 的作业（plan 和 apply）：
```yaml
plan:
  name: Terraform Plan (optional)
  runs-on: ubuntu-latest
  needs: validate
  permissions:
    id-token: write    # 必需：用于获取 OIDC 令牌
    contents: read     # 必需：用于 actions/checkout
  steps:
    # ... 其他步骤

    - name: Azure Login (OIDC)
      uses: azure/login@v3
      with:
        client-id: ${{ secrets.AZURE_CLIENT_ID }}
        tenant-id: ${{ secrets.AZURE_TENANT_ID }}
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
        enable-OIDC: true
        auth-type: OIDC
        audience: api://AzureADTokenExchange
        environment: azurecloud
        allow-no-subscriptions: false
        enable-AzPSSession: false
```

#### 关键配置说明：
- **permissions**: 必须包含 `id-token: write` 以获取 GitHub OIDC 令牌
- **auth-type**: 必须设置为 `OIDC`（当 `enable-OIDC: true` 时默认）
- **audience**: 应为 `api://AzureADTokenExchange`（Azure AD 的默认值）
- **environment**: Azure 云环境（默认为 `azurecloud`）

> **注意**：`validate` 作业不需要 OIDC 权限，因为它不进行 Azure 身份验证。

## 验证 OIDC 配置

### 1. 手动触发工作流
1. 在 GitHub 仓库中，进入 **Actions** → **Terraform CI**
2. 点击 **Run workflow** → 选择 **Apply: false**（仅运行 plan）
3. 观察工作流执行，确认 **Azure Login (OIDC)** 步骤成功

### 2. 检查 Azure AD 登录日志
1. 在 Azure 门户中，导航到 **Azure Active Directory** → **应用注册** → 选择你的应用
2. 转到 **监视** → **登录日志**
3. 筛选 **应用程序** 为你的应用注册名称
4. 确认看到来自 `GitHub Actions` 的成功登录

### 3. 验证 Terraform 执行
工作流中的 `terraform plan` 和 `terraform apply` 应成功执行，无需 `client_secret`

## 故障排除

### 常见问题
1. **错误：AADSTS70021** - 主体标识符不匹配
   - 检查联合身份凭证中的主体标识符格式
   - 确保仓库名称和分支名称正确

2. **错误：角色分配不足**
   - 确认应用注册已被分配正确的 RBAC 角色
   - 可能需要等待几分钟让角色分配生效

3. **错误：无效的客户端/租户 ID**
   - 检查 GitHub Secrets 中的值是否正确
   - 确认应用注册存在于正确的 Azure AD 租户中

4. **Terraform 仍要求 client_secret**
   - 确保 `use_oidc = true` 已设置
   - 检查 provider 版本是否 ≥ 3.40
   - 验证环境变量 `ARM_USE_OIDC` 是否已设置

### 调试步骤
1. 在工作流中添加调试步骤：
   ```yaml
   - name: Debug OIDC tokens
     run: |
       echo "Client ID: ${{ secrets.AZURE_CLIENT_ID }}"
       echo "Tenant ID: ${{ secrets.AZURE_TENANT_ID }}"
       echo "Subscription ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}"
   ```

2. 检查 Azure CLI 令牌（如果已安装）：
   ```bash
   az account get-access-token --resource https://management.azure.com
   ```

## 回滚到传统认证
如果需要恢复使用服务主体认证：
1. 从 `main.tf` 中移除 `use_oidc = true`
2. 设置 `client_secret` 变量值
3. 恢复使用 `AZURE_CREDENTIALS` Secret
4. 将工作流中的 `azure/login` 步骤恢复为使用 `creds` 输入

## 参考链接
- [GitHub Actions 与 Azure 的 OIDC 集成](https://docs.github.com/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure)
- [Azure AD 应用注册文档](https://docs.microsoft.com/azure/active-directory/develop/quickstart-register-app)
- [Terraform Azure Provider OIDC 认证](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/azure_cli)
- [Azure Login GitHub Action](https://github.com/Azure/login)