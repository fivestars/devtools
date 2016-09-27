# Source from .bashrc

# This will start up an ssh-agent process. This
# allows us to keep our private key on our local
# machine while making multiple ssh hops to remote
# hosts.
#
# Setup:
#   1) ForwardAgent configuration
#     a) Add the following lines to the bottom
#        of your ~/.ssh/config (easiest):
#          Host=*
#            ForwardAgent=yes
#                -- or --
#     b) Add "ForwardAgent yes" to entries in
#        ~/.ssh/config for sessions you wish to
#        use the ssh-agent with
#                -- or --
#     c) Invoke ssh with the -A option when you
#        want to use the ssh-agent for that session
#
#   2) Installation
#     Source this file in your .bashrc startup script.
#       . path/to/ssh_agent.sh
#
#     It will look for id_rsa and id_dsa by default.
#     If you have a different identities you can specify
#     them as optional arguments.
#       . path/to/ssh_agent.sh path/to/id_other path/to/id_home
#
#   3) Usage
#     You can also add more than one identity by using
#     the ssh-agent-start command.
#       ssh-agent-start path/to/id_qa path/to/id_staging path/to/id_prod
#
# You can now ssh to any box with your public keys in
# its authorized_keys file, even if you're ssh'ing across
# multiple boxes.
#
# Use ssh-copy-id to easily push your public key to
# a new box where you already have access (username:password, or another key).

# Create a place to store our ssh-agent stuff
mkdir -p ~/.ssh/agent

# Filename to act as a unix domain socket
export SSH_AUTH_SOCK=~/.ssh/agent/.ssh-socket

# Start the ssh-agent if not already started
function ssh-agent-start {

    local QUIET=false TMPFILE
    local OPT OPTARG OPTIND
    while getopts ":-q" OPT; do
        case $OPT in
            q) QUIET=true;;
        esac
    done
    shift $((OPTIND-1))

    # see if ssh-agent is running
    ssh-add -l &>/dev/null
    if [[ $? == 2 ]]; then

        # Start the agent and bind to our unix domain socket
        # The output of this command is another script we can use
        # to configure our environment
        if ! ssh-agent -a $SSH_AUTH_SOCK >~/.ssh/agent/.ssh-script 2>/dev/null; then
            echo "SSH agent did not shut down correctly. Cleaning up and trying again."
            rm $SSH_AUTH_SOCK

            if ! ssh-agent -a $SSH_AUTH_SOCK >~/.ssh/agent/.ssh-script 2>/dev/null; then
                echo "Could not start ssh-agent." >&2
                return 1
            fi
        fi

        # Execute environment configuration script
        . ~/.ssh/agent/.ssh-script >/dev/null

        # Exit status 2 means couldn't connect to ssh-agent
        $QUIET || echo -n "Starting SSH agent with PID="
        echo $SSH_AGENT_PID >~/.ssh/agent/.ssh-agent-pid
    else
        # The agent was already running
        $QUIET || echo -n "SSH Agent present with PID="
    fi

    $QUIET || cat ~/.ssh/agent/.ssh-agent-pid
    for ID in $*; do
        case $ID in
            *.pem)
                TMPFILE=${TMPFILE:-$(mktemp)}
                trap "rm -f $TMPFILE" EXIT
                ssh-keygen -y -f $ID >$TMPFILE
                ;;
            *)
                TMPFILE=$ID
                ;;
        esac

        if ! ssh-add -l | grep -q $(ssh-keygen -lf $TMPFILE | cut -d' ' -f2); then
            ssh-add $ID >/dev/null
        fi
        [[ $TMPFILE != $ID ]] && rm -f $TMPFILE
    done

    # Display the current identities
    $QUIET || echo "Current Identities:"
    $QUIET || ssh-add -l | sed "s/^/  /g"
}

# Stopping the previously started ssh-agent
function ssh-agent-stop {
    # see if ssh-agent is running
    ssh-add -l >/dev/null 2>&1
    if [[ $? -lt 2 ]]; then
        read PID <~/.ssh/agent/.ssh-agent-pid
        echo "Stopping SSH agent with PID=$PID"
        kill $PID
    else
        echo "SSH agent already stopped"
    fi

    # remove the PID file in either case
    rm -f ~/.ssh/agent/.ssh-agent-pid
}

# Actually start the ssh-agent up
if [[ $# -gt 0 ]]; then
    ssh-agent-start $(tr ':' ' ' <<<$SSH_AGENT_IDS) $*
elif [[ -e ~/.ssh/id_rsa ]]; then
    ssh-agent-start $(tr ':' ' ' <<<$SSH_AGENT_IDS) ~/.ssh/id_rsa
elif [[ -e ~/.ssh/id_dsa ]]; then
    ssh-agent-start $(tr ':' ' ' <<<$SSH_AGENT_IDS) ~/.ssh/id_dsa
fi
