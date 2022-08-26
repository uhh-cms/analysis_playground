#!/usr/bin/env bash

setup_playground() {
    # Runs the project setup, leading to a collection of environment variables starting with either
    #   - "CF_", for controlling behavior implemented by columnflow, or
    #   - "AP_", for features provided by the analysis playground itself.
    # Check the setup.sh in columnflow for documentation of the "CF_" variables. The purpose of all
    # "AP_" variables is documented below.
    #
    # The setup also handles the installation of the software stack via virtual environments, and
    # optionally an interactive setup where the user can configure certain variables.
    #
    #
    # Arguments:
    #   1. The name of the setup. "default" (which is itself the default when no name is set)
    #      triggers a setup with good defaults, avoiding all queries to the user and the writing of
    #      a custom setup file. See "interactive_setup()" for more info.
    #
    #
    # Optinally preconfigured environment variables:
    #   None yet.
    #
    #
    # Variables defined by the setup and potentially required throughout the playground.
    #   AP_BASE
    #       The absolute playground base directory. Used to infer file locations relative to it.
    #   PATH
    #       Ammended PATH variable.
    #   PYTHONPATH
    #       Ammended PYTHONPATH variable.
    #   PYTHONWARNINGS
    #       Set to "ignore".
    #   GLOBUS_THREAD_MODEL
    #       Set to "none".
    #   VIRTUAL_ENV_DISABLE_PROMPT
    #       Set to "1" when not defined already, leading to virtual envs leaving the PS1 prompt
    #       variable unaltered.
    #   X509_USER_PROXY
    #       Set to "/tmp/x509up_u$( id -u )" if not already set.
    #   LAW_HOME
    #       Set to $AP_BASE/.law.
    #   LAW_CONFIG_FILE
    #       Set to $AP_BASE/law.cfg.

    #
    # prepare local variables
    #

    local shell_is_zsh=$( [ -z "${ZSH_VERSION}" ] && echo "false" || echo "true" )
    local this_file="$( ${shell_is_zsh} && echo "${(%):-%x}" || echo "${BASH_SOURCE[0]}" )"
    local this_dir="$( cd "$( dirname "${this_file}" )" && pwd )"
    local orig="${PWD}"
    local setup_name="${1:-default}"
    local setup_is_default="false"
    [ "${setup_name}" = "default" ] && setup_is_default="true"


    #
    # global variables
    # (AP = analysis playground, CF = columnflow)
    #

    # lang defaults
    export LANGUAGE="${LANGUAGE:-en_US.UTF-8}"
    export LANG="${LANG:-en_US.UTF-8}"
    export LC_ALL="${LC_ALL:-en_US.UTF-8}"

    # proxy
    export X509_USER_PROXY="${X509_USER_PROXY:-/tmp/x509up_u$( id -u )}"

    # start exporting variables
    export AP_BASE="${this_dir}"
    export CF_BASE="${this_dir}/modules/columnflow"
    export CF_REPO_BASE="${AP_BASE}"
    export CF_SETUP_NAME="${setup_name}"

    # load cf setup helpers
    CF_SKIP_SETUP="1" source "${CF_BASE}/setup.sh" "" || return "$?"

    # interactive setup
    if [ "${CF_REMOTE_JOB}" != "1" ]; then
        cf_setup_interactive_body() {
            # start querying for variables
            query CF_CERN_USER "CERN username" "$( whoami )"
            export_and_save CF_CERN_USER_FIRSTCHAR "\${CF_CERN_USER:0:1}"
            query CF_DATA "Local data directory" "\$AP_BASE/data" "./data"
            query CF_STORE_NAME "Relative path used in store paths (see next queries)" "ap_store"
            query CF_STORE_LOCAL "Default local output store" "\$CF_DATA/\$CF_STORE_NAME"
            query CF_WLCG_CACHE_ROOT "Local directory for caching remote files" "" "''"
            export_and_save CF_WLCG_USE_CACHE "$( [ -z "${CF_WLCG_CACHE_ROOT}" ] && echo false || echo true )"
            export_and_save CF_WLCG_CACHE_CLEANUP "${CF_WLCG_CACHE_CLEANUP:-false}"
            query CF_SOFTWARE_BASE "Local directory for installing software" "\$CF_DATA/software"
            query CF_CMSSW_BASE "Local directory for installing CMSSW" "\$CF_DATA/cmssw"
            query CF_JOB_BASE "Local directory for storing job files" "\$CF_DATA/jobs"
            query CF_LOCAL_SCHEDULER "Use a local scheduler for law tasks" "True"
            if [ "${CF_LOCAL_SCHEDULER}" != "True" ]; then
                query CF_SCHEDULER_HOST "Address of a central scheduler for law tasks" "naf-cms15.desy.de"
                query CF_SCHEDULER_PORT "Port of a central scheduler for law tasks" "8082"
            else
                export_and_save CF_SCHEDULER_HOST "127.0.0.1"
                export_and_save CF_SCHEDULER_PORT "8082"
            fi
            query CF_VOMS "Virtual-organization" "cms:/cms/dcms"
            export_and_save CF_TASK_NAMESPACE "${CF_TASK_NAMESPACE:-cf}"
        }
        cf_setup_interactive "${CF_SETUP_NAME}" "${AP_BASE}/.setups/${CF_SETUP_NAME}.sh" || return "$?"
    fi

    # continue the fixed setup
    export CF_VENV_BASE="${CF_VENV_BASE:-${CF_SOFTWARE_BASE}/venvs}"
    export CF_CI_JOB="$( [ "${GITHUB_ACTIONS}" = "true" ] && echo 1 || echo 0 )"

    # overwrite some variables in remote and CI jobs
    if [ "${CF_REMOTE_JOB}" = "1" ]; then
        export CF_WLCG_USE_CACHE="true"
        export CF_WLCG_CACHE_CLEANUP="true"
        export CF_WORKER_KEEP_ALIVE="false"
    elif [ "${CF_CI_JOB}" = "1" ]; then
        export CF_WORKER_KEEP_ALIVE="false"
    fi

    # some variable defaults
    export CF_WORKER_KEEP_ALIVE="${CF_WORKER_KEEP_ALIVE:-false}"
    export CF_SCHEDULER_HOST="${CF_SCHEDULER_HOST:-127.0.0.1}"
    export CF_SCHEDULER_PORT="${CF_SCHEDULER_PORT:-8082}"


    #
    # minimal local software setup
    #

    cf_setup_software_stack "${CF_SETUP_NAME}" || return "$?"

    # ammend paths that are not covered by the central cf setup
    export PATH="${AP_BASE}/bin:${PATH}"
    export PYTHONPATH="${AP_BASE}:${AP_BASE}/modules/cmsdb:${PYTHONPATH}"

    # initialze submodules
    if [ -d "${AP_BASE}/.git" ]; then
        for m in $( ls -1q "${AP_BASE}/modules" ); do
            cf_init_submodule "${AP_BASE}/modules/${m}"
        done
    fi


    #
    # law setup
    #

    export LAW_HOME="${AP_BASE}/.law"
    export LAW_CONFIG_FILE="${AP_BASE}/law.cfg"

    if which law &> /dev/null; then
        # source law's bash completion scipt
        source "$( law completion )" ""

        # silently index
        law index -q
    fi
}

main() {
    # Invokes the main action of this script, catches possible error codes and prints a message.

    # run the actual setup
    if setup_playground "$@"; then
        echo -e "\x1b[0;49;35mplayground successfully setup\x1b[0m"
        return "0"
    else
        local code="$?"
        echo -e "\x1b[0;49;31mplayground setup failed with code ${code}\x1b[0m"
        return "${code}"
    fi
}

# entry point
if [ "${AP_SKIP_SETUP}" != "1" ]; then
    main "$@"
fi
