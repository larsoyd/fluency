import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.tokens
import qs.components
import qs.services
import "../logic/clipboard.mjs" as Clip
import "../logic/curve.mjs" as Curve

PanelWindow {
    id: root

    property bool open: false
    property real shift: 1
    property real anchorX: 0
    property string owner: ""
    property string ownerApp: ""
    property string pasting: ""
    property bool handBack: true
    property alias sliding: sliding
    property alias panel: panel
    readonly property int reach: panel.height + Metrics.flyoutOffset

    function act(result: string): void {
        open = false
        if (result !== "ok") console.log(`[clipboard] pick result="${result}"`)
    }

    visible: open || shift < 1
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "fluency-clipboard"
    WlrLayershell.layer: WlrLayer.Overlay
    // an exclusive layer gets every click, so it covers the screen to see clicks outside
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: {
        sliding.duration = Motion.calmed(open ? Motion.flyoutOpen : Motion.flyoutClose)
        sliding.easing.bezierCurve = Curve.easing(open ? Motion.curveDecelerate : Motion.curveAccelerate)
        shift = open ? 0 : 1
        if (!open) {
            if (handBack && owner) Hyprland.dispatch(Clip.focus(owner))
            console.log(`[clipboard] closed hand_back=${handBack} owner=${owner || "none"}`)
            return
        }
        owner = Hyprland.activeToplevel?.address ?? ""
        ownerApp = Hyprland.activeToplevel?.wayland?.appId ?? ""
        handBack = true
        panel.query = ""
        panel.cursor = -1
        panel.opened = -1
        panel.forceActiveFocus()
    }

    // the daemon answers once hyprland holds the new selection, only then the paste finds it
    Connections {
        target: Clipboard
        function onAnswered(request, result) {
            if (request !== root.pasting) return
            root.pasting = ""
            const paste = result === "ok" && root.owner ? Clip.paste(root.owner, root.ownerApp) : ""
            console.log(`[clipboard] paste request="${request}" result="${result}" app=${root.ownerApp || "none"}`)
            if (paste) Hyprland.dispatch(paste)
        }
    }

    Behavior on shift {
        NumberAnimation { id: sliding }
    }

    Item {
        objectName: "history"
        anchors.fill: parent

        // a click on the taskbar keeps the window the user came from, a click on a window gives it the keys
        MouseArea {
            objectName: "outside"
            anchors.fill: parent
            enabled: root.open
            onClicked: mouse => {
                root.handBack = mouse.y >= root.height - Metrics.taskbarHeight
                root.open = false
            }
        }

        Item {
            objectName: "flyout"
            x: Math.round(Math.max(Metrics.flyoutOffset, Math.min(root.width - panel.width - Metrics.flyoutOffset, root.anchorX - panel.width / 2)))
            y: root.height - Metrics.taskbarHeight - root.reach
            width: panel.width
            height: root.reach
            clip: true

            // clicks on the panel stay in the panel
            MouseArea {
                anchors.fill: panel
            }

            ClipboardPanel {
                id: panel
                objectName: "panel"
                y: root.shift * root.reach
                entries: Clipboard.entries
                now: Clock.now.getTime()
                maxHeight: root.height - Metrics.taskbarHeight - 2 * Metrics.flyoutOffset
                nameOf: app => Windows.entry(app)?.name ?? app
                iconOf: app => Windows.icon(app)
                onPicked: id => root.act(Clipboard.select(id))
                onAsText: id => {
                root.pasting = `text ${id}`
                root.act(Clipboard.asText(id))
            }
                onPinned: (id, on) => Clipboard.pin(id, on)
                onRemoved: id => Clipboard.remove(id)
                onCleared: Clipboard.clear()
                onDismissed: root.open = false
            }
        }
    }
}
