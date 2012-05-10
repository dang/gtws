
function tools {
	if [ -z "${1}" ]; then
		echo "tools [<version>] <workspace>"
		return 0
	fi
	if [ -z "${2}" ]; then
		WSVER="trunk"
		WSNAME="${1}"
	else
		WSVER="${1}"
		WSNAME="${2}"
	fi
	if [ ! -f ${HOME}/src/${WSVER}/${WSNAME}/.tools.env ]; then
		echo "No env for ${WSVER}/${WSNAME}"
		return 1
	else
		. ${HOME}/src/${WSVER}/${WSNAME}/.tools.env
	fi
}

function gatt() {
	TGT="${1}"
	shift
	case "${TGT}" in
		ospf3)
			cd ${GATED_TOOLS_PATH}/tests/cli/system/ospf3/"$@"
			;;
		ospf2)
			cd ${GATED_TOOLS_PATH}/tests/cli/system/ospf/"$@"
			;;
		bgp)
			cd ${GATED_TOOLS_PATH}/tests/cli/system/bgp/"$@"
			;;
		mpbgp)
			cd ${GATED_TOOLS_PATH}/tests/cli/system/mpbgp/"$@"
			;;
		mpbgpv4v6)
			cd ${GATED_TOOLS_PATH}/tests/cli/system/mpbgpv4v6/"$@"
			;;
		rip2)
			cd ${GATED_TOOLS_PATH}/tests/cli/system/rip/"$@"
			;;
		ripng)
			cd ${GATED_TOOLS_PATH}/tests/cli/system/ripng/"$@"
			;;
		leak)
			cd ${GATED_TOOLS_PATH}/tests/cli/system/leak/"$@"
			;;
		scripts)
			cd ${GATED_TOOLS_PATH}/scripts/"$@"
			;;
		data)
			cd ${GATED_TOOLS_PATH}/data/"$@"
			;;
		*)
			cd ${GATED_TOOLS_PATH}/"${TGT}"/"$@"
			;;
	esac
}

function cdws() {
	cd "${HOME}/src/${WSVER}/${CURWS}/$@"
}

function cdorigin() {
	cd "${HOME}/origin/${WSVER}/$@"
}

function debugws() {
	if [ -z "${2}" ]; then
		echo "debugws <gversion> <wsname> [<iversion>]"
		return 1
	elif [ -z "${3}" ]; then
		TGVER="${1}"
		TWS="${2}"
		case "${TGVER}" in
			"3.1")
				TIVER="i5.0"
				;;
			"3.2")
				TIVER="i10.0"
				;;
			"3.3")
				TIVER="i11.0"
				;;
			"trunk")
				TIVER="itrunk"
				;;
		esac
	else
		TGVER="${1}"
		TWS="${2}"
		TIVER="${3}"
	fi
	case "${TIVER}" in
		"itrunk")
			TBIN="bin/pcx86"
			;;
		"i11.0")
			TBIN="bin/pcx86"
			;;
		"i10.0")
			TBIN="pcx86"
			;;
		"i5.0")
			TBIN="pcx86"
			;;
		"i5.0-vrf")
			TBIN="pcx86"
			;;
	esac

	cd "${HOME}/src/${TGVER}/${TWS}/${TIVER}/${TBIN}"
}

