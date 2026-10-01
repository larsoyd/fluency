#!/usr/bin/env bash
# usage: build.sh <out dir>   prints the path of the built daemon
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
out=$1
xml=$(pkg-config --variable=pkgdatadir hyprland-protocols)/protocols/hyprland-lock-notify-v1.xml
[ -f "$xml" ] || { echo "[sessiond] result=fail reason=no_protocol path=$xml" >&2; exit 1; }
mkdir -p "$out" || exit 1
wayland-scanner client-header "$xml" "$out/hyprland-lock-notify-v1-client-protocol.h" || exit 1
wayland-scanner private-code "$xml" "$out/hyprland-lock-notify-v1-protocol.c" || exit 1
timeout 60 "${CC:-cc}" -O2 -c -o "$out/protocol.o" "$out/hyprland-lock-notify-v1-protocol.c" || exit 1
timeout 120 "${CXX:-c++}" -std=c++23 -O2 -Wall -Wextra -Wno-missing-field-initializers -I"$out" -o "$out/fluency-sessiond" \
  "$here/sessiond.cpp" "$out/protocol.o" $(pkg-config --libs wayland-client) >&2 || { echo "[sessiond] result=fail reason=compile" >&2; exit 1; }
echo "$out/fluency-sessiond"
