#!/usr/bin/env bash
# usage: fluency-plugins.sh abi|build <dest>|load [--no-wait] <lib>
# load rebuilds first when hyprland changed
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
usage='fluency-plugins.sh abi|build <dest>|load [--no-wait] <lib>'
title="Updating plugins"
toasts=0 note_id="" tmp="" wait=1

say() { echo "[plugins] $*"; }
refuse() { say "refused: $1"; exit "${2:-1}"; }

# the string a plugin built on these headers compares with the running hyprland
header_abi() {
  local prefix key value
  local -A v=()
  prefix=$(pkg-config --variable=prefix hyprland 2>/dev/null) || return 1
  [ -f "$prefix/hyprland/src/version.h" ] || return 1
  while read -r key value; do v[$key]=$value; done < <(sed -nE 's/^#define ([A-Z_]+) +"([^"]*)".*/\1 \2/p' "$prefix/hyprland/src/version.h")
  for key in GIT_COMMIT_HASH AQUAMARINE_VERSION HYPRUTILS_VERSION HYPRGRAPHICS_VERSION HYPRCURSOR_VERSION HYPRLANG_VERSION; do
    [ -n "${v[$key]:-}" ] || return 1
  done
  echo "${v[GIT_COMMIT_HASH]}_aq_${v[AQUAMARINE_VERSION]%.*}_hu_${v[HYPRUTILS_VERSION]%.*}_hg_${v[HYPRGRAPHICS_VERSION]%.*}_hc_${v[HYPRCURSOR_VERSION]%.*}_hlg_${v[HYPRLANG_VERSION]%.*}"
}

# a toast to a name nobody owns could start another daemon, and at login the shell may not be up yet
owner() {
  timeout 2 gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
    --method org.freedesktop.DBus.NameHasOwner org.freedesktop.Notifications 2>/dev/null | grep -q true
}

# the notification of this run, every call after the first replaces it
notify() {
  command -v notify-send >/dev/null && owner || return 0
  local args=(-a Fluency -i "$1")
  shift
  [ -n "$note_id" ] && args+=(-r "$note_id")
  timeout "${wait_for:-5}" notify-send "${args[@]}" "$@"
}

progress() {
  [ $toasts = 1 ] || return 0
  local args=(-t 0 -h "int:value:$1" -h "string:x-fluency-status:Building $(label "$3")" -h "string:x-fluency-value:$2 of $total")
  local body="Hyprland was updated, so Fluency is rebuilding title bars and minimize for it."
  if [ -z "$note_id" ]; then note_id=$(notify system-software-update -p "${args[@]}" "$title" "$body")
  else notify system-software-update "${args[@]}" "$title" "$body" > /dev/null; fi
}

label() { case $1 in titlebar) echo "title bars" ;; *) echo "$1" ;; esac; }

