import QtQuick
import qs.tokens
import "../logic/curve.mjs" as Curve
import "../logic/indicator.mjs" as Logic

Rectangle {
    id: root

    property int windows: 0
    property bool active: false
    property bool attention: false
    property bool shown: false
    property alias resize: resize
    readonly property var item: ({ windows, active, attention })

    width: shown ? Logic.width(item, Metrics) : 0
    height: Metrics.indicatorHeight
    radius: Metrics.indicatorRadius
    color: Logic.fill(item, Colors)

    Component.onCompleted: shown = true

    Behavior on width {
        NumberAnimation {
            id: resize
            duration: Motion.indicatorResize
            easing.bezierCurve: Curve.easing(Motion.curveIndicator)
        }
    }
}
