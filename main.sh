#include <stdlib/ask.sh>
#include <stdlib/log.sh>
#include <stdlib/trace.sh>
#include <stdlib/var.sh>

hbc() {
#-------------------------------------------------------------------------------- HBC OPTIONS
___BEGIN___ERROR___TRACE___
unset -v main OUTPUT
# PARSE ARGS
while [[ $# != 0 ]]; do
# HELP OPTION
if [[ $1 = "-h" || $1 = "--help" ]]; then
cat << EOM
USAGE: hbc [OPTION] [ARGUMENT]
    -d | --delete                       overwrite output file if it already exists
    -i | --ignore  <shellcheck codes>   ignore shellcheck codes, formatting: [-i SC2154,SC2155]
    -l | --library <library directory>  specify where to look for lib code, default: [/usr/local/include]
    -m | --main    <main script name>   specify main script name, default: [main.sh]
    -h | --help                         print this help message and exit unsuccessfully
    -o | --output  <output name>        specify output filename, default: [\$FOLDER_NAME.sh]
    -q | --quiet                        suppress hbc compile-time output (exit codes stay)
    -r | --run                          run output file if hbc successfully compiles
    -t | --test                         --run & --quiet the output from memory, no file made
    -v | --version                      print this hbc's time of compile and exit unsuccessfully
EOM
exit 2
# VERSION OPTION
elif [[ $1 = "-v" || $1 = "--version" ]]; then
	date -d @"$(grep -m1 "#nix <.*>$" "$0" | tr -d '#nix<> ')"
	exit 3
fi
# SHORT+LONG OPTIONS
case $1 in
	-d | --delete) local OPTION_DELETE=true; shift;;
	-i | --ignore)
		shift
		if [[ -z $1 ]]; then
			log::fail "hbc: no arg after --ignore"
			exit 1
		fi
		local OPTION_IGNORE="$1"; shift;;
	-l | --library)
		shift
		if [[ -z $1 ]]; then
			log::fail "hbc: no arg after --library"
			exit 1
		fi
		local LIB_DIRECTORY="$1"; shift;;
	-m | --main)
		shift
		if [[ -z $1 ]]; then
			log::fail "hbc: no arg after --main"
			exit 1
		fi
		local main="$1"; shift;;
	-o | --output)
		shift
		if [[ -z $1 ]]; then
			log::fail "hbc: no arg after --output"
			exit 1
		fi
		OUTPUT="$1"; shift;;
	-r | --run) OPTION_RUN=true; shift;;
	-t | --test) OPTION_RUN=true; OPTION_QUIET=true; OPTION_TEST=true; shift;;
	-q | --quiet) OPTION_QUIET=true; shift;;
	*) log::fail "hbc: invalid option: $1"; exit 1;;
esac
done
___ENDOF___ERROR___TRACE___

#-------------------------------------------------------------------------------- SANITY CHECKS
# NO SRC DIR
if [[ ! -d src && $OPTION_QUIET != true ]]; then
	log::warn "no src directory found"
fi

# MAIN SCRIPT
[[ -z $main ]] && local main="main.sh"
if [[ ! -e $main ]]; then
	log::fail "hbc: $main not found"
	exit 1
fi

# BOTH LIB/SRC NOT FOUND
local EXISTS_LIB=true
local SRC_FILES
local SRC_FILE_NAMES
SRC_FILES=$(find src -regex ".*\.sh\|.*\.bash" 2>/dev/null | sort)
if ! grep -m1 "^#include <.*>$" "$main" &>/dev/null; then
	EXISTS_LIB=false
	if [[ -z $SRC_FILES ]]; then
		log::fail "both [lib/src] are missing" "no reason to use hbc"
		exit 1
	fi
fi

# $1 OUT.SH NAMING
local DIRECTORY_NAME
DIRECTORY_NAME="$(basename "$PWD")"
if [[ $DIRECTORY_NAME = hbc && -z $OUTPUT ]]; then
	OUTPUT="hbc"
elif [[ -z $OUTPUT ]]; then
	OUTPUT="${DIRECTORY_NAME}.sh"
