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

# Common utility functions

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

# Function to encode file content to base64
encode_file_base64() {
    local file_path="$1"
    # Use base64 to encode the file content
    # -w 0 option is used to avoid line wrapping in the output
    base64 -w 0 "$file_path"
}

# Function to build virtual path from relative path
build_virtual_path() {
    local relative_path="$1"
    echo "${transformed_config_dir_path}${relative_path}"
}

# Function to add a file entry to a JSON array
# The add_file_to_json_array function uses indirect variable references
# and global assignment to update JSON arrays and flags that track
# which files have been processed. The variable names for the JSON array 
# and the "first file" flag are passed as arguments, allowing the
# function to generically update different arrays 
# (for regular and protected files) without hardcoding their names.
# The syntax ${!var} retrieves the value of the variable whose 
# name is stored in 'var', and declare -g ensures the updated
# values are set globally, so changes persist outside the function.
add_file_to_json_array() {
    local file_path="$1"
    local virtual_path="$2"
    local file_type="$3"  # "regular" or "protected"
    local json_var_name="$4"  # Variable name to modify
    local first_file_var_name="$5"  # Variable name for first_file flag
    
    if [ -f "$file_path" ]; then
        echo "Processing $file_type file: $file_path -> $virtual_path"
        
        # Base64 encode the file content
        local file_content_b64
        file_content_b64=$(encode_file_base64 "$file_path")
        
        # Get current values using indirect variable references
        local current_json="${!json_var_name}"
        local is_first_file="${!first_file_var_name}"
        
        # Add comma separator if not the first file
        if [ "$is_first_file" = false ]; then
            current_json+=","
        fi
        
        # Add the file entry to JSON array
        current_json+="{\"content\":\"$file_content_b64\",\"virtual-path\":\"$virtual_path\"}"
        
        # Update the variables using indirect assignment
        declare -g "$json_var_name=$current_json"
        declare -g "$first_file_var_name=false"
        
        if [[ "$debug" == true ]]; then
            echo "$file_type file virtual path: $virtual_path"
            echo "$file_type file content (base64): ${file_content_b64:0:50}..."
        fi
    else
        echo "Warning: $file_type file '$file_path' not found"
    fi
}

# Process protected files first to build exclusion list
protected_files_list=()
if [ -n "$protected_files" ]; then
    IFS=',' read -ra files <<< "$protected_files"
    
    for file in "${files[@]}"; do
        file=$(trim_whitespace "$file")
        if [ -n "$file" ]; then
            protected_files_list+=("$file")
        fi
    done
fi

# Function to check if a file is in the protected files list
is_protected_file() {
    local relative_path="$1"
    for protected_file in "${protected_files_list[@]}"; do
        if [ "$relative_path" = "$protected_file" ]; then
            return 0
        fi
    done
    return 1
}

# Process all configuration files individually (excluding protected files)

echo "Processing NGINX configuration files individually."

# Build the files JSON array
files_json="["
# shellcheck disable=SC2034  # Variable is used via indirect reference in add_file_to_json_array
files_first_file=true

# Find all files in the config directory and process them (excluding protected files)
while IFS= read -r -d '' file; do
    # Get relative path from config directory
    relative_path="${file#"$config_dir_path"}"
    
    # Skip if this file is in the protected files list
    if is_protected_file "$relative_path"; then
        echo "Skipping protected file from regular files: $relative_path"
        continue
    fi
    
    # Apply transformation to get virtual path
    virtual_path=$(build_virtual_path "$relative_path")
    
    add_file_to_json_array "$file" "$virtual_path" "regular" "files_json" "files_first_file"
done < <(find "$config_dir_path" -type f -print0)

files_json+="]"

if [[ "$debug" == true ]]; then
    echo "Regular files JSON: $files_json"
fi

# Process protected files if specified
protected_files_arg=""
if [ -n "$protected_files" ]; then
    echo "Processing protected files: $protected_files"
    
    # Build the protected files JSON array
    protected_files_json="["
    protected_first_file=true
    IFS=',' read -ra files <<< "$protected_files"
    
    for file in "${files[@]}"; do
        file=$(trim_whitespace "$file")
        if [ -n "$file" ]; then
            repo_file_path="${config_dir_path}${file}"
            virtual_path=$(build_virtual_path "$file")
            
            add_file_to_json_array "$repo_file_path" "$virtual_path" "protected" "protected_files_json" "protected_first_file"
        fi
    done
    
    protected_files_json+="]"
    
    if [ "$protected_first_file" = false ]; then
        protected_files_arg="--protected-files"
        if [[ "$debug" == true ]]; then
            echo "Protected files JSON: $protected_files_json"
        fi
    fi
fi


# Synchronize the NGINX configuration files to the NGINXaaS for Azure deployment.

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
    "--name" "default"
    "--deployment-name" "$nginx_deployment_name"
    "--resource-group" "$resource_group_name"
    "--root-file" "$transformed_root_config_file_path"
    "--files" "$files_json"
    "--verbose"
)

# Add protected files argument if present
if [ -n "$protected_files_arg" ]; then
    az_cmd+=("$protected_files_arg")
    az_cmd+=("$protected_files_json")
fi

if [[ "$debug" == true ]]; then
    az_cmd+=("--debug")
    echo "${az_cmd[@]}"
fi

"${az_cmd[@]}"
