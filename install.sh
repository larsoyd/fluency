#!/usr/bin/env bash
# usage: install.sh [--deps] [--[no-]recommended] [--no-plugins] [--dry-run] [--uninstall]
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
cfg=${XDG_CONFIG_HOME:-$HOME/.config}/hypr
share=$HOME/.local/share/fluency
lib=$HOME/.local/lib/fluency
fonts=${XDG_DATA_HOME:-$HOME/.local/share}/fonts/fluency
sys=${FLUENCY_SYSROOT:-}

fluent_url=https://raw.githubusercontent.com/microsoft/fluentui-system-icons/a563cf9166f4f91aa617557ed272612b7f0a2f72/fonts/FluentSystemIcons-Regular.ttf
fluent_sum=c5dab901c52362ecc94d3a1d2c88a5c060464eb9eb58bb5b0d64d17066af4d7f
selawik_url=https://github.com/microsoft/Selawik/releases/download/1.01/Selawik_Release.zip
selawik_sum=3f62c51e05e3b5a1e6241cf92a371f0be2ea1183aa87b30718bbd40832a8d423
cursor_url=https://github.com/Silicasandwhich/Bibata_Cursor_Translucent/archive/v1.1.2.tar.gz
cursor_sum=b0398c478c5968977ea092f64b00ecd49e09f0574e8951acc0a32db3b5132930
cursor_name=Bibata_Ghost

say() { echo "[install] $*"; }
refuse() { echo "[install] refused: $*"; exit 1; }
usage() { sed -n '2s/^# //p' "$0"; }

deps=0 plugins=1 dry=0 remove=0 extras=ask
for arg in "$@"; do
  case $arg in
    --deps) deps=1 ;;
    --recommended) extras=yes ;;
    --no-recommended) extras=no ;;
    --no-plugins) plugins=0 ;;
    --dry-run) dry=1 ;;
    --uninstall) remove=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage; refuse "bad_arg arg=$arg" ;;
  esac
done

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
stamp=$(date +%Y%m%d-%H%M%S)

at_least() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" = "$2" ]; }
same_tree() { [ -e "$2" ] && diff -rq "$1" "$2" >/dev/null 2>&1; }

backup() {
  [ -f "$1" ] || return 0
  cp -p "$1" "$1.bak-$stamp"
  say "stage=backup file=$1.bak-$stamp"
}

# replaces a directory in one rename, a reader never sees half of it
swap_dir() {
  local new=$1 dest=$2
  mkdir -p "$(dirname "$dest")"
  rm -rf "$dest.new"
  cp -r "$new" "$dest.new"
  rm -rf "$dest"
  mv "$dest.new" "$dest"
}

uninstall() {
  if [ -f "$cfg/hyprland.lua" ] && grep -qx 'require("fluency")' "$cfg/hyprland.lua"; then
    backup "$cfg/hyprland.lua"
    grep -vx 'require("fluency")' "$cfg/hyprland.lua" > "$work/hyprland.lua" || true
    mv "$work/hyprland.lua" "$cfg/hyprland.lua"
  fi
  rm -rf "$cfg/fluency" "$share" "$lib" "$fonts"
  command -v fc-cache >/dev/null && timeout 60 fc-cache -f >/dev/null 2>&1 || true
  say "stage=uninstall result=ok"
}

if [ $remove = 1 ]; then
  [ $dry = 1 ] && { say "stage=uninstall result=dry_run dirs=\"$cfg/fluency $share $lib $fonts\""; exit 0; }
  uninstall
  exit 0
fi

# package names for the binaries, by package manager
package() {
  local bin=$1 pm=$2
  case $bin:$pm in
    qs:pacman) echo quickshell ;;
    qs:*) echo "" ;;
    hyprctl:*|Hyprland:*) echo hyprland ;;
    wl-copy:*) echo wl-clipboard ;;
    gio:apt|gdbus:apt) echo libglib2.0-bin ;;
    gio:*|gdbus:*) echo glib2 ;;
    xdg-open:*|xdg-settings:*|xdg-mime:*) echo xdg-utils ;;
    busctl:*|systemctl:*) echo systemd ;;
    fc-cache:*) echo fontconfig ;;
    sha256sum:*) echo coreutils ;;
    pkg-config:pacman) echo pkgconf ;;
    pkg-config:dnf) echo pkgconf-pkg-config ;;
    pkg-config:*) echo pkg-config ;;
    c++:pacman) echo gcc ;;
    c++:apt) echo g++ ;;
    c++:*) echo gcc-c++ ;;
    *) echo "$bin" ;;
  esac
}

