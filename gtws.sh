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
	if [ ! -z "$(declare -F | grep "GTWScleanup")" ]; then
		GTWScleanup "$@"
	fi
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

# gtws_project_clone_default ${GTWS_ORIGIN} ${GTWS_PROJECT} ${GTWS_PROJECT_VERSION}
#
# Clone a version of a project into ${WSPATH} (which is the current working directory).  This is the default version of this that clones <origin>/<project>/<version>/*
function gtws_project_clone_default {
	local origin=$1
	local project=$2
	local version=$3
	local opv="${origin}/${project}/${version}"
	local wspath=${PWD}

	for i in "${opv}"/*; do
		local repo=$(basename $i)
		git clone "${i}" || die "failed to clone ${i}"
		cd "${i}" || die "failed to cd to ${i}"
		for f in ${GTWS_FILES_EXTRA}; do
			if [ -f "${f}" ]; then
				cp --parents "${f}" "${wspath}/${repo}" || die "failed to copy ${f}"
			fi
		done
		cd "${wspath}" || die "failed to cd to ${wspath}"
	done
}

# load_rc /path/to/workspace
#
# This should be in the workspace-level gtwsrc file
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