fi

# IF MAIN/OUT ARE WEIRD CHARACTERS
if [[ $main != [A-Za-z0-9_/~$]* ]]; then
	log::fail "hbc: \$main contains weird characters; only [A-Za-z0-9_/~$] is supported"
	exit 1
elif [[ $OUTPUT != [A-Za-z0-9_/]* ]]; then
	log::fail "hbc: \$OUTPUT contains weird characters; only [A-Za-z0-9_/~$] is supported"
	exit 1
fi

# OUT ALREADY EXISTS WARNING
if [[ -e $OUTPUT && $OPTION_DELETE != true && $OPTION_TEST != true ]]; then
	log::warn "$OUTPUT already exists"
	printf "%s" "         overwrite? (y/N) "
	ask::no && exit 2
fi

# QUIET OPTION
[[ $OPTION_QUIET = true ]] && exec 3>&1 &>/dev/null

#-------------------------------------------------------------------------------- VARIABLE INIT
___BEGIN___ERROR___TRACE___

# HEADERS
local HEADER_LIB="#-------------------------------------------------------------------------------- BEGIN LIB CODE"
local HEADER_SRC="#-------------------------------------------------------------------------------- BEGIN SRC CODE"
local HEADER_MAIN="#-------------------------------------------------------------------------------- BEGIN MAIN SCRIPT"
local ENDOF_MAIN="#-------------------------------------------------------------------------------- ENDOF MAIN SCRIPT"

# GIT HASH
local DIRECTORY_GIT
DIRECTORY_GIT=$(git rev-parse --short HEAD 2>/dev/null) || unset DIRECTORY_GIT

# HBC VERSION
local VERSION_HBC
VERSION_HBC=$(grep -m1 "^#git <hbc/.*>$" "$0" | grep -o "\/.*>" | tr -d '/>')

# LIB/SRC/MAIN
local LIB_GIT
[[ -z $LIB_DIRECTORY ]] && LIB_DIRECTORY="/usr/local/include"
#local SRC_FILES # this gets defined in the beginning sanity check

# MKTEMP
declare -g TMP_DIR
local TMP_HEADER
local TMP_LIB
local TMP_SRC
local TMP_SCRATCH
local VAR_SCRATCH
local EXISTS_TMP
if EXISTS_TMP=$(find /tmp/hbc.* -type d 2>/dev/null); then
	printf "${BWHITE}%s${OFF}\n" "cleaning [tmp]"
	local i
	for i in $EXISTS_TMP; do
		log::tab "$i"
		rm -rf "$i"
	done
fi
TMP_DIR="$(mktemp -d /tmp/hbc.XXXXXXXXXX)"
TMP_HEADER="$(mktemp "$TMP_DIR"/header.XXXXXXXXX)"
TMP_LIB="$(mktemp "$TMP_DIR"/lib.XXXXXXX)"
TMP_SRC="$(mktemp "$TMP_DIR"/src.XXXXXXX)"
TMP_SCRATCH="$(mktemp "$TMP_DIR"/scratch.XXXXXXXXXX)"
# TEST OUTPUT
if [[ $OPTION_TEST = true ]]; then
	local TMP_TEST
	TMP_TEST="$(mktemp "$TMP_DIR"/test.XXXXXXXXXX)"
	OUTPUT="$TMP_TEST"
fi

# SAFETY HEADERS
local SAFETY_LIB
SAFETY_LIB=$(cat << 'EOM'
POSIXLY_CORRECT=;\unset -f trap set unset declare exit printf read unalias;\unalias -a
set -eo pipefail || exit 111
trap 'printf "%s\n" "@@@@@@ LIB PANIC @@@@@@" "[line] ${LINENO}" "[file] $0" "[code] $?";set +eo pipefail;trap - ERR;while :;do read;done;exit 112' ERR || exit 112
unset POSIXLY_CORRECT || exit 113
EOM
)
local SAFETY_SRC
SAFETY_SRC=$(cat << 'EOM'
POSIXLY_CORRECT=;\unset -f trap set unset declare exit printf read unalias;\unalias -a
set -eo pipefail || exit 114
trap 'printf "%s\n" "@@@@@@ SRC PANIC @@@@@@" "[line] ${LINENO}" "[file] $0" "[code] $?";set +eo pipefail;trap - ERR;while :;do read;done;exit 115' ERR || exit 115
unset POSIXLY_CORRECT || exit 116
EOM
)
local SAFETY_END
SAFETY_END=$(cat << 'EOM'
trap - ERR || exit 117
set +eo pipefail || exit 118
EOM
)

