# Workaround for bash 3 not having associative arrays
#
#    set key:  map <mapname> <keyname> <<< <value>
#    get key:  map <mapname> <keyname>
#    del key:  map <mapname> <keyname> <<< ""
#    get keys: map <mapname>
#    get maps: map
function map {
    local KEYS

    if [[ -z $1 ]]; then
        echo $BASHMAPMAPS
    elif [[ -z $2 ]]; then
        eval echo \$BASHMAPKEYS_${1}
    else
        if [[ -t 0 ]]; then
            # retrieve
            eval echo \$BASHMAP_${1}_${2}
        else
            # store map
            if ! grep -qw $1 <<< $BASHMAPMAPS; then
                read BASHMAPMAPS <<< "$BASHMAPMAPS $1"
            fi

            # store key
            eval KEYS=\$BASHMAPKEYS_${1}
            if ! grep -qw $2 <<< $KEYS; then
                read BASHMAPKEYS_${1} <<< "$KEYS $2"
            fi

            # store mapping
            read BASHMAP_${1}_${2}
        fi
    fi
}
