//@ pragma IconTheme Papirus-Dark
//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.services
import qs.surfaces

ShellRoot {
    // deploys swap the directory and reload over ipc
    settings.watchFiles: false

    Variants {
        model: Quickshell.screens

        Wallpaper {
            required property var modelData
            screen: modelData
        }
    }

    // desktop icons stay on the main screen
    DesktopView {
        id: desktop
        screen: Quickshell.screens.find(screen => screen.name === Quickshell.env("FLUENCY_DESKTOP_SCREEN")) ?? Quickshell.screens.find(screen => screen.x === 0 && screen.y === 0) ?? Quickshell.screens[0]
    }

    Variants {
        id: bars
        model: Quickshell.screens

        Taskbar {
            required property var modelData
            screen: modelData
        }
    }

    Toasts {
        id: toasts
        screen: Quickshell.screens.find(screen => screen.name === TrayHost.screen) ?? Quickshell.screens[0]
    }

    // quick settings shows the level itself
    VolumeOsd {
        id: osd
        screen: Quickshell.screens.find(screen => screen.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        quiet: bars.instances.some(bar => bar.quick.open)
    }

    // the installer swaps the directory and reloads without a restart
    IpcHandler {
        target: "fluency"
        function reload(): void { Quickshell.reload(false) }
    }
}
