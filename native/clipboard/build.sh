#!/usr/bin/env bash
# usage: build.sh <out dir>   prints the path of the built daemon
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
out=$1
xml=$(pkg-config --variable=pkgdatadir wayland-protocols)/staging/ext-data-control/ext-data-control-v1.xml
[ -f "$xml" ] || { echo "[clipd] result=fail reason=no_protocol path=$xml" >&2; exit 1; }
mkdir -p "$out" || exit 1
wayland-scanner client-header "$xml" "$out/ext-data-control-v1-client-protocol.h" || exit 1
wayland-scanner private-code "$xml" "$out/ext-data-control-v1-protocol.c" || exit 1
timeout 60 "${CC:-cc}" -O2 -c -o "$out/protocol.o" "$out/ext-data-control-v1-protocol.c" || exit 1
timeout 120 "${CXX:-c++}" -std=c++23 -O2 -Wall -Wextra -Wno-missing-field-initializers -I"$out" -o "$out/fluency-clipd" \
  "$here/clipd.cpp" "$here/store.cpp" "$out/protocol.o" $(pkg-config --libs wayland-client) >&2 || { echo "[clipd] result=fail reason=compile" >&2; exit 1; }
echo "$out/fluency-clipd"
