# NGINXaaS for Azure Configuration Automation

This repository hosts two essential projects that facilitate the management and deployment of NGINXaaS for Azure configurations. Both projects aim to automate the process of synchronizing NGINX configuration files, but they target different platforms and have unique features and notation. To learn more about NGINXaaS for Azure, please review the [product homepage](https://www.nginx.com/products/nginx/nginxaas-for-azure/).

## Projects

### 1. Azure Pipeline Task

This project provides a custom Azure pipeline task that automates the synchronization of NGINXaaS configuration files for Azure deployments. It supports both GitHub Action pipelines and Azure DevOps pipeline tasks. [Read more](./azure-pipeline/README.md).

### 2. GitHub Action Task

This GitHub Action enables continuous deployment through GitHub workflows to automatically update the NGINXaaS for Azure deployment when changes are made to the NGINX configuration files stored in the repository. It also supports updating NGINX certificates that are present in Azure key vault. [Read more](./github-action/README.md).

## Comparison 

| Feature/Aspect                      | Azure Pipeline Task                | GitHub Action Task                  |
|------------------------------------|------------------------------------|-------------------------------------|
| **CI/CD Automation**               | Yes                                | Yes                                 |
| **Configuration File Host**        | GitHub Repos or Azure Repos        | GitHub                              |
| **Security**                       | Pipelines in secured agents        | Azure Login Action                  |
| **Authentication Methods**         | Service Connection                 | Service Principal with Secrets, OIDC|
| **Certificate Handling**           | No                                 | Yes (Azure key vault)               |
| **CI/CD Platform**                 | Azure DevOps                       | GitHub                              |

## Getting Started

To get started with either of these projects, please refer to the detailed README files linked above. 

## License

These projects are licensed under the Apache-2.0 License - see the [LICENSE.md](LICENSE) file for details.