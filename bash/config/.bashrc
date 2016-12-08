# To the extent possible under law, the author(s) have dedicated all
# copyright and related and neighboring rights to this software to the
# public domain worldwide. This software is distributed without any warranty.
# You should have received a copy of the CC0 Public Domain Dedication along
# with this software.
# If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.

# base-files version 4.2-4

# ~/.bashrc: executed by bash(1) for interactive shells.

# The latest version as installed by the Cygwin Setup program can
# always be found at /etc/defaults/etc/skel/.bashrc

# Modifying /etc/skel/.bashrc directly will prevent
# setup from updating it.

# The copy in your home directory (~/.bashrc) is yours, please
# feel free to customise it to create a shell
# environment to your liking.  If you feel a change
# would be benifitial to all, please feel free to send
# a patch to the cygwin mailing list.

# User dependent .bashrc file

# If not running interactively, don't do anything
[[ "$-" != *i* ]] && return

# Discover this file's path for later reference
LDIR=${BASH_SOURCE[0]}; while [[ -h "$LDIR" ]]; do LDIR="$(dirname $LDIR)/$(readlink "$LDIR")"; done;
# echo $PWD
# dirname ${BASH_SOURCE[0]}
# ls -al ${BASH_SOURCE[0]}
# echo $LDIR
LDIR=$(builtin cd -P $(dirname "$LDIR") && pwd)

# Shell Options
#
# See man bash for more options...
#
# Don't wait for job termination notification
set -o notify
#
# Don't use ^D to exit
# set -o ignoreeof
#
# Use case-insensitive filename globbing
# shopt -s nocaseglob
#
# Make bash append rather than overwrite the history on disk
# shopt -s histappend
#
# When changing directory small typos can be ignored by bash
# for example, cd /vr/lgo/apaache would find /var/log/apache
# shopt -s cdspell
# Enable extended globbing operators
shopt -s extglob
# Completion options
#
# These completion tuning parameters change the default behavior of bash_completion:
#
# Define to access remotely checked-out files over passwordless ssh for CVS
# COMP_CVS_REMOTE=1
#
# Define to avoid stripping description in --option=description of './configure --help'
# COMP_CONFIGURE_HINTS=1
#
# Define to avoid flattening internal contents of tar files
# COMP_TAR_INTERNAL_PATHS=1
#
# Uncomment to turn on programmable completion enhancements.
# Any completions you add in ~/.bash_completion are sourced last.
# [[ -f /etc/bash_completion ]] && . /etc/bash_completion

# History Options
#
# Don't put duplicate lines in the history.
# export HISTCONTROL=$HISTCONTROL${HISTCONTROL+,}ignoredups
#
# Ignore some controlling instructions
# HISTIGNORE is a colon-delimited list of patterns which should be excluded.
# The '&' is a special pattern which suppresses duplicate entries.
# export HISTIGNORE=$'[ \t]*:&:[fb]g:exit'
# export HISTIGNORE=$'[ \t]*:&:[fb]g:exit:ls' # Ignore the ls command as well
#
# Whenever displaying the prompt, write the previous line to disk
# export PROMPT_COMMAND="history -a"

# Aliases
#
# Some people use a different file for aliases
# if [ -f "${HOME}/.bash_aliases" ]; then
#   source "${HOME}/.bash_aliases"
# fi
#
# Some example alias instructions
# If these are enabled they will be used instead of any instructions
# they may mask.  For example, alias rm='rm -i' will mask the rm
# application.  To override the alias instruction use a \ before, ie
# \rm will call the real rm not the alias.
#
# Interactive operation...
# alias rm='rm -i'
# alias cp='cp -i'
# alias mv='mv -i'
#
# Default to human readable figures
# alias df='df -h'
# alias du='du -h'
#
# Misc :)
# alias less='less -r'                          # raw control characters
# alias whence='type -a'                        # where, of a sort
# alias grep='grep --color'                     # show differences in colour
# alias egrep='egrep --color=auto'              # show differences in colour
# alias fgrep='fgrep --color=auto'              # show differences in colour
#
# Some shortcuts for different directory listings
# alias ls='ls -hF --color=tty'                 # classify files in colour
# alias dir='ls --color=auto --format=vertical'
# alias vdir='ls --color=auto --format=long'
# alias ll='ls -la'                              # long list
# alias la='ls -A'                              # all but . and ..
# alias l='ls -CF'                              #

# Umask
#
# /etc/profile sets 022, removing write perms to group + others.
# Set a more restrictive umask: i.e. no exec perms for others:
# umask 027
# Paranoid: neither group nor others have any perms:
# umask 077


### Environment variables
# Add devtools directories to PATH
export PATH=$PATH:$LDIR/..

# X11 support
export DISPLAY=':0'


### Aliases
alias ls='ls -hF --color=tty'
alias ll='ls -al'
alias grep='grep --color'
alias cb='clipboard'


### Key bindings
bind '"\e[A": history-search-backward'  # Up arrow
bind '"\e[B": history-search-forward'   # Down arrow

### Sources
# Get a better 'cd'
. $LDIR/../cd.sh


### Completions
function _complete_ssh_hosts() {
    cur="${COMP_WORDS[COMP_CWORD]}"
    comp_ssh_hosts=$(
        if [ -f ~/.ssh/config ]; then
            sed -En "s/\*.*$//; s/^Host=(.)/\1/p" ~/.ssh/config
        fi
        sed '/^#/d; s/^  *//; s/[, ].*//; /\[/d' ~/.ssh/known_hosts | uniq
    )
    COMPREPLY=( $(compgen -W "${comp_ssh_hosts}" -- $cur) )
}
complete -F _complete_ssh_hosts ssh sch


