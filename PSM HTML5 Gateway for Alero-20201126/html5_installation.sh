#!/bin/bash

create_user() {
	uid=${1}
	username=${2}

	if [ -z $(getent passwd $uid) ]
	then
        	useradd -u $uid -M -r -s /bin/false $username
	else
        	existing_username=$(id -nu $uid)

	        if [ $existing_username != $username ]
	        then
	                echo "Error: uid '$uid' already exists (username: '$existing_username')"
	                exit 1
	        else
	                echo "User '$username' (uid: $uid) already exists"
	        fi
	fi
}

create_group() {
	gid=${1}
	group_name=${2}

	if [ -z $(getent group $gid) ]
        then
                groupadd -g $gid -r $group_name
        else
                existing_group_name=$(getent group $gid | cut -d: -f1)

                if [ $existing_group_name != $group_name ]
                then
                        echo "Error: gid '$gid' already exists (group name: '$existing_group_name')"
                        exit 1
                else
                        echo "Group '$group_name' (gid: $gid) already exists"
                fi
        fi
}

create_docker_network() {
	docker_network_name=${1}

	if [ -z $(docker network ls --filter name=^${docker_network_name}$ --format="{{ .Name }}") ]
	then 
     		docker network create ${docker_network_name}
	else
		echo "Docker network '$docker_network_name' already exists"
	fi
}

step() {
	local step_name=${1}

	printf "$step_name...\n"
}

step_done() {
	printf "DONE\n\n"
}

error() {
        local error_message=${1}

        if [[ ! -z $error_message ]]; then
                echo "Error: $error_message"
        fi

        exit 1
}

validate_docker_registry_config() {
	local docker_repository=${1}

	step "Validating docker registries configuration file for registry '$docker_repository'"

	# Making sure that the passed docker registry is the first one in the registries array
	# This is in order to mitigate a bug in old docker versions that causes docker to consider only the first registry and ignore all the rest

	if [ -f "$DOCKER_REGISTRIES_FILE" ]; then
        	docker_registry="$( cut -d '/' -f 1 <<< "$docker_repository" )"
		find_docker_registry_output=$(cat $DOCKER_REGISTRIES_FILE | grep -Pzo "\[registries\.search\]\s*registries\s*=\s*\[\s*'\s*"$docker_registry"\s*'")

 		if [ -z "$find_docker_registry_output" ]; then
                        registry_array_current="^\s*registries\s*=\s*\["
           		registry_array_new="registries=['$docker_registry',"
           		echo "Updating docker registries configuration file: '$DOCKER_REGISTRIES_FILE'"
		   	sed -i "0,/$registry_array_current/s//$registry_array_new/" $DOCKER_REGISTRIES_FILE
   			echo "Restarting docker service..."
           		service docker restart
		fi
    fi

	step_done
}

docker_hub_logout() {
	local silent_logoff=${1:-false}

	[[ $silent_logoff == false ]] && step "Logoff from docker hub"
	docker logout > /dev/null 2>&1
        [[ $silent_logoff == false ]] && step_done
}

docker_hub_login() {
        local docker_hub_username=${1}

	step "Login to docker hub (username: '$docker_hub_username')"

        docker_hub_logout true
        docker login -u=$docker_hub_username || error "failed to login docker hub"

	step_done
}

docker_hub_pull_repository() {
	local docker_repository=${1}

	step "Pulling '$docker_repository' image"

	docker pull $docker_repository

	if [ $? -ne 0 ]; then
		docker_hub_logout
		error
	fi

	step_done
}

download_html5_image() {
	local docker_hub_username=${1}
	local docker_repository=${2}

	validate_docker_registry_config "$docker_repository"
	docker_hub_login "$docker_hub_username"
	docker_hub_pull_repository "$docker_repository"
	docker_hub_logout
}

# variables
ca_tomcat_uid=367
ca_tomcat_gid=367
ca_tomcat=cyberark_tomcat
ca_psmgw_uid=368
ca_psmgw_gid=368
ca_psmgw=cyberark_psmgw
docker_network_name="cyberark"
local_image_path="./cahtml5gw"

# define defualt arguments
DEFAULT_ENVIRONMENT_DOMAIN="alero.io"
DEFAULT_DOCKER_REPOSITORY="docker.io/alerocyberark/psmhtml5:latest"

# define const variables
DOCKER_NETWORK_NAME="cyberark"
DOCKER_HUB_USERNAME="alerouser"
DOCKER_REGISTRIES_FILE=/etc/containers/registries.conf

DOCKER_REPOSITORY=${docker_repository:-$DEFAULT_DOCKER_REPOSITORY}

# installation steps
printf "Creating '$ca_tomcat' user...\n"
create_user $ca_tomcat_uid $ca_tomcat
step_done

printf "Creating '$ca_tomcat' group...\n"
create_group $ca_tomcat_gid $ca_tomcat
step_done

printf "Creating '$ca_psmgw' user...\n"
create_user $ca_psmgw_uid $ca_psmgw
step_done

printf "Creating '$ca_psmgw' group...\n"
create_group $ca_psmgw_gid $ca_psmgw
step_done

printf "Creating docker network '$docker_network_name'...\n"
create_docker_network $docker_network_name
step_done

if [ $1 = "localimage" ]
then
	printf "Loading the PSM HTML5 Gateway image from file '$local_image_path'\n"
	docker load -i $local_image_path
else
   download_html5_image "$DOCKER_HUB_USERNAME" "$DOCKER_REPOSITORY"
fi
