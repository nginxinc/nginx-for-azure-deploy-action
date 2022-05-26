#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

subscription_id=$1
resource_group_name=$2
nginx_deployment_name=$3
config_dir_path=$4
root_config_file=$5
transformed_config_dir_path=${6:-''}

# Validation and preprocessing

if [[ "$config_dir_path" = /* ]]
then
    echo "The NGINX configuration directory path in the repository '$config_dir_path' must be a relative path."
    exit 1
elif [[ ! "$config_dir_path" = */ ]]
then
    echo "The NGINX configuration directory path '$config_dir_path' does not end with '/'. Appending a trailing '/'."
    config_dir_path="$config_dir_path/"
fi

if [[ -d "$config_dir_path" ]]
then
    echo "The NGINX configuration directory '$config_dir_path' was found."
else 
    echo "The NGINX configuration directory '$config_dir_path' does not exist."
    exit 1
fi

if [[ "$root_config_file" = /* ]]
then
    echo "The NGINX configuration root file path '$root_config_file' must be a relative path to the NGINX configuration directory."
    exit 1
fi

# Remove the leading './' from the root configuration file path if any.
root_config_file=${root_config_file/#'./'/}

root_config_file_repo_path="$config_dir_path$root_config_file"
if [[ -f "$root_config_file_repo_path" ]]
then
    echo "The root NGINX configuration file '$root_config_file_repo_path' was found."
else 
    echo "The root NGINX configuration file '$root_config_file_repo_path' does not exist."
    exit 1
fi

if [[ -n "$transformed_config_dir_path" ]]
then
    if [[ ! "$transformed_config_dir_path" = /* ]]
    then
        echo "The specified transformed NGINX configuration directory path '$transformed_config_dir_path' must be an absolute path that starts with '/'."
        exit 1
    elif [[ ! "$transformed_config_dir_path" = */ ]]
    then
        echo "The specified transformed NGINX configuration directory path '$transformed_config_dir_path' does not end with '/'. Appending a trailing '/'."
        transformed_config_dir_path="$transformed_config_dir_path/"
    fi
fi

transformed_root_config_file_path="$transformed_config_dir_path$root_config_file"
echo "The transformed root NGINX configuration file path is '$transformed_root_config_file_path'."

# Create a NGINX configuration tarball.

config_tarball="nginx-config.tar.gz"

echo "Creating a tarball from the NGINX configuration directory."
tar -cvzf "$config_tarball" -C "$config_dir_path" --xform s:'./':"$transformed_config_dir_path": .
echo "Successfully created the tarball from the NGINX configuration directory."

echo "Listing the NGINX configuration file paths in the tarball."
tar -tf "$config_tarball"

encoded_config_tarball=$(base64 "$config_tarball")
echo "The base64 encoded NGINX configuration tarball"
echo "$encoded_config_tarball"
echo ""

# Synchronize the NGINX configuration tarball to the NGINX for Azure deployment.

uuid="$(cat /proc/sys/kernel/random/uuid)"
template_file="template-$uuid.json"
template_deployment_name="${nginx_deployment_name:0:20}-$uuid"

wget -O "$template_file" https://raw.githubusercontent.com/nginxinc/nginx-for-azure-deploy-action/487d1394d6115d4f42ece6200cbd20859595557d/src/nginx-for-azure-configuration-template.json
echo "Downloaded the ARM template for synchronizing NGINX configuration."
cat "$template_file"
echo ""

echo "Synchronizing NGINX configuration"
echo "Subscription ID: $subscription_id"
echo "Resource group name: $resource_group_name"
echo "NGINX for Azure deployment name: $nginx_deployment_name"
echo "ARM template deployment name: $template_deployment_name"
echo ""

az account set -s "$subscription_id" --verbose
az deployment group create --name "$template_deployment_name" --resource-group "$resource_group_name" --template-file "$template_file" --parameters nginxDeploymentName="$nginx_deployment_name" rootFile="$transformed_root_config_file_path" tarball="$encoded_config_tarball" --verbose
