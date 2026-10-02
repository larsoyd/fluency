import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.tokens
import qs.components
import qs.services
import "../logic/tray.mjs" as Tray

// previews never take the keyboard, the window under them keeps it
PanelWindow {
    id: root

    property var task: null
    property real anchorX: 0
    property real fade: open ? 1 : 0
    property alias panel: panel
    property string pending: ""
    readonly property bool open: task !== null && task.windows.length > 0
    readonly property bool hovered: inside.hovered

    signal done()

    function pick(address: string): void {
        pending = address
        done()
    }

    // an unmap under the pointer hands the keys to the window below, the pick has to come after that
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "closelayer" || event.data !== "fluency-preview" || !root.pending) return
            Windows.run({ action: "focus", address: root.pending })
            root.pending = ""
        }
    }

    visible: open || fade > 0
    anchors { left: true; bottom: true }
    margins.left: Tray.flyoutX(anchorX, panel.width, screen.width, Metrics.flyoutOffset)
    implicitWidth: Math.max(1, panel.width)
    implicitHeight: Math.max(1, panel.height + Metrics.flyoutOffset)
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "fluency-preview"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Behavior on fade {
        NumberAnimation { duration: Motion.switcherFade }
    }

    Item {
        objectName: "preview"
        anchors.fill: parent
        opacity: root.fade

        HoverHandler { id: inside }

        PreviewPanel {
            id: panel
            objectName: "panel"
            room: root.screen.width - 2 * Metrics.flyoutOffset
            preview: Component {
                ScreencopyView {
                    readonly property bool ready: hasContent
                    captureSource: root.visible ? Windows.toplevel(parent.address) : null
                    live: root.visible
                }
            }
            onPicked: address => root.pick(address)
            onCloseAsked: address => Windows.run({ action: "close", address })
        }

        // the cards hold still while the panel fades away
        Binding {
            target: panel
            property: "items"
            value: root.task ? root.task.windows.map(win => ({ address: win.address, title: win.title, icon: Windows.icon(win.appId), size: win.size })) : []
            when: root.open
            restoreMode: Binding.RestoreNone
        }
    }
}
