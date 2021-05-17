# HelloAzure
CI/CD Pipeline - Build / Deploy Docker Image in Azure

## 1. 在 Github 创建空的 git repository 

## 2. 创建 docker file
``` bash
FROM busybox
RUN echo "Hello Azure" 
```

## 3. 注册 Azure DevOps
https://dev.azure.com/
### 3.1 创建 Pipeline 
- 选择 Github
- 登陆 Github 安装 Azure Pipelines， 并选择刚才创建好的 Repository
- 跳转至 DevOps 页面后选择 Starter 创建 azure-piplelines.yml 并提交
- Commit 本地代码
