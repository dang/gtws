#
# Functions for gtws
#

# command | die "message"
#
# Print a message and exit with failure
die() {
	echo "$@"
	exit 1
}

# usage "You need to provide a frobnicator"
#
# Print a message and the usage for the current script and exit with failure.
usage() {
	local myusage;
	if [ -n "${USAGE}" ]; then
		myusage=${USAGE}
	else
		myusage="No usage given"
	fi
	if [ -n "$1" ]; then
		echo "$@"
	fi
	echo ""
	echo "Usage:"
	echo "`basename $0` ${myusage}"
	if [ -n "${LONGUSAGE}" ]; then
		echo -e "${LONGUSAGE}"
	fi
	exit 1
}

# title "foobar"
#
# Set the xterm/gnome-terminal title
function title {
	 echo -en "\033]2;$1\007"
}

# set_default_rtos "3.3"
#
# Given a gated version, set RTOS to the default rtos version
function set_default_rtos {
	case "${1}" in
		trunk) RTOS="itrunk" ;;
		3.3) RTOS="i11.0" ;;
		3.2) RTOS="i10.0" ;;
		3.1) RTOS="i5.0" ;;
		*) RTOS="itrunk" ;;
	esac
}
