#include <stdlib/ask.sh>
#include <stdlib/log.sh>
#include <stdlib/trace.sh>
#include <stdlib/var.sh>

hbc(){
# NO SRC FOLDER
if [[ ! -d src ]]; then
	log::warn "no src folder found"
fi

# ERROR INPUT
if [[ $# -gt 1 ]]; then
	log::warn "too many arguments"
	exit 1
elif [[ ! -f main.sh ]]; then
	log::warn "no main.sh file found"
	exit 1
fi

# OUT.SH NAMING
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

# OUT.SH ALREADY EXIST WARNING
if [[ -e ${out} ]]; then
	log::warn "${out} already exists"
	printf "overwrite? (y/N) "
	ask::no && exit 2
fi

# ROOT DIRECTORY DETECTION + OUT.SH
___BEGIN___ERROR___TRACE___
local main=main.sh
log::info "main: $main"
[[ -d src ]] && log::info "src directory detected"
log::info "creating ${out}"
echo "#!/usr/bin/env bash" > "${out}"

# HEADERS
local HEADER_LIB="#-------------------------------------------------------------------------------- BEGIN LIB CODE"
local HEADER_SRC="#-------------------------------------------------------------------------------- BEGIN SRC CODE"
local HEADER_MAIN="#-------------------------------------------------------------------------------- BEGIN MAIN SCRIPT"
local ENDOF_MAIN="#-------------------------------------------------------------------------------- ENDOF MAIN SCRIPT"

# CLEAN OLD HEADERS
#log::info "cleaning older headers"
#sed "/${HEADER_LIB}$/d" "$out"
#sed "/${HEADER_MAIN}$/d" "$out"
#sed "/${HEADER_SRC}$/d" "$out"
#sed "/${ENDOF_MAIN}$/d" "$out"

# LIB SAFETY HEADER
if [[ $DIRECTORY_NAME != stdlib ]]; then
if grep "#include <.*>$" "$main" &>/dev/null; then
echo "$HEADER_LIB" >> "$out"
cat << EOM >> "$out"
set -eo pipefail || exit 111
trap 'printf "%s\n" "@@@@@@ LIB PANIC @@@@@@" "[ \\\$_ ] \${LINENO}: \$BASH_COMMAND" "[file] \$0" "[code] \$?";while :;do read;done;exit 112' ERR || exit 113
EOM
fi
fi

# LIB INCLUDE
for i in $(grep "#include <.*>$" "$main" | awk '{print $2}' | tr -d '<>' | sort); do
#	if [[ -f /usr/local/include/"$i" ]]; then
#		printf "${BPURPLE}%s${OFF}%s\n" "including [${i}]"
#		for f in $(find /usr/local/include/"$i" -name ".*sh" | sort); do
#			printf "         %s\n" "$f"
#			cat "$f" >> "${out}"
#			local LIB_GIT
#			if LIB_GIT=$(grep '#git <.*>$' "$f" | awk '{print $2}'); then
#				sed -i "2i #lib $LIB_GIT" "$out"
#			fi
#		done
	if [[ $i = *.sh && -f /usr/local/include/$i ]]; then
		printf "${BPURPLE}%s${OFF}%s\n" "including [${i}]"
		printf "         %s\n" "$i"
		sed "/^#\|[[:space:]]#/d" "/usr/local/include/$i" >> "${out}"
		local LIB_GIT
		LIB_GIT=$(grep "#git <.*>$" "/usr/local/include/$i" | awk '{print $2}')
		sed -i "2i #lib $LIB_GIT" "$out"
#	elif [[ $i = */*.sh && -f /usr/local/include/$i ]]; then
#		printf "${BPURPLE}%s${OFF}%s\n" "including [${i}]"
#		printf "         %s\n" "$i"
#		cat "/usr/local/include/$i" >> "${out}"
#		local LIB_GIT
#		if LIB_GIT=$(grep '#git <.*>[[:blank:]]*$' "/usr/local/include/$i" | awk '{print $2}'); then
#			echo $LIB_GIT
#			sed -i "2i #lib $LIB_GIT" "$out"
#		fi
	else
		log::fail "$i not found"
		exit 1
	fi
done

# SRC FOLDER
if [[ -d src ]]; then
local SRC_FILES
SRC_FILES=$(find src -name "*.sh" 2>/dev/null)
if [[ $SRC_FILES ]]; then
	printf "${BCYAN}%s${OFF}%s\n" "compiling [src]"

# SRC SAFETY HEADER
if [[ $DIRECTORY_NAME != stdlib ]]; then
echo "$HEADER_SRC" >> "$out"
cat << EOM >> "$out"
set -eo pipefail || exit 114
trap 'printf "%s\n" "@@@@@@ SRC PANIC @@@@@@" "[ \\\$_ ] \${LINENO}: \$BASH_COMMAND" "[file] \$0" "[code] \$?";while :;do read;done;exit 115' ERR || exit 116
EOM
fi
fi

# COMPILE SRC FILES
	SRC_FILES=$(find src -name "*.sh" 2>/dev/null | sort)
	for i in $SRC_FILES; do
		printf "         %s\n" "$i"
		sed "/^#\|[[:space:]]#/d" "$i" >> "${out}"
	done
fi

# CLEANING MAIN.SH
#log::info "cleaning $main"
#sed -i -e '/#!\/usr\/bin\/env bash$/d' \
#	-i -e '/#!\/usr\/bin\/bash$/d' \
#	-i -e '/#!\/bin\/bash$/d' \
#	-i -e '/^$/d' \
#	-i -e '1 i\#!\/usr\/bin\/env bash' "$out"

# CLEANING OUT.SH
log::info "cleaning ${out}"
sed -i -e '/#!\/usr\/bin\/env bash$/d' \
	-i -e '/#!\/usr\/bin\/bash$/d' \
	-i -e '/#!\/bin\/bash$/d' \
	-i -e '/^$/d' "$out"
sed -i '1i \#!\/usr\/bin\/env bash' "$out"

# CLOSING SAFETY HEADER
if [[ $DIRECTORY_NAME != stdlib ]]; then
cat << EOM >> "$out"
trap - ERR || exit 117
set +eo pipefail || exit 118
EOM
fi

# ADDING MAIN.SH TO OUT.SH
if [[ $DIRECTORY_NAME != stdlib ]]; then
	log::info "appending $main"
	echo "$HEADER_MAIN" >> "$out"
	sed "/^#include <.*>$/d" "$main" >> "${out}"
fi

# SPACING HEADERS
if [[ $DIRECTORY_NAME != stdlib ]]; then
	log::info "spacing headers"
	sed -i "s/${HEADER_LIB}$/\n${HEADER_LIB}/g" "$out"
	sed -i "s/${HEADER_SRC}$/\n${HEADER_SRC}/g" "$out"
	sed -i "s/${HEADER_MAIN}$/\n${HEADER_MAIN}/g" "$out"
fi

# ADDING GIT HASH
local DIRECTORY_GIT
DIRECTORY_GIT="$(git rev-parse --short HEAD)"
log::info "git: $DIRECTORY_GIT"
if [[ $DIRECTORY_NAME = hbc ]]; then
	sed -i "2i #git <${DIRECTORY_NAME}\/${DIRECTORY_GIT}>" "$out"
else
	sed -i "2i #git <${DIRECTORY_NAME}.sh\/${DIRECTORY_GIT}>" "$out"
fi

# ADDING HBC VERSION
local HBC_VERSION
HBC_VERSION=$(grep -m1 "#git" "$0" | grep -o "\/.*>" | tr -d '/>')
log::info "hbc: $HBC_VERSION"
sed -i "3i #hbc <${HBC_VERSION}>" "$out"

# ADDING UNIX TIME
log::info "nix: $EPOCHSECONDS"
sed -i "2i #nix <${EPOCHSECONDS}>" "$out"

# ENDOF MAIN SCRIPT
if [[ $DIRECTORY_NAME != stdlib ]]; then
	log::info "ending script"
	echo "$ENDOF_MAIN" >> "$out"
fi

# ADDING FILE HASH
#local FILE_LINE
#local LINE_NUMBER
#while IFS= read -r FILE_LINE; do
#	LINE_NUMBER=$((LINE_NUMBER + 1))
#	[[ ! $FILE_LINE = "#"* ]] && break
#done < "$out"
#sed -i "${LINE_NUMBER}i tmp" "$out"
#local FILE_HASH
#FILE_HASH=$(sed "1,${LINE_NUMBER}d" "$out" | sha1sum | tr -d ' -')
#sed -i "${LINE_NUMBER}s/.*/#sha <sha1\/line${LINE_NUMBER}\/${FILE_HASH}>/" "$out"
#log::info "sha: $FILE_HASH"

# CHMOD PERMISSIONS
log::info "giving execution permission"
chmod 700 "${out}"

# SHELLCHECK
log::info "starting shellcheck"
shellcheck "${out}" --shell bash -e SC2274,SC2068,SC2128,SC2086,SC1036,SC1088,SC2153,SC2034,SC2155,SC2207,SC2119,SC2120,SC2044,SC2035,SC2129

# FINAL
log::ok "hbc done"
___ENDOF___ERROR___TRACE___
}
hbc $@
