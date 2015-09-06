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
	echo -e "Failed: $1" >&2
	if [ ! -z "$(declare -F | grep "GTWScleanup")" ]; then
		GTWScleanup
	fi
	if can_die; then
		exit 1
	fi
	return 1
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
	local me;
	if [ -n "${ME}" ]; then
		me=${ME}
	else
		me=$(basename $0)
	fi
	if [ -n "$1" ]; then
		echo "$@"
	fi
	echo ""
	echo "Usage:"
	echo "${me} ${myusage}"
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

# cmd_exists ${cmd}
#
# Determine if a command exists on the system
function cmd_exists {
	which $1 > /dev/null 2>&1
	if [ "$?" == "1" ]; then
		die "You don't have $1 installed, sorry" || return 1
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

	if ! is_git_repo "${try}" ; then
		try=${try}.git
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

# is_docker
#
# return success if process is running inside docker
is_docker() {
	debug_print "is_docker"
	grep -q docker /proc/self/cgroup
	return $?
}

function gtws_rcp {
	rsync --rsh=ssh -avzS --progress "$@"
}

function gtws_cpdot {
	local srcdir=$1
	local dstdir=$2

	debug_print "${FUNCNAME} - ${srcdir} to ${dstdir}"
	if [ -d "${srcdir}" ] && [ -d "${dstdir}" ]; then
		shopt -s dotglob
		cp -a "${srcdir}"/* "${dstdir}"/
		shopt -u dotglob
	fi
}

# gtws_find_dockerfile dockerfile
#
# Result will be in local variable dockerfile  Or:
#
# dockerfile = $(gtws_find_dockerfile)
#
# Result will be in local variable dockerfile
#
# Get the path to the most-specific Dockerfile
function gtws_find_dockerfile {
	local  __resultvar=$1
	local __dir="${GTWS_WSPATH}"
	local __file="Dockerfile"

	debug_print "${FUNCNAME} - trying ${__dir}/${__file}"
	if [ ! -f "${__dir}/${__file}" ]; then
		# Version dir
		__dir=$(dirname "${__dir}")
		debug_print "${FUNCNAME} - trying ${__dir}/${__file}"
	fi
	if [ ! -f "${__dir}/${__file}" ]; then
		# Project dir
		__dir=$(dirname "${__dir}")
		debug_print "${FUNCNAME} - trying ${__dir}/${__file}"
	fi
	if [ ! -f "${__dir}/${__file}" ]; then
		# Top level, flavor
		__dir="${GTWS_LOC}/dockerfiles"
		__file="Dockerfile-${FLAVOR}"
		debug_print "${FUNCNAME} - trying ${__dir}/${__file}"
	fi
	if [ ! -f "${__dir}/${__file}" ]; then
		# Top level, base
		__dir="${GTWS_LOC}/dockerfiles"
		__file="Dockerfile-base"
		debug_print "${FUNCNAME} - trying ${__dir}/${__file}"
	fi
	if [ ! -f "${__dir}/${__file}" ]; then
		die "Could not find a Dockerfile" || return 1
	fi

	debug_print "${FUNCNAME} - found ${__dir}/${__file}"
	if [[ "$__resultvar" ]]; then
		eval $__resultvar="'${__dir}/${__file}'"
	else
		echo "$__dir"
	fi
}

# gtws_smopvn ${GTWS_SUBMODULE_ORIGIN:-${GTWS_ORIGIN}} ${GTWS_PROJECT} ${GTWS_PROJECT_VERSION} ${GTWS_WSNAME} smopvn
#
# Result will be in local variable smopvn.  Or:
#
# smopvn = $(gtws_smopvn ${GTWS_ORIGIN} ${GTWS_PROJECT} ${GTWS_PROJECT_VERSION} ${GTWS_WSNAME})
#
# Result will be in local variable smovpn
#
# Get the path to submodules for this workspace
function gtws_smopvn {
	local origin=$1
	local project=$2
	local version=$3
	local name=$4
	local  __resultvar=$5
	local __smopv="${origin}/${project}/submodule"

	if [[ "$__resultvar" ]]; then
		eval $__resultvar="'$__smopv'"
	else
		echo "$__smopv"
	fi
}

# gtws_opvn ${GTWS_ORIGIN} ${GTWS_PROJECT} ${GTWS_PROJECT_VERSION} ${GTWS_WSNAME} opvn
#
# Result will be in local variable opvn.  Or:
#
# opvn = $(gtws_opvn ${GTWS_ORIGIN} ${GTWS_PROJECT} ${GTWS_PROJECT_VERSION} ${GTWS_WSNAME})
#
# Result will be in local variable opvn.
#
# Get the path to git repos for this workspace
function gtws_opvn {
	local origin=$1
	local project=$2
	local version=$3
	local name=$4
	local  __resultvar=$5
	local __opv="${origin}/${project}/${version}"

	if [[ $__opv == *:* ]]; then
		__opv="${__opv}/${name}"
		debug_print "remote; using opvn $__opv"
	elif [ ! -d "${__opv}" ]; then
		__opv="${origin}/${project}/git"
		if [ ! -d "${__opv}" ]; then
			die "No opvn for ${origin} ${project} ${version}" || return 1
		fi
	fi
	if [[ "$__resultvar" ]]; then
		eval $__resultvar="'$__opv'"
	else
		echo "$__opv"
	fi
}

# gtws_submodule_url ${submodule} url
#
# Result will be in local variable url  Or:
#
# url = $(gtws_submodule_url ${submodule})
#
# Result will be in local variable url
#
# Get the URL for a submodule
function gtws_submodule_url {
	local sub=$1
	local  __resultvar=$2
	local __url=$(git config --list | grep submodule | grep "${sub}" | cut -d = -f 2)

	if [ -z ${__url} ]; then
		local rpath=${PWD}
		local subsub=$(basename "${sub}")
		cd "$(dirname "${sub}")"
		debug_print "${FUNCNAME} trying ${PWD}"
		__url=$(git config --list | grep submodule | grep "${subsub}" | cut -d = -f 2)
		cd "${rpath}"
	fi

	debug_print "${FUNCNAME} $sub url: $__url"
	if [[ "$__resultvar" ]]; then
		eval $__resultvar="'$__url'"
	else
		echo "$__url"
	fi
}

# gtws_submodule_mirror ${opv} ${submodule} mloc
#
# Result will be in local variable mloc  Or:
#
# mloc = $(gtws_submodule_mirror ${opv} ${submodule})
#
# Result will be in local variable mloc
#
# Get the path to a local mirror of the submodule, if it exists
function gtws_submodule_mirror {
	local opv=$1
	local sub=$2
	local  __resultvar=$3
	local __mloc=""
	local url
	gtws_submodule_url ${sub} url
	if [ -n "${url}" ]; then
		local urlbase=$(basename ${url})
		# XXX TODO - handle remote repositories
		#if [[ ${opv} == *:* ]]; then
		## Remote OPV means clone from that checkout; I don't cm
		#refopt="--reference ${opv}/${name}/${sub}"
		if [ -d "${opv}/${urlbase}" ]; then
			__mloc="${opv}/${urlbase}"
		fi
	fi

	if [[ "$__resultvar" ]]; then
		eval $__resultvar="'$__mloc'"
	else
		echo "$__mloc"
	fi
}

# Non-recursive gtws_submodule_paths
function gtws_nr_submodule_paths {
	local  __resultvar=$1
	local __subpaths=$(git submodule status | sed 's/^ *//' | cut -d ' ' -f 2)

	if [[ "$__resultvar" ]]; then
		eval $__resultvar="'$__subpaths'"
	else
		echo "$__subpaths"
	fi
}

# gtws_submodule_paths subpaths
#
# Result will be in local variable subpaths  Or:
#
# subpaths = $(gtws_submodule_paths)
#
# Result will be in local variable subpaths
#
# Get the paths to submodules in a get repo
function gtws_submodule_paths {
	local  __resultvar=$1
	local __subpaths=$(gtws_nr_submodule_paths)
	local __subsubpaths=""
	local rpath="${PWD}"

	for subsub in ${__subpaths}; do
		cd "${subsub}"
		local smpath=$(gtws_nr_submodule_paths)
		if [ -n "${smpath}" ]; then
			__subsubpaths="${__subsubpaths}"$'\n'"${subsub}/$(gtws_nr_submodule_paths)"
		fi
		cd "${rpath}"
	done

	__subpaths="${__subpaths} ${__subsubpaths}"

	if [[ "$__resultvar" ]]; then
		eval $__resultvar="'$__subpaths'"
	else
		echo "$__subpaths"
	fi
}

# gtws_submodule_clone [<base-repo-path>]
#
# This will set up all the submodules in a repo.  Should be called from inside
# the parent repo
function gtws_submodule_clone {
	local opv=$1
	local sub_paths=$(gtws_submodule_paths)

	if [ -z "${opv}" ]; then
		opv=$(gtws_smopvn "${GTWS_SUBMODULE_ORIGIN:-${GTWS_ORIGIN}}" "${GTWS_PROJECT}" "${GTWS_PROJECT_VERSION}" "${GTWS_WSNAME}")
	fi
	git submodule init || die "${FUNCNAME}: Failed to init submodules" || return 1
	for sub in ${sub_paths}; do
		local refopt=""
		local mirror=$(gtws_submodule_mirror ${opv} ${sub})
		debug_print "${FUNCNAME} mirror: ${mirror}"
		if [ -n "${mirror}" ]; then
			refopt="--reference ${mirror}"
		fi
		git submodule update ${refopt} "${sub}"
	done
}

# gtws_repo_clone <base-repo-path> <repo> <branch> [<base-submodule-path>]
function gtws_repo_clone {
	local baserpath=${1%/}
	local repo=$2
	local branch=$3
	local basesmpath=$4
	local rpath="${baserpath}/${repo}"
	local origpath=${PWD}
	local rname=${repo%.git}

	if [[ ${rpath} != *:* ]]; then
		if [ ! -d "${rpath}" ]; then
			rpath="${rpath}.git"
		fi
	fi
	if [ -z "${basesmpath}" ]; then
		basesmpath="${baserpath}"
	fi
	debug_print "${FUNCNAME}: cloning ${baserpath} - ${repo} : ${branch} into ${GTWS_WSNAME} submodules: ${basesmpath}"

	# Main repo
	#git clone --recurse-submodules -b "${branch}" "${rpath}" || die "failed to clone ${rpath}:${branch}" || return 1
	git clone -b "${branch}" "${rpath}" || die "${FUNCNAME}: failed to clone ${rpath}:${branch}" || return 1

	# Update submodules
	cd "${rname}" || die "${FUNCNAME}: failed to cd to ${rpath}" || return 1
	gtws_submodule_clone "${basesmpath}" || return 1
	cd "${origpath}" || die "${FUNCNAME}: Failed to cd to ${origpath}" || return 1

	# Copy per-repo settings, if they exist
	gtws_cpdot "${baserpath%/git}/extra/repo/${rname}" "${origpath}/${rname}"

	# Extra files
	for i in ${GTWS_FILES_EXTRA}; do
		local esrc=

		IFS=':' read -ra ARR <<< "$i"
		if [ -n "${ARR[1]}" ]; then
			dst="${rname}/${ARR[1]}"
		else
			dst="${rname}/${ARR[0]}"
		fi

		if [ -n "${GTWS_REMOTE_IS_WS}" ]; then
			esrc="${baserpath}/${dst}"
		else
			esrc="${baserpath%/git}"
		fi

		gtws_rcp "${esrc}/${ARR[0]}" "${dst}"
	done
}

# gtws_project_clone_default ${GTWS_ORIGIN} ${GTWS_PROJECT} ${GTWS_PROJECT_VERSION} ${GTWS_WSNAME} [${SUBMODULE_BASE}]
#
# Clone a version of a project into ${GTWS_WSPATH} (which is the current working directory).  This is the default version of this that clones <origin>/<project>/<version>/*
function gtws_project_clone_default {
	local origin=$1
	local project=$2
	local version=$3
	local name=$4
	local basesmpath=$5
	local opv=$(gtws_opvn "${origin}" "${project}" "${version}" "${name}")
	local wspath=${PWD}
	local repos=
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

	if [ -z "${basesmpath}" ] || [ ! -d "${basesmpath}" ]; then
		basesmpath="${opv}"
	fi

	for repo in ${repos}; do
		gtws_repo_clone "${opv}" "${repo}" "${branches[${repo}]}" "${basesmpath}"
	done

	# Copy per-WS settings, if they exist
	gtws_cpdot "${opv%/git}/extra/ws" "${wspath}"
}

# gtws_repo_setup ${wspath} ${repo_path}
#
# The project can define gtws_repo_setup_local taking the same args to do
# project-specific setup.  It will be called last.
#
# Post-clone setup for an individual repo
function gtws_repo_setup {
	local wspath=$1
	local rpath=$2
	local savedir="${PWD}"

	if [ ! -d "${rpath}" ]; then
		return 0
	fi

	cd "${rpath}/src" 2>/dev/null \
		|| cd ${rpath} \
		|| die "Couldn't cd to ${rpath}" || return 1

	maketags ${GTWS_MAKETAGS_OPTS} > /dev/null 2> /dev/null &

	cd ${wspath} || die "Couldn't cd to ${wspath}" || return 1

	mkdir -p "${wspath}/build/$(basename ${rpath})"

	cd "${savedir}"

	if [ -n "$(declare -F | grep "\<gtws_repo_setup_local\>")" ]; then
		gtws_repo_setup_local "${wspath}" "${rpath}" \
			|| die "local repo setup failed" || return 1
	fi
}

# gtws_project_setup${GTWS_WSNAME} ${GTWS_ORIGIN} ${GTWS_PROJECT} ${GTWS_PROJECT_VERSION}
#
# The project can define gtws_project_setup_local taking the same args to do
# project-specific setup.  It will be called last.
#
# Post clone setup of a workspace in ${GTWS_WSPATH} (which is PWD)
function gtws_project_setup {
	local wsname=$1
	local origin=$2
	local project=$3
	local version=$4
	local wspath=${PWD}
	local opv=$(gtws_opvn "${origin}" "${project}" "${version}" "placeholder")

	for i in "${wspath}"/*; do
		gtws_repo_setup "${wspath}" "${i}"
	done

	mkdir "${wspath}"/install
	mkdir "${wspath}"/chroots
	mkdir "${wspath}"/patches

	if [ -n "$(declare -F | grep "\<gtws_project_setup_local\>")" ]; then
		gtws_project_setup_local "${wsname}" "${origin}" "${project}" \
			"${version}" || die "local project setup failed" || return 1
	fi
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

# save_env ${file} ${nukevars}
#
# Save the environment of GTWS_* to the give file, except for the variables
# given to nuke.  The default values to nuke are given below.
function save_env {
	local fname=${1}
	local nukevars=${2:-"SAVEPATH ORIGIN WS_GUARD LOC SAVEPS1"}
	debug_print "nukevars=$nukevars"

	for i in ${!GTWS*} ; do
		for j in ${nukevars}; do
			if [ "${i}" == "GTWS_${j}" ]; then
				debug_print "skipping $i"
				continue 2
			fi
		done
		debug_print "saving $i"
		echo "export $i=\"${!i}\"" >> "${fname}"
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

function gtws_get_origin {
	local opv=$1
	local target=$2
	local __origin=
	local  __resultvar=$3

	# If it's a git repo with a local origin, use that.
	__origin=$(git config --get remote.origin.url)
	if [ ! -d "${__origin}" ]; then
		__origin="${__origin}.git"
	fi
	if [ ! -d "${__origin}" ]; then
		# Try to figure it out
		if [ ! -d "${opv}" ]; then
			die "No opv for $target" || return 1
		fi
		find_git_repo "${opv}" "${target}" __origin || return 1
	fi

	if [[ "$__resultvar" ]]; then
		eval $__resultvar="'$__origin'"
	else
		echo "$__origin"
	fi
}

function gtws_cdorigin() {
	local opv=$(gtws_opvn "${GTWS_ORIGIN}" "${GTWS_PROJECT}" "${GTWS_PROJECT_VERSION}" "${GTWS_WSNAME}")
	local gitdir=""
	local target=""
	if [ -n "$1" ]; then
		target="$@"
	else
		git_top_dir gitdir || return 1
		target=$(basename $gitdir)
	fi

	gtws_get_origin $opv $target origin || return 1
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

# Override "cd" inside the workspace to go to GTWS_WSPATH by default
function cd {
	if [ -z "$@" ]; then
		cd "${GTWS_WSPATH}"
	else
		builtin cd $@
	fi
}

# Generate diffs/interdiffs for changes and ship to WS on other boxes
function gtws_interdiff {
	local targets=$@
	local target=
	local repo=$(basename ${PWD})
	local mainpatch="${GTWS_WSPATH}/patches/${repo}-full.patch"
	local interpatch="${GTWS_WSPATH}/patches/${repo}-incremental.patch"

	if [ -z "${targets}" ]; then
		echo "Usage: ${FUNCNAME} <targethost>"
		die "Must give targethost" || return 1
	fi
	if [ -f "${mainpatch}" ]; then
		git diff | interdiff "${mainpatch}" - > "${interpatch}"
	fi
	git diff > "${mainpatch}"
	for target in ${targets}; do
		gtws_rcp "${mainpatch}" "${interpatch}" \
			"${target}:${GTWS_WSPATH}/patches"
	done
}

function gtws_debug {
	local cmd=$1
	if [ -z "${cmd}" ]; then
		echo "Must give a command"
		echo
		die "${FUNCNAME} <cmd-path>" || return 1
	fi
	local cmdbase=$(basename $cmd)
	local pid=$(pgrep "${cmdbase}")

	cgdb ${cmd} ${pid}
}
