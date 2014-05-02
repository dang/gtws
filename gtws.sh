#
# Functions for gtws
#

GTWSLOC=$(readlink -f $(dirname "${BASH_SOURCE[0]}"))
export GTWSLOC

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

# debug_print "Print debug information"
#
# Print debug information based on GTWS_VERBOSE
debug_print() {
	if [ -n "${GTWS_VERBOSE}" ]; then
		echo "$@"
	fi
}

# gtws_project_clone_default ${GTWS_ORIGIN} ${GTWS_PROJECT} ${GTWS_PROJECT_VERSION}
#
# Clone a version of a project into ${GTWS_WSPATH} (which is the current working directory).  This is the default version of this that clones <origin>/<project>/<version>/*
function gtws_project_clone_default {
	local origin=$1
	local project=$2
	local version=$3
	local name=$4
	local opv="${origin}/${project}/${version}"
	local wspath=${PWD}
	local repos=${GTWS_PROJECT_REPOS}

	if [ -z "${repos}" ]; then
		for i in "${opv}"/*; do
			repos="$(basename $i) $repos"
		done
	fi

	for repo in ${repos}; do
		local rpath="${opv}/${repo}"
		git clone "${rpath}" || die "failed to clone ${rpath}"
		cd "${rpath}" || die "failed to cd to ${rpath}"
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
	# Load base RC first
	source "${HOME}"/.gtwsrc
	while [ "${BASE}" !=  "/" ]; do
		if [ -f "${BASE}"/.gtwsrc ]; then
			load_rc "$(dirname ${BASE})"
			debug_print "Loading ${BASE}/.gtwsrc"
			source "${BASE}"/.gtwsrc
			return 0
		fi
		BASE=$(readlink -f $(dirname "${BASE}"))
	done
	# Stop at /

	return 1
}
