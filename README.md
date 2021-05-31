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
- 跳转至 AuzreDevOps 页面后选择 Starter 创建 azure-piplelines.yml 并提交
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
            repository: 'helloazure'
            dockerfile: '$(Build.SourcesDirectory)/Dockerfile'
            containerRegistry: azureContainerRegistryConnection # Service connection name
            tags: | # 注意数字不要有单引号
              $(Build.BuildId) 
  ```
## 3. 创建 AKS， Helm Chart 并 Push 到 ACR（ Azure Container Registry ）
- 3.1 通过 Terraform 创建 AKS
  ```json
  resource "azurerm_kubernetes_cluster" "aks" {
    name                = "helloAzureAks"
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    dns_prefix          = "helloAzureAks"

    default_node_pool {
      name       = "default"
      node_count = 1
      vm_size    = "Standard_D2_v2"
    }

    identity {
      type = "SystemAssigned"
    }

    tags = {
      Environment = "Production"
    }
  }
  ```

  - 3.2 创建 Helm Chart 并将 Chart Push 到 ACR（ Azure Container Registry ）
    -  创建 Helm 目录
    -  创建 Chart.yaml
    -  在 DevOps 中创建用于执行 Task 的 Service Connection （ Azure Resource Manager ）
    -  添加 Helm Save & Push Pipeline Task
    ```yaml
    - task: AzureCLI@2
        displayName: "Helm Save & Push"
        inputs:
          azureSubscription: $(azureSubscription)
          scriptType: bash
          scriptLocation: inlineScript
          inlineScript: |
            appVersion="$(tag)"
            echo "App version: $appVersion"
            export HELM_EXPERIMENTAL_OCI=1
            echo $servicePrincipalKey | helm registry login $(acrUrl) --username $servicePrincipalId --password-stdin
            rm -rf *.tgz
            helm chart save $(helm package --app-version "$appVersion" --version $(helmTag) . | grep -o '/.*.tgz') $(acrUrl)/helm/$(helmRepoName)
            helm chart push $(acrUrl)/helm/$(helmRepoName):$(helmTag)
            helm chart remove $(acrUrl)/helm/$(helmRepoName):$(helmTag)
          addSpnToEnvironment: true
          workingDirectory: "helm/"
    ```

## 4. 通过 Helm Chart Deploy AKS 
### 4.1 添加 Deploy Pipeline
```yaml
- deployment: "Deploy"
      displayName: "Deploy"
      environment: deploy-test
      dependsOn: ["Build"]
      timeoutInMinutes: 300
      strategy:
        runOnce:
          deploy:
            steps:
              - download: none
              - checkout: none
              - task: AzureCLI@2
                displayName: "Helm upgrade"
                inputs:
                  azureSubscription: azureResourceManagerServiceConnection # Service connection name
                  scriptType: bash
                  scriptLocation: inlineScript
                  inlineScript: |
                    export HELM_EXPERIMENTAL_OCI=1
                    az aks get-credentials --name $(aksName) --resource-group $(aksResourceGroup)
                    kubectl config use-context $(aksName)
                    echo $servicePrincipalKey | helm registry login $(acrUrl) --username $servicePrincipalId --password-stdin
                    helm chart pull $(acrUrl)/helm/$(helmRepoName):$(helmTag)
                    rm -rf ./charts
                    helm chart export $(acrUrl)/helm/$(helmRepoName):$(helmTag) --destination ./charts
                    cd ./charts/hello/
                    helm upgrade -f values.yaml --install --create-namespace --wait $(helmRepoName) .
                  addSpnToEnvironment: true
```
### 4.2 添加 Helm chart template, 增加 CronJob Resource 
- 在 helm 文件夹下创建 templates folder
- 在 template folder 下创建 cronjob.yaml
```yaml
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: hello-cronjob
spec:
  schedule: "0 0 1 * *" # 每月执行一次，手动 Trigger
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: hello-cronjob
            image: "{{ $.Values.image.repository }}:{{ $.Chart.AppVersion }}"
            imagePullPolicy: {{ $.Values.image.pullPolicy }}
          restartPolicy: OnFailure
