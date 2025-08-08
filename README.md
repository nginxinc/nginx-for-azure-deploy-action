# NGINXaaS for Azure Deployment Action

This action supports managing the configuration and certificates of an [NGINXaaS for Azure](https://docs.nginx.com/nginxaas/azure/quickstart/overview/) deployment in a GitHub repository. It enables continuous deployment through GitHub workflows to automatically update the NGINXaaS for Azure deployment when changes are made to the NGINX configuration files stored in the repository. Additionally, one can update NGINX certificates that are already present in Azure key vault.

## Connecting to Azure

This action leverages the [Azure Login](https://github.com/marketplace/actions/azure-login) action for authenticating with Azure and performing update to an NGINXaaS for Azure deployment. Two different ways of authentication are supported:
- [Service principal with secrets](https://docs.microsoft.com/en-us/azure/developer/github/connect-from-azure?tabs=azure-portal%2Cwindows#use-the-azure-login-action-with-a-service-principal-secret)
- [OpenID Connect](https://docs.microsoft.com/en-us/azure/developer/github/connect-from-azure?tabs=azure-portal%2Cwindows#use-the-azure-login-action-with-openid-connect) (OIDC) with an Azure service principal using a Federated Identity Credential

### Sample workflow that authenticates with Azure using an Azure service principal with a secret

```yaml
# File: .github/workflows/nginxForAzureDeploy.yml

name: Sync the NGINX configuration from the GitHub repository to an NGINXaaS for Azure deployment
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

    - name: 'Run Azure Login using an Azure service principal with a secret'
      uses: azure/login@v2
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}

    - name: 'Sync the NGINX configuration from the GitHub repository to the NGINXaaS for Azure deployment'
      uses: nginxinc/nginx-for-azure-deploy-action@v0.5.0
      with:
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
        resource-group-name: ${{ secrets.AZURE_RESOURCE_GROUP_NAME }}
        nginx-deployment-name: ${{ secrets.NGINX_DEPLOYMENT_NAME }}
        nginx-config-directory-path: config/
        nginx-root-config-file: nginx.conf
        transformed-nginx-config-directory-path: /etc/nginx/
        debug: false
```

### Sample workflow that authenticates with Azure using OIDC

```yaml
# File: .github/workflows/nginxForAzureDeploy.yml

name: Sync the NGINX configuration from the GitHub repository to an NGINXaaS for Azure deployment
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
      uses: azure/login@v2
      with:
        client-id: ${{ secrets.AZURE_CLIENT_ID }}
        tenant-id: ${{ secrets.AZURE_TENANT_ID }}
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

    - name: 'Sync the NGINX configuration from the GitHub repository to the NGINXaaS for Azure deployment'
      uses: nginxinc/nginx-for-azure-deploy-action@v0.5.0
      with:
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
        resource-group-name: ${{ secrets.AZURE_RESOURCE_GROUP_NAME }}
        nginx-deployment-name: ${{ secrets.NGINX_DEPLOYMENT_NAME }}
        nginx-config-directory-path: config/
        nginx-root-config-file: nginx.conf
        transformed-nginx-config-directory-path: /etc/nginx/
        debug: false
```

> **Note:**
The service principal being used for authenticating with Azure should have access to manage the NGINXaaS deployment. For simplicity, this guide assumes that the service principal has `Contributor` role to manage the deployment. Refer [prerequisites](https://docs.nginx.com/nginxaas/azure/getting-started/prerequisites/) for details.

## Handling NGINX configuration file paths

To facilitate the migration of the existing NGINX configuration, NGINXaaS for Azure supports multiple-files configuration with each file uniquely identified by a file path, just like how NGINX configuration files are created and used in a self-hosting machine. An NGINX configuration file can include another file using the [include directive](https://docs.nginx.com/nginx/admin-guide/basic-functionality/managing-configuration-files/). The file path used in an `include` directive can either be an absolute path or a relative path to the [prefix path](https://www.nginx.com/resources/wiki/start/topics/tutorials/installoptions/).

The following example shows two NGINX configuration files inside the `/etc/nginx` directory on disk are copied and stored in a GitHub repository under its `config` directory.

| File path on disk                    | File path in the repository      |
| ------------------------------------ | --------------------------------- |
| /etc/nginx/nginx.conf                | /config/nginx.conf                |
| /etc/nginx/sites-enabled/mysite.conf | /config/sites-enabled/mysite.conf |

To use this action to sync the configuration files from this example, the directory path relative to the GitHub repository root `config/` is set to the action's input `nginx-config-directory-path` for the action to find and package the configuration files. The root file `nginx.conf` is set to the input `nginx-root-config-file`.

```yaml
    - name: 'Sync the NGINX configuration from the GitHub repository to the NGINXaaS for Azure deployment'
      uses: nginxinc/nginx-for-azure-deploy-action@v0.5.0
      with:
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
        resource-group-name: ${{ secrets.AZURE_RESOURCE_GROUP_NAME }}
        nginx-deployment-name: ${{ secrets.NGINX_DEPLOYMENT_NAME }}
        nginx-config-directory-path: config/
        nginx-root-config-file: nginx.conf
        debug: false
```

By default, the action uses a file's relative path to `nginx-config-directory-path` in the repository as the file path in the NGINXaaS for Azure deployment.

| File path on disk                    | File path in the repository      | File path in the NGINXaaS for Azure deployment |
| ------------------------------------ | --------------------------------- | ---------------------------------------------- |
| /etc/nginx/nginx.conf                | /config/nginx.conf                | nginx.conf                                     |
| /etc/nginx/sites-enabled/mysite.conf | /config/sites-enabled/mysite.conf | sites-enabled/mysite.conf                      |

The default file path handling works for the case of using relative paths in `include` directives, for example, if the root `nginx.conf` references `mysite.conf` using:

```
include sites-enabled/mysite.conf;
```

For the case of using absolute paths in `include` directives, for example, if the root `nginx.conf` references `mysite.conf` using:

```
include /etc/nginx/sites-enabled/mysite.conf;
```

The action supports an optional input `transformed-nginx-config-directory-path` to transform the absolute path of the configuration directory in the NGINXaaS for Azure deployment. The absolute configuration directory path on disk `/etc/nginx/` can be set to `transformed-nginx-config-directory-path` as follows to ensure the configuration files using absolute paths in `include` directives work as expected in the NGINXaaS for Azure deployment.

```yaml
    - name: 'Sync the NGINX configuration from the Git repository to the NGINXaaS for Azure deployment'
      uses: nginxinc/nginx-for-azure-deploy-action@v0.5.0
      with:
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
        resource-group-name: ${{ secrets.AZURE_RESOURCE_GROUP_NAME }}
        nginx-deployment-name: ${{ secrets.NGINX_DEPLOYMENT_NAME }}
        nginx-config-directory-path: config/
        nginx-root-config-file: nginx.conf
        transformed-nginx-config-directory-path: /etc/nginx/
        debug: false
```
The transformed paths of the two configuration files in the NGINXaaS for Azure deployment are summarized in the following table

| File path on disk                    | File path in the repository      | File path in the NGINXaaS for Azure deployment |
| ------------------------------------ | --------------------------------- | ---------------------------------------------- |
| /etc/nginx/nginx.conf                | /config/nginx.conf                | /etc/nginx/nginx.conf                          |
| /etc/nginx/sites-enabled/mysite.conf | /config/sites-enabled/mysite.conf | /etc/nginx/sites-enabled/mysite.conf           |

## Handling NGINX certificates

Since certificates are secrets, it is assumed they are stored in Azure key vault. One can provide multiple certificate entries to the github action as an array of JSON objects with keys:

`certificateName`- A unique name for the certificate entry

`keyvaultSecret`- The secret ID for the certificate on Azure key vault

`certificateVirtualPath`- This path must match one or more ssl_certificate directive file arguments in your Nginx configuration; and must be unique between certificates within the same deployment

`keyVirtualPath`- This path must match one or more ssl_certificate_key directive file arguments in your Nginx configuration; and must be unique between certificates within the same deployment

See the example below

```yaml
- name: "Sync NGINX certificates to NGINXaaS for Azure"
        uses: nginxinc/nginx-for-azure-deploy-action@v0.5.0
        with:
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
          resource-group-name: ${{ secrets.AZURE_RESOURCE_GROUP_NAME }}
          nginx-deployment-name: ${{ secrets.NGINX_DEPLOYMENT_NAME }}
          nginx-deployment-location: ${{ secrets.NGINX_DEPLOYMENT_LOCATION }}
          nginx-certificates: '[{"certificateName": "$NGINX_CERT_NAME", "keyvaultSecret": "https://$NGINX_VAULT_NAME.vault.azure.net/secrets/$NGINX_CERT_NAME", "certificateVirtualPath": "/etc/nginx/ssl/my-cert.crt", "keyVirtualPath": "/etc/nginx/ssl/my-cert.key"  } ]'
          debug: false
```

## Handling NGINX configuration and certificates

```yaml
 - name: "Sync NGINX configuration- multi file and certificate to NGINXaaS for Azure"
        uses: nginxinc/nginx-for-azure-deploy-action@v0.5.0
        with:
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
          resource-group-name: ${{ secrets.AZURE_RESOURCE_GROUP_NAME }}
          nginx-deployment-name: ${{ secrets.NGINX_DEPLOYMENT_NAME }}
          nginx-deployment-location: ${{ secrets.NGINX_DEPLOYMENT_LOCATION }}
          nginx-config-directory-path: config/
          nginx-root-config-file: nginx.conf
          transformed-nginx-config-directory-path: /etc/nginx/
          nginx-certificates: '[{"certificateName": "$NGINX_CERT_NAME", "keyvaultSecret": "https://$NGINX_VAULT_NAME.vault.azure.net/secrets/$NGINX_CERT_NAME", "certificateVirtualPath": "/etc/nginx/ssl/my-cert.crt", "keyVirtualPath": "/etc/nginx/ssl/my-cert.key"  } ]'
          debug: false
```
