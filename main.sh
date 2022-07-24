#include <stdlib/ask.sh>
#include <stdlib/log.sh>
#include <stdlib/trace.sh>
#include <stdlib/debug.sh>
#include <stdlib/readonly.sh>

hbc() {
#-------------------------------------------------------------------------------- HBC OPTIONS
___BEGIN___ERROR___TRACE___
debug
# HELP OPTION
if [[ $* = *"-h"* || $* = *"--help"* ]]; then
printf "${BWHITE}%s${OFF}%s${BPURPLE}%s${BYELLOW}%s\n\n" "USAGE: " "hbc " "--OPTION " "<ARGUMENT>"
printf "${BPURPLE}%s${OFF}%s${BPURPLE}%s${BYELLOW}%s${OFF}%s\n" \
"    -a" " |" " --add" "     <text file>" "          add a text file (like a license) on top of output, default: [LICENSE]" \
"    -c" " |" " --config" "  <hbc config file>" "    specify hbc config to use, default: [\$PWD/hbc.conf] or [/etc/hbc.conf]"
printf "${BPURPLE}%s${OFF}%s${BPURPLE}%s${OFF}%s\n" \
"    -d" " |" " --delete" "                       overwrite output file if it already exists"
printf "${BPURPLE}%s${OFF}%s${BPURPLE}%s${BYELLOW}%s${OFF}%s\n" \
"    -i" " |" " --ignore" "  <codes> or <ALL>" "     ignore shellcheck codes or disable shellcheck: [-i SC2154,SC2155] or [-i ALL]" \
"    -l" " |" " --library" " <library directory>" "  specify where to look for lib code, default: [/usr/local/include]" \
"    -m" " |" " --main" "    <main script name>" "   specify main script name, default: [main.sh]"
printf "${BPURPLE}%s${OFF}%s${BPURPLE}%s${OFF}%s\n" \
"    -h" " |" " --help" "                         print this help message and exit unsuccessfully"
printf "${BPURPLE}%s${OFF}%s${BPURPLE}%s${BYELLOW}%s${OFF}%s\n" \
"    -o" " |" " --output" "  <output name>" "        specify output filename, default: [\$FOLDER_NAME.sh]"
printf "${BPURPLE}%s${OFF}%s${BPURPLE}%s${OFF}%s\n" \
"    -q" " |" " --quiet" "                        suppress hbc compile-time output (exit codes stay)" \
"    -r" " |" " --run" "                          run output file if hbc successfully compiles"
printf "${BPURPLE}%s${OFF}%s${BPURPLE}%s${BYELLOW}%s${OFF}%s\n" \
"    -s" " |" " --source" "  <source directory>" "   specify where to look for src code, default: [src]"
printf "${BPURPLE}%s${OFF}%s${BPURPLE}%s${OFF}%s\n" \
"    -t" " |" " --test" "                         --run & --quiet the output from memory, no file made" \
"    -v" " |" " --version" "                      print this hbc's time of compile and exit unsuccessfully"
printf "${OFF}%s\n" \
	"" \
	"hbc - hinto's bash compiler" \
	"Full documentation <https://github.com/hinto-janaiyo/hbc>" \
	"Copyright (c) 2022 hinto-janaiyo <https://github.com/hinto-janaiyo>"
exit 2
# VERSION OPTION
elif [[ $* = *"-v"* || $* = *"--version"* ]]; then
	___TEMPORARY___LINE___MEANT___FOR___REPLACEMENT___
	exit 3
fi

# UNSET ENVIRONMENT
unset -v ADD OPTIONS CONFIG LICENSE DELETE IGNORE LIBRARY MAIN OUTPUT QUIET RUN SOURCE TEST

# PARSE CONFIG FILE (because directly sourcing is spooky)
hbc_parse_config() {
	local i IFS=$'\n' OPTIONS || return 1
	mapfile OPTIONS < $1 || return 2
	for i in ${OPTIONS[@]}; do
	    [[ $i =~ ^ADD=[[:alnum:]./_-]*$ ]]                   && declare -g LICENSE="${i/*=/}"
	    [[ $i =~ ^DELETE=true[[:space:]]*$ ]]                && declare -g DELETE="true"
		[[ $i =~ ^IGNORE=SC.*$ ]]                            && declare -g IGNORE=${i/*=/}
		[[ $i =~ ^LIBRARY=[[:alnum:]./_-]*$ ]]               && declare -g LIBRARY="${i/*=/}"
		[[ $i =~ ^MAIN=[[:alnum:]./_-]*$ ]]                  && declare -g MAIN="${i/*=/}"
		[[ $i =~ ^OUTPUT=[[:alnum:]./_-]*$ ]]                && declare -g OUTPUT="${i/*=/}"
	    [[ $i =~ ^QUIET=true[[:space:]]*$ ]]                 && declare -g QUIET="true"
	    [[ $i =~ ^RUN=true[[:space:]]*$ ]]                   && declare -g RUN="true"
		[[ $i =~ ^SOURCE=[[:alnum:]./_-]*$ ]]                && declare -g SOURCE="${i/*=/}"
	    [[ $i =~ ^TEST=true[[:space:]]*$ ]]                  && declare -g TEST="true"
	    [[ $i =~ ^STD_LOG_DEBUG=true[[:space:]]*$ ]]         && declare -g STD_LOG_DEBUG="true"
	    [[ $i =~ ^STD_LOG_DEBUG_VERBOSE=true[[:space:]]*$ ]] && declare -g STD_LOG_DEBUG_VERBOSE="true"
	done
	log::debug "=== hbc_parse_config ==="
	log::debug "ADD     | $LICENSE"
	log::debug "CONFIG  | $CONFIG"
	log::debug "DELETE  | $DELETE"
	log::debug "IGNORE  | $IGNORE"
	log::debug "LIBRARY | $LIBRARY"
	log::debug "MAIN    | $MAIN"
	log::debug "OUTPUT  | $OUTPUT"
	log::debug "QUIET   | $QUIET"
	log::debug "RUN     | $RUN"
	log::debug "SOURCE  | $SOURCE"
	log::debug "TEST    | $TEST"
	return 0
}

# SOURCE CONFIG BEFORE OPTIONS
local i CONFIG_FLAG_SET
for i in $@ " "; do
	if [[ $i = "-c" || $i = "--config" ]]; then
		CONFIG_FLAG_SET=true
	elif [[ $CONFIG_FLAG_SET ]]; then
		local CONFIG="$i"
		if [[ -z $CONFIG || $CONFIG = " " ]]; then
			log::fail "hbc: no arg after --config"
			exit 1
		fi
		if hbc_parse_config "$CONFIG"; then
			break
		else
			log::fail "config: $CONFIG"
			exit 1
		fi
	fi
done

# IF NO --CONFIG, HBC DEFAULT CONFIG
if [[ -r "$PWD/hbc.conf" && -z $CONFIG_FLAG_SET ]]; then
	local CONFIG="$PWD/hbc.conf"
	if ! hbc_parse_config "$CONFIG"; then
		log::warn "config: $CONFIG fail"
	fi
elif [[ -r /etc/hbc.conf && -z $CONFIG_FLAG_SET ]]; then
	local CONFIG="/etc/hbc.conf"
	if ! hbc_parse_config "$CONFIG"; then
		log::warn "config: $CONFIG fail"
	fi
fi

# PARSE ARGS
while [[ $# != 0 ]]; do
# SHORT+LONG OPTIONS (overwrites config)
case $1 in
	-a | --add)
		shift
		if [[ -z $1 ]]; then
			log::fail "hbc: no arg after --add"
			exit 1
		fi
		LICENSE="$1"; shift;;
	-c | --config) shift; shift;;
	-d | --delete) local DELETE=true; shift;;
	-i | --ignore)
		shift
		if [[ -z $1 ]]; then
			log::fail "hbc: no arg after --ignore"
			exit 1
		fi
		local IGNORE="${IGNORE},$1"; shift;;
	-l | --library)
		shift
		if [[ -z $1 ]]; then
			log::fail "hbc: no arg after --library"
			exit 1
		fi
		local LIBRARY="$1"; shift;;
	-m | --main)
		shift
		if [[ -z $1 ]]; then
			log::fail "hbc: no arg after --main"
			exit 1
		fi
		local MAIN="$1"; shift;;
	-o | --output)
		shift
		if [[ -z $1 ]]; then
			log::fail "hbc: no arg after --output"
			exit 1
		fi
		OUTPUT="$1"; shift;;
	-q | --quiet) QUIET=true; shift;;
	-r | --run) RUN=true; shift;;
	-s | --source)
		shift
		if [[ -z $1 ]]; then
			log::fail "hbc: no arg after --source"
			exit 1
		fi
		SOURCE="$1"; shift;;
	-t | --test) TEST=true; shift;;
	*) log::fail "hbc: invalid option: $1"; exit 1;;
esac
done
# to make the config test work
[[ $TEST = true ]] && RUN=true QUIET=true
___ENDOF___ERROR___TRACE___

#-------------------------------------------------------------------------------- SANITY CHECKS
# CONFIG
[[ $CONFIG && -z $QUIET ]] && log::info "config: $CONFIG"

# LICENSE
[[ -z $LICENSE ]] && local LICENSE="LICENSE"
if [[ -r $LICENSE ]]; then
	[[ -z $QUIET ]] && log::info "add: $LICENSE"
else
	log::warn "add: $LICENSE not found"
	unset -v LICENSE
fi

# SRC DIR
[[ -z $SOURCE ]] && local SOURCE="src"
if [[ ! -d $SOURCE ]]; then
	log::warn "src: $SOURCE not found"
else
	[[ -z $QUIET ]] && log::info "src: $SOURCE"
fi

# MAIN SCRIPT
[[ -z $MAIN ]] && local MAIN="main.sh"
if [[ ! -r $MAIN ]]; then
	log::fail "main: $MAIN not found"
	exit 1
else
	[[ -z $QUIET ]] && log::info "main: $MAIN"
fi

# BOTH LIB/SRC NOT FOUND
local EXISTS_LIB=true
local SRC_FILES
local SRC_FILE_NAMES
SRC_FILES=$(find $SOURCE -regex ".*\.sh\|.*\.bash" 2>/dev/null | sort)
if ! grep -m1 "^#include <.*>$" "$MAIN" &>/dev/null; then
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
case $DIRECTORY_NAME in
	*lib|*lib.sh|lib*|*Lib|*Lib.sh|Lib*|*LIB|*LIB.sh|LIB*)
		DIRECTORY_IS_LIB=true
		;;
esac

# IF MAIN/OUT ARE WEIRD CHARACTERS
if [[ $MAIN != [A-Za-z0-9_/~$]* ]]; then
	log::fail "hbc: \$MAIN contains weird characters; only [A-Za-z0-9_/~$] is supported"
	exit 1
elif [[ $OUTPUT != [A-Za-z0-9_/]* ]]; then
	log::fail "hbc: \$OUTPUT contains weird characters; only [A-Za-z0-9_/~$] is supported"
	exit 1
fi

# DEBUG OPTION PRINTS
log::debug "=== post --option debug ==="
log::debug "ADD     | $LICENSE"
log::debug "CONFIG  | $CONFIG"
log::debug "DELETE  | $DELETE"
log::debug "IGNORE  | $IGNORE"
log::debug "LIBRARY | $LIBRARY"
log::debug "MAIN    | $MAIN"
log::debug "OUTPUT  | $OUTPUT"
log::debug "QUIET   | $QUIET"
log::debug "RUN     | $RUN"
log::debug "SOURCE  | $SOURCE"
log::debug "TEST    | $TEST"
if [[ $DIRECTORY_IS_LIB = true ]]; then
	log::warn "library detected, not adding safety headers!"
fi

# OUT ALREADY EXISTS WARNING
if [[ -e $OUTPUT && $DELETE != true && $TEST != true ]]; then
	log::warn "$OUTPUT already exists"
	printf "%s" "         overwrite? (y/N) "
	ask::no && exit 2
fi

# QUIET OPTION
[[ $QUIET = true ]] && exec 3>&1 &>/dev/null

#-------------------------------------------------------------------------------- VARIABLE INIT
___BEGIN___ERROR___TRACE___

# HEADERS
local HEADER_SAFETY="#-------------------------------------------------------------------------------- BEGIN SAFETY"
local HEADER_LIB="#-------------------------------------------------------------------------------- BEGIN LIB"
local HEADER_SRC="#-------------------------------------------------------------------------------- BEGIN SRC"
local HEADER_MAIN="#-------------------------------------------------------------------------------- BEGIN MAIN"
local ENDOF_MAIN="#-------------------------------------------------------------------------------- ENDOF MAIN"

# GIT HASH
local DIRECTORY_GIT
DIRECTORY_GIT=$(git rev-parse --short HEAD 2>/dev/null) || unset DIRECTORY_GIT

# HBC VERSION
local VERSION_HBC
VERSION_HBC=$(grep -m1 "^#git <hbc/.*>$" "$0" | grep -o "\/.*>" | tr -d '/>')

# LIB/SRC/MAIN
local LIB_GIT
[[ -z $LIBRARY ]] && LIBRARY="/usr/local/include"
#local SRC_FILES # this gets defined in the beginning sanity check

# MKTEMP
declare -g TMP_DIR
local TMP_HEADER
local TMP_SAFETY
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
TMP_SAFETY="$(mktemp "$TMP_DIR"/safety.XXXXXXXXX)"
TMP_LIB="$(mktemp "$TMP_DIR"/lib.XXXXXXX)"
TMP_SRC="$(mktemp "$TMP_DIR"/src.XXXXXXX)"
TMP_SCRATCH="$(mktemp "$TMP_DIR"/scratch.XXXXXXXXXX)"
# TEST OUTPUT
if [[ $TEST = true ]]; then
	local TMP_TEST
	TMP_TEST="$(mktemp "$TMP_DIR"/test.XXXXXXXXXX)"
	OUTPUT="$TMP_TEST"
fi

# SAFETY HEADERS
# safety
local SAFETY_HEADER
SAFETY_HEADER=$(cat << 'EOM'
POSIXLY_CORRECT= || exit 90
	# bash builtins
\unset -f alias bg bind break builtin caller cd command compgen complete compopt continue declare dirs disown echo enable eval exec exit export false fc fg getopts hash help history jobs kill let local logout mapfile popd printf pushd pwd read readarray readonly return set shift shopt source suspend test times trap true type typeset ulimit umask unalias unset wait || exit 91
	# gnu core-utils
\unset -f arch base64 basename cat chcon chgrp chmod chown chroot cksum comm cp csplit cut date dd df dir dircolors dirname du echo env expand expr factor false fmt fold groups head hostid hostname id install join kill link ln logname ls md5sum mkdir mkfifo mknod mktemp mv nice nl nohup nproc numfmt od paste pathchk pinky pr printenv printf ptx pwd readlink realpath rm rmdir runcon seq shred shuf sleep sort split stat stdbuf stty sum tac tail tee test timeout touch tr true truncate tsort tty uname unexpand uniq unlink uptime users vdir wc who whoami yes || exit 92
\unalias -a || exit 93
unset POSIXLY_CORRECT || exit 94
set -eo pipefail || exit 95
EOM
)
# lib
SAFETY_LIB=$(cat << 'EOM'
trap 'printf "%s\n" "@@@@@@ LIB PANIC @@@@@@" "[line] ${LINENO}" "[file] $0" "[code] $?";set +eo pipefail;trap - ERR;while :;do read;done;exit 112' ERR || exit 112
EOM
)
# src
local SAFETY_SRC
SAFETY_SRC=$(cat << 'EOM'
trap 'printf "%s\n" "@@@@@@ SRC PANIC @@@@@@" "[line] ${LINENO}" "[file] $0" "[code] $?";set +eo pipefail;trap - ERR;while :;do read;done;exit 115' ERR || exit 115
EOM
)
# safety end
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

# LICENSE
if [[ $LICENSE ]]; then
	log::tab "add: $LICENSE"
	echo "#" >> "$TMP_HEADER"
	cat "$LICENSE" >> "$TMP_HEADER"
	echo  >> "$TMP_HEADER"
fi

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

#-------------------------------------------------------------------------------- SAFETY
# ONLY CREATE SAFETY IF NOT CREATING LIBRARY CODE
if [[ $DIRECTORY_IS_LIB != true ]]; then
	printf "${BRED}%s${OFF}\n" "creating [safety] ****************"
	log::tab "<safety>"
	echo "$SAFETY_HEADER" >> "$TMP_SAFETY"
fi

#-------------------------------------------------------------------------------- LIB
# LIB LOOP
if [[ $EXISTS_LIB = true && $DIRECTORY_IS_LIB != true ]]; then
	printf "${BPURPLE}%s${OFF}\n" "compiling [lib] ******************"
	local i
	# include each found #include in TMP_LIB
	for i in $(grep "^#include <.*>$" "$MAIN" | cut -d ' ' -f2 | tr -d '<>' | sort); do
		if [[ $i = *.bash || $i = *.sh && -f "${LIBRARY}/${i}" ]]; then
			sed "/^#\|^[[:space:]]#/d" "$LIBRARY/$i" >> "$TMP_LIB"
			# if #git is found in the lib file, attach to TMP_HEADER
			if LIB_GIT=$(grep -m1 "^#git <.*>$" "$LIBRARY/$i" | cut -d ' ' -f2); then
				log::tab "$LIB_GIT"
				echo "#lib $LIB_GIT" >> "$TMP_HEADER"
			else
				log::warn "<lib missing #git>"
				echo "#lib <UNKNOWN>" >> "$TMP_HEADER"
			fi
		else
			log::fail "${LIBRARY}/${i} not *.sh || ${LIBRARY}/${i} not found"
			exit 1
		fi
	done
fi

#-------------------------------------------------------------------------------- SRC
# SRC LOOP
if [[ $SRC_FILES ]]; then
	printf "${BCYAN}%s${OFF}\n" "compiling [src] ******************"
	for i in $SRC_FILES; do
		log::tab "<${i/src\//}>"
		sed "/^#\|^[[:space:]]#/d" "$i" >> "$TMP_SRC"
		echo "#src <${i/src\//}>" >> "$TMP_HEADER"
	done
fi

#-------------------------------------------------------------------------------- CLEANING
printf "${BYELLOW}%s${OFF}\n" "cleaning *************************"

# SCRATCH (ref for grep to remove lines)
log::tab "creating scratch"
echo "$SAFETY_HEADER" > "$TMP_SCRATCH"
echo "$SAFETY_LIB" >> "$TMP_SCRATCH"
echo "$SAFETY_SRC" >> "$TMP_SCRATCH"
echo "$SAFETY_END" >> "$TMP_SCRATCH"

# LIB
if [[ $EXISTS_LIB = true ]]; then
	local LINES_LIB
	LINES_LIB[0]=$(wc -l "$TMP_LIB" | cut -d ' ' -f1)
	sed -i -e '/#!\/usr\/bin\/env bash$/d' \
		-i -e '/#!\/usr\/bin\/bash$/d' \
		-i -e '/#!\/bin\/bash$/d' \
		-i -e '/^$/d' \
		-i -e '/^#/d' \
		-i -e '/^[[:space:]]*#/d' "$TMP_LIB"
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
		-i -e '/^$/d' "$TMP_SRC" \
		-i -e '/^#/d' \
		-i -e '/^[[:space:]]*#/d' "$TMP_LIB"
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
log::tab "[header] ---------> line $(wc -l "$OUTPUT" | cut -f1 -d ' ')"
cat "$TMP_HEADER" > "$OUTPUT"

# SAFETY
if [[ $DIRECTORY_IS_LIB != true ]]; then
	echo >> "$OUTPUT"
	log::tab "[safety::header] -> line $(($(wc -l "$OUTPUT" | cut -f1 -d ' ')+1))"
	echo "$HEADER_SAFETY" >> "$OUTPUT"
	log::tab "[safety] ---------> line $(($(wc -l "$OUTPUT" | cut -f1 -d ' ')+1))"
	cat "$TMP_SAFETY" >> "$OUTPUT"
fi

# LIB
if [[ $EXISTS_LIB = true && $DIRECTORY_IS_LIB != true ]]; then
	echo >> "$OUTPUT"
	log::tab "[lib::header] ----> line $(($(wc -l "$OUTPUT" | cut -f1 -d ' ')+1))"
	echo "$HEADER_LIB" >> "$OUTPUT"
	log::tab "[lib::safety] ----> line $(($(wc -l "$OUTPUT" | cut -f1 -d ' ')+1))"
	echo "$SAFETY_LIB" >> "$OUTPUT"
	log::tab "[lib] ------------> line $(($(wc -l "$OUTPUT" | cut -f1 -d ' ')+1))"
	cat "$TMP_LIB" >> "$OUTPUT"
	# DECLARE -FR
	log::tab "[lib::declare] ---> line $(($(wc -l "$OUTPUT" | cut -f1 -d ' ')+1))"
	local FUNCTIONS_LIB
	if FUNCTIONS_LIB=($(grep -ho "^[0-9A-Za-z.:_-]\+(){\|^[0-9A-Za-z.:_-]\+()[[:blank:]]\+{" "$TMP_LIB" | tr -d '(){ ')); then
		if [[ -z ${FUNCTIONS_LIB[0]} ]]; then
			log::fail "no functions found"
			exit 3
		fi
		local d
		for d in ${FUNCTIONS_LIB[@]}; do
			echo "declare -frg $d" >> "$OUTPUT"
		done
	fi
fi

# SRC
if [[ $SRC_FILES ]]; then
	echo >> "$OUTPUT"
	log::tab "[src::header] ----> line $(($(wc -l "$OUTPUT" | cut -f1 -d ' ')+1))"
	echo "$HEADER_SRC" >> "$OUTPUT"
	if [[ $DIRECTORY_IS_LIB != true ]]; then
		log::tab "[src::safety] ----> line $(($(wc -l "$OUTPUT" | cut -f1 -d ' ')+1))"
		echo "$SAFETY_SRC" >> "$OUTPUT"
	fi
	log::tab "[src] ------------> line $(($(wc -l "$OUTPUT" | cut -f1 -d ' ')+1))"
	cat "$TMP_SRC" >> "$OUTPUT"
	# DECLARE -FR
	if [[ $DIRECTORY_IS_LIB != true ]]; then
		log::tab "[src::declare] ---> line $(($(wc -l "$OUTPUT" | cut -f1 -d ' ')+1))"
		local FUNCTIONS_SRC
		if FUNCTIONS_SRC=($(grep -ho "^[0-9A-Za-z.:_-]\+(){\|^[0-9A-Za-z.:_-]\+()[[:blank:]]\+{" "$TMP_SRC" | tr -d '(){ ')); then
			if [[ -z ${FUNCTIONS_SRC[0]} ]]; then
				log::fail "no functions found"
				exit 3
			fi
			local d
			for d in ${FUNCTIONS_SRC[@]}; do
				echo "declare -frg $d" >> "$OUTPUT"
			done
		fi
	fi
fi

# SAFETY END
if [[ $DIRECTORY_IS_LIB != true ]]; then
	log::tab "[safety::end] ----> line $(($(wc -l "$OUTPUT" | cut -f1 -d ' ')+1))"
	echo "$SAFETY_END" >> "$OUTPUT"
fi

# MAIN
local EXISTS_MAIN
EXISTS_MAIN=$(sed -e "/^#include <.*>$/d" -e '/./,$!d' "$MAIN")
if [[ $EXISTS_MAIN ]]; then
	echo >> "$OUTPUT"
	log::tab "[main::header] ---> line $(($(wc -l "$OUTPUT" | cut -f1 -d ' ')+1))"
	echo "$HEADER_MAIN" >> "$OUTPUT"
	log::tab "[main] -----------> line $(($(wc -l "$OUTPUT" | cut -f1 -d ' ')+1))"
	echo "$EXISTS_MAIN" >> "$OUTPUT"
	log::tab "[main::endof] ----> line $(($(wc -l "$OUTPUT" | cut -f1 -d ' ')+1))"
	echo "$ENDOF_MAIN" >> "$OUTPUT"

	# HBC INLINE VERSION/DATE REPLACEMENT
	if [[ $DIRECTORY_NAME = hbc ]]; then
		local VERSION_LINE
		VERSION_LINE="$(printf "%s\n" "$(date -d @$EPOCHSECONDS "+%Y %B %d") - $(git rev-parse HEAD 2>/dev/null)")"
		VERSION_LINE='printf "%s\\n" '\""$VERSION_LINE"\"''
		# only replace first instace
		sed -i '0,/___TEMPORARY___LINE___MEANT___FOR___REPLACEMENT___/s//'"$VERSION_LINE"'/' $OUTPUT
		log::tab "hbc version replacement"
	fi
fi

# END STATS (WC)
log::tab "[${OUTPUT}] total lines: $(wc -l "$OUTPUT" | cut -f1 -d ' ')"

#-------------------------------------------------------------------------------- END
# CHMOD PERMISSIONS
log::info "700 permissions"
chmod 700 "${OUTPUT}"

# SHELLCHECK
if [[ $IGNORE = *ALL* || $IGNORE = *all* ]]; then
	log::warn "skipping shellcheck"
else
	log::info "starting shellcheck"
	if [[ $QUIET = true ]]; then
		if [[ $IGNORE ]]; then
			shellcheck "${OUTPUT}" --shell bash -e "$IGNORE" >&3
		else
			shellcheck "${OUTPUT}" --shell bash >&3
		fi
	else
		if [[ $IGNORE ]]; then
			shellcheck "${OUTPUT}" --shell bash -e "$IGNORE"
		else
			shellcheck "${OUTPUT}" --shell bash
		fi
	fi
fi

# DELETE TMP_DIR
if [[ $TEST != true ]]; then
	log::info "deleting $TMP_DIR"
	rm -rf "$TMP_DIR"
fi

# FINAL
log::ok "$OUTPUT"
[[ $QUIET = true ]] && exec &>/dev/tty
___ENDOF___ERROR___TRACE___
}
# EXECUTE
hbc $@
if [[ $? = 0 && $RUN = true ]]; then
	if [[ $TEST = true ]]; then
		log::debug "beginning --test"
		trap 'trap - EXIT; rm -rf "$TMP_DIR"' EXIT
		bash "$OUTPUT"
		exit $?
	else
		log::debug "beginning --run"
		exec ./"$OUTPUT"
	fi
fi
log::debug "hbc done"
exit 0

