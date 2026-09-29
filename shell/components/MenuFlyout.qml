import QtQuick
import qs.tokens
import "../logic/curve.mjs" as Curve

Item {
    id: root

    property bool open: false
    property alias rows: panel.rows
    property alias drop: panel.drop
    property alias growing: growing
    property alias fading: fading

    signal chosen(int index)

    width: panel.width
    height: panel.height
    visible: open || fading.running

    onOpenChanged: {
        if (open) {
            fading.stop()
            panel.opacity = 1
            growing.restart()
        } else {
            growing.stop()
            fading.restart()
        }
    }

    MenuPanel {
        id: panel
        objectName: "menu"
        onChosen: index => root.chosen(index)
    }

    // numbers of the fluent menu popup transition
    NumberAnimation {
        id: growing
        target: panel
        property: "drop"
        from: panel.height * Metrics.menuClosedRatio
        to: 0
        duration: Motion.menuOpen
        easing.bezierCurve: Curve.easing(Motion.curveDecelerate)
    }

    NumberAnimation {
        id: fading
        target: panel
        property: "opacity"
        from: 1
        to: 0
        duration: Motion.menuFade
    }
}
