#!/usr/bin/env bash

# Script that sets up a virtual env in $AP_VENV_PATH.
# For more info on functionality and parameters, see the generic setup script _setup_venv.sh.

action() {
    local this_file="$( [ ! -z "$ZSH_VERSION" ] && echo "${(%):-%x}" || echo "${BASH_SOURCE[0]}" )"
    local this_dir="$( cd "$( dirname "$this_file" )" && pwd )"
    local ap_dir="$( dirname "$this_dir" )"

    # set variables and source the generic venv setup
    export AP_VENV_NAME="$( basename "${this_file%.sh}" )"
    export AP_VENV_REQUIREMENTS="$ap_dir/docs/requirements.txt"

    source "$this_dir/_setup_venv.sh" "$@"
}
action "$@"
