#include <stdlib/ask.sh>
#include <stdlib/log.sh>
#include <stdlib/trace.sh>
#include <stdlib/var.sh>

hbc() {
#-------------------------------------------------------------------------------- SANITY CHECKS
# NO SRC DIR
if [[ ! -d src ]]; then
	log::warn "no src directory found"
fi

# MAIN SCRIPT
local main="main.sh"

# BOTH LIB/SRC NOT FOUND
local EXISTS_LIB=true
local SRC_FILES
SRC_FILES=$(find src -name "*.sh" 2>/dev/null | cut -d '/' -f2 | sort)
if ! grep -m1 "^#include <.*>$" "$main" &>/dev/null; then
	EXISTS_LIB=false
	if [[ -z $SRC_FILES ]]; then
		log::fail "both [lib/src] are missing" "no reason to use hbc" "exiting..."
		exit 1
	fi
fi

# ERROR INPUT
if [[ $# -gt 1 ]]; then
	log::warn "args -gt 1"
	exit 1
elif [[ ! -f main.sh ]]; then
	log::warn "no main.sh found"
	exit 1
fi

# $1 OUT.SH NAMING
local DIRECTORY_NAME
DIRECTORY_NAME="$(basename "$PWD")"
local out
if [[ $1 ]]; then
	out="$1"
elif [[ $DIRECTORY_NAME = hbc ]]; then
	out="hbc"
else
	out="${DIRECTORY_NAME}.sh"
fi

# OUT ALREADY EXISTS WARNING
if [[ -e ${out} ]]; then
	log::warn "${out} already exists"
	printf "%s" "         overwrite? (y/N) "
	ask::no && exit 2
fi

#-------------------------------------------------------------------------------- VARIABLE INIT
___BEGIN___ERROR___TRACE___

# HEADERS
local HEADER_LIB="#-------------------------------------------------------------------------------- BEGIN LIB CODE"
local HEADER_SRC="#-------------------------------------------------------------------------------- BEGIN SRC CODE"
local HEADER_MAIN="#-------------------------------------------------------------------------------- BEGIN MAIN SCRIPT"
local ENDOF_MAIN="#-------------------------------------------------------------------------------- ENDOF MAIN SCRIPT"

# GIT HASH
local DIRECTORY_GIT
if DIRECTORY_GIT=$(git rev-parse --short HEAD 2>/dev/null); then
	:
fi

# HBC VERSION
local VERSION_HBC
VERSION_HBC=$(grep -m1 "^#git <hbc/.*>$" "$0" | grep -o "\/.*>" | tr -d '/>')

# LIB/SRC/MAIN
local LIB_GIT
#local SRC_FILES # this gets defined in the beginning sanity check

# MKTEMP
local TMP_DIR
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

# SAFETY HEADERS
local SAFETY_LIB
SAFETY_LIB=$(cat << 'EOM'
set -eo pipefail || exit 111
trap 'printf "%s\n" "@@@@@@ LIB PANIC @@@@@@" "[line] ${LINENO}" "[file] $0" "[code] $?";set +eo pipefail;trap - ERR;while :;do read;done;exit 112' ERR || exit 113
EOM
)
local SAFETY_SRC
SAFETY_SRC=$(cat << 'EOM'
set -eo pipefail || exit 114
trap 'printf "%s\n" "@@@@@@ SRC PANIC @@@@@@" "[line] ${LINENO}" "[file] $0" "[code] $?";set +eo pipefail;trap - ERR;while :;do read;done;exit 115' ERR || exit 116
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
		echo "#git <${out}/${DIRECTORY_GIT}>" >> "$TMP_HEADER"
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
	for i in $(grep "^#include <.*>$" "$main" | cut -d ' ' -f2 | tr -d '<>' | sort); do
		if [[ $i = *.sh && -f /usr/local/include/$i ]]; then
			sed "/^#\|[[:space:]]#/d" "/usr/local/include/$i" >> "$TMP_LIB"
			LIB_GIT=$(grep "^#git <.*>$" "/usr/local/include/$i" | cut -d ' ' -f2)
			log::tab "$LIB_GIT"
			echo "#lib $LIB_GIT" >> "$TMP_HEADER"
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
		log::tab "$i"
		sed "/^#\|[[:space:]]#/d" "src/$i" >> "$TMP_SRC"
		echo "#src <${i}>" >> "$TMP_HEADER"
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
printf "%s" "" > "$out"
log::tab "[header] -------> line $(wc -l "$out" | cut -f1 -d ' ')"
cat "$TMP_HEADER" > "$out"

# LIB
if [[ $EXISTS_LIB = true && $DIRECTORY_NAME != *lib ]]; then
	echo >> "$out"
	log::tab "[lib::header] --> line $(($(wc -l "$out" | cut -f1 -d ' ')+1))"
	echo "$HEADER_LIB" >> "$out"
	log::tab "[lib::safety] --> line $(($(wc -l "$out" | cut -f1 -d ' ')+1))"
	echo "$SAFETY_LIB" >> "$out"
	log::tab "[lib] ----------> line $(($(wc -l "$out" | cut -f1 -d ' ')+1))"
	cat "$TMP_LIB" >> "$out"
	# DECLARE -FR
	log::tab "[lib::declare] -> line $(($(wc -l "$out" | cut -f1 -d ' ')+1))"
	local FUNCTIONS_LIB
	if FUNCTIONS_LIB=($(grep -ho "^[0-9A-Za-z:_-]\+(){\|^[0-9A-Za-z:_-]\+()[[:blank:]]\+{" "$TMP_LIB" | tr -d '(){ ')); then
		if [[ -z ${FUNCTIONS_LIB[0]} ]]; then
			log::fail "no functions found"
			exit 3
		fi
		local d
		for d in ${FUNCTIONS_LIB[@]}; do
			echo "declare -fr $d" >> "$out"
		done
	fi
fi

# SRC
if [[ $SRC_FILES ]]; then
	echo >> "$out"
	log::tab "[src::header] --> line $(($(wc -l "$out" | cut -f1 -d ' ')+1))"
	echo "$HEADER_SRC" >> "$out"
	if [[ $DIRECTORY_NAME != *lib ]]; then
		log::tab "[src::safety] --> line $(($(wc -l "$out" | cut -f1 -d ' ')+1))"
		echo "$SAFETY_SRC" >> "$out"
	fi
	log::tab "[src] ----------> line $(($(wc -l "$out" | cut -f1 -d ' ')+1))"
	cat "$TMP_SRC" >> "$out"
	# DECLARE -FR
	if [[ $DIRECTORY_NAME != *lib ]]; then
		log::tab "[src::declare] -> line $(($(wc -l "$out" | cut -f1 -d ' ')+1))"
		local FUNCTIONS_SRC
		if FUNCTIONS_SRC=($(grep -ho "^[0-9A-Za-z:_-]\+(){\|^[0-9A-Za-z:_-]\+()[[:blank:]]\+{" "$TMP_SRC" | tr -d '(){ ')); then
			if [[ -z ${FUNCTIONS_SRC[0]} ]]; then
				log::fail "no functions found"
				exit 3
			fi
			local d
			for d in ${FUNCTIONS_SRC[@]}; do
				echo "declare -fr $d" >> "$out"
			done
		fi
	fi
fi

# SAFETY END
if [[ $DIRECTORY_NAME != *lib ]]; then
	log::tab "[safety::end] --> line $(($(wc -l "$out" | cut -f1 -d ' ')+1))"
	echo "$SAFETY_END" >> "$out"
fi

# MAIN
local EXISTS_MAIN
EXISTS_MAIN=$(sed -e "/^#include <.*>$/d" -e '/./,$!d' "$main")
if [[ $EXISTS_MAIN ]]; then
	echo >> "$out"
	log::tab "[main::header] -> line $(($(wc -l "$out" | cut -f1 -d ' ')+1))"
	echo "$HEADER_MAIN" >> "$out"
	log::tab "[main] --------> line $(($(wc -l "$out" | cut -f1 -d ' ')+1))"
	echo "$EXISTS_MAIN" >> "$out"
	log::tab "[main::endof] --> line $(($(wc -l "$out" | cut -f1 -d ' ')+1))"
	echo "$ENDOF_MAIN" >> "$out"
fi

# END STATS (WC)
log::tab "[${out}] total lines: $(wc -l "$out" | cut -f1 -d ' ')"

#-------------------------------------------------------------------------------- END
# CHMOD PERMISSIONS
log::info "700 permissions"
chmod 700 "${out}"

# SHELLCHECK
log::info "starting shellcheck"
shellcheck "${out}" --shell bash -e SC2274,SC2068,SC2128,SC2086,SC1036,SC1088,SC2153,SC2034,SC2155,SC2207,SC2119,SC2120,SC2044,SC2035,SC2129

# DELETE TMP_DIR
log::info "deleting $TMP_DIR"
rm -rf "$TMP_DIR"

# FINAL
log::ok "hbc done: $out"
___ENDOF___ERROR___TRACE___
}
hbc $@
