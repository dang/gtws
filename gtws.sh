#!/bin/bash
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

# if can_die; then exit
#
# Check to see if it's legal to exit during die
can_die() {
	if (( BASH_SUBSHELL > 0 )); then
		debug_print "\t\tbaby shell; exiting"
		return 0
	fi
	if ! is_interactive; then
		debug_print "\t\tNot interactive; exiting"
		return 0
	fi
	debug_print "\t\tParent interactive; not exiting"
	return 1
}

# In a function:
# command || die "message" || return 1
# Outside a function:
# command || die "message"
#
# Print a message and exit with failure
die() {
	echo "Failed: $1"
	if [ ! -z "$(declare -F | grep "GTWScleanup")" ]; then
		GTWScleanup
	fi
	if can_die; then
		exit 1
	elif [ -n "${2}" ]; then
		return 1
	fi
}

# Alternativess for using die properly to handle both interactive and script useage:
#
# Version 1:
#
#testfunc() {
#	command1 || die "${FUNCNAME}: command1 failed" || return 1
#	command2 || die "${FUNCNAME}: command2 failed" || return 1
#	command3 || die "${FUNCNAME}: command3 failed" || return 1
#}
#
# Version 2:
#
#testfunc() {
#	(
#		command1 || die "${FUNCNAME}: command1 failed"
#		command2 || die "${FUNCNAME}: command2 failed"
#		command3 || die "${FUNCNAME}: command3 failed"
#	)
#	return $?
#}
#
# Optionally, the return can be replaced with this:
#	local val=$?
#	[[ "${val}" == "0" ]] || die
#	return ${val}
# This will cause the contaning script to abort

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
	debug_print "is_git_repo $1"
	if [[ $1 == *:* ]]; then
		debug_print "    remote; assume good"
		return 0
	elif [ ! -d "$1" ]; then
		debug_print "    fail: not dir"
		return 1
	fi
	cd "$1"
	git rev-parse --git-dir >/dev/null 2>&1
	local ret=$?
	cd - > /dev/null
	debug_print "    retval: $ret"
	return $ret
}

# find_git_repo ${basedir} ${repo_name} repo_dir
#
# Find the git repo for ${repo_name} in ${basedir}.  It's one of ${repo_name}
# or ${repo_name}.git
#
# Result will be in the local variable repo_dir  Or:
#
# repo_dir=$(find_git_repo ${basedir} ${repo_name})
#
function find_git_repo {
	local basedir=$1
	local repo_name=$2
	local __resultvar=$3
	local try="${basedir}/${repo_name}"

	if [ ! -d "${try}" ]; then
		try=${try}.git
	fi
	if [ ! -d "${try}" ]; then
		die "No directory for ${repo_name} in ${basedir}" || return 1
	fi

	is_git_repo "${try}" || die "${repo_name} in ${basedir} is not a git repository" || return 1

	if [[ "$__resultvar" ]]; then
		eval $__resultvar="'$try'"
	else
		echo "$try"
	fi
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
		die "${PWD} is not a git repo" || return 1
	fi
	if [[ "$__resultvar" ]]; then
		eval $__resultvar="'$__top'"
	else
		echo "$__top"
	fi
}

function gtws_rcp {
	rsync --rsh=ssh -avzS --progress "$@"
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
		die "No opv for ${origin} ${project} ${version}" || return 1
	fi
	if [[ "$__resultvar" ]]; then
		eval $__resultvar="'$__opv'"
	else
		echo "$__opv"
	fi
}

