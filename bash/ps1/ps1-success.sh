#! /bin/sh 
# Source from .bash_user

# Display the return code of the last executed command
# and color-code the success status. Also, return the
# current error code so as to not disturb the current
# return state.
function ps1-success() {
    local RESULT=$?;
    [[ $RESULT == 0 ]] && echo -e "\e[1;32m" || echo -e "\e[1;31m($RESULT)" && return $RESULT
}

