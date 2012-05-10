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