#-------------------------------------------------------------------------------- HEADER
printf "${BBLUE}%s${OFF}\n" "compiling [header] ***************"
# BASH SHEBANG
log::tab "#!/usr/bin/env bash"
echo "#!/usr/bin/env bash" > "$TMP_HEADER"

# GIT HASH
if [[ $DIRECTORY_GIT ]]; then
	log::tab "git: $DIRECTORY_GIT"
	if [[ $DIRECTORY_NAME = hbc ]]; then
		echo "#git <hbc/${DIRECTORY_GIT}>" >> "$TMP_HEADER"
	else
		echo "#git <${OUTPUT}/${DIRECTORY_GIT}>" >> "$TMP_HEADER"
	fi
else
	log::warn "git: no hash found"
fi

# UNIX TIME
log::tab "nix: $EPOCHSECONDS"
echo "#nix <$EPOCHSECONDS>" >> "$TMP_HEADER"

# HBC VERSION
log::tab "hbc: $VERSION_HBC"
echo "#hbc <$VERSION_HBC>" >> "$TMP_HEADER"

#-------------------------------------------------------------------------------- LIB
# LIB LOOP
if [[ $EXISTS_LIB = true && $DIRECTORY_NAME != *lib ]]; then
	printf "${BPURPLE}%s${OFF}\n" "compiling [lib] ******************"
	local i
	# include each found #include in TMP_LIB
	for i in $(grep "^#include <.*>$" "$main" | cut -d ' ' -f2 | tr -d '<>' | sort); do
		if [[ $i = *.sh && -f "$LIB_DIRECTORY/$i" ]]; then
			sed "/^#\|[[:space:]]#/d" "$LIB_DIRECTORY/$i" >> "$TMP_LIB"
			# if #git is found in the lib file, attach to TMP_HEADER
			if LIB_GIT=$(grep "^#git <.*>$" "$LIB_DIRECTORY/$i" | cut -d ' ' -f2); then
				log::tab "$LIB_GIT"
				echo "#lib $LIB_GIT" >> "$TMP_HEADER"
			else
				log::warn "<lib missing #git>"
				echo "#lib <UNKNOWN>" >> "$TMP_HEADER"
			fi
		else
			log::fail "$i not *.sh || $i not found"
			exit 1
		fi
	done
fi

#-------------------------------------------------------------------------------- SRC
# SRC LOOP
if [[ $SRC_FILES ]]; then
	printf "${BCYAN}%s${OFF}\n" "compiling [src]"
	for i in $SRC_FILES; do
		log::tab "<${i/src\//}>"
		sed "/^#\|[[:space:]]#/d" "$i" >> "$TMP_SRC"
		echo "#src <${i/src\//}>" >> "$TMP_HEADER"
	done
fi

#-------------------------------------------------------------------------------- CLEANING
printf "${BYELLOW}%s${OFF}\n" "cleaning *************************"

# SCRATCH (ref for grep to remove lines)
log::tab "creating scratch"
echo "$SAFETY_LIB" > "$TMP_SCRATCH"
echo "$SAFETY_SRC" >> "$TMP_SCRATCH"
echo "$SAFETY_END" >> "$TMP_SCRATCH"

