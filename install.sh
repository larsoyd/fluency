#!/usr/bin/env bash
# usage: install.sh [--deps] [--[no-]recommended] [--no-plugins] [--dry-run] [--uninstall]
set -Eeuo pipefail

here=$(cd "$(dirname "$0")" && pwd)
cfg=${XDG_CONFIG_HOME:-$HOME/.config}/hypr
share=$HOME/.local/share/fluency
lib=$HOME/.local/lib/fluency
fonts=${XDG_DATA_HOME:-$HOME/.local/share}/fonts/fluency
fontconf=${XDG_CONFIG_HOME:-$HOME/.config}/fontconfig/conf.d/50-fluency.conf
sys=${FLUENCY_SYSROOT:-}
state=${XDG_STATE_HOME:-$HOME/.local/state}/fluency
manifest=$state/manifest
block=$'\nrequire("fluency")\n'

fluent_url=https://raw.githubusercontent.com/microsoft/fluentui-system-icons/a563cf9166f4f91aa617557ed272612b7f0a2f72/fonts/FluentSystemIcons-Regular.ttf
fluent_sum=c5dab901c52362ecc94d3a1d2c88a5c060464eb9eb58bb5b0d64d17066af4d7f
selawik_url=https://github.com/microsoft/Selawik/releases/download/1.01/Selawik_Release.zip
selawik_sum=3f62c51e05e3b5a1e6241cf92a371f0be2ea1183aa87b30718bbd40832a8d423
cursor_url=https://github.com/Silicasandwhich/Bibata_Cursor_Translucent/archive/v1.1.2.tar.gz
cursor_sum=b0398c478c5968977ea092f64b00ecd49e09f0574e8951acc0a32db3b5132930
cursor_name=Bibata_Ghost
hyprcursor_name=Bibata_Ghost_Hyprcursor
engine_url=https://github.com/hyprwm/hyprqt6engine/archive/d0ce29ca5471f406c71558cd9453573686b8c976.tar.gz
engine_sum=a6f113357277246002e56d844b0ff94699c4822ebf78f7748c395752b3bab42b
engine_plugin=$lib/qt6/plugins/platformthemes/libhyprqt6engine.so
breeze_dark=/usr/share/color-schemes/BreezeDark.colors

say() { echo "[install] $*"; }
refuse() { echo "[install] refused: $*"; exit 1; }
# an unhandled failure names its line, probes inside subshells stay quiet
caught() { [ "$BASH_SUBSHELL" != 0 ] || refuse "unexpected_failure line=$2 status=$1"; }
trap 'caught $? $LINENO' ERR
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
chosen=() pkgs=() tools=() fetched=() built=() converted=()
trap 'rm -rf "$work"' EXIT
stamp=$(date +%Y%m%d-%H%M%S)

at_least() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" = "$2" ]; }
same_tree() { [ -e "$2" ] && diff -rq "$1" "$2" >/dev/null 2>&1; }

backup() {
  [ -f "$1" ] || return 0
  local target
  target=$(readlink -f "$1")
  cp -p "$target" "$target.bak-$stamp"
  say "stage=backup file=$target.bak-$stamp"
}

# what this installer made, one line each, so uninstall takes away exactly that
note() {
  if [ ! -d "$state" ]; then
    local d=$state missing=()
    while [ ! -e "$d" ]; do missing=("$d" "${missing[@]}"); d=$(dirname "$d"); done
    mkdir -p "$state"
    for d in "${missing[@]}"; do echo "dir $d" >> "$manifest"; done
  fi
  grep -qxF -- "$*" "$manifest" 2>/dev/null || echo "$*" >> "$manifest"
}

# a path about to be made, with the parents it needs that are not there yet
track() {
  local dir parents=()
  dir=$(dirname "$1")
  while [ ! -e "$dir" ]; do parents=("$dir" "${parents[@]}"); dir=$(dirname "$dir"); done
  for dir in "${parents[@]}"; do note "dir $dir"; done
  [ -e "$1" ] || note "made $1"
}

# writes through a link so the dotfile it points at stays the file that changes
write_entry() {
  local target
  target=$(readlink -f "$cfg/hyprland.lua")
  if [ -L "$cfg/hyprland.lua" ]; then
    cat "$1" > "$target"
  else
    cp "$1" "$cfg/.hyprland.lua.new"
    mv "$cfg/.hyprland.lua.new" "$cfg/hyprland.lua"
  fi
}

# swaps in place when mv can exchange, otherwise the old dir is gone for a moment
swap_dir() {
  local new=$1 dest=$2
  mkdir -p "$(dirname "$dest")"
  rm -rf "$dest.new"
  cp -r "$new" "$dest.new"
  if mv --exchange -T "$dest.new" "$dest" 2>/dev/null; then
    rm -rf "$dest.new"
  else
    rm -rf "$dest"
    mv "$dest.new" "$dest"
  fi
}

local_template=$'-- your own settings for this machine, kept when the installer runs again\n-- generated.lua holds what the installer found, a key here wins over it\nreturn {}\n'

