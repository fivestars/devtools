# Source to provide stack-enabled cd command

[[ -z $CD_DIRS ]] && CD_DIRS=()
export CD_DIRS

function cd() {
	local N
	if [[ $# == 0 ]]; then
		pushd ~ &>/dev/null
		CD_DIRS=()
	elif [[ $1 == -* ]]; then
		N=${1#-}; N=${N:-1}
		[[ $N -ge ${#DIRSTACK[@]} ]] && N=$(( ${#DIRSTACK[@]} - 1 ))

		for ((; N != 0; N-- )); do
			#echo back $DIRSTACK
			eval CD_DIRS=( $DIRSTACK ${CD_DIRS[@]} )
			popd &>/dev/null
		done

	elif [[ $1 == +* ]]; then
		N=${1#+}; N=${N:-1}
		[[ $N -gt ${#CD_DIRS[@]} ]] && N=${#CD_DIRS[@]}

		for ((; N != 0; N-- )); do
			# echo forward $CD_DIRS
			pushd $CD_DIRS &>/dev/null
			CD_DIRS=( ${CD_DIRS[@]:1} )
		done
	elif [[ $1 == '--' ]]; then
		dirs -c
		CD_DIRS=()
	else
		if pushd "$@" &>/dev/null; then
			CD_DIRS=()
		fi
	fi
}