# LIB
if [[ $EXISTS_LIB = true ]]; then
	local LINES_LIB
	LINES_LIB[0]=$(wc -l "$TMP_LIB" | cut -d ' ' -f1)
	sed -i -e '/#!\/usr\/bin\/env bash$/d' \
		-i -e '/#!\/usr\/bin\/bash$/d' \
		-i -e '/#!\/bin\/bash$/d' \
		-i -e '/^$/d' "$TMP_LIB"
	LINES_LIB[1]=$(wc -l "$TMP_LIB" | cut -d ' ' -f1)
	log::tab "[lib] sed  removed: $((LINES_LIB[0] - LINES_LIB[1]))"
	if VAR_SCRATCH="$(grep -vxFf "$TMP_SCRATCH" "$TMP_LIB")"; then
		LINES_LIB[2]=$(echo "$VAR_SCRATCH" | wc -l)
		echo "$VAR_SCRATCH" > "$TMP_LIB"
		log::tab "[lib] grep removed: $((LINES_LIB[1] - LINES_LIB[2]))"
	fi
	log::tab "[lib] ${LINES_LIB[0]} -> ${LINES_LIB[2]}"
fi
# SRC
if [[ $SRC_FILES ]]; then
	local LINES_SRC
	LINES_SRC[0]=$(wc -l "$TMP_SRC" | cut -d ' ' -f1)
	sed -i -e '/#!\/usr\/bin\/env bash$/d' \
		-i -e '/#!\/usr\/bin\/bash$/d' \
		-i -e '/#!\/bin\/bash$/d' \
		-i -e '/^$/d' "$TMP_SRC"
	LINES_SRC[1]=$(wc -l "$TMP_SRC" | cut -d ' ' -f1)
	log::tab "[src] sed  removed: $((LINES_SRC[0] - LINES_SRC[1]))"
	if VAR_SCRATCH="$(grep -vxFf "$TMP_SCRATCH" "$TMP_SRC")"; then
		LINES_SRC[2]=$(echo "$VAR_SCRATCH" | wc -l)
		echo "$VAR_SCRATCH" > "$TMP_SRC"
		log::tab "[src] grep removed: $((LINES_SRC[1] - LINES_SRC[2]))"
	fi
	log::tab "[src] ${LINES_SRC[0]} -> ${LINES_SRC[2]}"
fi

#-------------------------------------------------------------------------------- LINKING
printf "${BGREEN}%s${OFF}\n" "linking  *************************"

# HEADER
printf "%s" "" > "$OUTPUT"
log::tab "[header] -------> line $(wc -l "$OUTPUT" | cut -f1 -d ' ')"
cat "$TMP_HEADER" > "$OUTPUT"

# LIB
if [[ $EXISTS_LIB = true && $DIRECTORY_NAME != *lib ]]; then
	echo >> "$OUTPUT"
	log::tab "[lib::header] --> line $(($(wc -l "$OUTPUT" | cut -f1 -d ' ')+1))"
	echo "$HEADER_LIB" >> "$OUTPUT"
	log::tab "[lib::safety] --> line $(($(wc -l "$OUTPUT" | cut -f1 -d ' ')+1))"
	echo "$SAFETY_LIB" >> "$OUTPUT"
	log::tab "[lib] ----------> line $(($(wc -l "$OUTPUT" | cut -f1 -d ' ')+1))"
	cat "$TMP_LIB" >> "$OUTPUT"
	# DECLARE -FR
	log::tab "[lib::declare] -> line $(($(wc -l "$OUTPUT" | cut -f1 -d ' ')+1))"
	local FUNCTIONS_LIB
	if FUNCTIONS_LIB=($(grep -ho "^[0-9A-Za-z:_-]\+(){\|^[0-9A-Za-z:_-]\+()[[:blank:]]\+{" "$TMP_LIB" | tr -d '(){ ')); then
		if [[ -z ${FUNCTIONS_LIB[0]} ]]; then
			log::fail "no functions found"
			exit 3
		fi
		local d
		for d in ${FUNCTIONS_LIB[@]}; do
			echo "declare -fr $d" >> "$OUTPUT"
		done
	fi
fi

