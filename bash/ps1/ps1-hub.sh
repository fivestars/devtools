function ps1-hub() {
    git rev-parse --git-dir &>/dev/null || return
    command -v hub &>/dev/null || return

    case $(hub ci-status 2>/dev/null) in
        success) echo -en "\033[1;32m\xE2\x9C\x93";;
        failure) echo -en "\033[1;31m\xE2\x9C\x97";;
        "no status") ;;
    esac
    echo -en "\033[0;37m"
}
