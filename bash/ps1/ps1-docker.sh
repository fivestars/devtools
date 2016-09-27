#! /bin/sh
# Source from .bashrc
#
# Provides:
#
#   ps1-docker: Generates a prompt string summarizing the state of the local docker environment
#
# Example (in .bashrc):
#
#   . /path/to/ps1-docker.sh # use some sort of non-relative path
#   export PS1='\n\u\033[1;37m@\033[1;36m\h:\033[1;33m\w ($(ps1-docker))\033[1;37m\n$\033[0m '

function ps1-docker() {
    local swarm manager status tasks node=$DOCKER_MACHINE_NAME

    if ! command -v docker &>/dev/null || ! command -v docker-machine &>/dev/null; then
        return
    fi

    if [[ -n $DOCKER_MACHINE_NAME ]]; then
        # Check the status of our current node
        status=$(docker-machine status $DOCKER_MACHINE_NAME)
        if [[ $status != "Running" ]]; then
            # Not much to do if it's not running
            printf "\n[%s:%s]" $DOCKER_MACHINE_NAME $status
        else
            # Determine if our current machine is part of a swarm
            swarm=$(docker info | grep -q "Swarm: active" && echo true || echo false)

            if $swarm && docker node ls &>/dev/null; then
                # If we're in a swarm, and the current node is the swarm master,
                # print a swarm summary

                # Print the running containers on the master node first
                tasks=$(docker node ps -f 'desired-state=Running' $node |
                        tail -n +2 | awk '{print $2}' | cut -d. -f1 | sort | uniq | xargs)
                printf "\n\033[1;37m[%s\033[0m%s\033[1;37m]\033[0m" $node "${tasks:+ $tasks}"

                # Then print all the worker node info
                for node in $(docker node ls | sed 's/*//' | tail -n +2 | awk '{print $2}'); do
                    # Don't print the master node info again
                    [[ $node == $DOCKER_MACHINE_NAME ]] && continue

                    # Print the running containers on the worker node
                    tasks=$(docker node ps -f 'desired-state=Running' $node |
                            tail -n +2 | awk '{print $2}' | cut -d. -f1 | sort | uniq | xargs)
                    printf "\n\033[1;37m<%s\033[0m%s\033[1;37m>\033[0m" $node "${tasks:+ $tasks}"
                done
            else
                # We're just looking at a non-swarm or worker node.
                # Just print the running containers on the node.
                tasks=$(docker ps |
                        tail -n +2 | awk '{print $1}' | cut -d. -f1 | sort | uniq | xargs)
                printf "\n\033[1;37m<%s\033[0m%s\033[1;37m>\033[0m" $node "${tasks:+ $tasks}"
            fi
        fi
    fi
}
