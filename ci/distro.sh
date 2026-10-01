#!/usr/bin/env bash
# usage: distro.sh <distro> <fluency checkout> [out dir]   as root in a throwaway container
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
distro=${1:?distro}
src=$(realpath "${2:?fluency checkout}")
out=${3:-/tmp/ci-out}
def=$here/distros/$distro.sh
home=/home/ci
fails=0

log() { echo "[ci] distro=$distro $*"; }
refuse() { log "result=refused reason=$*"; exit 1; }
step() { log "stage=$1 result=$2 ${3:-}"; [ "$2" = ok ] || fails=$((fails + 1)); }
as_ci() { (cd "$home" && sudo -u ci -H env PATH="$PATH" XDG_RUNTIME_DIR=/run/user/1000 bash -c "$1"); }
tree() { as_ci "find .config/hypr .local/share/fluency .local/lib/fluency .local/share/fonts/fluency -type f ! -name '*.bak-*' 2>/dev/null | sort | xargs -r sha256sum"; }

[ -f "$def" ] || refuse "unknown_distro file=$def"
[ "$(id -u)" = 0 ] || refuse "needs_root uid=$(id -u)"
[ -f "$src/install.sh" ] || refuse "not_a_fluency_checkout src=$src"
# shellcheck source=/dev/null
source "$def"
mkdir -p "$out"

start=$(date +%s)
setup > "$out/setup.log" 2>&1 && step setup ok "secs=$(( $(date +%s) - start ))" || { tail -20 "$out/setup.log"; step setup fail; exit 1; }

useradd -m -u 1000 ci && install -d -m 700 -o 1000 /run/user/1000 && echo 'ci ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/ci && chmod 440 /etc/sudoers.d/ci
git config --system --add safe.directory '*'
cp -a "$src" "$home/fluency"
chown -R ci: "$home"

as_ci "cd fluency && timeout 2400 ./install.sh --deps --no-recommended < /dev/null" > "$out/install.log" 2>&1
as_ci "timeout 10 Hyprland --version 2>&1 | head -1; timeout 10 qs --version 2>&1 | head -1" > "$out/probe.log" 2>&1
log "stage=probe $(tr '\n' ' ' < "$out/probe.log" | cut -c1-200)"
if grep -qx '\[install\] result=ok' "$out/install.log"; then step install ok
else tail -20 "$out/install.log"; step install fail; log "done fails=$fails"; exit 1; fi

as_ci "timeout 30 Hyprland --verify-config -c ~/.config/hypr/hyprland.lua" > "$out/verify.log" 2>&1 && step verify ok || { tail -10 "$out/verify.log"; step verify fail; }
plugins=$(as_ci "ls .local/lib/fluency/*.so 2>/dev/null | wc -l")
[ "$plugins" = 2 ] && step plugins ok "built=$plugins" || step plugins fail "built=$plugins"

before=$(tree)
as_ci "cd fluency && timeout 1200 ./install.sh --no-recommended < /dev/null" > "$out/again.log" 2>&1
after=$(tree)
if ! grep -qx '\[install\] result=ok' "$out/again.log"; then tail -5 "$out/again.log"; step idempotent fail "reason=second_run"
elif [ "$before" = "$after" ]; then step idempotent ok "files=$(echo "$after" | wc -l)"
else diff <(echo "$before") <(echo "$after") | head -10; step idempotent fail; fi

# the recommended extras with the real package manager, the cursor must come out as a hyprcursor theme
as_ci "cd fluency && timeout 2400 ./install.sh --recommended < /dev/null" > "$out/recommended.log" 2>&1
hc=$(grep -o 'stage=hyprcursor result=[a-z]*.*' "$out/recommended.log" | tail -1)
if grep -qx '\[install\] result=ok' "$out/recommended.log" && [ "$hc" = "stage=hyprcursor result=ok shapes=49 aliases=85" ] \
  && as_ci "grep -q 'HYPRCURSOR_THEME = \"Bibata_Ghost_Hyprcursor\"' .config/hypr/fluency/generated.lua"; then
  step recommended ok
else
  tail -20 "$out/recommended.log"; step recommended fail "hyprcursor=\"$hc\""
fi

as_ci "cd fluency && timeout 120 ./install.sh --uninstall" > "$out/uninstall.log" 2>&1
left=$(as_ci "ls -d .config/hypr/fluency .local/share/fluency .local/lib/fluency .local/share/fonts/fluency 2>/dev/null; grep -lx 'require(\"fluency\")' .config/hypr/hyprland.lua 2>/dev/null" | tr '\n' ' ')
[ -z "$left" ] && step uninstall ok || step uninstall fail "left=\"$left\""

log "done fails=$fails secs=$(( $(date +%s) - start ))"
[ $fails = 0 ]
