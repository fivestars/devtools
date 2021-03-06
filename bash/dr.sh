#! /usr/bin/env bash
# Wrapper script to make working with services a little easier
# Source this file to provide your shell with the "dr" function.



function dr_config {
    (
        if [[ -f ~/.dr ]]; then
            . ~/.dr
        fi

        PS3="Select your driver [DR_DRIVER=$DR_DRIVER]: "
        options=("xhyve/hyper-v" "docker-machine")
        select opt in "${options[@]}"; do
            case $opt in
                "${options[0]}") DR_DRIVER="$opt"; break ;;
                "${options[1]}") DR_DRIVER="$opt"; break ;;
                *) printf "Choose a valid option $opt\n" ;;
            esac
        done
        printf "\n"

        if [[ $DR_DRIVER == "docker-machine" ]]; then
            PS3="Choose machines to boot on startup [DR_MACHINES=(${DR_MACHINES[@]})]: "
            options=$(docker-machine ls -f {{.Name}} | xargs -n1)
            if [[ -n $options ]]; then
                select opt in $options "-finalize-"; do
                    case $opt in
                        "-finalize-") break ;;
                        "") printf "Choose a valid option\n" ;;
                        *)  NEW_DR_MACHINES=(${DR_MACHINES[@]/$opt})
                            if [[ ${DR_MACHINES[@]} == ${NEW_DR_MACHINES[@]} ]]; then
                                DR_MACHINES+=($opt)
                            else
                                DR_MACHINES=(${DR_MACHINES[@]/$opt})
                            fi
                            PS3="Choose machines to boot on startup [DR_MACHINES=(${DR_MACHINES[@]})]: "
                            ;;
                    esac
                done
                printf "\n"

                if [[ ${#DR_MACHINES[@]} -gt 1 ]]; then
                    PS3="Choose the machine to attach to on startup [DR_MACHINE=${DR_MACHINE}]: "
                    options="${DR_MACHINES[@]}"
                    select opt in $options; do
                        case $opt in
                            "") printf "Choose a valid option\n" ;;
                            *)  DR_MACHINE=$opt; break ;;
                        esac
                        PS3="Choose the machine to attach to on startup [DR_MACHINE=${DR_MACHINE}]: "
                    done
                    printf "\n"
                fi
            fi
        fi

        printf "Writing the following config to ~/.dr\n"
        printf "%s\n" "--------------------------------------------------------------------------------"
        tee ~/.dr <<EOF
# The docker driver to use for the docker engine
DR_DRIVER=$DR_DRIVER

# If DR_DRIVER is docker-machine, these machines will start on "dr boot"
DR_MACHINES=(${DR_MACHINES[@]})
# If DR_DRIVER is docker-machine, this machine will be the initial docker engine"
DR_MACHINE=$DR_MACHINE
EOF
    printf "%s\n" "--------------------------------------------------------------------------------"
    )

    # Set up this shell as if it was started with these new settings
    unset $(echo ${!DOCKER*})
    if dr_using_machine; then
        dr_boot
    fi
}

function dr_using_machine {
    (. ~/.dr; [[ $DR_DRIVER == docker-machine ]])
}

function dr_env {
    local node=$1
    shift

    if ! dr_using_machine; then
        printf "This command is only valid when using the docker-machine driver\n" >&2
        return
    fi

    if [[ $(docker-machine status $node) != Running ]]; then
        docker-machine start $node
    fi

    while ! docker-machine env $node &>/dev/null; do
        sleep 1
    done

    eval $(docker-machine env $node)
}

function dr_logs {
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
                    dr_using_machine && eval $(docker-machine env $node)
                    docker ps --format "{{.Names}}" | grep "^$name"
                )

                # Output the logs, and prefix each line with its
                # container designation.
                (
                    dr_using_machine && eval $(docker-machine env $node)
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
                    dr_using_machine && eval $(docker-machine env $node)
                    docker logs ${@:1:$(( $# - 1 ))} $container
                )
            else
                # They are trying to get logs for a normal non-service
                # container on the current node
                docker logs $container
            fi
        fi
    else
        docker logs "$@"
    fi
}

function dr_shell {
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
            output=$(mktemp -t dr_shell.XXXX); trap "rm -f $output" EXIT
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
                                dr_using_machine && eval $(docker-machine env $node)
                                docker ps --format "{{.Names}}" | grep "^$name"
                            )
                            (
                                dr_using_machine && eval $(docker-machine env $node)
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
                        dr_using_machine && eval $(docker-machine env loyalty)
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
            container=$(dr_using_machine && eval $(docker-machine env $node)
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
            dr_using_machine && eval $(docker-machine env $node)
            docker exec -it $container ${*:-/usr/bin/env bash -l}
        )
    else
        docker exec -it $container ${*:-/usr/bin/env bash -l}
    fi
}

function dr_boot {
    local manager node

    if ! dr_using_machine; then
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

function dr_create_node {
    if ! dr_using_machine; then
        printf "This command is only valid when using the docker-machine driver\n" >&2
        return
    fi

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

function dr_ecr_login {
    eval $(aws ecr get-login --region us-east-1)
}

function dr_ecr_images {
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
                jq '.imageIds[] | select(has("imageTag")) | .imageTag, .imageDigest' |
                xargs -n2)
        printf "\n"
    done
}

function dr_ecr {
    local cmd=${1:-login}
    shift

    if command -v dr_ecr_$cmd &>/dev/null; then
        dr_ecr_$cmd "$@"
    else
        aws ecr $cmd "$@"
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
    local bare_commands=("boot" "config" "create_node" "env" "ecr")

    if grep -qw "$cmd" <<<"${bare_commands[@]}"; then
        # These commands should run directly in the current shell's environment
        dr_$cmd "$@"
    elif command -v dr_$cmd &>/dev/null; then
        # Invoke the appropriate function in a subshell
        # (so bg jobs die with the function call)
        ( dr_$cmd "$@" )
    elif dr_using_machine && docker-machine env $cmd 2>&1 |
                                grep -qv "Host does not exist"; then
        # They are trying to use the dr_env shorthand?
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

# Export our functions for use in sub-shells
export -f $(grep '^function ' $BASH_SOURCE | awk '{ print $2 }' | xargs)
