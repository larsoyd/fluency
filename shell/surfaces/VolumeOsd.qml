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
    property bool quiet: false
    property real shift: 1
    property var last: ({})
    property alias sliding: sliding
    property alias hiding: hiding
    readonly property int reach: pill.height + Metrics.osdGap

    function state() {
        return { ready: Status.ready, sink: Status.sink, volume: Status.volume, muted: Status.muted }
    }

    // the quick settings slider already shows the level
    function check() {
        const next = state()
        if (Volume.osd(last, next) && !quiet) {
            open = true
            hiding.restart()
        }
        last = next
    }

    visible: open || shift < 1
    anchors { left: true; bottom: true }
    margins.left: Math.round((screen.width - pill.width) / 2)
    implicitWidth: pill.width
    implicitHeight: reach
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "fluency-osd"

    onOpenChanged: shift = open ? 0 : 1
    // a binding would follow the change before check sees it
    Component.onCompleted: last = state()

    Connections {
        target: Status
        function onVolumeChanged() { root.check() }
        function onMutedChanged() { root.check() }
        function onSinkChanged() { root.check() }
        function onReadyChanged() { root.check() }
    }

    Timer {
        id: hiding
        interval: Motion.osdShown
        onTriggered: pill.hovered ? restart() : root.open = false
    }

    Behavior on shift {
        NumberAnimation {
            id: sliding
            duration: Motion.calmed(root.open ? Motion.flyoutOpen : Motion.flyoutClose)
            easing.bezierCurve: Curve.easing(Motion.curveDecelerate)
        }
    }

    Item {
        objectName: "osd"
        anchors.fill: parent
        clip: true

        OsdPill {
            id: pill
            objectName: "pill"
            y: root.shift * root.reach
            opacity: root.open ? 1 : 0
            level: Status.volume
            muted: Status.muted
            onMoved: value => Status.setVolume(value)

            Behavior on opacity {
                NumberAnimation { duration: Motion.controlFaster }
            }
        }
    }
}
