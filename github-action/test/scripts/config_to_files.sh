#!/bin/bash

# Function to print usage
print_usage() {
    echo "Usage: $0 [-f <json_file>] [-o <output_filepath>]"
    echo "Options:"
    echo "  -f <json_file>  Specify the JSON file to generate the config from (required)"
    echo "  -o <output_filepath>  Specify the base output filepath (optional)"
    exit 1
}

# Parse command line options
json_file=''
output_filepath=$PWD

while getopts ":o:f:" opt; do
    case $opt in
        f)  json_file="$OPTARG";;
        o)  output_filepath="$OPTARG";;
        \?) echo "Error: Invalid option -$OPTARG" >&2; print_usage;;
    esac
done

# Check if the JSON file exists
if [ ! -f "$json_file" ]; then
    echo "Error: JSON file '$json_file' not found."
    exit 1
fi

# Extract base64 encoded content and virtualPath
# Use mapfile to store the output of jq into arrays
while IFS= read -r content; do
    content_list+=("$content")
done < <(jq -r '.properties.files[].content' "$json_file")

while IFS= read -r virtual_path; do
    virtual_path_list+=("$virtual_path")
done < <(jq -r '.properties.files[].virtualPath' "$json_file")

# Decode and write content to files, keeping track of created files
created_files=()
for (( i=0; i<${#content_list[@]}; i++ )); do
    content=$(echo "${content_list[$i]}" | base64 -d)
    virtual_path="${virtual_path_list[$i]}"
    echo "Extracting file $virtual_path to ${output_filepath}${virtual_path}"
    
    # Extract the directory path and create parent directories if they don't exist
    parent_dir=$(dirname "${output_filepath}${virtual_path}")
    mkdir -p "$parent_dir"
    
    # Write content to file
    echo "$content" > "${output_filepath}${virtual_path}"
    
    # Add created file to the list
    created_files+=("${output_filepath}${virtual_path}")
done

echo "Extracted ${#created_files[@]} files"