# gtws_repo_clone <base-repo-path> <repo> <branch>
function gtws_repo_clone {
	local baserpath=$1
	local repo=$2
	local branch=$3
	local rpath="${baserpath}/${repo}"

	debug_print "${FUNCNAME}: cloning ${baserpath} - ${repo} : ${branch} into ${GTWS_WSNAME}"
	git clone --recurse-submodules -b "${branch}" "${rpath}" || die "failed to clone ${rpath}:${branch}" || return 1
	for i in ${GTWS_FILES_EXTRA}; do
		local esrc=

		IFS=':' read -ra ARR <<< "$i"
		if [ -n "${ARR[1]}" ]; then
			dst="${repo}/${ARR[1]}"
		else
			dst="${repo}/${ARR[0]}"
		fi

		if [ -n "${GTWS_REMOTE_IS_WS}" ]; then
			esrc="${baserpath}/${dst}"
		else
			esrc="${baserpath%/git}"
		fi

		gtws_rcp "${esrc}/${ARR[0]}" "${dst}"
	done
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
	local repos=
	local baserpath=
	local -A branches

	if [ -z "${GTWS_PROJECT_REPOS}" ]; then
		for i in "${opv}"/*; do
			repos="$(basename $i) $repos"
			branches[$i]=${version}
		done
	else
		for i in ${GTWS_PROJECT_REPOS}; do
			IFS=':' read -ra ARR <<< "$i"
			repos="${ARR[0]} $repos"
			if [ -n "${ARR[1]}" ]; then
				branches[${ARR[0]}]=${ARR[1]}
			else
				branches[${ARR[0]}]=${version}
			fi
		done
	fi

	if [ -n "${GTWS_REMOTE_IS_WS}" ]; then
		baserpath="${opv}/${name}"
	else
		baserpath="${opv}"
	fi

	for repo in ${repos}; do
		gtws_repo_clone "${baserpath}" "${repo}" "${branches[${repo}]}"
	done
}

# gtws_repo_setup ${wspath} ${repo_path}
#
# Post-clone setup for an individual repo
function gtws_repo_setup {
	local wspath=$1
	local rpath=$2
	local savedir="${PWD}"

	if [ ! -d "${rpath}" ]; then
		return 0
	fi

	cd "${rpath}/src" 2>/dev/null || cd ${rpath} || die "Couldn't cd to ${rpath}" || return 1

	maketags ${GTWS_MAKETAGS_OPTS} > /dev/null 2> /dev/null &
	if [ -x "src/scripts/git_hooks/install_git_hooks.sh" ]; then
		./src/scripts/git_hooks/install_git_hooks.sh
	fi

	cd ${wspath} || die "Couldn't cd to ${wspath}" || return 1

	mkdir -p "${wspath}/build/$(basename ${rpath})"

	cd "${savedir}"
}

# gtws_project_setup_default ${GTWS_WSNAME} ${GTWS_ORIGIN} ${GTWS_PROJECT} ${GTWS_PROJECT_VERSION}
#
# Post clone setup of a workspace in ${GTWS_WSPATH} (which is PWD)
function gtws_project_setup_default {
	local wsname=$1
	local origin=$2
	local project=$3
	local version=$4
	local wspath=${PWD}

	for i in "${wspath}"/*; do
		gtws_repo_setup "${wspath}" "${i}"
	done

	mkdir "${wspath}"/install
	mkdir "${wspath}"/chroots
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
	local gitdir=""
	local target=""
	if [ -n "$1" ]; then
		target="$@"
	else
		git_top_dir gitdir || return 1
		target=$(basename $gitdir)
	fi

	# If it's a git repo with a local origin, use that.
	local origin=$(git config --get remote.origin.url)
	if [ -d "${origin}" ]; then
		debug_print "Local origin"
		cd "${origin}"
		return 0
	fi

	# Try to figure it out
	if [ ! -d "${opv}" ]; then
		die "No opv for $target" || return 1
	fi
	find_git_repo "${opv}" "${target}" origin || return 1
	cd "${origin}"
}

# Copy files to another machine in the same workspace
function wsrcp {
	local target="${!#}"
	local length=$(($#-1))
	local base=${PWD}

	if [ -z "${1}" -o -z "${2}" ]; then
		echo "usage: ${FUNCNAME} <path> [<path>...] <target>"
		return 1
	fi

	for path in "${@:1:$length}"; do
		gtws_rcp "${path}" "${target}:${base}/${path}"
	done
}
