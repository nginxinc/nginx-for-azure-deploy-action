#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

for i in "$@"
do
case $i in
    --subscription_id=*)
    subscription_id="${i#*=}"
    shift 
    ;;
    --resource_group_name=*)
    resource_group_name="${i#*=}"
    shift 
    ;;
    --nginx_deployment_name=*)
    nginx_deployment_name="${i#*=}"
    shift 
    ;;
    --nginx_resource_location=*)
    nginx_resource_location="${i#*=}"
    shift 
    ;;
    --certificates=*)
    certificates="${i#*=}"
    shift 
    ;;
    *)
    echo "Not matched option '${i#*=}' passed in."
    exit 1
    ;;
esac
done

if [[ ! -v subscription_id ]];
then
    echo "Please set 'subscription-id' ..."
    exit 1 
fi
if [[ ! -v resource_group_name ]];
then
    echo "Please set 'resource-group-name' ..."
    exit 1 
fi
if [[ ! -v nginx_deployment_name ]];
then
    echo "Please set 'nginx-deployment-name' ..."
    exit 1 
fi
if [[ ! -v nginx_resource_location ]];
then
    echo "Please set 'nginx-resource-location' ..."
    exit 1 
fi
if [[ ! -v certificates ]];
then
    echo "Please set 'nginx-certificate-details' ..."
    exit 1 
fi

arm_template_file="nginx-for-azure-certificate-template.json"

#get the ARM template file
wget -O "$arm_template_file" https://nginxgithubactions.blob.core.windows.net/armtemplates/nginx-for-azure-certificate-template.json
echo "Downloaded the ARM template for synchronizing NGINX certificate."

cat "$arm_template_file"
echo ""

az account set -s "$subscription_id" --verbose

count=$(echo $certificates | jq '. | length')
for (( i=0; i<count; i++ ));
do
    nginx_cert_name=$(echo $certificates | jq -r '.['"$i"'].certificateName')
    nginx_cert_file=$(echo $certificates | jq -r '.['"$i"'].certificateVirtualPath')
    nginx_key_file=$(echo $certificates | jq -r '.['"$i"'].keyVirtualPath')
    keyvault_secret=$(echo $certificates | jq -r '.['"$i"'].keyvaultSecret')

    do_nginx_arm_deployment=1
    err_msg=" "
    if [ -z "$nginx_cert_name" ] || [ "$nginx_cert_name" = "null" ]
    then
        err_msg+="nginx_cert_name is empty;"
        do_nginx_arm_deployment=0
    fi
    if [ -z "$nginx_cert_file" ] || [ "$nginx_cert_file" = "null" ]
    then
        err_msg+="nginx_cert_file is empty;"
        do_nginx_arm_deployment=0
    fi
    if [ -z "$nginx_key_file" ] || [ "$nginx_key_file" = "null" ]
    then
        err_msg+="nginx_key_file is empty;"
        do_nginx_arm_deployment=0
    fi
    if [ -z "$keyvault_secret" ] || [ "$keyvault_secret" = "null" ]
    then
        err_msg+="keyvault_secret is empty;"
        do_nginx_arm_deployment=0
    fi

    uuid="$(cat /proc/sys/kernel/random/uuid)"
    template_file="template-$uuid.json"
    template_deployment_name="${nginx_deployment_name:0:20}-$uuid"
    
    cp "$arm_template_file" "$template_file"
    
    echo "Synchronizing NGINX certificate"
    echo "Subscription ID: $subscription_id"
    echo "Resource group name: $resource_group_name"
    echo "NGINX for Azure deployment name: $nginx_deployment_name"
    echo "NGINX for Azure Location: $nginx_resource_location"
    echo "ARM template deployment name: $template_deployment_name"
    echo ""
    echo "NGINX for Azure cert name: $nginx_cert_name"
    echo "NGINX for Azure cert file location: $nginx_cert_file"
    echo "NGINX for Azure key file location: $nginx_key_file"
    echo ""

    if [ $do_nginx_arm_deployment -eq 1 ]
    then
        set +e
        az deployment group create --name "$template_deployment_name" --resource-group "$resource_group_name" --template-file "$template_file" --parameters name="$nginx_cert_name" location="$nginx_resource_location" nginxDeploymentName="$nginx_deployment_name" certificateVirtualPath="$nginx_cert_file" keyVirtualPath="$nginx_key_file" keyVaultSecretID="$keyvault_secret" --verbose
        set -e  
    else 
        echo "Skipping JSON object $i cert deployment with error:$err_msg"
        echo ""
    fi     
done
