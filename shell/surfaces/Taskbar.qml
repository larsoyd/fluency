import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.tokens
import qs.components
import qs.services
import "../logic/clock.mjs" as Pictures
import "../logic/tasks.mjs" as Tasks
import "../logic/tray.mjs" as Tray
import "../logic/volume.mjs" as Volume

PanelWindow {
    id: root

    property alias bar: bar
    property alias overflow: overflow
    property alias trayMenu: trayMenu
    property alias start: start
    property alias quick: quick
    property alias jump: jump
    readonly property var icons: Tray.split(TrayHost.items)
    readonly property var lines: Pictures.lines(Clock.now, Clock.pictures)

    anchors { left: true; right: true; bottom: true }
    implicitHeight: Metrics.taskbarHeight
    exclusiveZone: Metrics.taskbarHeight
    color: "transparent"
    WlrLayershell.namespace: "fluency-taskbar"

    Bar {
        id: bar
        objectName: "bar"
        anchors.fill: parent
        trayWidth: tray.width
        startOpen: start.open
        tasks: Tasks.arrange(Tasks.group(Windows.pinned, Tasks.visible(Windows.windows, root.screen.name, Windows.mode)), (Windows.orders[root.screen.name] ?? []))
        icon: appId => Windows.icon(appId)
        progress: appId => Windows.progress(appId)
        badge: appId => Windows.badge(appId)
        onRequested: action => Windows.run(action)
        onActivated: name => { if (name === "start") start.open = !start.open }
        onJumpAsked: (key, x) => jump.show(key, x)
        onReordered: keys => Windows.arrange(keys, root.screen.name)

        TrayArea {
            id: tray
            objectName: "tray"
            anchors.right: parent.right
            full: TrayHost.screen === root.screen.name
            icons: root.icons.shown
            hidden: root.icons.hidden.length
            open: overflow.open
            quickOpen: quick.open
            glyphs: Tray.glyphs(Status)
            time: root.lines[0]
            date: root.lines[1]
            onToggled: overflow.open = !overflow.open
            onPressed: (key, input, x, y) => TrayHost.press(key, input, root, tray.x + x, y)
            onScrolled: (key, delta) => TrayHost.scroll(key, delta)
            onAsked: name => name === "status" ? quick.open = !quick.open : Windows.run({ action: name })
            onTurned: delta => Status.setVolume(Volume.wheel(Status.volume, delta))
            onHiddenChanged: if (hidden === 0) overflow.open = false
        }
    }

    TrayOverflow {
        id: overflow
        screen: root.screen
        icons: root.icons.hidden
        anchorX: tray.x + Metrics.trayIconMinWidth / 2
        onPressed: (key, input, x, y) => TrayHost.press(key, input, overflow, x, y)
        onScrolled: (key, delta) => TrayHost.scroll(key, delta)
    }

    TrayMenu {
        id: trayMenu
        screen: root.screen
    }

    StartMenu {
        id: start
        screen: root.screen
    }

    QuickSettings {
        id: quick
        screen: root.screen
    }

    JumpList {
        id: jump
        screen: root.screen
        task: bar.byKey[key] ?? null
    }

    // x is inside the window that asked, the overflow sits away from the screen edge
    Connections {
        target: TrayHost
        function onMenuAsked(handle, window, x) {
            if (window === root) trayMenu.show(handle, x)
            if (window === overflow) trayMenu.show(handle, overflow.margins.left + x)
        }
    }

    HyprlandFocusGrab {
        windows: [root, overflow]
        active: overflow.open
        onCleared: overflow.open = false
    }

    // hyprland posts it on a lone super tap, the bar of the focused monitor answers
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "custom" || Hyprland.focusedMonitor?.name !== root.screen.name) return
            if (event.data === "fluency-start") start.open = !start.open
            if (event.data === "fluency-sound") {
                quick.panel.page = "sound"
                quick.open = true
            }
        }
    }

    HyprlandFocusGrab {
        windows: [root, start]
        active: start.open
        onCleared: start.open = false
    }

    HyprlandFocusGrab {
        windows: [jump]
        active: jump.open
        onCleared: jump.open = false
    }

    HyprlandFocusGrab {
        windows: [root, quick]
        active: quick.open
        onCleared: quick.open = false
    }
}