uninstall() {
  local lines=() line entry=$cfg/hyprland.lua target
  [ -f "$manifest" ] && mapfile -t lines < "$manifest"
  [ -f "$manifest" ] || say "stage=uninstall warn=no_manifest hint=only_the_known_dirs_are_removed"
  if [ -f "$entry" ]; then
    target=$(readlink -f "$entry")
    if printf '%s\n' "${lines[@]}" | grep -qx "entry starter $(sha256sum < "$target" | cut -c1-64)"; then
      rm -f "$entry"
    elif grep -qx 'require("fluency")' "$target"; then
      backup "$entry"
      if tail -c ${#block} "$target" | cmp -s - <(printf '%s' "$block"); then
        head -c -${#block} "$target" > "$work/hyprland.lua"
      else
        grep -vx 'require("fluency")' "$target" > "$work/hyprland.lua" || true
      fi
      cat "$work/hyprland.lua" > "$target"
    fi
  fi
  if [ -f "$cfg/fluency/local.lua" ] && ! cmp -s "$cfg/fluency/local.lua" <(printf '%s' "$local_template"); then
    cp -p "$cfg/fluency/local.lua" "$cfg/fluency-local.lua.bak-$stamp"
    say "stage=uninstall kept=$cfg/fluency-local.lua.bak-$stamp"
  fi
  rm -rf "$cfg/fluency" "$share" "$lib" "$fonts" "$fontconf" "$manifest"
  for ((i = ${#lines[@]} - 1; i >= 0; i--)); do
    line=${lines[i]}
    case $line in
      "made "*) rm -rf "${line#made }" ;;
      "gsettings "*) timeout 5 gsettings reset org.gnome.desktop.interface "${line#gsettings }" 2>/dev/null || true ;;
      "dir "*) rmdir "${line#dir }" 2>/dev/null || true ;;
    esac
  done
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
    hyprctl:*|Hyprland:*|hyprland.pc:pacman) echo hyprland ;;
    hyprland.pc:apt) echo hyprland-dev ;;
    wayland-scanner:apt) echo libwayland-bin ;;
    wayland-client.pc:apt) echo libwayland-dev ;;
    wayland-scanner:pacman|wayland-client.pc:pacman) echo wayland ;;
    wayland-scanner:*|wayland-client.pc:*) echo wayland-devel ;;
    wayland-protocols.pc:dnf) echo wayland-protocols-devel ;;
    wayland-protocols.pc:*) echo wayland-protocols ;;
    hyprland.pc:*) echo hyprland-devel ;;
    QtQuick.Shapes:apt) echo qml6-module-qtquick-shapes ;;
    QtQuick.Effects:apt) echo qml6-module-qtquick-effects ;;
    Qt.labs.folderlistmodel:apt) echo qml6-module-qt-labs-folderlistmodel ;;
    Qt*:pacman) echo qt6-declarative ;;
    Qt*:*) echo qt6-qtdeclarative ;;
    wl-copy:*) echo wl-clipboard ;;
    notify-send:apt) echo libnotify-bin ;;
    notify-send:*) echo libnotify ;;
    flock:*) echo util-linux ;;
    gio:apt|gdbus:apt) echo libglib2.0-bin ;;
    gio:*|gdbus:*) echo glib2 ;;
    xdg-open:*|xdg-settings:*|xdg-mime:*) echo xdg-utils ;;
    busctl:*|systemctl:*) echo systemd ;;
    fc-cache:*) echo fontconfig ;;
    sha256sum:*) echo coreutils ;;
    cmp:*|diff:*) echo diffutils ;;
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
  for pm in pacman dnf apt; do command -v "$pm" >/dev/null && { echo "$pm"; return; }; done
  echo unknown
}

# sudo asks on the terminal so it runs in the foreground, without one it may not ask
install_packages() {
  local pm=$1; shift
  local root=(sudo)
  command -v sudo >/dev/null || root=(pkexec)
  if [ "${root[0]}" = sudo ] && [ ! -t 0 ]; then
    root=(sudo -n)
    timeout 10 sudo -n true 2>/dev/null || refuse "needs_password manager=$pm packages=\"$*\" hint=run_in_a_terminal"
  fi
  case $pm in
    pacman) timeout --foreground 1800 "${root[@]}" pacman -S --needed --noconfirm "$@" ;;
    dnf) timeout --foreground 1800 "${root[@]}" dnf install -y "$@" ;;
    apt) timeout --foreground 1800 "${root[@]}" apt update && timeout --foreground 1800 "${root[@]}" apt install -y "$@" ;;
    *) return 1 ;;
  esac
}

have() {
  case $1 in
    *.pc) pkg-config --exists "${1%.pc}" 2>/dev/null ;;
    Qt*.*) qml_module "$1" ;;
    *) command -v "$1" >/dev/null ;;
  esac
}

qml_module() {
  compgen -G "$sys/usr/lib*/qt6/qml/${1//.//}/qmldir" >/dev/null \
    || compgen -G "$sys/usr/lib/*/qt6/qml/${1//.//}/qmldir" >/dev/null
}

