# Fluency

A desktop shell for Hyprland with elements inspired by the [Fluent design language](https://en.wikipedia.org/wiki/Fluent_Design_System). It includes a taskbar with a Start menu, a system tray, quick settings, toasts, desktop icons, jump lists, title bars with caption buttons, and minimize to the taskbar. It is built with Quickshell and Hyprland's Lua config.

![Fluency at 1920x1080 with the Start menu open](media/desktop.png)

## Requirements

- Hyprland 0.56 or newer, with a Lua config (`~/.config/hypr/hyprland.lua`). A hyprlang `hyprland.conf` is refused.
- Quickshell 0.3 or newer.
- For the title bar and minimize plugins: `cmake`, `pkg-config`, a C++23 compiler, and Hyprland's headers for the version that is running.
- Runtime tools: `wl-clipboard`, `glib2` (`gio`, `gdbus`), `xdg-utils`, `systemd`, `zip`, `unzip`, `curl`, `fontconfig`.

The installer checks for all of these. Run it with `--deps` and it installs what is missing through `pacman`, `dnf`, `apt` or `zypper`, using `sudo` or `pkexec`.

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
- the default browser, file manager and terminal, as the first pins
- your icon theme
- the NVIDIA variables, only when an NVIDIA driver is loaded
- the KDE platform theme, only when it is installed

Running the installer again changes nothing unless something is new. If the shell is running, the installer reloads it. Otherwise it starts at your next login.

Other options:

```bash
./install.sh --dry-run      # check everything, write nothing
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
| Alt + F4 | close the window |

## Settings

These environment variables change the defaults:

- `FLUENCY_WALLPAPER`: path to another picture.
- `FLUENCY_PINS`: comma separated desktop ids for the first Start and taskbar pins.
- `FLUENCY_TRAY_SCREEN`: the output that shows the full tray. The default is the screen at 0,0.
- `FLUENCY_DESKTOP_DIR`: the folder shown on the desktop. The default is `~/Desktop`.

## Licenses

The title bar plugin is based on hyprbars by Vaxry (BSD 3-clause, `plugins/titlebar/LICENSE`). Selawik is under the SIL Open Font License. Fluent System Icons is under the MIT license. Both fonts are downloaded at install time and are not part of this repository.
