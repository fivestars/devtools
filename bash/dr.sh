#! /usr/bin/env bash
# Wrapper script to make working with services a little easier
# Source this file to provide your shell with the "dr" function.

function dr-help {
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

  dr create-node <node> [-s] [-m <swarm>] [-w <swarm>]
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
        dr create-node mynode

    Create a manager node for a new swarm:
        dr create-node myswarmmanager -s

    Create a new manager node for an existing swarm:
        dr create-node mymanager -m myswarmmanager

    Create a worker node for an existing swarm:
        dr create-node myworker -w myswarmmanager

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

function dr-env {
    local node=$1
    shift

    if [[ $(docker-machine status $node) != Running ]]; then
        docker-machine start $node
    fi

    while ! docker-machine env $node &>/dev/null; do
        sleep 1
    done

    eval $(docker-machine env $node)
}

function dr-logs {
    local swarm=$(docker info | grep -q "Swarm: active" &&
                  echo true || echo false)
    local manager=$($swarm && docker info | grep -q "Is Manager: true" &&
                    echo true || echo false)
    local service container name node
    local choice

    if $manager; then
        service=${@:$#:1}
        choice=${service#*.}
        service=${service%.*}
        [[ $choice == $service ]] && choice=

        if docker service ps $service &>/dev/null; then
            # We are looking for the logs from a service
            while read name node; do
                # Did they specify a particular instance of the service?
                if [[ -n $choice && $service.$choice != $name ]]; then
                    continue
                fi

                # Find the container associated with the service instance
                container=$(
                    eval $(docker-machine env $node)
                    docker ps --format "{{.Names}}" | grep "^$name"
                )

                # Output the logs, and prefix each line with its
                # container designation.
                (
                    eval $(docker-machine env $node)
                    docker logs ${@:1:$(( $# - 1 ))} $container 2>&1 |
                        sed "s/^/${container%.*}: /g"
                ) &
            done < <(docker service ps $service | tail -n +2 | grep "Running" |
                grep -v "\\_" | awk '{ print $2" "$4 }')
            wait
        else
            # The argument could be a single instance of the service (service.2)
            # or just a raw container on the node itself
            # (service.2.e0w8b8t2fa0vtyl4yxs3d2qu7).
            container=$service
            name=${container%.*}
            service=${container%%.*}
            if docker service ps $service &>/dev/null; then
                # They are trying to get logs for an instance of a service
                node=$(docker service ps $service | tail -n +2 | grep $name |
                    awk '{ print $4 }')
                (
                    eval $(docker-machine env $node)
                    docker logs ${@:1:$(( $# - 1 ))} $container
                )
            else
                # They are trying to get logs for a normal non-service
                # container on the current node
                docker logs $container
            fi
        fi
    else
        docker logs $*
    fi
}

function dr-shell {
    local swarm=$(docker info | grep -q "Swarm: active" &&
                  echo true || echo false)
    local manager=$($swarm && docker info | grep -q "Is Manager: true" &&
                    echo true || echo false)
    local service container name node=$DOCKER_MACHINE_NAME
    local output choice

    if $manager; then
        service=$1
        shift
        choice="${service#*.}"
        service=${service%.*}
        [[ $choice == $service ]] && choice=

        if [[ "$choice" == "*" && $# -eq 0 ]]; then
            printf "Cannot open a shell on \"*\"." >&2
            printf " Specify a service instance.\n" >&2
            return 1
        fi

        if docker service ps $service &>/dev/null; then
            output=$(mktemp); trap "rm -f $output" EXIT
            docker service ps $service |
                tail -n +2 |
                grep "Running" |
                grep -v "\\_" |
                awk '{ print $2" "$4 }' > $output

            if [[ $(wc -l <$output) -eq 1 ]]; then
                read name node < $output
            else
                if [[ -n "$choice" ]]; then
                    if [[ "$choice" == "*" ]]; then
                        while read name node; do
                            container=$(
                                eval $(docker-machine env $node)
                                docker ps --format "{{.Names}}" | grep "^$name"
                            )
                            (
                                eval $(docker-machine env $node)
                                docker exec $container ${@:1:$#} 2>&1 |
                                    sed "s/^/${container%.*}: /g"
                            ) &
                        done < <(docker service ps $service | tail -n +2 |
                                 grep "Running" | grep -v "\\_" |
                                 awk '{ print $2" "$4 }')
                        wait
                        return
                    else
                        read name node < <(grep "$service\.$choice" $output)
                    fi
                else
                    printf "Multiple containers found for '%s'\n" $service
                    printf "%s\n" "------------------------------------"
                    (
                        eval $(docker-machine env loyalty)
                        docker ps --format "table {{.Names}}\t{{.Status}}" |
                            tail -n +2 |
                            grep "$service\." |
                            sort |
                            awk '{print NR ") " $0}'
                    )
                    printf "Choose (default=1): "
                    read choice
                    read name node < <(cat $output | tail -n +${choice:-1} |
                                       head -n 1)
                fi
                if [[ -z $name ]];then
                    printf "Invalid choice\n" >&2
                    return 1
                fi
            fi
            container=$(eval $(docker-machine env $node)
                        docker ps --format "{{.Names}}" | grep "^$name")
        else
            container=$service
            name=${container%.*}
            service=${container%%.*}

            if docker service ps $service &>/dev/null; then
                node=$(docker service ps $service |
                       tail -n +2 | grep $name | awk '{ print $4 }')
            fi
        fi
        (
            eval $(docker-machine env $node)
            docker exec -it $container ${*:-/bin/bash}
        )
    else
        docker exec -it $1 ${*:-/usr/bin/env bash}
    fi
}

function dr-boot {
    local manager node

    if [[ -f ~/.dr ]]; then
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
            dr-env $manager
        fi
    else
        printf "Create a ~/.dr file.\n" >&2
        printf "DR_MACHINES: a list of machines to start on boot up.\n" >&2
        printf "\tDR_MACHINES=(docker-machine-1 docker-machine-2 ...)\n" >&2
        return 1
    fi
}

function dr-create-node {
    if ! command -v docker-machine-ipconfig &>/dev/null; then
        printf "Could not find docker-machine-ipconfig\n" >&2
        return 1
    fi

    if ! command -v docker-machine-nfs.sh &>/dev/null; then
        printf "Could not find docker-machine-nfs.sh\n" >&2
        return 1
    fi

    local node=$1
    shift;

    local OPT OPTARG OPTIND
    local ip_addr swarm as_manager=false as_worker=false
    while getopts "i:sm:w:" OPT; do
        case $OPT in
            i) ip_addr=$OPTARG;;
            s) as_manager=true;;
            m) as_manager=true; swarm=$OPTARG;;
            w) as_worker=true; swarm=$OPTARG;;
            *) return 1;;
        esac
    done
    shift $((OPTIND-1))

    if [[ -z $node ]]; then
        printf "Must provide the desired name of your new node\n" >&2
        return 1
    fi

    if docker-machine inspect $node &>/dev/null; then
        printf "Node '$node' already exists\n" >&2
        return 1
    fi

    if [[ -n $swarm ]]; then
        if ! docker-machine inspect $swarm &>/dev/null; then
            printf "Node '$swarm' does not exist\n" >&2
            return 1
        fi

        if ! ( eval $(docker-machine env $swarm)
               docker info | grep -q "Is Manager: true" ); then
            printf "Node '$swarm' is not a swarm manager\n"
            return 1
        fi
    fi

    printf "Creating node '%s'\n" $node
    printf "%s\n" "----------------------------------------"
    docker-machine create -d virtualbox $node

    printf "\nConfiguring '%s' to use static ip address %s\n" $node $ip_addr
    printf "%s\n" "----------------------------------------"
    docker-machine-ipconfig static $node $ip_addr
    docker-machine-ipconfig hosts

    printf "\nSharing your ~/ directory with '%s'\n" $node
    printf "%s\n" "----------------------------------------"
    docker-machine-nfs.sh $node

    if $as_manager; then
        if [[ -z $swarm ]]; then
            swarm=$node
            printf "\nInitializing swarm with '%s' as a manager\n" $node
            printf "%s\n" "----------------------------------------"
            docker-machine ssh $node docker swarm init --advertise-addr \
                $(docker-machine ls |
                    grep -w $node |
                    awk '{ print $5 }' |
                    sed 's/tcp:\/\/\(.*\):.*/\1/')

        else
            printf "\nJoining '%s' to swarm '%s' as a manager\n" $node $swarm
            printf "%s\n" "----------------------------------------"
            docker-machine ssh $node \
                "$(docker-machine ssh $swarm docker swarm join-token manager |
                    tail -n +2)"
        fi

    elif $as_worker; then
        printf "\nJoining '%s' to swarm '%s' as a worker\n" $node $swarm
        printf "%s\n" "----------------------------------------"
        docker-machine ssh $node \
            "$(docker-machine ssh $swarm docker swarm join-token worker |
                tail -n +2)"
    fi

    if [[ -n $swarm ]]; then
        printf "\nSwarm nodes\n"
        printf "%s\n" "----------------------------------------"
        eval $(docker-machine env $swarm)
        docker node ls
    fi

    printf "\n%s\n" "----------------------------------------"
    printf "Finished creating node '%s'\n" $node
    printf "%s\n" "----------------------------------------"
}

function dr-ecr-login {
    eval $(aws ecr get-login --region us-east-1)
}

function dr-ecr-images {
    if ! command -v jq &>/dev/null; then
        printf "Missing jq command. Install it and try again" >&2
        return 1
    fi

    local repo id

    for repo in $(aws ecr describe-repositories | jq '.repositories[] | .repositoryUri' | xargs); do
        [[ -n $1 && ${repo#*/} != $1 ]] && continue
        printf "%s:\n" $repo
        printf "  %20s %-71s %s\n" TAG DIGEST ID
        while read tag digest; do
            id=$(docker images --digests --format "{{.Tag}}\t{{.Digest}}\t{{.ID}}" |
                grep "$tag.*$digest" | awk '{print $3}')
            printf "  %20s %71s %s\n" $tag $digest "${id:-<not pulled yet>}"
        done < <(
            aws ecr list-images --repository-name ${repo#*/} |
                jq '.imageIds[] | if has("imageTag") then . else empty end | objects | .imageTag, .imageDigest' |
                xargs -n2)
        printf "\n"
    done
}

function dr-ecr {
    local cmd=${1:-login}
    shift

    if command -v dr-ecr-$cmd &>/dev/null; then
        dr-ecr-$cmd $*
    else
        aws ecr $cmd $*
    fi
}

function dr {
    # $1 should correspond to one of the functions in this file
    local cmd=${1:-help}
    shift

    # Commands that modify the environment
    local bare_commands=("boot" "create-node" "env" "ecr")

    if grep -qw "$cmd" <<<"${bare_commands[@]}"; then
        # These commands should run directly in the current shell's environment
        dr-$cmd $*
    elif command -v dr-$cmd &>/dev/null; then
        # Invoke the appropriate function in a subshell
        # (so bg jobs die with the function call)
        ( dr-$cmd $* )
    elif docker-machine env $cmd 2>&1 | grep -qv "Host does not exist"; then
        # They are trying to use the dr-env shorthand?
        dr-env $cmd
    else
        # Fall back to docker
        docker $cmd $*
    fi
}

# In case we want to call this script directly rather than sourcing it
# (helpful when developing/debugging this script)
if [[ $(basename -- $0) == $(basename -- $BASH_SOURCE) ]]; then
    dr $*
fi
