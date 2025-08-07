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
    --certificates=*)
    certificates="${i#*=}"
    shift
    ;;
    --debug=*)
    debug="${i#*=}"
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
if [[ ! -v certificates ]];
then
    echo "Please set 'nginx-certificates' ..."
    exit 1
fi

az account set -s "$subscription_id" --verbose

count=$(echo "$certificates" | jq '. | length')
for (( i=0; i<count; i++ ));
do
    nginx_cert_name=$(echo "$certificates" | jq -r '.['"$i"'].certificateName')
    nginx_cert_file=$(echo "$certificates" | jq -r '.['"$i"'].certificateVirtualPath')
    nginx_key_file=$(echo "$certificates" | jq -r '.['"$i"'].keyVirtualPath')
    keyvault_secret=$(echo "$certificates" | jq -r '.['"$i"'].keyvaultSecret')

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

    echo "Synchronizing NGINX certificate"
    echo "Subscription ID: $subscription_id"
    echo "Resource group name: $resource_group_name"
    echo "NGINXaaS for Azure deployment name: $nginx_deployment_name"
    echo ""
    echo "NGINXaaS for Azure cert name: $nginx_cert_name"
    echo "NGINXaaS for Azure cert file location: $nginx_cert_file"
    echo "NGINXaaS for Azure key file location: $nginx_key_file"
    echo ""

    echo "Installing the az nginx extension if not already installed."
    az extension add --name nginx --allow-preview true

    if [ $do_nginx_arm_deployment -eq 1 ]
    then
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
        set +e
        "${az_cmd[@]}"
        set -e
    else
        echo "Skipping JSON object $i cert deployment with error:$err_msg"
        echo ""
    fi
done
