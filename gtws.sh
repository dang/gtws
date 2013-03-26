#
# Functions for gtws
#

# if is_interactive; then echo "interactive" fi
#
# Check for an interactive shell
is_interactive() {
	case $- in
		*i*)
			# Don't die in interactive shells
			return 0
			;;
		*)
			return 1
			;;
	esac
}

# command | die "message"
#
# Print a message and exit with failure
die() {
	echo "Failed: $@"
	if ! is_interactive; then
		exit 1
	fi
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
# Given an INTEGRITY version, set GTWS_COMPILER_PATH to the path to the default
# compiler.  Note, the command is not included, just the path.  If
# GTWS_COMPLIER_PATH is already set, it is *not* overridden
function set_default_comp {
	if [ -n "${GTWS_COMPILER_PATH}" ]; then
		return 0
	fi
	case "${1}" in
		i5.0)     GTWS_COMPILER_PATH="/share/multi/multi506/linux86" ;;
		i5.0-vrf) GTWS_COMPILER_PATH="/share/multi/multi524/linux86" ;;
		i10.0)    GTWS_COMPILER_PATH="/share/multi/multi524/linux86" ;;
		i11.0)    GTWS_COMPILER_PATH="/share/ghs/comp/2012.1" ;;
		*)        GTWS_COMPILER_PATH="/share/ghs/comp/current" ;;
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
