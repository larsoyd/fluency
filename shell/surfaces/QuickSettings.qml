import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.tokens
import qs.components
import qs.services
import "../logic/curve.mjs" as Curve
import "../logic/volume.mjs" as Volume

PanelWindow {
    id: root

    property bool open: false
    property real shift: 1
    property alias sliding: sliding
    property alias panel: panel
    readonly property int reach: panel.height + Metrics.flyoutOffset

    visible: open || shift < 1
    anchors { right: true; bottom: true }
    margins.right: Metrics.flyoutOffset
    implicitWidth: panel.width
    implicitHeight: reach
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "fluency-quick"

    onOpenChanged: {
        shift = open ? 0 : 1
        if (!open) panel.reset()
    }

    Behavior on shift {
        NumberAnimation {
            id: sliding
            duration: Motion.calmed(root.open ? Motion.flyoutOpen : Motion.flyoutClose)
            easing.bezierCurve: Curve.easing(Motion.curveDecelerate)
        }
    }

    Item {
        objectName: "quick"
        anchors.fill: parent
        clip: true

        QuickPanel {
            id: panel
            objectName: "panel"
            y: root.shift * root.reach
            opacity: root.open ? 1 : 0
            level: Status.volume
            muted: Status.muted
            outputs: Volume.outputs(Status.nodes, Status.sink)
            apps: Volume.apps(Status.nodes)
            icon: names => Windows.icon(names[0] ?? "")
            onMoved: value => Status.setVolume(value)
            onMuteAsked: silent => Status.setMuted(silent)
            onChosen: id => Status.choose(id)
            onAppMoved: (ids, value) => Status.setApp(ids, value)

            Behavior on opacity {
                NumberAnimation { duration: Motion.controlFaster }
            }
        }
    }
}
