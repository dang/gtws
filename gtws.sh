#
# Functions for gtws
#

GTWS_LOC=$(readlink -f $(dirname "${BASH_SOURCE[0]}"))
export GTWS_LOC

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
		echo -e "$@" >&2
	fi
}

# is_git_repo ${dir}
#
# return success if ${dir} is in a git repo, or failure otherwise
is_git_repo() {
	debug_print "is_git_repo $i"
	if [[ $1 == *:* ]]; then
		debug_print "    remote; assume good"
		return 0
	elif [ ! -d "$1" ]; then
		debug_print "    fail: not dir"
		return 1
	fi
	cd "$i"
	git rev-parse --git-dir >/dev/null 2>&1
	local ret=$?
	cd -
	debug_print "    retval: $ret"
	return $ret
}

# git_top_dir top
#
# Get the top level of the git repo contaning PWD, or return failure;
#
# Result will be in local variable top  Or:
#
# top = $(git_top_dir)
#
# Result will be in local variable top
function git_top_dir {
	local  __resultvar=$1
	local __top="$(git rev-parse --show-toplevel 2>/dev/null)"

	if [ -z "${__top}" ]; then
		die "${PWD} is not a git repo"
		return 1
	fi
	if [[ "$__resultvar" ]]; then
		eval $__resultvar="'$__top'"
	else
		echo "$__top"
	fi
}

# gtws_opv ${GTWS_ORIGIN} ${GTWS_PROJECT} ${GTWS_PROJECT_VERSION} opv
#
# Result will be in local variable opv.  Or:
#
# opv = $(gtws_opv ${GTWS_ORIGIN} ${GTWS_PROJECT} ${GTWS_PROJECT_VERSION})
#
# Result will be in local variable opv.
function gtws_opv {
	local origin=$1
	local project=$2
	local version=$3
	local  __resultvar=$4
	local __opv="${origin}/${project}/${version}"

	if [[ $__opv == *:* ]]; then
		debug_print "remote; skip check"
	elif [ ! -d "${__opv}" ]; then
		__opv="${origin}/${project}/git"
	elif [ ! -d "${__opv}" ]; then
		die "No opv for ${origin} ${project} ${version}"
	fi
	if [[ "$__resultvar" ]]; then
		eval $__resultvar="'$__opv'"
	else
		echo "$__opv"
	fi
}

