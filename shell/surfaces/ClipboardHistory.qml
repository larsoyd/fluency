import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.tokens
import qs.components
import qs.services
import "../logic/curve.mjs" as Curve

PanelWindow {
    id: root

    property bool open: false
    property real shift: 1
    property bool grabbing: false
    property real anchorX: 0
    property alias sliding: sliding
    property alias panel: panel
    readonly property int reach: panel.height + Metrics.flyoutOffset

    function act(result: string): void {
        open = false
        if (result !== "ok") console.log(`[clipboard] pick result="${result}"`)
    }

    visible: open || shift < 1
    anchors { left: true; bottom: true }
    margins.left: Math.round(Math.max(Metrics.flyoutOffset, Math.min(screen.width - panel.width - Metrics.flyoutOffset, anchorX - panel.width / 2)))
    implicitWidth: panel.width
    implicitHeight: reach
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "fluency-clipboard"
    WlrLayershell.keyboardFocus: !open ? WlrKeyboardFocus.None : grabbing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

    onOpenChanged: {
        sliding.duration = Motion.calmed(open ? Motion.flyoutOpen : Motion.flyoutClose)
        sliding.easing.bezierCurve = Curve.easing(open ? Motion.curveDecelerate : Motion.curveAccelerate)
        shift = open ? 0 : 1
        if (!open) return
        panel.query = ""
        panel.cursor = -1
        panel.opened = -1
        panel.forceActiveFocus()
        grabbing = true
    }

    FrameAnimation {
        running: root.grabbing
        onTriggered: if (currentFrame > 1) root.grabbing = false
    }

    Behavior on shift {
        NumberAnimation { id: sliding }
    }

    Item {
        objectName: "history"
        anchors.fill: parent
        clip: true

        ClipboardPanel {
            id: panel
            objectName: "panel"
            y: root.shift * root.reach
            entries: Clipboard.entries
            now: Clock.now.getTime()
            maxHeight: root.screen.height - Metrics.taskbarHeight - 2 * Metrics.flyoutOffset
            nameOf: app => Windows.entry(app)?.name ?? app
            iconOf: app => Windows.icon(app)
            onPicked: id => root.act(Clipboard.select(id))
            onAsText: id => root.act(Clipboard.asText(id))
            onPinned: (id, on) => Clipboard.pin(id, on)
            onRemoved: id => Clipboard.remove(id)
            onCleared: Clipboard.clear()
            onDismissed: root.open = false
        }
    }
}
