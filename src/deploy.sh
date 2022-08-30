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
    --config_dir_path=*)
    config_dir_path="${i#*=}"
    shift 
    ;;
    --root_config_file=*)
    root_config_file="${i#*=}"
    shift 
    ;;
    --transformed_config_dir_path=*)
    transformed_config_dir_path="${i#*=}"
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

if [[ -v nginx_resource_location ]] && [[ -v certificates ]];
then
    ./deploy-certificate.sh \
    --subscription_id="$subscription_id" \
    --resource_group_name="$resource_group_name" \
    --nginx_deployment_name="$nginx_deployment_name" \
    --nginx_resource_location="$nginx_resource_location" \
    --certificates="$certificates"
fi

if [[ ! -v transformed_config_dir_path ]];
then
    transformed_config_dir_path=''
fi

if [[ -v config_dir_path ]] && [[ -v root_config_file ]];
then
    ./deploy-config.sh \
    --subscription_id="$subscription_id" \
    --resource_group_name="$resource_group_name" \
    --nginx_deployment_name="$nginx_deployment_name" \
    --config_dir_path="$config_dir_path" \
    --root_config_file="$root_config_file" \
    --transformed_config_dir_path="$transformed_config_dir_path"
fi

