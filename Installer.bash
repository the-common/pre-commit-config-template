#!/usr/bin/env bash
# shellcheck disable=SC2034

# Install the templates to their proper locations
#
# Copyright 2020 林博仁(Buo-ren, Lin) <Buo.Ren.Lin@gmail.com>
# SPDX-License-Identifier: CC-BY-SA-4.0

# Error on premature signs
set \
    -o errexit \
    -o errtrace \
    -o nounset \
    -o pipefail

# Runtime Dependencies Checking
runtime_dependency_checking_failed=false
for required_command in \
    basename \
    dirname \
    install \
    realpath \
    rm; do
    if ! command -v "${required_command}" >/dev/null; then
        runtime_dependency_checking_failed=true

        case "${required_command}" in
            basename \
            |dirname \
            |install \
            |mv \
            |realpath \
            |rm)
                required_software='GNU Coreutils'
                ;;
            *)
                required_software="${required_command}"
                ;;
        esac

        printf \
            'Error: This program requires "%s" to be installed and its executables in the executable searching paths.\n' \
            "${required_software}" \
            1>&2
    fi
done
if test "${runtime_dependency_checking_failed}" == true; then
    printf --\
        'Error: Runtime dependency checking fail, the progrom cannot continue.\n' 1>&2
    exit 1
fi
unset \
    runtime_dependency_checking_failed \
    required_command \
    required_software

## Non-overridable Primitive Variables
## BASHDOC: Shell Variables » Bash Variables
## BASHDOC: Basic Shell Features » Shell Parameters » Special Parameters
if test -v 'BASH_SOURCE[0]'; then
    RUNTIME_EXECUTABLE_PATH="$(realpath --strip "${BASH_SOURCE[0]}")"
    RUNTIME_EXECUTABLE_FILENAME="$(basename "${RUNTIME_EXECUTABLE_PATH}")"
    RUNTIME_EXECUTABLE_NAME="${RUNTIME_EXECUTABLE_FILENAME%.*}"
    RUNTIME_EXECUTABLE_DIRECTORY="$(dirname "${RUNTIME_EXECUTABLE_PATH}")"
    RUNTIME_COMMANDLINE_BASECOMMAND="${0}"
    readonly \
        RUNTIME_EXECUTABLE_PATH RUNTIME_EXECUTABLE_FILENAME RUNTIME_EXECUTABLE_NAME \
        RUNTIME_EXECUTABLE_DIRECTORY RUNTIME_COMMANDLINE_BASECOMMAND
fi
declare -ar RUNTIME_COMMANDLINE_ARGUMENTS=("${@}")

