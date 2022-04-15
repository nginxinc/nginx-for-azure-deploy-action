#!/bin/bash

# Stop on error.
set -e

subscriptionId=$1
resourceGroupName=$2
nginxDeploymentName=$3
nginxConfigurationFile=$4

# Read and encode the NGINX configuration file content.
if [ -f "$nginxConfigurationFile" ]
then
    echo "NGINX configuration"
    cat "$nginxConfigurationFile"
    echo ""
else 
    echo "NGINX configuration $nginxConfigurationFile does not exist."
    exit 32
fi

encodedConfigContent=$(base64 $nginxConfigurationFile)
echo "Base64 encoded NGINX configuration content"
echo "$encodedConfigContent"
echo ""

# Deploy the configuration to the NGINX instance on Azure using an ARM template.
uuid="$(cat /proc/sys/kernel/random/uuid)"
templateFile="template-$uuid.json"
templateDeploymentName="${nginxDeploymentName:0:20}-$uuid"

wget -O "$templateFile" https://raw.githubusercontent.com/bangbingsyb/azure-quickstart-templates/master/quickstarts/nginx.nginxplus/nginx-single-configuration-file/azuredeploy.json
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
