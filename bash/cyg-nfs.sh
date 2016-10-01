
function restart-nfs {
    if net start | grep -qw rpcbind; then
        sudo net stop /y rpcbind
        while net start | grep -qw rpcbind; do :; done
    fi

    if ! net start | grep -qw mountd; then
        sudo net start mountd
        while ! net start | grep -qw mountd; do :; done
    fi

    if ! net start | grep -qw nfsd; then
        sudo net start nfsd
        while ! net start | grep -qw nfsd; do :; done
    fi

    date +"%Y-%m-%d %H:%M:%S" > ~/.nfs-restarted
}

function boot-nfs {
    if [[ ! -f ~/.nfs-restarted ||
        $(date --date="$(<~/.nfs-restarted)" +%s) -lt $(date --date="$(uptime -s)" +%s) ]]; then
        restart-nfs
    fi
}