check_deps() {
  local need=(Hyprland hyprctl qs wl-copy gio gdbus xdg-open xdg-settings xdg-mime busctl systemctl zip unzip curl sha256sum fc-cache cmp diff QtQuick.Shapes QtQuick.Effects Qt.labs.folderlistmodel)
  [ $plugins = 1 ] && need+=(cmake make pkg-config c++ notify-send flock wayland-scanner)
  local missing=() bin
  for bin in "${need[@]}"; do have "$bin" || missing+=("$bin"); done
  local pc
  [ $plugins = 1 ] && for pc in hyprland.pc wayland-client.pc wayland-protocols.pc; do have "$pc" || missing+=("$pc"); done
  [ ${#missing[@]} = 0 ] && { say "stage=deps result=ok"; return; }
  local pm pkgs=() manual=()
  pm=$(manager)
  [ "$pm" != unknown ] || refuse "missing_deps bins=\"${missing[*]}\" manager=unknown hint=install_them_by_hand"
  for bin in "${missing[@]}"; do
    local p
    p=$(package "$bin" "$pm")
    if [ -n "$p" ]; then pkgs+=("$p"); else manual+=("$bin"); fi
  done
  [ ${#manual[@]} = 0 ] || refuse "missing_without_package bins=\"${manual[*]}\" manager=$pm hint=build_from_upstream"
  [ $deps = 1 ] || refuse "missing_deps bins=\"${missing[*]}\" manager=$pm packages=\"${pkgs[*]}\" hint=rerun_with_--deps"
  [ $dry = 1 ] && { say "stage=deps result=dry_run would_install=\"${pkgs[*]}\""; return; }
  install_packages "$pm" "${pkgs[@]}" || refuse "package_install_failed manager=$pm packages=\"${pkgs[*]}\""
  for bin in "${missing[@]}"; do have "$bin" || refuse "still_missing bin=$bin"; done
  say "stage=deps result=installed packages=\"${pkgs[*]}\""
}

# prints the first icons dir that holds the path
icon_path() {
  local dir
  local IFS=:
  for dir in "${XDG_DATA_HOME:-$HOME/.local/share}" ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do
    [ -e "$dir/icons/$1" ] && { echo "$dir/icons/$1"; return 0; }
  done
  [ -e "$HOME/.icons/$1" ] && echo "$HOME/.icons/$1"
}

cursor_exists() { [ -n "$(icon_path "$cursor_name/cursors")" ]; }
hyprcursor_exists() { [ -n "$(icon_path "$hyprcursor_name/manifest.hl")" ]; }

hyprcursor_tools() {
  local bin
  for bin in hyprcursor-util xcur2png; do command -v "$bin" >/dev/null || { hc_reason=no_$bin; return 1; }; done
}

# stock themes and cursor themes do not count as icons of the user's own
own_icons() {
  local dirs=() dir index name
  IFS=: read -ra dirs <<< "${XDG_DATA_HOME:-$HOME/.local/share}:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
  for dir in "${dirs[@]/%//icons}" "$HOME/.icons"; do
    for index in "$dir"/*/index.theme; do
      [ -f "$index" ] || continue
      name=$(basename "$(dirname "$index")")
      case $name in hicolor|Adwaita*|default|locolor|HighContrast) continue ;; esac
      grep -q '^Directories=' "$index" && return 0
    done
  done
  return 1
}

# with no name, any theme but the ones gtk ships counts
gtk_theme_exists() {
  local dirs=() dir theme
  IFS=: read -ra dirs <<< "${XDG_DATA_HOME:-$HOME/.local/share}:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
  for dir in "${dirs[@]/%//themes}" "$HOME/.themes"; do
    for theme in "$dir"/*/gtk-3.0; do
      [ -d "$theme" ] || continue
      theme=${theme%/gtk-3.0}
      theme=${theme##*/}
      if [ -n "${1:-}" ]; then [ "$theme" = "$1" ] && return 0; continue; fi
      case $theme in Default|Emacs|Raleigh|HighContrast*|Adwaita*) ;; *) return 0 ;; esac
    done
  done
  return 1
}

has_noto() {
  local families
  families=$(timeout 30 fc-list : family 2>/dev/null)
  [[ $'\n'${families//,/$'\n'}$'\n' == *$'\n''Noto Sans'$'\n'* ]]
}

qt_engine_exists() {
  qt_plugin libqt6ct.so || qt_plugin '*hyprqt6engine*.so' || [ -f "$engine_plugin" ] || qt_plugin KDEPlasmaPlatformTheme6.so
}

# icons, terminal, file manager, cursor and qt engine the shell looks best with, all optional
recommended() {
  icon_theme_exists Papirus-Dark || own_icons || echo papirus
  has_entry kitty || echo kitty
  [ -n "$(file_manager)" ] || echo dolphin
  cursor_exists || echo bibata-ghost
  hyprcursor_exists || echo bibata-hyprcursor
  qt_engine_exists || echo hyprqt6engine
  gtk_theme_exists || echo breeze-gtk
  has_noto || echo noto
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

# hyprland draws the cursor itself from a hyprcursor theme, made here from the xcursor one
convert_cursor() {
  local src out=$1 stage=$work/hc log=$work/hyprcursor.log link pair shape spot shapes=0 aliases=0
  hyprcursor_tools || return 1
  src=$(icon_path "$cursor_name")
  [ -n "$src" ] || { hc_reason=no_xcursor; return 1; }
  # the extractor empties this fixed dir, so one it did not make is left alone
  [ ! -e /tmp/hyprcursor-util ] || { hc_reason=extractor_busy; return 1; }
  mkdir -p "$stage"
  cp -a "$src" "$stage/$cursor_name" || { hc_reason=copy; return 1; }
  for pair in diamond_cross:crosshair draft_large:draft ew-resize:size_hor; do
    link=$stage/$cursor_name/cursors/${pair%%:*}
    if [ -L "$link" ] && [ ! -e "$link" ]; then ln -sfn "${pair#*:}" "$link"; fi
  done
  timeout 300 hyprcursor-util --extract "$stage/$cursor_name" --output "$stage" --resize bilinear >"$log" 2>&1
  local status=$?
  rm -rf /tmp/hyprcursor-util
  [ $status = 0 ] || { tail -5 "$log"; hc_reason=extract; return 1; }
  local theme=$stage/extracted_$cursor_name
  printf 'name = %s\ndescription = Bibata Ghost as hyprcursor\nversion = 1.1.2\ncursors_directory = hyprcursors\n' "$hyprcursor_name" > "$theme/manifest.hl"
  for shape in "$stage/$cursor_name"/cursors/*; do
    if [ -L "$shape" ]; then
      link=$(basename "$(readlink -f "$shape")")
      grep -qxF "define_override = ${shape##*/}" "$theme/hyprcursors/$link/meta.hl" 2>/dev/null || { hc_reason=lost_alias_${shape##*/}; return 1; }
      aliases=$((aliases + 1))
      continue
    fi
    # one hotspot per shape, taken from the size the artwork was drawn at
    spot=$(timeout 10 xcur2png -q -n -c - "$shape" 2>/dev/null | awk '$1 == 40 { print $2, $3 }' | sort -u)
    [[ $spot =~ ^[0-9]+\ [0-9]+$ ]] || { hc_reason=hotspot_${shape##*/}; return 1; }
    awk -v x="${spot% *}" -v y="${spot#* }" 'BEGIN { printf "hotspot_x = %.9f\nhotspot_y = %.9f\n", x / 40, y / 40 } !/^hotspot_[xy]/' \
      "$theme/hyprcursors/${shape##*/}/meta.hl" > "$stage/meta.hl" && mv "$stage/meta.hl" "$theme/hyprcursors/${shape##*/}/meta.hl" \
      || { hc_reason=meta_${shape##*/}; return 1; }
    shapes=$((shapes + 1))
  done
  timeout 300 hyprcursor-util --create "$theme" --output "$stage" >>"$log" 2>&1 || { tail -5 "$log"; hc_reason=create; return 1; }
  mv "$stage/theme_$hyprcursor_name" "$out" || { hc_reason=move; return 1; }
  printf 'Bibata Ghost by the Bibata Cursor Translucent contributors, GPL-3.0.\nSource: %s\n' "${cursor_url%/archive/*}" > "$out/README.txt"
  say "stage=hyprcursor result=ok shapes=$shapes aliases=$aliases"
}

extra_packages() {
  case $1:$2 in
    papirus:dnf) echo papirus-icon-theme papirus-icon-theme-dark ;;
    papirus:*) echo papirus-icon-theme ;;
    kvantum:apt) echo qt6-style-kvantum ;;
    breeze-gtk:apt) echo breeze-gtk-theme ;;
    breeze-gtk:dnf) echo breeze-gtk-gtk3 breeze-gtk-gtk4 ;;
    noto:pacman) echo noto-fonts noto-fonts-cjk noto-fonts-emoji ;;
    noto:dnf) echo google-noto-sans-vf-fonts google-noto-sans-cjk-vf-fonts google-noto-color-emoji-fonts ;;
    noto:apt) echo fonts-noto-core fonts-noto-cjk fonts-noto-color-emoji ;;
    hyprcursor-tools:apt) echo hyprcursor-util xcur2png ;;
    hyprcursor-tools:*) echo hyprcursor xcur2png ;;
    *) echo "$1" ;;
  esac
}

