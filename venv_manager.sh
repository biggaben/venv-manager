#!/bin/bash

# Function to ensure the virtual environments directory exists
ensure_venv_dir() {
    local dir="$1"
    mkdir -p "$dir"
}

# Function to check if a virtual environment name is provided
check_venv_name() {
    if [ -z "$1" ]; then
        echo "Error: You must specify a name for the virtual environment."
        return 1
    fi
}

# Function to list available commands
list_commands() {
    echo "Available commands:"
    echo "  venv list (l)            - List available commands"
    echo "  venv create (c) <name>   - Create a new virtual environment"
    echo "  venv activate (a) <name> - Activate an existing virtual environment"
    echo "  venv deactivate (d)      - Deactivate the current virtual environment"
    echo "  venv remove (r) <name>   - Remove an existing virtual environment"
    echo "  venv show (s)            - Show all virtual environments"
}

# Function to create a virtual environment
venv_create() {
    local venv_path="$1"
    local version="$2"
    local python_exe_path="$3"
    local json_path="$HOME/.local/share/venv/PythonVersions.json"

    # Ensure jq is installed
    if ! command -v jq &>/dev/null; then
        echo "Error: jq is required for JSON handling. Please install jq."
        return 1
    fi

    # Load existing versions from JSON or initialize an empty list
    if [[ -f "$json_path" ]]; then
        versions_list=$(cat "$json_path")
    else
        versions_list="[]"
    fi

    if [[ -n "$version" && -z "$python_exe_path" ]]; then
        existing_entry=$(echo "$versions_list" | jq -r --arg version "$version" '.[] | select(.Version==$version)')
        if [[ -n "$existing_entry" ]]; then
            python_exe_path=$(echo "$existing_entry" | jq -r '.Path')
        else
            correct_version=false
            until [[ "$correct_version" == true ]]; do
                read -p "Specify the path to python executable: " python_exe_path
                if [[ -x "$python_exe_path" ]]; then
                    output=$($python_exe_path --version 2>&1)
                    if [[ "$output" == *"$version"* ]]; then
                        correct_version=true
                    else
                        echo "The Python executable at $python_exe_path does not match the requested version $version."
                    fi
                else
                    echo "Path is invalid. Please enter a valid path."
                fi
            done
            versions_list=$(echo "$versions_list" | jq --arg version "$version" --arg path "$python_exe_path" '. += [{"Version":$version,"Path":$path}]')
            echo "$versions_list" | jq '.' > "$json_path"
        fi
    fi

    if [[ -n "$python_exe_path" ]]; then
        echo "Creating virtual environment using: $python_exe_path -m venv $venv_path"
        $python_exe_path -m venv "$venv_path"
    else
        echo "Creating virtual environment using: python -m venv $venv_path"
        python -m venv "$venv_path"
    fi

    if [[ $? -eq 0 ]]; then
        echo "Virtual environment created successfully at '$venv_path'."
    else
        echo "Failed to create virtual environment at '$venv_path'."
    fi
}

# Function to manage virtual environments
venv() {
    local venv_dir="$HOME/.virtualenvs"
    ensure_venv_dir "$venv_dir"

    case $1 in
        list | l)
            list_commands
            ;;
        create | c)
            check_venv_name "$2" || return 1
            venv_create "$venv_dir/$2"
            ;;
        activate | a)
            check_venv_name "$2" || return 1
            if [ -f "$venv_dir/$2/bin/activate" ]; then
                echo "Activating virtual environment: $venv_dir/$2"
                source "$venv_dir/$2/bin/activate"
            else
                echo "Error: Virtual environment '$2' does not exist."
                return 1
            fi
            ;;
        deactivate | d)
            if [[ -n "$VIRTUAL_ENV" ]]; then
                echo "Deactivating current virtual environment: $VIRTUAL_ENV"
                deactivate
            else
                echo "No virtual environment is currently active."
            fi
            ;;
        remove | r)
            check_venv_name "$2" || return 1
            echo "Removing virtual environment: $venv_dir/$2"
            rm -rf "$venv_dir/$2"
            echo "Virtual environment '$2' removed."
            ;;
        show | s)
            if [ -d "$venv_dir" ]; then
                echo "Available virtual environments:"
                ls "$venv_dir"
            else
                echo "No virtual environments found."
            fi
            ;;
        *)
            echo "Unknown command: $1"
            echo "Use 'venv list' to see available commands."
            return 1
            ;;
    esac
}

venv "$@"
