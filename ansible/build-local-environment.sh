#!/bin/bash

function create_inventory_file() {
    echo "INFO: Creating ansible inventory file: ${inventory_file} ..."
	cat << EOF > "${inventory_file}"
localhost ansible_connection=local openshift=${minishift_ip}:8443
EOF
    if [ $? -eq 0 ]; then
        echo "INFO: Created ansible inventory file: ${inventory_file} OK."
    else
		echo "ERROR: Failed to write ansible inventory to ${inventory_file}."
		return 1
    fi
}

function ensure_minishift_installed() {
	declare minishift_version=
	
	minishift_version="$(minishift version)" || {
		echo "ERROR: Failed to get minishift version. Is minishift installed?"
		return 1
    }

    echo "INFO: minishift version is:"
    echo "${minishift_version}"
}


function is_minishift_running() {
	declare minishift_status=
	
	minishift_status="$(minishift status)" || {
		echo "ERROR: Failed to get minishift status."
		return 2
    }

    declare -A status_map

	while read -r status_line; do

	    declare key="${status_line%%:*}"
	
	    # Remove leading spaces.
	    key="${key#"${key%%[![:space:]]*}"}"

    	declare value="${status_line#*:}"
	
	    # Remove leading spaces.
	    value="${value#"${value%%[![:space:]]*}"}"

    	status_map["${key}"]="${value}"
    done <<< "${minishift_status}"

    declare minishift_status="${status_map["Minishift"]}"

    echo "INFO: Minishift status is \"${minishift_status}\"."

    if [[ "${minishift_status}" == "Running" ]]; then
    	return 0
    else
    	return 1
    fi
}

function ensure_minishift_running() {

    is_minishift_running
    declare -i running=$?

    if [[ ${running} -eq 1 ]]; then
    	echo "INFO: minishift is not running - starting it ..."
    	start_minishift
	elif [[ ${running} -eq 0 ]]; then
		echo "INFO: minishift is running."
	else
		# Can't start minishift.
		return 1
	fi
}

function start_minishift() {
	echo "INFO: starting minishift. This will take a while ..."
	minishift start && {
		echo "INFO: Started minishift OK."
		return 0
    }

    echo "ERROR: Failed to start minishift."
    return 1
}

function get_minishift_ip() {
	echo "INFO: Getting minishift IP address ..."
	minishift_ip="$( minishift ip )" || {
		echo "ERROR: Failed to get minishift VM IP address."
		return 1
    }

    echo "INFO: minishift IP address is ${minishift_ip}"
}

function run_ansible() {
	echo "INFO: creating the local environment. This will take a while ..."
	ansible-playbook -i "${inventory_file}" create-local-environment-playbook.yml $@
	if [ $? -eq 0 ]; then
		echo "INFO: Created local environment OK."
	else
		echo "ERROR: Failed to create local environment."
		return 1
    fi
}

ensure_minishift_installed || exit 1

ensure_minishift_running || exit 1

minishift_ip=
get_minishift_ip || exit 1


inventory_file="${TMPDIR:=/tmp}/inventory$$"

# Ensure the inventory file is removed at program termination or after a signal has been received.
trap 'rm -f "${inventory_file}" >/dev/null 2>&1' 0
trap "exit 2" SIGHUP SIGINT SIGQUIT SIGPIPE SIGTERM

create_inventory_file || exit 1

run_ansible $@ || exit 1