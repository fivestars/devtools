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

  dr create-node <node> [-s] [-m <swarm>] [-w <swarm>] [i <ip address>]

    Create a new docker machine (using virtualbox) and optionally create a new swarm with the node
    as a manager or join the new node to an existing swarm.


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
    local swarm=$(docker info | grep -q "Swarm: active" && echo true || echo false)
    local manager=$($swarm && docker info | grep -q "Is Manager: true" && echo true || echo false)
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

                (
                    eval $(docker-machine env $node)
                    docker logs ${@:1:$(( $# - 1 ))} $container |& sed "s/^/${container%.*}: /g"
                ) &
            done < <(docker service ps $service | tail -n +2 | grep "Running" | grep -v "\\_" | awk '{ print $2" "$4 }')
            wait
        else
            # The argument could be a single instance of the service (eg. service.2) or just a raw
            # container on the node itself (eg. service.2.e0w8b8t2fa0vtyl4yxs3d2qu7).
            container=$service
            name=${container%.*}
            service=${container%%.*}
            if docker service ps $service &>/dev/null; then
                # They are trying to get logs for an instance of a service
                node=$(docker service ps $service | tail -n +2 | grep $name | awk '{ print $4 }')
                ( eval $(docker-machine env $node); docker logs ${@:1:$(( $# - 1 ))} $container )
            else
                # They are trying to get logs for a normal non-service container on the current node
                docker logs $container
            fi
        fi
    else
        docker logs $*
    fi
}

function dr-shell {
    local swarm=$(docker info | grep -q "Swarm: active" && echo true || echo false)
    local manager=$($swarm && docker info | grep -q "Is Manager: true" && echo true || echo false)
    local service container name node=$DOCKER_MACHINE_NAME
    local output choice

    if $manager; then
        service=$1
        shift
        choice="${service#*.}"
        service=${service%.*}
        [[ $choice == $service ]] && choice=

        if [[ "$choice" == "*" && $# -eq 0 ]]; then
            printf "Cannot open a shell on \"*\". Specify a service instance.\n" >&2
            return 1
        fi

        if docker service ps $service &>/dev/null; then
            output=$(mktemp); trap "rm -f $output" EXIT
            docker service ps $service | \
                tail -n +2 | \
                grep "Running" | \
                grep -v "\\_" | \
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
                                docker exec $container ${@:1:$#} |& sed "s/^/${container%.*}: /g"
                            ) &
                        done < <(docker service ps $service | tail -n +2 | grep "Running" | grep -v "\\_" | awk '{ print $2" "$4 }')
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
                        docker ps --format "table {{.Names}}\t{{.Status}}" | \
                            tail -n +2 | \
                            grep "$service\." | \
                            sort | \
                            awk '{print NR ") " $0}'
                    )
                    printf "Choose (default=1): "
                    read choice
                    read name node < <(cat $output | tail -n +${choice:-1} | head -n 1)
                fi
                if [[ -z $name ]];then
                    printf "Invalid choice\n" >&2
                    return 1
                fi
            fi
            container=$(eval $(docker-machine env $node); docker ps --format "{{.Names}}" | grep "^$name")
        else
            container=$service
            name=${container%.*}
            service=${container%%.*}

            if docker service ps $service &>/dev/null; then
                node=$(docker service ps $service | tail -n +2 | grep $name | awk '{ print $4 }')
            fi
        fi
        ( eval $(docker-machine env $node); docker exec -it $container ${*:-/bin/bash})
    else
        docker exec -it $1 ${*:-/usr/bin/env bash}
    fi
}

function dr-boot {
    local manager

    if [[ -f ~/.draoeu ]]; then
        manager=$(
            . ~/.dr >&2

            if [[ -n $DR_MACHINES ]]; then
                docker-machine start ${DR_MACHINES[@]} >&2
                echo $DR_MACHINES
            fi
        )

        if [[ -n $manager ]]; then
            dr-env $manager
        fi
    else
        printf "Create a ~/.dr file with a list of machines to start on boot up.\nFormat:\n" >&2
        printf "DR_MACHINES=(docker-machine-1 docker-machine-2 ...)" >&2
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
            m) swarm=$OPTARG; as_manager=true;;
            w) swarm=$OPTARG; as_worker=true;;
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

        if ! ( eval $(docker-machine env $swarm); docker info | grep -q "Is Manager: true" ); then
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

    printf "\nSharing your ~/ directory with the '%s'\n" $node
    printf "%s\n" "----------------------------------------"
    docker-machine-nfs.sh $node -s=$HOME:/home/fivestars

    if $as_manager; then
        if [[ -z $swarm ]]; then
            swarm=$node
            printf "\nInitializing swarm with '%s' as a manager\n" $node
            printf "%s\n" "----------------------------------------"
            docker-machine ssh $node docker swarm init --advertise-addr \
                $(docker-machine ls | \
                    grep -w $node | \
                    awk '{ print $5 }' | \
                    sed 's/tcp:\/\/\(.*\):.*/\1/')

        else
            printf "\nJoining '%s' to swarm '%s' as a manager\n" $node $swarm
            printf "%s\n" "----------------------------------------"
            docker-machine ssh $node \
                "$(docker-machine ssh $swarm docker swarm join-token manager | tail -n +2)"
        fi

        printf "\nSwarm nodes\n"
        printf "%s\n" "----------------------------------------"
        eval $(docker-machine env $swarm)
        docker node ls

    elif $as_worker; then
        printf "\nJoining '%s' to swarm '%s' as a worker\n" $node $swarm
        printf "%s\n" "----------------------------------------"
        docker-machine ssh $node \
            "$(docker-machine ssh $swarm docker swarm join-token worker | tail -n +2)"

        printf "\nSwarm nodes\n"
        printf "%s\n" "----------------------------------------"
        (
            eval $(docker-machine env $swarm)
            docker node ls
        )
    fi

    printf "\Finished creating node '%s'\n" $node
}

function dr {
    # $1 should correspond to one of the functions in this file
    local cmd=${1:-help}
    shift

    if [[ "$cmd" == "boot" ]]; then
        dr-boot
    elif command -v dr-$cmd &>/dev/null; then
        # Invoke the appropriate function in a subshell (so bg jobs die with the function call)
        ( dr-$cmd $* )
    elif docker-machine env $cmd |& grep -qv "Host does not exist"; then
        # They are trying to use the dr-env shorthand?
        dr-env $cmd
    else
        # Fall back to docker
        docker $cmd $*
    fi
}

# In case we want to call this script directly rather than sourcing it
# (helpful when developing/debugging this script)
if [[ $(basename $0) == $(basename $BASH_SOURCE) ]]; then
    dr $*
fi