# no distribution packages hyprqt6engine, so it is built for this user with breeze dark support
build_engine() {
  local bin
  for bin in cmake c++ pkg-config; do command -v "$bin" >/dev/null || { engine_reason=no_$bin; return 1; }; done
  pkg-config --exists hyprlang hyprutils || { engine_reason=no_hyprlang; return 1; }
  [ -f "$sys$breeze_dark" ] || { engine_reason=no_breeze_dark; return 1; }
  mkdir -p "$work/dl" "$work/engine"
  timeout 120 curl -fsSL -o "$work/dl/engine.tar.gz" "$engine_url" || refuse "qtengine_download url=$engine_url"
  local got log=$work/build-hyprqt6engine.log
  got=$(sha256sum "$work/dl/engine.tar.gz" | cut -d' ' -f1)
  [ "$got" = "$engine_sum" ] || refuse "qtengine_checksum got=$got want=$engine_sum"
  timeout 60 tar -xzf "$work/dl/engine.tar.gz" -C "$work/engine" --strip-components=1 || refuse "qtengine_unpack"
  timeout 120 cmake -S "$work/engine" -B "$work/engine/build" -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$lib/qt6" -DCMAKE_INSTALL_LIBDIR=lib -DPLUGINDIR="$lib/qt6/plugins" \
    -DCMAKE_INSTALL_RPATH="$lib/qt6/lib" -DCMAKE_REQUIRE_FIND_PACKAGE_KF6Config=ON \
    -DCMAKE_REQUIRE_FIND_PACKAGE_KF6ColorScheme=ON -DCMAKE_REQUIRE_FIND_PACKAGE_KF6IconThemes=ON >"$log" 2>&1 \
    || { tail -5 "$log"; engine_reason=configure_failed; return 1; }
  timeout 900 cmake --build "$work/engine/build" -j"$(nproc)" >>"$log" 2>&1 || { tail -5 "$log"; engine_reason=build_failed; return 1; }
  DESTDIR="$work/engine/stage" timeout 60 cmake --install "$work/engine/build" >>"$log" 2>&1 \
    || { tail -5 "$log"; engine_reason=install_failed; return 1; }
}