# gtws_project_clone_default ${GTWS_ORIGIN} ${GTWS_PROJECT} ${GTWS_PROJECT_VERSION} ${GTWS_WSNAME}
#
# Clone a version of a project into ${GTWS_WSPATH} (which is the current working directory).  This is the default version of this that clones <origin>/<project>/<version>/*
function gtws_project_clone_default {
	local origin=$1
	local project=$2
	local version=$3
	local name=$4
	local opv=$(gtws_opv "${origin}" "${project}" "${version}")
	local wspath=${PWD}
	local repos=${GTWS_PROJECT_REPOS}

	if [ -z "${repos}" ]; then
		for i in "${opv}"/*; do
			repos="$(basename $i) $repos"
		done
	fi

	for repo in ${repos}; do
		local rpath=""
		if [ -n "${GTWS_REMOTE_IS_WS}" ]; then
			rpath="${opv}/${name}/${repo}"
		else
			rpath="${opv}/${repo}"
		fi
		git clone --recurse-submodules -b "${version}" "${rpath}" || die "failed to clone ${rpath}:${version}"
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
	debug_print "load_rc: Enter + Top: ${BASE}"
	source "${HOME}"/.gtwsrc
	while [ "${BASE}" !=  "/" ]; do
		if [ -f "${BASE}"/.gtwsrc ]; then
			load_rc "$(dirname ${BASE})"
			debug_print "\tLoading ${BASE}/.gtwsrc"
			source "${BASE}"/.gtwsrc
			return 0
		fi
		BASE=$(readlink -f $(dirname "${BASE}"))
	done
	# Stop at /

	return 1
}

# clear_env
#
# Clear the environment of GTWS_* except for the contents of GTWS_SAVEVARS.
# The default values for GTWS_SAVEVARS are below.
function clear_env {
	local savevars=${GTWS_SAVEVARS:-"LOC PROJECT PROJECT_VERSION VERBOSE WSNAME"}
	local verbose="${GTWS_VERBOSE}"
	debug_print "savevars=$savevars"

	# Reset prompt
	if [ -n "${GTWS_SAVEPS1}" ]; then
		PS1="${GTWS_SAVEPS1}"
	fi
	if [ -n "${GTWS_SAVEPATH}" ]; then
		export PATH=${GTWS_SAVEPATH}
	fi
	unset LD_LIBRARY_PATH
	unset PYTHONPATH
	unset PROMPT_COMMAND
	unset CDPATH
	unset SDIRS

	# Save variables
	for i in ${savevars}; do
		SRC=GTWS_${i}
		DST=SAVE_${i}
		debug_print "\t $i: ${DST} = ${!SRC}"
		eval ${DST}=${!SRC}
	done

	# Clear GTWS evironment
	for i in ${!GTWS*} ; do
		if [ -n "${verbose}" ]; then
			echo -e "unset $i" >&2
		fi
		unset $i
	done

	# Restore variables
	for i in ${savevars}; do
		SRC=SAVE_${i}
		DST=GTWS_${i}
		if [ -n "${verbose}" ]; then
			echo -e "\t $i: ${DST} = ${!SRC}" >&2
		fi
		if [ -n "${!SRC}" ]; then
			eval export ${DST}=${!SRC}
		fi
		unset ${SRC}
	done
}

# gtws_tmux_session_info ${SESSION_NAME} running attached
#
# Determine if a session is running, and if it is attached
#
# Result will be in local variables running and attached
#
# Test with:
# if $running ; then
#	echo "is running"
# fi

function gtws_tmux_session_info {
	local ses_name=$1
	local  __result_running=$2
	local  __result_attached=$3

	local __num_ses=$(tmux ls | grep "^${ses_name}" | wc -l)
	local __attached=$(tmux ls | grep "^${ses_name}" | grep attached)

	echo "$ses_name ses=${__num_ses}"

	if [[ "$__result_running" ]]; then
		if [ "${__num_ses}" != "0" ]; then
			eval $__result_running="true"
		else
			eval $__result_running="false"
		fi
	fi
	if [[ "$__result_attached" ]]; then
		if [ -n "${__attached}" ]; then
			eval $__result_attached="true"
		else
			eval $__result_attached="false"
		fi
	fi
}

# gtws_tmux_kill ${BASENAME}
#
# Kill all sessiont matching a pattern
function gtws_tmux_kill {
	local basename=$1
        local old_sessions=$(tmux ls 2>/dev/null | fgrep "${basename}" | cut -f 1 -d:)
	for session in ${old_sessions}; do
		tmux kill-session -t "${session}"
	done
}

# gtws_tmux_cleanup
#
# Clean up defunct tmux sessions
function gtws_tmux_cleanup {
        local old_sessions=$(tmux ls 2>/dev/null | egrep "^[0-9]{14}.*[0-9]+\)$" | cut -f 1 -d:)
	for session in ${old_sessions}; do
		tmux kill-session -t "${session}"
	done
}

# gtws_tmux_attach ${SESSION_NAME}
#
# Attach to a primary session.  It will remain after detaching.
function gtws_tmux_attach {
	local ses_name=$1

	tmux attach-session -t "${ses_name}"
}

# gtws_tmux_slave ${SESSION_NAME}
#
# Create a secondary session attached to the primary session.  It will exit it
# is detached.
function gtws_tmux_slave {
	local ses_name=$1

	# Session is is date and time to prevent conflict
	local session=`date +%Y%m%d%H%M%S`
	# Create a new session (without attaching it) and link to base session
	# to share windows
	tmux new-session -d -t "${ses_name}" -s "${session}"
	# Attach to the new session
	gtws_tmux_attach "${session}"
	# When we detach from it, kill the session
	tmux kill-session -t "${session}"
}

function cdorigin() {
	if [ -n "$(declare -F | grep "gtws_project_cdorigin")" ]; then
		gtws_project_cdorigin $@
	else
		gtws_cdorigin $@
	fi
}

function gtws_cdorigin() {
	local opv=$(gtws_opv "${GTWS_ORIGIN}" "${GTWS_PROJECT}" "${GTWS_PROJECT_VERSION}")
	local target=""
	if [ -n "$1" ]; then
		target="$@"
	else
		git_top_dir target || return 1
		target=$(basename $target)
	fi
	if [ ! -d "${opv}" ]; then
		die "No opv for $target"
	fi
	if [ ! -d "${opv}/$target" ]; then
		target=${target}.git
	fi
	if [ ! -d "${opv}/$target" ]; then
		die "No opv for $target"
	fi
	cd "${opv}/$target"
}