```
- 提交代码触发 Pipeline，在 Azure Portal 验证和 Azure DevOps 中验证
- Trigger Job, 在 Azure Portal 中查看
```powershell
az aks install-cli
az aks get-credentials --resource-group hello-azure-resources --name helloAzureAks
kubectl get nodes
kubectl create job --from=cronjobs/hello-cronjob job-1 -n default
```
此时 Job 会执行失败， 显示 ImagePullBackOff
```powershell
kubectl get pods  
kubectl describe pod job-1-625xw
```
查看 Log 可以看到原因 ：Failed to authorize: failed to fetch anonymous token: unexpected status: 401 Unauthorized

- 为 AKS 添加 ACR 
https://docs.microsoft.com/zh-cn/azure/aks/cluster-container-registry-integration
```powershell
az aks update -n helloAzureAks -g hello-azure-resources --attach-acr helloAzureContainerRegistry
```
添加成功后，删除 Job 重新执行 
```powershell
kubectl create job --from=cronjobs/hello-cronjob job-1 -n default
```

### 4.3 添加环境变量
```yaml
 {{- with .Values.env }}
 env:
    {{- toYaml . | nindent 12 }}
  {{- end}}
```
values.yaml
```yaml
env:
  - name: "StorageAccountName"
    value: "My StorageAccountName Value"
```

- 创建 Job
```powershell
kubectl create job --from=cronjobs/hello-cronjob job-2 -n default
```
查看 Job pod container, 在环境变量选项卡中可以看到新添加的 StorageAccountName 变量及 Value

注意：Cronjob 默认会保留最近三次成功的和一次失败的Job
successfulJobsHistoryLimit: 3
failedJobsHistoryLimit: 1


## 5 创建 Keyvault 并将 Keyvault 挂在到 AKS Sectet 设置为环境变量
### 5.1 通过 Terraform 创建 Keyvault

https://docs.microsoft.com/zh-cn/azure/key-vault/general/key-vault-integrate-kubernetes

```json

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "akv" {
  name                = "hellKeyvault"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "premium"
}

resource "azurerm_key_vault_access_policy" "akv_policy" {
  key_vault_id = azurerm_key_vault.akv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_kubernetes_cluster.aks.kubelet_identity.0.object_id

  key_permissions = [
    "Get",
  ]

  secret_permissions = [
    "Get",
  ]
}
```
```bash
terraform plan
terraform apply
terraform show
```
- 创建 csi provider
```bash
az aks get-credentials --name helloAzureAks --resource-group hello-azure-resources

helm repo add csi-secrets-store-provider-azure https://raw.githubusercontent.com/Azure/secrets-store-csi-driver-provider-azure/master/charts

helm install csi-secrets-store-provider-azure/csi-secrets-store-provider-azure --generate-name
```
### 5.2 创建 SecretProviderClass
- cd /helm/templates
- create secretproviderclass.yaml
```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1alpha1
kind: SecretProviderClass
metadata:
  name: "hello-secret-provider"
spec:
  provider: azure
  secretObjects:
  secretObjects:
    - secretName: hello-secrets
      type: Opaque
      labels:
        environment: default
      data:
        - objectName: oneSectetInKeyVault
          key: oneSectetInProvider
  parameters:
    useVMManagedIdentity: "true"
    userAssignedIdentityID: f8be5e9a-e60a-4b7b-abff-0459c4f6566e # helloAzureAks-agentpool's Client ID
    keyvaultName: "hellKeyvault"
    cloudName: "AzurePublicCloud"
    objects: |
      array:
        - |
          objectName: oneSectetInKeyVault
          objectType: secret
          objectVersion: ""
    tenantId: 6479215a-abae-4b35-b4e7-480d4e9c2799
```

- AKS 会自动创建 kubelet_identity, 使用 kubelet_identity.client_id 作为 userAssignedIdentityID
- 同样这个 ID 在我们创建 Key vault access policy 的时候也已经被我们设置了对 Key Vault 的 Get 权限
  （ object_id    = azurerm_kubernetes_cluster.aks.kubelet_identity.0.object_id ）

### 5.3 MountVolums
modify cronjob.yaml
```yaml
metadata:
  name: hello-cronjob
spec:
  schedule: "0 1 1 * *" # 每月执行一次，手动 Trigger
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: hello-cronjob-pod
            image: "{{ $.Values.image.repository }}:{{ $.Chart.AppVersion }}"
            imagePullPolicy: {{ $.Values.image.pullPolicy }}
             {{- with .Values.env }}
            env:
              {{- toYaml . | nindent 12 }}
            {{- end}}
            volumeMounts:
            - name: "hello-secret-provider"
              mountPath: "/mnt/hello-secret-provider"
              readOnly: true
          restartPolicy: OnFailure
          volumes:
            - name: "hello-secret-provider"
              csi:
                driver: secrets-store.csi.k8s.io
                readOnly: true
                volumeAttributes:
                  secretProviderClass: "hello-secret-provider"
```
### 5.4 添加 Secrets 到 Env
modify values.yaml
```yaml
env:
  - name: "StorageAccountName"
    value: "My StorageAccountName Value"
  - name: "OneSectetInProvider"
    valueFrom:
      secretKeyRef:
        name: hello-secrets
        key: oneSectetInProvider 
```
