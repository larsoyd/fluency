import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.tokens
import qs.components
import qs.services
import "../logic/switcher.mjs" as Switcher

// hyprland posts the keys, so the switcher never takes the keyboard from the window under it
PanelWindow {
    id: root

    property bool holding: false
    property bool shown: false
    property var list: []
    property int index: -1
    property alias panel: panel

    function begin(by: int): void {
        if (holding) {
            index = Switcher.step(index, by, list.length)
            return
        }
        Hyprland.refreshToplevels()
        list = Switcher.order(Windows.windows, Hyprland.monitors.values.map(monitor => monitor.activeWorkspace?.name ?? ""))
        if (!list.length) return
        holding = true
        index = by > 0 ? Switcher.first(list.length) : list.length - 1
        delay.restart()
    }

    function end(address: string): void {
        holding = shown = false
        delay.stop()
        if (address) Windows.run({ action: "focus", address })
    }

    visible: shown
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: Math.max(1, panel.width)
    implicitHeight: Math.max(1, panel.height)
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "fluency-switch"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Timer {
        id: delay
        interval: Motion.switcherDelay
        onTriggered: root.shown = root.holding
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "custom") return
            if (event.data === "fluency-switch-next") root.begin(1)
            if (event.data === "fluency-switch-prev") root.begin(-1)
            if (event.data === "fluency-switch-done" && root.holding) root.end(root.list[root.index]?.address ?? "")
            if (event.data === "fluency-switch-cancel") root.end("")
        }
    }

    SwitcherPanel {
        id: panel
        objectName: "switcher"
        opacity: root.shown ? 1 : 0
        maxWidth: root.screen.width - 2 * Metrics.switcherEdge
        maxHeight: root.screen.height - 2 * Metrics.switcherEdge
        selectedIndex: root.index
        items: root.list.map(win => ({ address: win.address, title: win.title, icon: Windows.icon(win.appId), size: win.size }))
        preview: Component {
            ScreencopyView {
                readonly property bool ready: hasContent
                captureSource: root.shown ? Windows.toplevel(parent.address) : null
                live: root.shown
            }
        }
        onPicked: address => root.end(address)
        onCloseAsked: address => {
            Windows.run({ action: "close", address })
            root.list = root.list.filter(win => win.address !== address)
            root.index = Math.min(root.index, root.list.length - 1)
        }

        Behavior on opacity {
            NumberAnimation { duration: Motion.switcherFade }
        }
    }
}
