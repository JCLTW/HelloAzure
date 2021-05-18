# HelloAzure
CI/CD Pipeline - Build / Deploy Docker Image in Azure

## 1. 准备工作
### 1.1 在 Github 创建空的 git repository 

### 1.2. 创建 docker file
``` bash
FROM busybox
RUN echo "Hello Azure" 
```

### 1.3. 注册 Azure DevOps
### 1.4 创建 Pipeline 
- 选择 Github
- 登陆 Github 安装 Azure Pipelines， 并选择刚才创建好的 Repository
- 跳转至 DevOps 页面后选择 Starter 创建 azure-piplelines.yml 并提交
- Commit 本地代码, 并 Pull Rebase 远程代码
- Git Push 代码， 应该看到 Pipleline 被重新 Trigger


### 1.5 安装 Azure CLI
https://docs.microsoft.com/en-us/cli/azure/install-azure-cli

### 1.6 安装 Terraform
Terraform Azure: https://learn.hashicorp.com/

### 1.7 创建 Container Registry
Terraform Create Container Register: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_registry

- 初始化 Terraform Folder 使用 azurerm 
```json
resource "azurerm_resource_group" "rg" {
  name     = "hello-azure-resources"
  location = "West Europe"
}

resource "azurerm_container_registry" "acr" {
  name                     = "helloAzureContainerRegistry"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  sku                      = "Premium"
  admin_enabled            = false
  georeplication_locations = ["East US", "West Europe"]
}
```

- Apply Terraform 到 Azure
``` bash
cd terraform/ 
terraform init
terraform plan
terraform apply
terraform show
``` 

## 2. 修改 Pipelines, Build Image 并 Push 到 ACR（ Azure Container Registry ）

- 新建 Azure service connection
  - Azure DevOps 中A创建新的 service connection， 选择 Docker Registry
  - 创建 Service Connection 名字为 azureContainerRegistryConnection
- 修改 azure-pipelines.yml

```yaml
trigger:
- main

stages:
  - stage: Build
    displayName: Build and push stage
    jobs:
    - job: Build
      displayName: Build
      pool:
        vmImage: ubuntu-latest
      steps:
      - task: Docker@2
        displayName: Build and push an image to container registry
        inputs:
          command: buildAndPush
          repository: 'helloazure' # 注意单引号
          dockerfile: '$(Build.SourcesDirectory)/Dockerfile'
          containerRegistry: azureContainerRegistryConnection # Service connection name
          tags: |
            '$(Build.BuildId)'
```
