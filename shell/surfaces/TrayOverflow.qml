import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.tokens
import qs.components
import "../logic/curve.mjs" as Curve
import "../logic/tray.mjs" as Tray

PanelWindow {
    id: root

    property bool open: false
    property var icons: []
    property real anchorX: 0
    property real shift: 1
    property alias sliding: sliding
    readonly property int reach: panel.height + Metrics.flyoutOffset

    signal pressed(string key, string input, real x, real y)
    signal scrolled(string key, int delta)

    visible: open || shift < 1
    anchors { left: true; bottom: true }
    margins.left: Tray.flyoutX(anchorX, panel.width, screen.width, Metrics.flyoutOffset)
    implicitWidth: panel.width
    implicitHeight: reach
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "fluency-flyout"

    onOpenChanged: shift = open ? 0 : 1

    Behavior on shift {
        NumberAnimation {
            id: sliding
            duration: root.open ? Motion.flyoutOpen : Motion.flyoutClose
            easing.bezierCurve: Curve.easing(Motion.curveDecelerate)
        }
    }

    Item {
        objectName: "overflow"
        anchors.fill: parent
        clip: true

        OverflowPanel {
            id: panel
            objectName: "panel"
            y: root.shift * root.reach
            opacity: root.open ? 1 : 0
            icons: root.icons
            onPressed: (key, input, x, y) => root.pressed(key, input, x, y)
            onScrolled: (key, delta) => root.scrolled(key, delta)

            Behavior on opacity {
                NumberAnimation { duration: Motion.controlFaster }
            }
        }
    }
}
