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
		trunk) RTOS="itrunk"; RTOS_SUPP="itrunk i11.0" ;;
		3.3) RTOS="i11.0"; RTOS_SUPP="i11.0 i10.0" ;;
		3.2) RTOS="i10.0"; RTOS_SUPP="i10.0 i5.0" ;;
		3.1) RTOS="i5.0"; RTOS_SUPP="i5.0" ;;
		*) RTOS="itrunk"; RTOS_SUPP="itrunk" ;;
	esac
}

# set_default_comp "i10.0"
#
# Given a multi version, set GTCOMP to the path to the default compiler.  Note,
# the command is not included, just the path.
function set_default_comp {
	case "${1}" in
		i5.0)     GTCOMP="/share/multi/multi506/linux86" ;;
		i5.0-vrf) GTCOMP="/share/multi/multi524/linux86" ;;
		i10.0)    GTCOMP="/share/multi/multi524/linux86" ;;
		i11.0)    GTCOMP="/share/ghs/comp/2012.1" ;;
		*)        GTCOMP="/share/ghs/comp/current" ;;
	esac
}

# load_rc /path/to/workspace
#
# Recursively load all RC files, starting at /
function load_rc {
	local BASE=$(readlink -f "${1}")
	while [ "${BASE}" !=  "/" ]; do
		if [ -f "${BASE}"/.gtwsrc ]; then
			load_rc "$(dirname ${BASE})"
			echo "Loading ${BASE}/.gtwsrc"
			source "${BASE}"/.gtwsrc
			return 0
		fi
		BASE=$(readlink -f $(dirname "${BASE}"))
	done

	# Stop at /
	return 1
}