## init function: entrypoint of main program
## This function is called near the end of the file,
## with the script's command-line parameters as arguments
init(){
    local flag_uninstall=false

    # [template|project]
    local mode_install=template

    local install_directory_templates
    local install_directory_project

    if ! process_commandline_arguments \
            flag_uninstall \
            mode_install \
            install_directory_project; then
        printf \
            'Error: %s: Invalid command-line parameters.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        print_help
        exit 1
    fi

    case "${mode_install}" in
        template)
            if ! determine_templates_directory \
                    install_directory_templates; then
                printf \
                    'Error: Unable to determine install directory, installer cannot continue.\n' \
                    1>&2
                exit 1
            else
                printf \
                    'Will be installed to: %s\n' \
                    "${install_directory_templates}"
                printf '\n'
            fi

            cleanup_old_installation \
                "${install_directory_templates}"
            if test "${flag_uninstall}" = true; then
                printf \
                        'Software uninstalled successfully.\n'
                exit 0
            fi

            printf \
                'Installing template files...\n'
            mkdir \
                --parents \
                "${XDG_TEMPLATES_DIR}"
            install \
                --verbose \
                --mode=u=rw,go=r \
                "${RUNTIME_EXECUTABLE_DIRECTORY}/common.pre-commit-config.yaml" \
                "${install_directory_templates}"/.pre-commit-config.yaml
            printf '\n' # Seperate output from different operations

            flag_install_kde_support=false
            while true; do
                printf \
                    'Do you want to install files to enable KDE support(y/N)?'
                read -r answer

                if test -z "${answer}"; then
                    break
                else
                    # lowercasewize
                    answer="${answer,,?}"

                    if test "${answer}" != n && test "${answer}" != y; then
                        # wrong format, re-ask
                        continue
                    else
                        flag_install_kde_support=true
                        break
                    fi
                fi
            done
            if test "${answer}" == y; then
                printf 'Configuring templates for KDE...\n'
                mkdir \
                    --parents \
                    "${HOME}/.local/share/templates"
                install \
                    --verbose \
                    --mode=u=rw,go=r \
                    "${RUNTIME_EXECUTABLE_DIRECTORY}/common.pre-commit-config.yaml" \
                    "${HOME}/.local/share/templates"
                install \
                    --verbose \
                    --mode=u=rw,go=r \
                    "${RUNTIME_EXECUTABLE_DIRECTORY}/Template Setup for KDE"/*.desktop \
                    "${HOME}/.local/share/templates"
            fi
            unset answer

        ;;
        project)
            if test -e "${install_directory_project}"/.pre-commit-config.yaml; then
                mv \
                    "${install_directory_project}"/.pre-commit-config.yaml{,."$(date +%Y%m%d-%H%M%S-%A)".bak}
                install \
                    --mode=0644 \
                    "${RUNTIME_EXECUTABLE_DIRECTORY}"/common.pre-commit-config.yaml \
                    "${install_directory_project}"/.pre-commit-config.yaml
            fi
        ;;
        *)
            printf \
                'Error: Invalid install mode, contact the publisher for support.\n' \
                1>&2
            exit 1
        ;;
    esac

    printf 'Installation completed.\n'
    exit 0
}

print_help(){
    printf '# %s #\n' "${RUNTIME_EXECUTABLE_NAME}"
    printf 'This program installs the templates into the system to make it accessible.\n\n'

    printf '## Synopsis ##\n'
    pritnf "### Install template to the user's template directory ###\\n"
    printf '%s [OPTION]...\n\n' "${RUNTIME_EXECUTABLE_NAME}"

    pritnf "### Install template to the specified project's directory ###\\n"
    printf '%s [OPTION]... [PROJECT_DIR]\n\n' "${RUNTIME_EXECUTABLE_NAME}"

    printf '## Command-line Options ##\n'
    printf '### --help / -h ###\n'
    printf 'Print this message\n\n'

    printf '### --uninstall / -u ###\n'
    printf 'Instead of installing, attempt to remove previously installed product\n\n'

    printf '### --debug / -d ###\n'
    printf 'Enable debug mode\n\n'

    return 0
}

process_commandline_arguments() {
    local -n flag_uninstall_ref="${1}"; shift 1
    local -n mode_install_ref="${1}"; shift 1
    local -n install_directory_project_ref="${1}"; shift 1

    if test "${#RUNTIME_COMMANDLINE_ARGUMENTS[@]}" -eq 0; then
        return 0
    fi

    # modifyable parameters for parsing by consuming
    local -a parameters=("${RUNTIME_COMMANDLINE_ARGUMENTS[@]}")

    # Normally we won't want debug traces to appear during parameter parsing, so we add this flag and defer it activation till returning
    local enable_debug=false

    while true; do
        if test "${#parameters[@]}" -eq 0; then
            break
        else
            case "${parameters[0]}" in
                --help\
                |-h)
                    print_help;
                    exit 0
                    ;;
                --uninstall\
                |-u)
                    flag_uninstall_ref=true
                    ;;
                --debug\
                |-d)
                    enable_debug=true
                    ;;
                *)
                    if test "${mode_install_ref}" == template; then
                        printf \
                            'ERROR: This program only supports at most 1 positional argument.\n' \
                            >&2
                        return 1
                    fi
                    mode_install_ref=project
                    install_directory_project_ref="${parameters[0]}"
                    ;;
            esac
            # shift array by 1 = unset 1st then repack
            unset 'parameters[0]'
            if test "${#parameters[@]}" -ne 0; then
                parameters=("${parameters[@]}")
            fi
        fi
    done

    if test "${enable_debug}" == true; then
        trap 'trap_return "${FUNCNAME[0]}"' RETURN
        set -o xtrace
    fi
    return 0
}
declare -fr process_commandline_arguments

determine_templates_directory(){
    local -n install_directory_templates_ref="${1}"; shift

    # For $XDG_TEMPLATES_DIR
    if test -f "${HOME}"/.config/user-dirs.dirs;then
        # external file, disable check
        #shellcheck disable=SC1091
        source "${HOME}"/.config/user-dirs.dirs

        if test -v XDG_TEMPLATES_DIR; then
            install_directory_templates_ref="${XDG_TEMPLATES_DIR}"
            return 0
        fi
    fi

    printf \
        "%s: Warning: Installer can't locate user-dirs configuration, will fallback to unlocalized directories\\n" \
        "${FUNCNAME[0]}" \
        1>&2

    if ! test -d "${HOME}"/Templates; then
        return 1
    else
        install_directory_templates_ref="${HOME}"/Templates
    fi

}
declare -fr determine_templates_directory

## Attempt to remove old installation files
cleanup_old_installation(){
    local install_directory_templates="${1}"; shift 1

    printf 'Removing previously installed templates(if available)...\n'
    rm \
        --verbose \
        --force \
        "${install_directory_templates}/common.pre-commit-config.yaml"
    rm \
        --verbose \
        --force \
        "${HOME}/.local/share/templates/common.pre-commit-config.yaml" \
        "${HOME}/.local/share/templates/common.pre-commit-config.yaml.desktop"
    printf 'Finished.\n'

    printf '\n' # Additional blank line for separating output
    return 0
}

## Traps: Functions that are triggered when certain condition occurred
## Shell Builtin Commands » Bourne Shell Builtins » trap
trap_errexit(){
    printf 'An error occurred and the script is prematurely aborted\n' 1>&2
    return 0
}

trap_exit(){
    return 0
}

trap_return(){
    local returning_function="${1}"

    printf 'DEBUG: %s: returning from %s\n' "${FUNCNAME[0]}" "${returning_function}" 1>&2
}

trap_interrupt(){
    printf '\n' # Separate previous output
    printf 'Recieved SIGINT, script is interrupted.' 1>&2
    return 1
}

init "${@}"