build() {
  local dest=$1 abi dir name step=0 status start
  [ -d "$dest" ] || refuse "no_dest dir=$dest"
  local log=$dest/build.log dirs=("$here"/*/CMakeLists.txt)
  [ -f "${dirs[0]}" ] || refuse "no_sources dir=$here"
  total=${#dirs[@]}
  : > "$log"
  abi=$(header_abi) || { echo "no_headers: pkg-config finds no hyprland headers" >> "$log"; say "refused: no_headers"; return 1; }
  tmp=$(mktemp -d)
  trap 'rm -rf "${tmp:?}"' EXIT
  for dir in "${dirs[@]%/CMakeLists.txt}"; do
    name=$(basename "$dir") step=$((step + 1)) start=$(date +%s%N)
    say "stage=build name=$name step=$step total=$total"
    progress $(( (step - 1) * 100 / total )) $step "$name"
    if timeout 120 cmake -S "$dir" -B "$tmp/$name" -DCMAKE_BUILD_TYPE=Release >> "$log" 2>&1; then
      timeout 900 cmake --build "$tmp/$name" -j"$(nproc)" 2>&1 | percents $step "$name" "$log"
      status=${PIPESTATUS[0]}
    else
      status=configure
    fi
    [ "$status" = 0 ] || { say "stage=build result=fail name=$name log=$log"; return 1; }
    say "stage=build name=$name result=ok ms=$(( ($(date +%s%N) - start) / 1000000 ))"
  done
  for dir in "${dirs[@]%/CMakeLists.txt}"; do
    for so in "$tmp/$(basename "$dir")"/lib*.so; do
      # a rename keeps the file a running hyprland has mapped intact
      cp "$so" "$dest/.$(basename "$so").new" && mv -f "$dest/.$(basename "$so").new" "$dest/$(basename "$so")" || return 1
    done
  done
  echo "$abi" > "$dest/.abi.new" && mv -f "$dest/.abi.new" "$dest/abi"
  say "stage=build result=ok abi=$abi"
}

# cmake prints its percent per step, the toast shows the share of the whole build
percents() {
  local step=$1 name=$2 log=$3 line last=""
  while IFS= read -r line; do
    echo "$line" >> "$log"
    [[ $line =~ ^\[\ *([0-9]+)%\] ]] || continue
    [ "${BASH_REMATCH[1]}" = "$last" ] && continue
    last=${BASH_REMATCH[1]}
    progress $(( ((step - 1) * 100 + last) / total )) "$step" "$name"
  done
}

failed() {
  local choice
  for _ in $(seq 50); do owner && break; sleep 0.2; done
  owner || { say "toast=skipped reason=no_notification_server"; exit 1; }
  # the installer runs this too and cannot wait for an answer
  if [ $wait = 0 ]; then
    notify dialog-error -u critical "Couldn't update title bars" "Windows still work, but without title bars and minimize. The log is $lib/build.log." > /dev/null
    exit 1
  fi
  choice=$(wait_for=3600 notify dialog-error -u critical -A "retry=Try again" -A "details=Show details" -w \
    "Couldn't update title bars" "Windows still work, but without title bars and minimize. Show details tells what went wrong.")
  case $choice in
    retry) rm -rf "${tmp:-/nonexistent}"; exec bash "$here/fluency-plugins.sh" load "$lib" ;;
    details) timeout 10 xdg-open "$lib/build.log" ;;
  esac
  exit 1
}

load() {
  lib=$1
  [ -d "$lib" ] || refuse "no_lib dir=$lib"
  # a shared dir is only used under a name of this user, made by this user
  local lock=${XDG_RUNTIME_DIR:-}/fluency-plugins.lock
  if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
    lock=${TMPDIR:-/tmp}/fluency-plugins-$(id -u).lock
    [ ! -e "$lock" ] || [ -O "$lock" ] || refuse "foreign_lock path=$lock"
  fi
  exec 9> "$lock"
  flock -n 9 || refuse busy
  local json running version built headers so name loaded sum fails=0
  json=$(timeout 5 hyprctl version -j 2>/dev/null)
  running=$(sed -nE 's/.*"abiHash": *"([^"]*)".*/\1/p' <<< "$json")
  version=$(sed -nE 's/.*"version": *"([^"]*)".*/\1/p' <<< "$json")
  [ -n "$running" ] || refuse no_hyprland
  built=$(cat "$lib/abi" 2>/dev/null)
  if [ "$built" = "$running" ]; then
    say "stage=check result=current abi=$running"
  else
    say "stage=check result=stale abi=$running built=${built:-none}"
    if ! headers=$(header_abi); then
      echo "no_headers: pkg-config finds no hyprland headers" > "$lib/build.log"
      say "refused: no_headers"
      failed
    fi
    if [ "$headers" != "$running" ]; then
      notify system-software-update "Sign out to finish updating" \
        "Hyprland changed while you were signed in. Title bars and minimize come back when you sign in again." > /dev/null
      refuse "headers_differ running=$running headers=$headers"
    fi
    toasts=1
    build "$lib" || failed
  fi
  loaded=$(timeout 5 hyprctl plugin list -j 2>/dev/null)
  for so in "$lib"/lib*.so; do
    name=$(basename "$so" .so) name=${name#lib}
    sum=$(sha256sum < "$so" | cut -c1-64)
    if grep -q "\"name\": *\"$name\"" <<< "$loaded"; then
      # the build hyprland holds is the one this file was when it loaded, a reinstall swaps it
      if [ "$(cat "$lib/.loaded-$name" 2>/dev/null)" = "$sum" ]; then say "stage=load name=$name result=already"; continue; fi
      [ "$(timeout 10 hyprctl plugin unload "$so" 2>&1)" = ok ] || { say "stage=unload name=$name result=fail"; fails=$((fails + 1)); continue; }
      say "stage=unload name=$name result=ok reason=new_build"
    fi
    if [ "$(timeout 10 hyprctl plugin load "$so" 2>&1)" = ok ]; then say "stage=load name=$name result=ok"; echo "$sum" > "$lib/.loaded-$name"
    else say "stage=load name=$name result=fail"; fails=$((fails + 1)); fi
  done
  [ $fails = 0 ] || failed
  [ $toasts = 1 ] && notify system-software-update "Title bars are back" "Fluency is ready for Hyprland $version." > /dev/null
  say "done result=ok"
}

case ${1:-} in
  abi) [ $# = 1 ] || refuse "bad_args usage=\"$usage\"" 2; header_abi || refuse no_headers ;;
  build) [ $# = 2 ] || refuse "bad_args usage=\"$usage\"" 2; build "$2" ;;
  load)
    [ "${2:-}" = --no-wait ] && { wait=0; set -- "$1" "${@:3}"; }
    [ $# = 2 ] || refuse "bad_args usage=\"$usage\"" 2
    load "$2" ;;
  *) refuse "bad_args usage=\"$usage\"" 2 ;;
esac
