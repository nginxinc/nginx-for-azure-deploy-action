#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

subscriptionId=$1
resourceGroupName=$2
nginxDeploymentName=$3
nginxConfigurationFile=$4

# Read and encode the NGINX configuration file content.
if [ -f "$nginxConfigurationFile" ]
then
    echo "The NGINX configuration file was found."
else 
    echo "The NGINX configuration file $nginxConfigurationFile does not exist."
    exit 2
fi

encodedConfigContent=$(base64 "$nginxConfigurationFile")
echo "Base64 encoded NGINX configuration content"
echo "$encodedConfigContent"
echo ""

# Deploy the configuration to the NGINX instance on Azure using an ARM template.
uuid="$(cat /proc/sys/kernel/random/uuid)"
templateFile="template-$uuid.json"
templateDeploymentName="${nginxDeploymentName:0:20}-$uuid"

wget -O "$templateFile" https://raw.githubusercontent.com/nginxinc/nginx-for-azure-deploy-action/main/src/nginx-for-azure-configuration-template.json
echo "Downloaded the ARM template for deploying NGINX configuration"
cat "$templateFile"
echo ""

echo "Deploying NGINX configuration"
echo "Subscription: $subscriptionId"
echo "Resource group: $resourceGroupName"
echo "NGINX deployment name: $nginxDeploymentName"
echo "Template deployment name: $templateDeploymentName"
echo ""

az account set -s "$subscriptionId" --verbose
az deployment group create --name "$templateDeploymentName" --resource-group "$resourceGroupName" --template-file "$templateFile" --parameters nginxDeploymentName="$nginxDeploymentName" rootConfigContent="$encodedConfigContent" --verbose