# chooses the extras in preflight, nothing is installed until every check has passed
recommend_plan() {
  local missing=() name answer
  chosen=()
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
  local pm kept=() skipped=()
  pm=$(manager)
  for name in "${chosen[@]}"; do
    case $name in
      bibata-ghost) fetched+=("$name") ;;
      hyprqt6engine) built+=("$name") ;;
      bibata-hyprcursor) converted+=("$name")
        hyprcursor_tools || [ "$pm" = unknown ] || read -ra tools <<< "$(extra_packages hyprcursor-tools "$pm")" ;;
      *) if [ "$pm" = unknown ]; then skipped+=("$name"); continue; fi
        read -ra answer <<< "$(extra_packages "$name" "$pm")"
        pkgs+=("${answer[@]}") ;;
    esac
    kept+=("$name")
  done
  [ ${#skipped[@]} = 0 ] || say "stage=recommend result=skipped reason=no_package_manager names=\"${skipped[*]}\""
  chosen=("${kept[@]}")
  [ $dry = 1 ] && say "stage=recommend result=dry_run would_install=\"${pkgs[*]}\" would_fetch=\"${fetched[*]}\" would_build=\"${built[*]}\" would_convert=\"${converted[*]}\" would_tools=\"${tools[*]}\""
  return 0
}

recommend_apply() {
  [ ${#chosen[@]} -gt 0 ] || return 1
  local pm name missing=()
  pm=$(manager)
  [ ${#fetched[@]} = 0 ] || fetch_cursor
  if [ ${#built[@]} -gt 0 ] && ! build_engine; then
    say "stage=qtengine result=fallback reason=$engine_reason packages=\"qt6ct kvantum\""
    built=()
    [ "$pm" = unknown ] || for name in qt6ct kvantum; do pkgs+=("$(extra_packages "$name" "$pm")"); done
  fi
  if [ ${#pkgs[@]} -gt 0 ]; then
    install_packages "$pm" "${pkgs[@]}" || refuse "recommended_install_failed manager=$pm packages=\"${pkgs[*]}\""
  fi
  [ ${#fetched[@]} = 0 ] || { track "${XDG_DATA_HOME:-$HOME/.local/share}/icons/$cursor_name"; swap_dir "$work/cursor/$cursor_name" "${XDG_DATA_HOME:-$HOME/.local/share}/icons/$cursor_name"; }
  [ ${#built[@]} = 0 ] || { track "$lib/qt6"; swap_dir "$work/engine/stage$lib/qt6" "$lib/qt6"; }
  # the tools only make the theme, a distribution without them still gets the xcursor one
  if [ ${#tools[@]} -gt 0 ] && ! install_packages "$pm" "${tools[@]}"; then
    say "stage=hyprcursor result=skipped reason=tools_install_failed packages=\"${tools[*]}\""
    converted=()
  fi
  if [ ${#converted[@]} -gt 0 ]; then
    if convert_cursor "$work/hyprcursor"; then
      track "${XDG_DATA_HOME:-$HOME/.local/share}/icons/$hyprcursor_name"
      swap_dir "$work/hyprcursor" "${XDG_DATA_HOME:-$HOME/.local/share}/icons/$hyprcursor_name"
    else
      say "stage=hyprcursor result=skipped reason=$hc_reason"
      converted=()
    fi
  fi
  mapfile -t missing < <(recommended)
  for name in "${chosen[@]}"; do
    [ "$name" = bibata-hyprcursor ] && [ ${#converted[@]} = 0 ] && continue
    [[ " ${missing[*]} " != *" $name "* ]] || refuse "still_missing name=$name packages=\"${pkgs[*]}\""
  done
  say "stage=recommend result=installed packages=\"${pkgs[*]}\" fetched=\"${fetched[*]}\" built=\"${built[*]}\""
}

# sets out and status of the caller so a failed probe can say how it failed
probe() {
  status=0
  out=$(timeout 10 "$1" --version 2>/dev/null) || status=$?
}

preflight() {
  if [ ! -f "$cfg/hyprland.lua" ] && [ -f "$cfg/hyprland.conf" ]; then
    refuse "hyprlang_config file=$cfg/hyprland.conf hint=fluency_needs_a_lua_config"
  fi
  [ ! -e "$share" ] || [ -f "$share/REVISION" ] || refuse "not_a_fluency_dir dir=$share"
  check_deps
  recommend_plan
  local hv qv out status absent=()
  # a dry run before the packages exist can only say what it would check
  if [ $dry = 1 ]; then
    have Hyprland || absent+=(Hyprland)
    have qs || absent+=(qs)
    [ ${#absent[@]} = 0 ] || { say "stage=preflight result=dry_run would_check=\"${absent[*]}\""; hypr_version=""; return; }
  fi
  probe Hyprland
  hv=$(sed -n '1s/^Hyprland \([0-9.]*\).*/\1/p' <<< "$out")
  [ -n "$hv" ] || refuse "no_hyprland_version status=$status"
  at_least "$hv" 0.56 || refuse "old_hyprland version=$hv need=0.56"
  probe qs
  qv=$(sed -n '1s/^Quickshell \([0-9.]*\).*/\1/p' <<< "$out")
  [ -n "$qv" ] || refuse "no_quickshell_version status=$status"
  at_least "$qv" 0.3 || refuse "old_quickshell version=$qv need=0.3"
  say "stage=preflight result=ok hyprland=$hv quickshell=$qv"
  hypr_version=$hv
}

# the committed tree when this is a git checkout, so a stray edit never ships
export_source() {
  mkdir -p "$work/src"
  # a release unpacked inside another repo is no checkout of its own
  if [ "$(git -C "$here" rev-parse --show-toplevel 2>/dev/null)" = "$(cd "$here" && pwd -P)" ]; then
    local dirty
    dirty=$(git -C "$here" status --porcelain -- shell hypr plugins native | cut -c4- | tr '\n' ',')
    [ -z "$dirty" ] || refuse "uncommitted_changes files=${dirty%,}"
    revision=$(git -C "$here" rev-parse --short HEAD)
    git -C "$here" archive HEAD shell hypr plugins native | tar -x -C "$work/src"
  else
    revision=archive
    cp -r "$here/shell" "$here/hypr" "$here/plugins" "$here/native" "$work/src/"
  fi
  say "stage=source result=ok revision=$revision"
}

fetch_fonts() {
  mkdir -p "$work/dl" "$work/fonts"
  [ $dry = 0 ] || { say "stage=fonts result=dry_run would_fetch=\"$fluent_url $selawik_url\""; return; }
  timeout 120 curl -fsSL -o "$work/dl/fluent.ttf" "$fluent_url" || refuse "font_download url=$fluent_url"
  timeout 120 curl -fsSL -o "$work/dl/selawik.zip" "$selawik_url" || refuse "font_download url=$selawik_url"
  local got
  got=$(sha256sum "$work/dl/fluent.ttf" | cut -d' ' -f1)
  [ "$got" = "$fluent_sum" ] || refuse "font_checksum file=FluentSystemIcons-Regular.ttf got=$got want=$fluent_sum"
  got=$(sha256sum "$work/dl/selawik.zip" | cut -d' ' -f1)
  [ "$got" = "$selawik_sum" ] || refuse "font_checksum file=Selawik_Release.zip got=$got want=$selawik_sum"
  cp "$work/dl/fluent.ttf" "$work/fonts/FluentSystemIcons-Regular.ttf"
  timeout 30 unzip -q -j "$work/dl/selawik.zip" '*.ttf' -d "$work/fonts" || refuse "font_unpack file=Selawik_Release.zip"
  cat > "$work/fontconf" <<'XML'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <alias binding="same">
    <family>Selawik</family>
    <accept>
      <family>Noto Sans</family>
      <family>Noto Sans CJK SC</family>
      <family>Noto Color Emoji</family>
    </accept>
  </alias>
</fontconfig>
XML
  say "stage=fonts result=fetched files=$(ls "$work/fonts" | wc -l)"
}

build_plugins() {
  mkdir -p "$work/lib"
  [ $plugins = 1 ] || { say "stage=plugins result=skipped"; return; }
  [ $dry = 0 ] || { say "stage=plugins result=dry_run would_build=\"$(ls "$work/src/plugins" | grep -v '\.sh$' | tr '\n' ' ')clipboard\""; return; }
  local pc
  pc=$(pkg-config --modversion hyprland 2>/dev/null) || refuse "plugin_headers reason=no_hyprland_pc"
  [ "$pc" = "$hypr_version" ] || refuse "plugin_headers headers=$pc running=$hypr_version"
  "$work/src/plugins/fluency-plugins.sh" build "$work/lib" > "$work/build-plugins.log" 2>&1 \
    || { tail -20 "$work/lib/build.log" 2>/dev/null; tail -5 "$work/build-plugins.log"; refuse "plugin_build"; }
  say "stage=plugins result=built files=$(ls "$work/lib"/*.so | wc -l)"
  "$work/src/native/clipboard/build.sh" "$work/clipd" > "$work/build-clipd.log" 2>&1 \
    || { tail -10 "$work/build-clipd.log"; refuse "clipboard_build"; }
  say "stage=clipboard result=built"
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
  local file categories
  file=$(entry_file "$1") || return 1
  categories=$(sed -n '/^\[Desktop Entry\]/,/^\[/s/^Categories=//p' "$file")
  [[ ";${categories%%$'\n'*};" == *";$2;"* ]]
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
  local kind=${2:-platformthemes}
  compgen -G "$sys/usr/lib*/qt6/plugins/$kind/$1" >/dev/null \
    || compgen -G "$sys/usr/lib/*/qt6/plugins/$kind/$1" >/dev/null
}

# an engine the user installed on purpose goes before the ones that come with a desktop
qt_theme() {
  if qt_plugin 'libqt6ct.so'; then echo qt6ct
  elif qt_plugin '*hyprqt6engine*.so' || [ -f "$engine_plugin" ]; then echo hyprqt6engine
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
  return 0
}

# values land in a lua string and a qml pragma, anything odd is refused
plain() { [[ $1 =~ ^[A-Za-z0-9._,+/\ -]*$ ]] || refuse "odd_value name=$2 value=\"$1\""; }

write_machine() {
  local theme term pins=() id
  theme=$(icon_theme)
  term=$(terminal)
  qt_engine=$(qt_theme)
  for id in "$(timeout 5 xdg-settings get default-web-browser 2>/dev/null)" "$(file_manager)" "$term"; do
    id=${id%.desktop}
    [ -n "$id" ] && has_entry "$id" && [[ " ${pins[*]} " != *" $id "* ]] && pins+=("$id")
  done
  local env=()
  [ -n "$term" ] && env+=("TERMINAL=$term")
  [ ${#pins[@]} -gt 0 ] && env+=("FLUENCY_PINS=$(IFS=,; echo "${pins[*]}")")
  # beside an integrated gpu the defaults pick per app, forcing nvidia would wake it always
  if [ -e "$sys/proc/driver/nvidia/version" ]; then
    if [ -d "$sys/sys/module/i915" ] || [ -d "$sys/sys/module/xe" ] || [ -d "$sys/sys/module/amdgpu" ]; then
      say "stage=machine note=hybrid_gpu nvidia_env=skipped"
    else
      env+=("__GLX_VENDOR_LIBRARY_NAME=nvidia")
      if compgen -G "$sys/usr/lib*/dri/nvidia_drv_video.so" >/dev/null || compgen -G "$sys/usr/lib/*/dri/nvidia_drv_video.so" >/dev/null; then
        env+=("LIBVA_DRIVER_NAME=nvidia" "NVD_BACKEND=direct")
      fi
    fi
  elif [ -d "$sys/sys/module/amdgpu" ]; then
    env+=("LIBVA_DRIVER_NAME=radeonsi" "VDPAU_DRIVER=radeonsi")
  fi
  [ -n "$qt_engine" ] && env+=("QT_QPA_PLATFORMTHEME=$qt_engine")
  if [ "$qt_engine" = hyprqt6engine ] && ! qt_plugin '*hyprqt6engine*.so'; then
    env+=("QT_PLUGIN_PATH=$lib/qt6/plugins")
  fi
  if cursor_exists && [ "${XCURSOR_THEME:-$cursor_name}" = "$cursor_name" ] \
    && ! grep -rqs --exclude-dir=fluency XCURSOR_THEME "$cfg"; then
    env+=("XCURSOR_THEME=$cursor_name")
    if hyprcursor_exists && [ "${HYPRCURSOR_THEME:-$hyprcursor_name}" = "$hyprcursor_name" ] \
      && ! grep -rqs --exclude-dir=fluency HYPRCURSOR_THEME "$cfg"; then
      env+=("HYPRCURSOR_THEME=$hyprcursor_name")
    fi
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
  rm -rf "$work/share"
  mkdir -p "$work/share"
  cp -r "$work/src/shell" "$work/share/shell"
  echo "$revision" > "$work/share/REVISION"
  sed -i "1s|^//@ pragma IconTheme .*|//@ pragma IconTheme $icon|" "$work/share/shell/shell.qml"
  grep -qx "//@ pragma IconTheme $icon" "$work/share/shell/shell.qml" || refuse "no_icon_pragma file=shell.qml"
}

# keys the user's own files bind that fluency binds too, both would fire on them
doubled_binds() {
  local line name combo files=() mods user=() found=() own
  mapfile -t files < <(find "$work/cand" -name '*.lua' -not -path "$work/cand/fluency/*" 2>/dev/null)
  [ ${#files[@]} -gt 0 ] || return 0
  mods=$(grep -hoE 'local mainMod *= *"[^"]+"' "${files[@]}" | head -1 | sed -E 's/.*"([^"]+)"/\1/' || true)
  while IFS= read -r line; do
    line=${line#*hl.bind(}
    line=$(sed -E "s/^ *mainMod *\.\. *\"/\"${mods:-SUPER}/" <<< "$line")
    user+=("$(tr -d ' "' <<< "${line^^}")")
  done < <(grep -hoE 'hl\.bind\( *("[^"]+"|mainMod *\.\. *"[^"]+")' "${files[@]}" || true)
  own=$(cat "$work/cand/fluency/local.lua" 2>/dev/null || true)
  while IFS= read -r line; do
    name=$(sed -E 's/^ *\[?"?([a-z-]+)"?\]? *=.*/\1/' <<< "$line")
    combo=$(sed -E 's/.*= *"([^"]+)".*/\1/' <<< "$line")
    grep -qE "(^|[^a-z-])\"?$name\"?\]? *= *false" <<< "$own" && continue
    [[ " ${user[*]} " == *" $(tr -d ' ' <<< "${combo^^}") "* ]] && found+=("$combo")
  done < <(sed -n '/^local defaults = {/,/^}/p' "$work/src/hypr/fluency/binds.lua" | grep '= "')
  [ ${#found[@]} = 0 ] || say "stage=binds warn=also_bound combos=\"$(IFS=,; echo "${found[*]}")\" hint=turn_one_off_in_fluency/local.lua"
  return 0
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
  rm -rf "$work/cand"
  mkdir -p "$work/cand"
  [ -d "$cfg" ] && cp -a "$cfg/." "$work/cand/"
  if [ -L "$cfg/hyprland.lua" ]; then
    local target
    target=$(readlink -m "$cfg/hyprland.lua")
    [ -e "$target" ] || refuse "dangling_config file=$cfg/hyprland.lua target=$target"
    grep -qx 'require("fluency")' "$target" || [ -w "$target" ] || refuse "read_only_config file=$target"
    rm "$work/cand/hyprland.lua"
    cp "$target" "$work/cand/hyprland.lua"
  fi
  rm -rf "$work/cand/fluency"
  cp -r "$work/src/hypr/fluency" "$work/cand/fluency"
  write_machine "$work/cand/fluency/generated.lua"
  # an install from before generated.lua wrote local.lua itself, that one moves aside
  if [ -f "$cfg/fluency/local.lua" ] && [ -f "$cfg/fluency/generated.lua" ]; then
    cp -p "$cfg/fluency/local.lua" "$work/cand/fluency/local.lua"
  else
    [ -f "$cfg/fluency/local.lua" ] && cp -p "$cfg/fluency/local.lua" "$work/cand/fluency/local.lua.bak-$stamp"
    printf '%s' "$local_template" > "$work/cand/fluency/local.lua"
  fi
  if [ -f "$work/cand/hyprland.lua" ]; then
    grep -qx 'require("fluency")' "$work/cand/hyprland.lua" || printf '%s' "$block" >> "$work/cand/hyprland.lua"
  else
    starter > "$work/cand/hyprland.lua"
  fi
  doubled_binds
  local out
  if [ $dry = 1 ] && ! have Hyprland; then say "stage=verify result=dry_run would_check=Hyprland"; return; fi
  out=$(timeout 30 Hyprland --verify-config -c "$work/cand/hyprland.lua" 2>&1) || {
    echo "$out" | sed -n '/Config parsing result/,$p' | tail -n +2 | head -20
    refuse "verify_failed config=$cfg/hyprland.lua"
  }
  say "stage=verify result=ok"
}

# selawik covers latin only, noto takes the rest
apply_fonts() {
  if same_tree "$work/fonts" "$fonts" && cmp -s "$work/fontconf" "$fontconf"; then say "stage=fonts result=same"; return; fi
  track "$fonts"
  swap_dir "$work/fonts" "$fonts"
  track "$fontconf"
  mkdir -p "$(dirname "$fontconf")"
  cp "$work/fontconf" "$fontconf"
  timeout 60 fc-cache -f "$fonts" >/dev/null 2>&1 || say "stage=fonts warn=fc_cache_failed"
  say "stage=fonts result=installed dir=$fonts"
}

apply_plugins() {
  [ $plugins = 1 ] || return 0
  track "$lib"
  mkdir -p "$lib"
  local so
  for so in "$work/lib"/*.so; do
    cp "$so" "$lib/.$(basename "$so").new"
    mv -f "$lib/.$(basename "$so").new" "$lib/$(basename "$so")"
  done
  # the loader rebuilds from these at login when hyprland changed
  swap_dir "$work/src/plugins" "$lib/plugins"
  cp "$work/lib/abi" "$lib/.abi.new" && mv -f "$lib/.abi.new" "$lib/abi"
  cp "$work/clipd/fluency-clipd" "$lib/.fluency-clipd.new" && mv -f "$lib/.fluency-clipd.new" "$lib/fluency-clipd"
  say "stage=plugins result=installed dir=$lib"
}

apply_shell() {
  if same_tree "$work/share" "$share"; then say "stage=shell result=same"; return; fi
  track "$share"
  swap_dir "$work/share" "$share"
  say "stage=shell result=installed dir=$share revision=$revision"
}

apply_config() {
  if same_tree "$work/cand/fluency" "$cfg/fluency" && cmp -s "$work/cand/hyprland.lua" "$cfg/hyprland.lua"; then
    say "stage=config result=same"
    return
  fi
  # modules first, the entry that requires them last
  track "$cfg/fluency"
  swap_dir "$work/cand/fluency" "$cfg/fluency"
  if [ ! -e "$cfg/hyprland.lua" ]; then
    track "$cfg/hyprland.lua"
    sed -i '/^made .*\/hyprland\.lua$/d' "$manifest"
    write_entry "$work/cand/hyprland.lua"
    note "entry starter $(sha256sum < "$cfg/hyprland.lua" | cut -c1-64)"
  elif ! cmp -s "$work/cand/hyprland.lua" "$cfg/hyprland.lua"; then
    backup "$cfg/hyprland.lua"
    write_entry "$work/cand/hyprland.lua"
    note "entry appended"
  fi
  say "stage=config result=installed dir=$cfg"
}

# a dark look for the engine this installer set up, never over a config the user has
apply_qt() {
  local conf
  case $qt_engine in
    hyprqt6engine) conf=$cfg/hyprqt6engine.conf ;;
    qt6ct) conf=${XDG_CONFIG_HOME:-$HOME/.config}/qt6ct/qt6ct.conf ;;
    *) return 0 ;;
  esac
  [ ! -e "$conf" ] || { say "stage=qttheme result=kept file=$conf"; return; }
  [ "$qt_engine" != hyprqt6engine ] || [ -f "$sys$breeze_dark" ] || { say "stage=qttheme result=skipped reason=no_breeze_dark"; return; }
  [ "$qt_engine" != qt6ct ] || qt_plugin libkvantum.so styles || { say "stage=qttheme result=skipped reason=no_kvantum"; return; }
  track "$conf"
  mkdir -p "$(dirname "$conf")"
  if [ "$qt_engine" = hyprqt6engine ]; then
    [ -f "$sys$breeze_dark" ] || { say "stage=qttheme result=skipped reason=no_breeze_dark"; return; }
    local style=Fusion
    qt_plugin breeze6.so styles && style=Breeze
    printf 'theme {\n    color_scheme = %s\n    style = %s\n    icon_theme = %s\n}\n' "$breeze_dark" "$style" "$icon" > "$conf"
  else
    qt_plugin libkvantum.so styles || { say "stage=qttheme result=skipped reason=no_kvantum"; return; }
    printf '[Appearance]\ncustom_palette=false\nicon_theme=%s\nstyle=kvantum-dark\n' "$icon" > "$conf"
  fi
  say "stage=qttheme result=written file=$conf"
}

# gtk gets the same dark look, a key the user ever set stays theirs
apply_gtk() {
  if ! command -v gsettings >/dev/null || ! command -v dconf >/dev/null; then
    say "stage=gtk result=skipped reason=no_gsettings"
    return
  fi
  local pairs=() set=() kept=() pair key
  gtk_theme_exists Breeze-Dark && pairs+=("gtk-theme=Breeze-Dark")
  pairs+=("color-scheme=prefer-dark" "icon-theme=$icon")
  cursor_exists && pairs+=("cursor-theme=$cursor_name")
  for pair in "${pairs[@]}"; do
    key=${pair%%=*}
    if [ -n "$(timeout 5 dconf read "/org/gnome/desktop/interface/$key" 2>/dev/null)" ]; then kept+=("$key"); continue; fi
    if timeout 5 gsettings set org.gnome.desktop.interface "$key" "${pair#*=}"; then set+=("$key"); note "gsettings $key"; else say "stage=gtk warn=set_failed key=$key"; fi
  done
  say "stage=gtk result=ok set=\"${set[*]}\" kept=\"${kept[*]}\""
}

reload() {
  [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || { say "stage=start result=next_login"; return; }
  local errors
  errors=$(timeout 5 hyprctl configerrors 2>/dev/null | grep -v '^$' || true)
  [ -z "$errors" ] || say "stage=reload warn=config_errors first=\"$(echo "$errors" | head -1)\""
  if [ $plugins = 1 ]; then
    # an older config loaded them itself, this reload unloads those so the loader can load them again
    timeout 10 hyprctl reload > /dev/null 2>&1 || say "stage=reload warn=reload_failed hint=hyprland_instance_signature_may_be_stale"
    if timeout 300 "$lib/plugins/fluency-plugins.sh" load --no-wait "$lib" > "$work/load.log" 2>&1; then say "stage=plugins result=loaded"
    else say "stage=plugins warn=not_loaded last=\"$(tail -1 "$work/load.log")\""; fi
  fi
  # a running daemon keeps its history and runs the new build from the next login
  if [ $plugins = 1 ] && ! timeout 5 "$lib/fluency-clipd" ctl list >/dev/null 2>&1; then
    timeout 5 hyprctl dispatch "hl.dsp.exec_cmd('$lib/fluency-clipd')" >/dev/null 2>&1 && say "stage=clipboard result=started"
  fi
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
# what the extras add is found again, so the machine file and the shell see it
if recommend_apply; then
  build_config
  build_shell
fi
apply_fonts
apply_plugins
apply_shell
apply_config
apply_qt
apply_gtk
reload
say "result=ok"