### Functions
function in_docker_container () {
    grep -q docker /proc/1/cgroup 2>/dev/null
}

function set_title() {
    echo -ne "\e]2;$@\a";
}

function ssh() {
    local RETURN OPT OPTARG OPTIND ARGS=$@

    while getopts ":" OPT; do shift; done
    eval set_title \${$OPTIND}
    /usr/bin/ssh ${ARGS[@]}; RETURN=$?
    set_title local

    return $RETURN
}

function sch() {
    # To enable automatic screen sessions, run 'psh -i <private key file> <host>'
    local OPT OPTIND OPTARG INSTALL=false KEYFILE LC_SESSION_NAME
    while getopts ":s:n:" OPT; do
        case $OPT in
            s) INSTALL=true; KEYFILE=$OPTARG; shift 2;;
            n) LC_SESSION_NAME=$OPTARG; shift 2;;
        esac
    done

    if $INSTALL; then
        # Copy this ssh key up to the server
        echo -e "\e[1;32mCopying keyfile up to the server\e[0m"
        ssh-copy-id -i $KEYFILE $@

        # Create the command.sh file to be invoked from .ssh/authorized_keys for this key
        echo -e "\e[1;32mCreating ~/.ssh/command.sh\e[0m"
        cat <<EOF | ssh -i $KEYFILE $@ "cat > ~/.ssh/command.sh && chmod 755 ~/.ssh/command.sh"
#!/bin/bash
# To be invoked by ssh login.
# Should be in your command= option in your .ssh/authorized_keys file.

if [[ -z \$SSH_ORIGINAL_COMMAND ]]; then
    # ~/.screenrc will look here for for SSH_AUTH_SOCK domain socket
    # This allows us to inform all virtual terminals about changes
    # to the ssh forwarding settings.
    ln -fs \$SSH_AUTH_SOCK ~/.ssh/SSH_AUTH_SOCK

    # Start or attach to our screen session
    screen -xS \${LC_SESSION_NAME:-\$USER}
else
    # Allow one-off commands to still work
    eval \$SSH_ORIGINAL_COMMAND
fi
EOF
        # Configure screen appropriately
        echo -e "\e[1;32mCreating ~/.screenrc\e[0m"
        cat <<EOF | ssh -i $KEYFILE $@ "cat >~/.screenrc"
escape "\`\`"
msgwait 1
multiuser on
bell_msg ""
setenv SSH_AUTH_SOCK \$HOME/.ssh/SSH_AUTH_SOCK
EOF
        echo -e "\e[1;32mAdding command=\"~/.ssh/command.sh\" to the ~/.ssh/authorized_keys file\e[0m"
        cat ${KEYFILE}.pub | sed 's/\//\\\//g' | \
            ssh -i $KEYFILE $@ "sed -i 's/^\($(cat)\)\$/command=\"~\/.ssh\/command.sh\" \1/' ~/.ssh/authorized_keys"

        echo -e "\e[1;32mssh setup complete. You will now get an automatic screen session when you log in with this key.\e[0m"
        return
    fi

    # Start our ssh session
    LC_SESSION_NAME=$LC_SESSION_NAME ssh -o SendEnv=LC_SESSION_NAME $@
}

function timer-start() {
    # Used to time each command-line action
    TIMER=${TIMER:-$(date +%s%N)}
    TIMER_AT=${TIMER_AT:-$(date +%T)}
}

function timer-finish() {
    # Used to time each command-line action
    local ELAPSED=$(printf '%09d' $(( $(date +%s%N) - TIMER )))
    local S=${ELAPSED:0:$(( ${#ELAPSED} - 9 ))}
    TIMER_OUTPUT=$TIMER_AT+${S:-0}.${ELAPSED:$(( ${#ELAPSED} - 9 )):3}
    unset TIMER TIMER_AT
}


### Command prompt
function ps1-git() {
    # placeholder in case ps1-git.sh is not present yet
    return
    echo -e '\e[0m(no ps1-git)'
}
function ps1-docker() {
    # placeholder in case ps1-git.sh is not present yet
    return
    echo -e '\e[0m(no ps1-git)'
}
[[ -e $LDIR/../ps1/ps1-git.sh ]] && . $LDIR/../ps1/ps1-git.sh


if ! in_docker_container; then
    # PS1 Configuration
    . $LDIR/../ps1/ps1-success.sh
    . $LDIR/../ps1/ps1-docker.sh
    . $LDIR/../ps1/ps1-hub.sh

    trap timer-start DEBUG
    PROMPT_COMMAND=timer-finish

    export PS1='\n$TIMER_OUTPUT $(ps1-success)\[\e[1;33m\]\w$(ps1-git -l -s) $(ps1-hub)\033[0;37m$(ps1-docker)\[\e[1;37m\]\n$\[\e[0m\] '

    # Docker utilities
    export PATH=${PATH}:$LDIR/../../dr
    . $LDIR/../../dr/dr.sh
    dr boot

    # SSH Agent
    if compgen -G ~/.ssh/id_rsa!(*\.pub) &>/dev/null; then
        . $LDIR/../ssh_agent.sh ~/.ssh/id_rsa!(*\.pub)
    fi
    unset LDIR

    # Environment-specific stuff
    if [[ -f ~/.bash_user ]]; then
        . ~/.bash_user
    else
        echo -e "\nCreate a ~/.bash_user file for customized shell configuration"
    fi
fi