# SRC
if [[ $SRC_FILES ]]; then
	echo >> "$OUTPUT"
	log::tab "[src::header] --> line $(($(wc -l "$OUTPUT" | cut -f1 -d ' ')+1))"
	echo "$HEADER_SRC" >> "$OUTPUT"
	if [[ $DIRECTORY_NAME != *lib ]]; then
		log::tab "[src::safety] --> line $(($(wc -l "$OUTPUT" | cut -f1 -d ' ')+1))"
		echo "$SAFETY_SRC" >> "$OUTPUT"
	fi
	log::tab "[src] ----------> line $(($(wc -l "$OUTPUT" | cut -f1 -d ' ')+1))"
	cat "$TMP_SRC" >> "$OUTPUT"
	# DECLARE -FR
	if [[ $DIRECTORY_NAME != *lib ]]; then
		log::tab "[src::declare] -> line $(($(wc -l "$OUTPUT" | cut -f1 -d ' ')+1))"
		local FUNCTIONS_SRC
		if FUNCTIONS_SRC=($(grep -ho "^[0-9A-Za-z:_-]\+(){\|^[0-9A-Za-z:_-]\+()[[:blank:]]\+{" "$TMP_SRC" | tr -d '(){ ')); then
			if [[ -z ${FUNCTIONS_SRC[0]} ]]; then
				log::fail "no functions found"
				exit 3
			fi
			local d
			for d in ${FUNCTIONS_SRC[@]}; do
				echo "declare -fr $d" >> "$OUTPUT"
			done
		fi
	fi
fi

# SAFETY END
if [[ $DIRECTORY_NAME != *lib ]]; then
	log::tab "[safety::end] --> line $(($(wc -l "$OUTPUT" | cut -f1 -d ' ')+1))"
	echo "$SAFETY_END" >> "$OUTPUT"
fi

# MAIN
local EXISTS_MAIN
EXISTS_MAIN=$(sed -e "/^#include <.*>$/d" -e '/./,$!d' "$main")
if [[ $EXISTS_MAIN ]]; then
	echo >> "$OUTPUT"
	log::tab "[main::header] -> line $(($(wc -l "$OUTPUT" | cut -f1 -d ' ')+1))"
	echo "$HEADER_MAIN" >> "$OUTPUT"
	log::tab "[main] ---------> line $(($(wc -l "$OUTPUT" | cut -f1 -d ' ')+1))"
	echo "$EXISTS_MAIN" >> "$OUTPUT"
	log::tab "[main::endof] --> line $(($(wc -l "$OUTPUT" | cut -f1 -d ' ')+1))"
	echo "$ENDOF_MAIN" >> "$OUTPUT"
fi

# END STATS (WC)
log::tab "[${OUTPUT}] total lines: $(wc -l "$OUTPUT" | cut -f1 -d ' ')"

#-------------------------------------------------------------------------------- END
# CHMOD PERMISSIONS
log::info "700 permissions"
chmod 700 "${OUTPUT}"

# SHELLCHECK
log::info "starting shellcheck"
if [[ $OPTION_QUIET = true ]]; then
	shellcheck "${OUTPUT}" --shell bash -e SC2274,SC2068,SC2128,SC2086,SC1036,SC1088,SC2153,SC2034,SC2155,SC2207,SC2119,SC2120,SC2044,SC2035,SC2129,${OPTION_IGNORE} >&3
else
	shellcheck "${OUTPUT}" --shell bash -e SC2274,SC2068,SC2128,SC2086,SC1036,SC1088,SC2153,SC2034,SC2155,SC2207,SC2119,SC2120,SC2044,SC2035,SC2129,${OPTION_IGNORE}
fi

# DELETE TMP_DIR
if [[ $OPTION_TEST != true ]]; then
	log::info "deleting $TMP_DIR"
	rm -rf "$TMP_DIR"
fi

# FINAL
log::ok "$OUTPUT"
___ENDOF___ERROR___TRACE___
return 0
}
# EXECUTE
hbc $@
if [[ $? = 0 && $OPTION_RUN = true ]]; then
	if [[ $OPTION_TEST = true ]]; then
		trap 'trap - EXIT; rm -rf "$TMP_DIR"' EXIT
		bash "$OUTPUT" >&3
		exit $?
	elif [[ $OPTION_QUIET = true ]]; then
		exec ./"$OUTPUT" >&3
	else
		exec ./"$OUTPUT"
	fi
else
	exit 0
fi
