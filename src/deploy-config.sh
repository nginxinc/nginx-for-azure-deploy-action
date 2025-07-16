#!/bin/bash
set -eo pipefail
IFS=$'\n\t'

transformed_config_dir_path=''
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
    --nginx-config-directory-path=*)
    config_dir_path="${i#*=}"
    shift
    ;;
    --nginx-root-config-file=*)
    root_config_file="${i#*=}"
    shift
    ;;
    --transformed-nginx-config-directory-path=*)
    transformed_config_dir_path="${i#*=}"
    shift
    ;;
    --debug=*)
    debug="${i#*=}"
    shift
    ;;
    --protected-files=*)
    protected_files="${i#*=}"
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
if [ -z "$config_dir_path" ]; then
    missing_params+=("nginx-config-directory-path")
fi
if [ -z "$root_config_file" ]; then
    missing_params+=("nginx-root-config-file")
fi

# Check and print if any required params are missing
if [ ${#missing_params[@]} -gt 0 ]; then
    echo "Error: Missing required variables in the workflow:"
    echo "${missing_params[*]}"
    exit 1
fi

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

encoded_config_tarball=$(base64 "$config_tarball" -w 0)

if [[ "$debug" == true ]]; then
    echo "The base64 encoded NGINX configuration tarball"
    echo "$encoded_config_tarball"
fi
echo ""

# Synchronize the NGINX configuration tarball to the NGINXaaS for Azure deployment.

echo "Synchronizing NGINX configuration"
echo "Subscription ID: $subscription_id"
echo "Resource group name: $resource_group_name"
echo "NGINXaaS for Azure deployment name: $nginx_deployment_name"
echo ""

az account set -s "$subscription_id" --verbose

echo "Installing the az nginx extension if not already installed."
az extension add --name nginx --allow-preview true

az_cmd=(
    "az"
    "nginx"
    "deployment"
    "configuration"
    "update"
    "--verbose"
    "--name" "default"
    "--deployment-name" "$nginx_deployment_name"
    "--resource-group" "$resource_group_name"
    "--root-file" "$transformed_root_config_file_path"
    "--package" "data=$encoded_config_tarball"
)

# Function to trim whitespace from a string
trim_whitespace() {
    local var="$1"
    # Trim leading whitespace from the file path (var)
    # ${var%%[![:space:]]*} starts at the file path's end
    # and finds the longest match of non-whitespace
    # characters leaving only leading whitespaces
    # ${var#"..." } removes the leading whitespace found
    var="${var#"${var%%[![:space:]]*}"}"
    # Remove trailing whitespace
    # See explanation above. The process is reversed here.
    var="${var%"${var##*[![:space:]]}"}"
    # Check if the file exists in the repository
    echo "$var"
}

# Add protected-files parameter if provided
if [[ -n "$protected_files" ]]; then
    # Convert comma-separated list to JSON array format
    IFS=',' read -ra files <<< "$protected_files"
    json_array="["
    for i in "${files[@]}"; do
        # Trim whitespace and add quotes
        file_path="$(trim_whitespace "$i")"
        if [[ "$json_array" != "[" ]]; then
            json_array+=","
        fi
        json_array+="\"$transformed_config_dir_path$file_path\""
    done
    json_array+="]"
    
    az_cmd+=("protected-files=$json_array")
    echo "Protected files: $json_array"
fi

if [[ "$debug" == true ]]; then
    az_cmd+=("--debug")
    echo "${az_cmd[@]}"
fi

"${az_cmd[@]}"
