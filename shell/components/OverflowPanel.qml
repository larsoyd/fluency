import QtQuick
import qs.tokens
import "../logic/acrylic.mjs" as Acrylic
import "../logic/tray.mjs" as Tray
import "../logic/curve.mjs" as Curve

Item {
    id: root

    property var icons: []
    property alias resizing: resizing
    readonly property var grid: Tray.flyout(icons.length, Metrics)
    readonly property var fill: Acrylic.fill({
        tint: [Colors.flyoutTint.r, Colors.flyoutTint.g, Colors.flyoutTint.b],
        luminosityOpacity: Colors.flyoutLuminosityOpacity,
    })

    signal pressed(string key, string input, real x, real y)
    signal scrolled(string key, int delta)

    width: grid.width
    height: grid.height

    Behavior on width {
        NumberAnimation {
            duration: Motion.resize
            easing.bezierCurve: Curve.easing(Motion.curvePointToPoint)
        }
    }

    Behavior on height {
        NumberAnimation {
            id: resizing
            duration: Motion.resize
            easing.bezierCurve: Curve.easing(Motion.curvePointToPoint)
        }
    }

    Slots {
        id: slots
        items: root.icons
    }

    Rectangle {
        objectName: "backdrop"
        anchors.fill: parent
        radius: Metrics.flyoutRadius
        color: Qt.rgba(root.fill.color[0], root.fill.color[1], root.fill.color[2], root.fill.alpha)
        border.width: Metrics.flyoutBorder
        border.color: Colors.flyoutStroke
    }

    Grid {
        x: Metrics.flyoutBorder + Metrics.overflowGridMargin
        y: Metrics.flyoutBorder + Metrics.overflowGridMargin
        columns: Metrics.overflowColumns

        Repeater {
            model: slots

            TrayIcon {
                required property string key
                readonly property point place: mapToItem(root, pointer.x, pointer.y)
                objectName: "icon:" + key
                width: Metrics.overflowCell
                height: Metrics.overflowCell
                inset: 0
                source: slots.byKey[key].icon
                onClicked: root.pressed(key, "click", place.x, place.y)
                onMiddleClicked: root.pressed(key, "middle", place.x, place.y)
                onMenuRequested: root.pressed(key, "menu", place.x, place.y)
                onScrolled: delta => root.scrolled(key, delta)
            }
        }
    }
}
