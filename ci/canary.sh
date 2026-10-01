#!/usr/bin/env bash
# usage: canary.sh <fluency checkout>   inside the dev shell of hyprland main
set -uo pipefail

src=$(realpath "${1:?fluency checkout}")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fails=0
step() { echo "[canary] stage=$1 result=$2 ${3:-}"; [ "$2" = ok ] || fails=$((fails + 1)); }

version=$(timeout 10 Hyprland --version 2>&1 | head -1)
step version "$([ -n "$version" ] && echo ok || echo fail)" "hyprland=\"$version\" headers=$(pkg-config --modversion hyprland 2>&1)"

for dir in "$src"/plugins/*/; do
  name=$(basename "$dir")
  if timeout 300 cmake -S "$dir" -B "$work/$name" -DCMAKE_BUILD_TYPE=Release > "$work/$name.log" 2>&1 \
    && timeout 900 cmake --build "$work/$name" -j"$(nproc)" >> "$work/$name.log" 2>&1; then
    step "plugin_$name" ok
  else
    grep -E 'error:|Error' "$work/$name.log" | head -15
    step "plugin_$name" fail
  fi
done

mkdir -p "$work/cfg"
cp -r "$src/hypr/fluency" "$work/cfg/fluency"
echo 'require("fluency")' > "$work/cfg/hyprland.lua"
if out=$(timeout 30 Hyprland --verify-config -c "$work/cfg/hyprland.lua" 2>&1); then step verify ok
else echo "$out" | tail -15; step verify fail; fi

echo "[canary] done fails=$fails"
[ $fails = 0 ]
