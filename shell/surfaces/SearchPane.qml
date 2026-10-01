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
    property alias sliding: sliding
    property alias panel: panel
    readonly property int reach: panel.height + Metrics.flyoutOffset

    function act(action: string, kind: string, key: string): string {
        if (action !== "open") return action.endsWith("-taskbar") ? Windows.pin(action.slice(0, -"-taskbar".length), key) : Apps.pin(action, key)
        open = false
        return kind === "folder" ? Apps.open(key) : Apps.launch(key)
    }

    visible: open || shift < 1
    anchors { left: true; bottom: true }
    margins.left: Math.round((screen.width - panel.width) / 2)
    implicitWidth: panel.width
    implicitHeight: reach
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "fluency-search"
    // map exclusive for the keyboard, then on demand gives the pointer back
    WlrLayershell.keyboardFocus: !open ? WlrKeyboardFocus.None : grabbing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

    onOpenChanged: {
        sliding.duration = Motion.calmed(open ? Motion.searchOpen : Motion.searchClose)
        sliding.easing.bezierCurve = Curve.easing(open ? Motion.curveDecelerate : Motion.curveStartClose)
        shift = open ? 0 : 1
        if (!open) return
        panel.query = ""
        panel.tab = "all"
        panel.typing = false
        panel.forceActiveFocus()
        grabbing = true
    }

    FrameAnimation {
        running: root.grabbing
        onTriggered: if (currentFrame > 1) root.grabbing = false
    }

    Behavior on shift {
        NumberAnimation {
            id: sliding
            onRunningChanged: if (!running && root.open) panel.typing = true
        }
    }

    Item {
        objectName: "searchpane"
        anchors.fill: parent
        clip: true

        SearchPanel {
            id: panel
            objectName: "panel"
            y: root.shift * root.reach
            entries: Apps.entries
            links: Apps.links
            pins: Apps.pins
            taskbarPins: Windows.pinned
            launches: Apps.launches
            onActed: (action, kind, key) => root.act(action, kind, key)
            onDismissed: root.open = false
        }
    }
}
