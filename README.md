# NGINX for Azure Deployment Action

This action syncs NGINX configuration files in the repository to an NGINX deployment in Azure. It enables continuous deployment scenarios where the configuration of the NGINX deployment is automatically updated when changes are made through GitHub workflows.

## Usage example

The following example updates the configuration of a NGINX deployment in Azure each time a change is made to the configuration file in config folder in the `main` branch.

### Sample workflow that authenticates with Azure using Azure Service Principal with a secret

```yaml
# File: .github/workflows/nginxForAzureDeploy.yml

name: Sync configuration to NGINX for Azure 
on:
  push:
    branches:
      - main
    paths:
      - config/**

jobs:
  Deploy-NGINX-Configuration:
    runs-on: ubuntu-latest
    steps:
    - name: 'Checkout repository'
      uses: actions/checkout@v2

    - name: 'Run Azure Login using Azure Service Principal with a secret'
      uses: azure/login@v1
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}

    - name: 'Sync NGINX configuration to NGINX on Azure instance'
      uses: nginxinc/nginx-for-azure-deploy-action@v1
      with:
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
        resource-group-name: ${{ secrets.AZURE_RESOURCE_GROUP_NAME }}
        nginx-deployment-name: ${{ secrets.NGINX_DEPLOYMENT_NAME }}
        nginx-config-file-path: ${{ secrets.NGINX_CONFIG_FILE }}
```

### Sample workflow that authenticates with Azure using OIDC

```yaml
# File: .github/workflows/nginxForAzureDeploy.yml

name: Sync configuration to NGINX for Azure 
on:
  push:
    branches:
      - main
    paths:
      - config/**

permissions:
      id-token: write
      contents: read

jobs:
  Deploy-NGINX-Configuration:
    runs-on: ubuntu-latest
    steps:
    - name: 'Checkout repository'
      uses: actions/checkout@v2

    - name: 'Run Azure Login using OIDC'
      uses: azure/login@v1
      with:
        client-id: ${{ secrets.AZURE_CLIENT_ID }}
        tenant-id: ${{ secrets.AZURE_TENANT_ID }}
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

    - name: 'Sync NGINX configuration to NGINX on Azure instance'
      uses: nginxinc/nginx-for-azure-deploy-action@v1
      with:
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
        resource-group-name: ${{ secrets.AZURE_RESOURCE_GROUP_NAME }}
        nginx-deployment-name: ${{ secrets.NGINX_DEPLOYMENT_NAME }}
        nginx-config-file-path: ${{ secrets.NGINX_CONFIG_FILE }}
```
