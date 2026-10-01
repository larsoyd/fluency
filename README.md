# Fluency

A desktop shell for Hyprland with elements inspired by the [Fluent design language](https://en.wikipedia.org/wiki/Fluent_Design_System). It includes a taskbar with a Start menu, a system tray, quick settings, toasts, desktop icons, jump lists, title bars with caption buttons, and minimize to the taskbar. It is built with Quickshell and Hyprland's Lua config.

![Fluency at 1920x1080 with the Start menu open](media/desktop.png)

<sub>Shown with the [Papirus Dark](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme) icons and the Bibata Ghost cursor from [Bibata Translucent](https://github.com/Silicasandwhich/Bibata_Cursor_Translucent).</sub>

## Requirements

- Hyprland 0.56 or newer, with a Lua config (`~/.config/hypr/hyprland.lua`). A hyprlang `hyprland.conf` is refused.
- Quickshell 0.3 or newer.
- For the title bar and minimize plugins: `cmake`, `pkg-config`, a C++23 compiler, and Hyprland's headers for the version that is running.
- Runtime tools: `wl-clipboard`, `glib2` (`gio`, `gdbus`), `xdg-utils`, `systemd`, `zip`, `unzip`, `curl`, `fontconfig`.
- The QML modules QtQuick.Shapes and Qt.labs.folderlistmodel. Debian ships them apart from Qt Quick, as `qml6-module-qtquick-shapes` and `qml6-module-qt-labs-folderlistmodel`.

The installer checks for all of these. Run it with `--deps` and it installs what is missing through `pacman`, `dnf` or `apt`, using `sudo` or `pkexec`.

Recommended, not required:

| what | offered when | package |
|---|---|---|
| Papirus icons | you have no icon theme besides the stock ones (hicolor, Adwaita) | `papirus-icon-theme` (on Fedora also `papirus-icon-theme-dark`) |
| kitty, the terminal | kitty is missing | `kitty` |
| Dolphin, the file manager | you have no file manager | `dolphin` |
| Bibata Ghost, the cursor | it is missing | none, see below |
| Bibata Ghost as a Hyprcursor theme | it is missing | the tools that make it, `hyprcursor` and `xcur2png`, on Debian and Ubuntu `hyprcursor-util` and `xcur2png` (on Fedora `xcur2png` comes from the sdegler/hyprland COPR) |
| hyprqt6engine, the Qt theme engine | you have no Qt engine (qt6ct, hyprqt6engine or KDE's) | none, see below |
| Breeze for GTK | you have no GTK theme besides the stock ones (Adwaita, HighContrast) | `breeze-gtk`, on Debian and Ubuntu `breeze-gtk-theme`, on Fedora `breeze-gtk-gtk3` and `breeze-gtk-gtk4` |
| Noto fonts | Noto Sans is missing | Noto Sans, Noto Sans CJK and Noto Color Emoji, named per distribution |

When one of them is offered, the installer asks whether to install it. `--recommended` installs them all without asking, and `--no-recommended` skips them. Without a terminal to ask on, it only names them.

No distribution packages the cursor, so the installer downloads the Bibata Translucent 1.1.2 release from GitHub, checks its SHA-256 and puts Bibata Ghost in `~/.local/share/icons`. `--uninstall` leaves it there, like the packages.

Hyprland loads Hyprcursor themes natively, so the installer also converts Bibata Ghost into `~/.local/share/icons/Bibata_Ghost_Hyprcursor` with `hyprcursor-util` and `xcur2png`. The artwork keeps every size and frame, and the original theme stays for apps that draw their own cursor. It installs the two tools from your distribution when they are missing and keeps them. If the distribution has no package for one, the installer says so and keeps plain Bibata Ghost.

hyprqt6engine is not packaged either, so the installer builds it from a pinned commit of its GitHub repository into `~/.local/lib/fluency/qt6`, for your user only. The build needs `cmake`, a C++ compiler, the hyprlang and hyprutils headers, Qt 6.9 or newer with its private headers, the KF6 Config, ColorScheme and IconThemes headers, and Breeze for its colours. When any of that is missing or the build fails, the installer installs qt6ct and Kvantum from your repository instead.

The engine gets a dark look, but only when it has no config yet: hyprqt6engine gets Breeze Dark in `~/.config/hypr/hyprqt6engine.conf`, and qt6ct gets the dark Kvantum style in `~/.config/qt6ct/qt6ct.conf`. A config you already have is never changed.

GTK apps follow the same dark look through gsettings: the Breeze Dark theme when it is installed, the dark colour scheme, your icon theme and Bibata Ghost. Only settings you never changed yourself are set, anything you chose stays.

Selawik only covers Latin scripts. A fontconfig file in `~/.config/fontconfig/conf.d/50-fluency.conf` makes Noto Sans, Noto Sans CJK and Noto Color Emoji the fallback for everything else. `--uninstall` removes it.

## Versions

| branch | built for |
|---|---|
| `main` | Hyprland 0.56.2, the version Arch Linux ships |
| `canary` | Hyprland `main`, last built against e826317 on 2026-09-30 |

Install from `main`. `canary` follows Hyprland's development branch and gets fixes for it before a release reaches Arch.

## Install

```bash
git clone <this repository> fluency
cd fluency
./install.sh            # or ./install.sh --deps
```

The installer checks everything first and writes nothing if a check fails:

1. Hyprland and Quickshell versions.
2. Fonts. It downloads Selawik (OFL) and Fluent System Icons (MIT) at pinned versions and checks their SHA-256.
3. Plugins. The plugin headers must match the running Hyprland, then it builds both plugins.
4. Config. It builds your config with Fluency added and runs `Hyprland --verify-config` on it.

Only after all of that passes does it write:

| what | where |
|---|---|
| the shell | `~/.local/share/fluency/shell` |
| plugins | `~/.local/lib/fluency` |
| fonts | `~/.local/share/fonts/fluency` |
| config modules | `~/.config/hypr/fluency/` |
| one line appended to `hyprland.lua` | `require("fluency")` |

Your `hyprland.lua` is backed up to `hyprland.lua.bak-<time>` before the require line is added. If you have no config yet, a small starter is written.

Anything specific to your machine goes into `~/.config/hypr/fluency/local.lua`:

- your terminal
- the default browser, file manager and terminal, as the first pins. The folder handler counts as the file manager only when it is one, otherwise the first installed of Dolphin, Nautilus, Thunar, Nemo, PCManFM and Caja is used
- your icon theme. One chosen in KDE comes first, then Papirus Dark when it is installed, then the GTK default
- Bibata Ghost as the cursor when it is installed, and its Hyprcursor theme when that is there too, unless your own config or environment sets another
- the NVIDIA video variables when an NVIDIA driver is loaded, otherwise the AMD ones (`radeonsi`) when `amdgpu` is loaded
- a Qt platform theme, the first one installed of qt6ct, hyprqt6engine (also the one the installer built), KDE and GTK

Running the installer again changes nothing unless something is new. If the shell is running, the installer reloads it. Otherwise it starts at your next login.

Other options:

```bash
./install.sh --dry-run      # check everything, write nothing
./install.sh --recommended  # also install Papirus, kitty, Dolphin and Bibata Ghost
./install.sh --no-plugins   # skip the title bar and minimize plugins
./install.sh --uninstall    # remove fluency and the require line
```

## Keys

| key | action |
|---|---|
| Super | Start |
| Super + Up | maximize, or restore what Super + Down minimized |
| Super + Down | minimize to the taskbar |
| Super + Ctrl + V | volume mixer |
| Super + S | search |
| Super + Tab | task view, with new desktops that stay until closed |
| Super + N | notifications and calendar |
| Alt + Tab | switch windows while Alt is held, Shift goes back |
| Alt + F4 | close the window |

## Settings

These environment variables change the defaults:

- `FLUENCY_WALLPAPER`: path to another picture.
- `FLUENCY_PINS`: comma separated desktop ids for the first Start and taskbar pins.
- `FLUENCY_TRAY_SCREEN`: the output that shows the full tray. The default is the screen at 0,0.
- `FLUENCY_DESKTOP_DIR`: the folder shown on the desktop. The default is `~/Desktop`.

## Licenses

Fluency is under the MIT license, see `LICENSE`. The title bar plugin is based on hyprbars by Vaxry (BSD 3-clause, `plugins/titlebar/LICENSE`). Selawik is under the SIL Open Font License. Fluent System Icons is under the MIT license. Both fonts are downloaded at install time and are not part of this repository. Bibata Translucent is under the GPL 3.0 and hyprqt6engine is under the BSD 3-clause license. Both are only downloaded when you choose them.
