# Source to provide ps1-screen command

# Display the screen info above the prompt
function ps1-screen() {
	local RESULT=$?
	local COLORS=(1 31 32 33 35 36)
    local SESSION_NAME
    [[ ${STY##*.} != $USER ]] && SESSION_NAME=${STY##*.}:
	[[ -n $STY ]] && echo -e "\e[0;${COLORS[${WINDOW}]}m[${SESSION_NAME}${WINDOW}]" || echo -e "\e[1;37m[]"
	return $RESULT
}
