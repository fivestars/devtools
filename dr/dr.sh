#! /usr/bin/env bash
# Wrapper script to make working with services a little easier
# Source this file to provide your shell with the "dr" function.

function dr_help {
    cat <<EOF
Wrapper for the docker command that makes it easier to work with swarm nodes
and their services. Any unrecognized dr commands will be assumed to be docker
commands and will be forwarded to the docker command.

Usage:
  dr <command> <args>

Commands:
  dr <node>
  dr env <node>

    Point your docker client at the given <node>

  dr config

    Create and populate the ~/.dr configuration file.

  dr logs [-f] <service[.<instance number>]|container>

    Display the logs for the given <service|container>

    If <service>, the log output lines will be prefixed with the name of the
    service instance producing the lines. This is useful when running with
    more than one replica for the service. Provide the instance number to only
    display logs from that service instance.

    If <container>, it is assumed the container is running on the current node.

    Specifying -f will display logs in "follow" mode.


  dr shell <service[.<instance number>]> [<command>]

    Open a bash shell on the given <service>, or run <command>, if given.

  dr create_node <node> [-s] [-m <swarm>] [-w <swarm>]
                        [-i <ip address>]
                        [-u <user id>:<group id>]

    Create a new docker machine (using virtualbox) and optionally create a new
    swarm with the node as a manager or join the new node to an existing swarm.

    If -i <ip address> is provided, the new node will be configured to use it as
    it's static IP address. Otherwise, it will use whatever address was
    provided by the VirtualBox DHCP service. Your /etc/hosts file will be
    updated with an entry for this new node.

    Your ~/ directory will be exported to and mounted by the new node. Your
    /etc/exports file (and /etc/nfs/server.map file) will be updated
    accordingly. For Cygwin users only: if -u <user id>:<group id> is provided
    the server.map file will use those values rather than 0:0 (root) for the
    user/group mapping. The files in the NFS mount will appear to be owned by
    the node's user and group corresponding to the given ids.

    Create standard non-swarm node:
        dr create_node mynode

    Create a manager node for a new swarm:
        dr create_node myswarmmanager -s

    Create a new manager node for an existing swarm:
        dr create_node mymanager -m myswarmmanager

    Create a worker node for an existing swarm:
        dr create_node myworker -w myswarmmanager

  dr boot

    Reads the contents of ~/.dr and starts all machines found in the DR_MACHINES
    list. For example:
        DR_MACHINES=(myswarmmanager mymanager myworker)

  dr ecr <...>

    Passes <...> as arguments to the 'aws ecr' command

  dr ecr login

    Retrieve and install temporary ECR credentials into your docker config.

    These credentials are installed into the currently active docker engine.

  dr ecr images [<repo short name>]

    List the repositories and images available to your currently installed ECR
    credentials.

    ECR repositories URIs are of the form <path component>/<repo short name>. If
    <repo short name> is provided to this command, it will display the images
    for that repository only.

EOF
}


function dr_env {
    local node=$1
    shift

    if ! dr-using-machine; then
        printf "This command is only valid when using the docker-machine driver\n" >&2
        return
    fi

    if [[ $(docker-machine status $node) != Running ]]; then
        docker-machine start $node
    fi

    while ! docker-machine env $node &>/dev/null; do
        printf "Waiting for node '%s' to start\n" $node >&2
        sleep 1
    done

    eval $(docker-machine env $node)
}

function dr_boot {
    local manager node

    if ! dr-using-machine; then
        printf "This command is only valid when using the docker-machine driver\n" >&2
        return
    fi

    manager=$(
        . ~/.dr >&2

        if [[ -n $DR_MACHINES ]]; then
            for node in ${DR_MACHINES[@]}; do
                if [[ $(docker-machine status $node) != Running ]]; then
                    docker-machine start $node >&2
                fi
            done
            # First one is assumed to be the manager
            echo $DR_MACHINES
        fi
    )

    if [[ -n $manager ]]; then
        dr_env $manager
    fi
}


function dr {
    # $1 should correspond to one of the functions in this file
    local cmd=${1:-help}
    shift

    # Check for presence of ~/.dr config file
    if [[ ! -f ~/.dr ]]; then
        printf "You must configure dr first\n\n"
        dr_config
        printf "\nRun 'dr config' to change these values\n"
    fi

    # Commands that modify the environment
    local bare_commands=("boot" "env")

    if command -v dr_$cmd &>/dev/null; then
        dr_$cmd "$@"
    elif command -v dr-$cmd &>/dev/null; then
        dr-$cmd "$@"
    elif dr-using-machine && docker-machine env $cmd 2>&1 |
            grep -qv "Host does not exist"; then
        # They are trying to use the dr-env shorthand?
        dr_env $cmd
    else
        # Fall back to docker
        docker $cmd "$@"
    fi
}

# In case we want to call this script directly rather than sourcing it
# (helpful when developing/debugging this script)
if [[ $(basename -- $0) == $(basename -- $BASH_SOURCE) ]]; then
    dr "$@"
fi

# Export our dr function for use in sub-shells
export -f dr