manager() {
  local pm
  for pm in pacman dnf apt zypper; do command -v "$pm" >/dev/null && { echo "$pm"; return; }; done
  echo unknown
}

install_packages() {
  local pm=$1; shift
  local root=sudo
  command -v sudo >/dev/null || root=pkexec
  case $pm in
    pacman) timeout 600 "$root" pacman -S --needed --noconfirm "$@" ;;
    dnf) timeout 600 "$root" dnf install -y "$@" ;;
    apt) timeout 600 "$root" apt install -y "$@" ;;
    zypper) timeout 600 "$root" zypper --non-interactive install "$@" ;;
    *) return 1 ;;
  esac
}

check_deps() {
  local need=(Hyprland hyprctl qs wl-copy gio gdbus xdg-open xdg-settings xdg-mime busctl systemctl zip unzip curl sha256sum fc-cache)
  [ $plugins = 1 ] && need+=(cmake pkg-config c++)
  local missing=() bin
  for bin in "${need[@]}"; do command -v "$bin" >/dev/null || missing+=("$bin"); done
  [ ${#missing[@]} = 0 ] && { say "stage=deps result=ok"; return; }
  local pm pkgs=() manual=()
  pm=$(manager)
  for bin in "${missing[@]}"; do
    local p
    p=$(package "$bin" "$pm")
    if [ -n "$p" ]; then pkgs+=("$p"); else manual+=("$bin"); fi
  done
  [ ${#manual[@]} = 0 ] || refuse "missing_without_package bins=\"${manual[*]}\" manager=$pm hint=build_from_upstream"
  [ $deps = 1 ] || refuse "missing_deps bins=\"${missing[*]}\" manager=$pm packages=\"${pkgs[*]}\" hint=rerun_with_--deps"
  [ $dry = 1 ] && { say "stage=deps result=dry_run would_install=\"${pkgs[*]}\""; return; }
  install_packages "$pm" "${pkgs[@]}" || refuse "package_install_failed manager=$pm packages=\"${pkgs[*]}\""
  for bin in "${missing[@]}"; do command -v "$bin" >/dev/null || refuse "still_missing bin=$bin"; done
  say "stage=deps result=installed packages=\"${pkgs[*]}\""
}

cursor_exists() {
  local dir
  local IFS=:
  for dir in "${XDG_DATA_HOME:-$HOME/.local/share}" ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do
    [ -d "$dir/icons/$cursor_name/cursors" ] && return 0
  done
  [ -d "$HOME/.icons/$cursor_name/cursors" ]
}

# icons, terminal, file manager and cursor the shell looks best with, all optional
recommended() {
  icon_theme_exists Papirus-Dark || echo papirus
  has_entry kitty || echo kitty
  has_entry org.kde.dolphin || echo dolphin
  cursor_exists || echo bibata-ghost
}

# no distribution packages this cursor, so it comes from its release at a pinned checksum
fetch_cursor() {
  mkdir -p "$work/dl" "$work/cursor"
  timeout 120 curl -fsSL -o "$work/dl/cursor.tar.gz" "$cursor_url" || refuse "cursor_download url=$cursor_url"
  local got
  got=$(sha256sum "$work/dl/cursor.tar.gz" | cut -d' ' -f1)
  [ "$got" = "$cursor_sum" ] || refuse "cursor_checksum got=$got want=$cursor_sum"
  timeout 60 tar -xzf "$work/dl/cursor.tar.gz" -C "$work/cursor" --strip-components=1 "Bibata_Cursor_Translucent-1.1.2/$cursor_name" \
    || refuse "cursor_unpack name=$cursor_name"
}

extra_packages() {
  case $1:$2 in
    papirus:dnf) echo papirus-icon-theme papirus-icon-theme-dark ;;
    papirus:*) echo papirus-icon-theme ;;
    *) echo "$1" ;;
  esac
}

recommend() {
  local missing=() chosen=() name answer
  mapfile -t missing < <(recommended)
  [ ${#missing[@]} = 0 ] && { say "stage=recommend result=ok"; return; }
  case $extras in
    no) say "stage=recommend result=skipped missing=\"${missing[*]}\""; return ;;
    yes) chosen=("${missing[@]}") ;;
    ask)
      if [ $dry = 1 ] || [ ! -t 0 ]; then
        say "stage=recommend result=hint missing=\"${missing[*]}\" hint=rerun_with_--recommended"
        return
      fi
      for name in "${missing[@]}"; do
        read -r -t 60 -p "[install] recommended: $name, install? [y/N] " answer || answer=n
        [[ $answer == [yY]* ]] && chosen+=("$name")
      done
      [ ${#chosen[@]} -gt 0 ] || { say "stage=recommend result=declined missing=\"${missing[*]}\""; return; }
      ;;
  esac
  local pm pkgs=() fetched=()
  pm=$(manager)
  for name in "${chosen[@]}"; do
    if [ "$name" = bibata-ghost ]; then fetched+=("$name"); continue; fi
    read -ra answer <<< "$(extra_packages "$name" "$pm")"
    pkgs+=("${answer[@]}")
  done
  [ $dry = 1 ] && { say "stage=recommend result=dry_run would_install=\"${pkgs[*]}\" would_fetch=\"${fetched[*]}\""; return; }
  [ ${#fetched[@]} = 0 ] || fetch_cursor
  if [ ${#pkgs[@]} -gt 0 ]; then
    install_packages "$pm" "${pkgs[@]}" || refuse "recommended_install_failed manager=$pm packages=\"${pkgs[*]}\""
  fi
  [ ${#fetched[@]} = 0 ] || swap_dir "$work/cursor/$cursor_name" "${XDG_DATA_HOME:-$HOME/.local/share}/icons/$cursor_name"
  mapfile -t missing < <(recommended)
  for name in "${chosen[@]}"; do [[ " ${missing[*]} " != *" $name "* ]] || refuse "still_missing name=$name packages=\"${pkgs[*]}\""; done
  say "stage=recommend result=installed packages=\"${pkgs[*]}\" fetched=\"${fetched[*]}\""
}

preflight() {
  if [ ! -f "$cfg/hyprland.lua" ] && [ -f "$cfg/hyprland.conf" ]; then
    refuse "hyprlang_config file=$cfg/hyprland.conf hint=fluency_needs_a_lua_config"
  fi
  [ ! -e "$share" ] || [ -f "$share/REVISION" ] || refuse "not_a_fluency_dir dir=$share"
  check_deps
  recommend
  local hv qv
  hv=$(timeout 10 Hyprland --version 2>/dev/null | sed -n '1s/^Hyprland \([0-9.]*\).*/\1/p')
  [ -n "$hv" ] || refuse "no_hyprland_version"
  at_least "$hv" 0.56 || refuse "old_hyprland version=$hv need=0.56"
  qv=$(timeout 10 qs --version 2>/dev/null | sed -n '1s/^Quickshell \([0-9.]*\).*/\1/p')
  [ -n "$qv" ] || refuse "no_quickshell_version"
  at_least "$qv" 0.3 || refuse "old_quickshell version=$qv need=0.3"
  say "stage=preflight result=ok hyprland=$hv quickshell=$qv"
  hypr_version=$hv
}

# the committed tree when this is a git checkout, so a stray edit never ships
export_source() {
  mkdir -p "$work/src"
  if git -C "$here" rev-parse --git-dir >/dev/null 2>&1; then
    local dirty
    dirty=$(git -C "$here" status --porcelain -- shell hypr plugins | cut -c4- | tr '\n' ',')
    [ -z "$dirty" ] || refuse "uncommitted_changes files=${dirty%,}"
    revision=$(git -C "$here" rev-parse --short HEAD)
    git -C "$here" archive HEAD shell hypr plugins | tar -x -C "$work/src"
  else
    revision=archive
    cp -r "$here/shell" "$here/hypr" "$here/plugins" "$work/src/"
  fi
  say "stage=source result=ok revision=$revision"
}

fetch_fonts() {
  mkdir -p "$work/dl" "$work/fonts"
  timeout 120 curl -fsSL -o "$work/dl/fluent.ttf" "$fluent_url" || refuse "font_download url=$fluent_url"
  timeout 120 curl -fsSL -o "$work/dl/selawik.zip" "$selawik_url" || refuse "font_download url=$selawik_url"
  local got
  got=$(sha256sum "$work/dl/fluent.ttf" | cut -d' ' -f1)
  [ "$got" = "$fluent_sum" ] || refuse "font_checksum file=FluentSystemIcons-Regular.ttf got=$got want=$fluent_sum"
  got=$(sha256sum "$work/dl/selawik.zip" | cut -d' ' -f1)
  [ "$got" = "$selawik_sum" ] || refuse "font_checksum file=Selawik_Release.zip got=$got want=$selawik_sum"
  cp "$work/dl/fluent.ttf" "$work/fonts/FluentSystemIcons-Regular.ttf"
  timeout 30 unzip -q -j "$work/dl/selawik.zip" '*.ttf' -d "$work/fonts" || refuse "font_unpack file=Selawik_Release.zip"
  say "stage=fonts result=fetched files=$(ls "$work/fonts" | wc -l)"
}

build_plugins() {
  mkdir -p "$work/lib"
  [ $plugins = 1 ] || { say "stage=plugins result=skipped"; return; }
  local pc
  pc=$(pkg-config --modversion hyprland 2>/dev/null) || refuse "plugin_headers reason=no_hyprland_pc"
  [ "$pc" = "$hypr_version" ] || refuse "plugin_headers headers=$pc running=$hypr_version"
  local dir name
  for dir in "$work/src/plugins"/*/; do
    name=$(basename "$dir")
    timeout 120 cmake -S "$dir" -B "$work/build/$name" -DCMAKE_BUILD_TYPE=Release >"$work/build-$name.log" 2>&1 \
      || { tail -20 "$work/build-$name.log"; refuse "plugin_configure name=$name"; }
    timeout 900 cmake --build "$work/build/$name" -j"$(nproc)" >>"$work/build-$name.log" 2>&1 \
      || { tail -20 "$work/build-$name.log"; refuse "plugin_build name=$name"; }
    cp "$(find "$work/build/$name" -maxdepth 1 -name 'lib*.so' | head -1)" "$work/lib/" || refuse "plugin_output name=$name"
  done
  say "stage=plugins result=built files=$(ls "$work/lib" | wc -l)"
}

icon_theme_exists() {
  local dir
  local IFS=:
  for dir in "${XDG_DATA_HOME:-$HOME/.local/share}" ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do
    [ -f "$dir/icons/$1/index.theme" ] && return 0
  done
  [ -f "$HOME/.icons/$1/index.theme" ]
}

# kdeglobals names a theme only once chosen, gsettings always has its default
icon_theme() {
  local chosen fallback
  chosen=$(sed -n '/^\[Icons\]/,/^\[/s/^Theme=//p' "${XDG_CONFIG_HOME:-$HOME/.config}/kdeglobals" 2>/dev/null | head -1)
  fallback=$(timeout 5 gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'") || fallback=""
  local name
  for name in "$chosen" Papirus-Dark "$fallback"; do
    [ -n "$name" ] && icon_theme_exists "$name" && { echo "$name"; return; }
  done
  echo hicolor
}

entry_file() {
  local dir
  local IFS=:
  for dir in "${XDG_DATA_HOME:-$HOME/.local/share}" ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do
    [ -f "$dir/applications/$1.desktop" ] && { echo "$dir/applications/$1.desktop"; return 0; }
  done
  return 1
}

has_entry() { entry_file "$1" >/dev/null; }

in_category() {
  local file
  file=$(entry_file "$1") || return 1
  sed -n '/^\[Desktop Entry\]/,/^\[/s/^Categories=//p' "$file" | head -1 | tr ';' '\n' | grep -qx "$2"
}

# the folder handler can be any app that opens folders, a terminal among them
file_manager() {
  local id
  id=$(timeout 5 xdg-mime query default inode/directory 2>/dev/null)
  id=${id%.desktop}
  [ -n "$id" ] && in_category "$id" FileManager && { echo "$id"; return; }
  for id in org.kde.dolphin org.gnome.Nautilus thunar nemo pcmanfm-qt pcmanfm caja; do
    in_category "$id" FileManager && { echo "$id"; return; }
  done
}

qt_plugin() {
  compgen -G "$sys/usr/lib*/qt6/plugins/platformthemes/$1" >/dev/null \
    || compgen -G "$sys/usr/lib/*/qt6/plugins/platformthemes/$1" >/dev/null
}

# an engine the user installed on purpose goes before the ones that come with a desktop
qt_theme() {
  if qt_plugin 'libqt6ct.so'; then echo qt6ct
  elif qt_plugin '*hyprqt6engine*.so'; then echo hyprqt6engine
  elif qt_plugin 'KDEPlasmaPlatformTheme6.so'; then echo kde
  elif qt_plugin 'libqgtk3.so'; then echo gtk3
  fi
}

terminal() {
  if [ -n "${TERMINAL:-}" ]; then echo "$TERMINAL"; return; fi
  local t
  for t in kitty foot alacritty wezterm ghostty konsole gnome-terminal xterm; do
    command -v "$t" >/dev/null && { echo "$t"; return; }
  done
}

# values land in a lua string and a qml pragma, anything odd is refused
plain() { [[ $1 =~ ^[A-Za-z0-9._,+/\ -]*$ ]] || refuse "odd_value name=$2 value=\"$1\""; }

write_machine() {
  local theme term qt pins=() id
  theme=$(icon_theme)
  term=$(terminal)
  qt=$(qt_theme)
  for id in "$(timeout 5 xdg-settings get default-web-browser 2>/dev/null)" "$(file_manager)" "$term"; do
    id=${id%.desktop}
    [ -n "$id" ] && has_entry "$id" && [[ " ${pins[*]} " != *" $id "* ]] && pins+=("$id")
  done
  local env=()
  [ -n "$term" ] && env+=("TERMINAL=$term")
  [ ${#pins[@]} -gt 0 ] && env+=("FLUENCY_PINS=$(IFS=,; echo "${pins[*]}")")
  if [ -e "$sys/proc/driver/nvidia/version" ]; then
    env+=("LIBVA_DRIVER_NAME=nvidia" "__GLX_VENDOR_LIBRARY_NAME=nvidia" "NVD_BACKEND=direct")
  elif [ -d "$sys/sys/module/amdgpu" ]; then
    env+=("LIBVA_DRIVER_NAME=radeonsi" "VDPAU_DRIVER=radeonsi")
  fi
  [ -n "$qt" ] && env+=("QT_QPA_PLATFORMTHEME=$qt")
  if cursor_exists && [ "${XCURSOR_THEME:-$cursor_name}" = "$cursor_name" ] \
    && ! grep -rqs --exclude-dir=fluency XCURSOR_THEME "$cfg"; then
    env+=("XCURSOR_THEME=$cursor_name")
  fi
  plain "$theme" icon_theme
  {
    echo "return {"
    echo "    icon_theme = \"$theme\","
    echo "    env = {"
    local pair
    for pair in "${env[@]}"; do
      plain "${pair#*=}" "${pair%%=*}"
      echo "        ${pair%%=*} = \"${pair#*=}\","
    done
    echo "    },"
    echo "}"
  } > "$1"
  icon=$theme
  say "stage=machine result=ok icon_theme=$theme terminal=${term:-none} pins=\"${pins[*]}\" env=${#env[@]}"
}

build_shell() {
  mkdir -p "$work/share"
  cp -r "$work/src/shell" "$work/share/shell"
  echo "$revision" > "$work/share/REVISION"
  sed -i "1s|^//@ pragma IconTheme .*|//@ pragma IconTheme $icon|" "$work/share/shell/shell.qml"
  grep -qx "//@ pragma IconTheme $icon" "$work/share/shell/shell.qml" || refuse "no_icon_pragma file=shell.qml"
}

starter() {
  cat <<'LUA'
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

hl.bind("SUPER + Q", hl.dsp.exec_cmd("$TERMINAL"))
hl.bind("SUPER + M", hl.dsp.exec_cmd("hyprctl dispatch 'hl.dsp.exit()'"))
for i = 1, 9 do
    hl.bind("SUPER + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind("SUPER + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

require("fluency")
LUA
}

build_config() {
  mkdir -p "$work/cand"
  [ -d "$cfg" ] && cp -a "$cfg/." "$work/cand/"
  rm -rf "$work/cand/fluency"
  cp -r "$work/src/hypr/fluency" "$work/cand/fluency"
  write_machine "$work/cand/fluency/local.lua"
  if [ -f "$work/cand/hyprland.lua" ]; then
    grep -qx 'require("fluency")' "$work/cand/hyprland.lua" || printf '\nrequire("fluency")\n' >> "$work/cand/hyprland.lua"
  else
    starter > "$work/cand/hyprland.lua"
  fi
  local out
  out=$(timeout 30 Hyprland --verify-config -c "$work/cand/hyprland.lua" 2>&1) || {
    echo "$out" | sed -n '/Config parsing result/,$p' | tail -n +2 | head -20
    refuse "verify_failed config=$cfg/hyprland.lua"
  }
  say "stage=verify result=ok"
}

apply_fonts() {
  if same_tree "$work/fonts" "$fonts"; then say "stage=fonts result=same"; return; fi
  swap_dir "$work/fonts" "$fonts"
  timeout 60 fc-cache -f "$fonts" >/dev/null 2>&1 || say "stage=fonts warn=fc_cache_failed"
  say "stage=fonts result=installed dir=$fonts"
}

apply_plugins() {
  [ $plugins = 1 ] || return 0
  mkdir -p "$lib"
  local so
  for so in "$work/lib"/*.so; do
    cp "$so" "$lib/.$(basename "$so").new"
    mv -f "$lib/.$(basename "$so").new" "$lib/$(basename "$so")"
  done
  say "stage=plugins result=installed dir=$lib"
}

apply_shell() {
  if same_tree "$work/share" "$share"; then say "stage=shell result=same"; return; fi
  swap_dir "$work/share" "$share"
  say "stage=shell result=installed dir=$share revision=$revision"
}

apply_config() {
  if same_tree "$work/cand/fluency" "$cfg/fluency" && cmp -s "$work/cand/hyprland.lua" "$cfg/hyprland.lua"; then
    say "stage=config result=same"
    return
  fi
  # modules first, the entry that requires them last
  swap_dir "$work/cand/fluency" "$cfg/fluency"
  if ! cmp -s "$work/cand/hyprland.lua" "$cfg/hyprland.lua"; then
    backup "$cfg/hyprland.lua"
    cp "$work/cand/hyprland.lua" "$cfg/.hyprland.lua.new"
    mv "$cfg/.hyprland.lua.new" "$cfg/hyprland.lua"
  fi
  say "stage=config result=installed dir=$cfg"
}

reload() {
  [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || { say "stage=start result=next_login"; return; }
  local errors
  errors=$(timeout 5 hyprctl configerrors 2>/dev/null | grep -v '^$' || true)
  [ -z "$errors" ] || say "stage=reload warn=config_errors first=\"$(echo "$errors" | head -1)\""
  if timeout 5 qs ipc -p "$share/shell" call fluency reload >/dev/null 2>&1; then
    say "stage=reload result=ok"
  else
    say "stage=start result=not_running hint=\"qs --no-duplicate --log-rules qt.svg.warning=false -p $share/shell\""
  fi
}

preflight
export_source
fetch_fonts
build_plugins
build_config
build_shell
if [ $dry = 1 ]; then
  say "stage=apply result=dry_run fonts=$fonts lib=$lib shell=$share config=$cfg"
  exit 0
fi
apply_fonts
apply_plugins
apply_shell
apply_config
reload
say "result=ok"
