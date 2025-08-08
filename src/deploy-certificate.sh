#!/bin/bash
set -eo pipefail
IFS=$'\n\t'

for i in "$@"
do
case $i in
    --subscription-id=*)
    subscription_id="${i#*=}"
    shift
    ;;
    --resource-group-name=*)
    resource_group_name="${i#*=}"
    shift
    ;;
    --nginx-deployment-name=*)
    nginx_deployment_name="${i#*=}"
    shift
    ;;
    --certificates=*)
    certificates="${i#*=}"
    shift
    ;;
    --debug=*)
    debug="${i#*=}"
    shift
    ;;
    *)
    echo "Unknown option '${i}' passed in."
    exit 1
    ;;
esac
done

# Validate Required Parameters
missing_params=()
if [ -z "$subscription_id" ]; then
    missing_params+=("subscription-id")
fi
if [ -z "$resource_group_name" ]; then
    missing_params+=("resource-group-name")
fi
if [ -z "$nginx_deployment_name" ]; then
    missing_params+=("nginx-deployment-name")
fi
if [ -z "$certificates" ]; then
    missing_params+=("certificates")
fi

# Check and print if any required params are missing
if [ ${#missing_params[@]} -gt 0 ]; then
    echo "Error: Missing required variables in the workflow:"
    echo "${missing_params[*]}"
    exit 1
fi

# Synchronize the NGINX certificates to the NGINXaaS for Azure deployment.

echo "Synchronizing NGINX certificates"
echo "Subscription ID: $subscription_id"
echo "Resource group name: $resource_group_name"
echo "NGINXaaS for Azure deployment name: $nginx_deployment_name"
echo ""

az account set -s "$subscription_id" --verbose

echo "Installing the az nginx extension if not already installed."
az extension add --name nginx --allow-preview true

count=$(echo "$certificates" | jq '. | length')
for (( i=0; i<count; i++ ));
do
    nginx_cert_name=$(echo "$certificates" | jq -r '.['"$i"'].certificateName')
    nginx_cert_file=$(echo "$certificates" | jq -r '.['"$i"'].certificateVirtualPath')
    nginx_key_file=$(echo "$certificates" | jq -r '.['"$i"'].keyVirtualPath')
    keyvault_secret=$(echo "$certificates" | jq -r '.['"$i"'].keyvaultSecret')

    # Validate certificate parameters
    missing_cert_params=()
    if [ -z "$nginx_cert_name" ] || [ "$nginx_cert_name" = "null" ]; then
        missing_cert_params+=("certificateName")
    fi
    if [ -z "$nginx_cert_file" ] || [ "$nginx_cert_file" = "null" ]; then
        missing_cert_params+=("certificateVirtualPath")
    fi
    if [ -z "$nginx_key_file" ] || [ "$nginx_key_file" = "null" ]; then
        missing_cert_params+=("keyVirtualPath")
    fi
    if [ -z "$keyvault_secret" ] || [ "$keyvault_secret" = "null" ]; then
        missing_cert_params+=("keyvaultSecret")
    fi

    if [ ${#missing_cert_params[@]} -gt 0 ]; then
        echo "Skipping certificate $i deployment due to missing parameters:"
        echo "${missing_cert_params[*]}"
        echo ""
        continue
    fi

    echo "Processing certificate: $nginx_cert_name"
    echo "Certificate file location: $nginx_cert_file"
    echo "Key file location: $nginx_key_file"
    echo ""

    az_cmd=(
        "az"
        "nginx"
        "deployment"
        "certificate"
        "create"
        "--resource-group" "$resource_group_name"
        "--certificate-name" "$nginx_cert_name"
        "--deployment-name" "$nginx_deployment_name"
        "--certificate-path" "$nginx_cert_file"
        "--key-path" "$nginx_key_file"
        "--key-vault-secret-id" "$keyvault_secret"
        "--verbose"
    )

    if [[ "$debug" == true ]]; then
        az_cmd+=("--debug")
        echo "${az_cmd[@]}"
    fi

    "${az_cmd[@]}"
done
