import QtQuick
import qs.tokens
import "../logic/curve.mjs" as Curve
import "../logic/volume.mjs" as Volume

Item {
    id: root

    property real value: 0
    property bool thumb: true
    readonly property real travel: width - (thumb ? Metrics.sliderThumb : 0)
    readonly property real centre: (thumb ? Metrics.sliderThumb / 2 : 0) + value * travel

    signal moved(real value)

    function at(x) {
        return Volume.clamp((x - (thumb ? Metrics.sliderThumb / 2 : 0)) / travel)
    }

    height: Metrics.sliderHeight

    Rectangle {
        objectName: "rail"
        y: (parent.height - height) / 2
        width: parent.width
        height: Metrics.sliderTrack
        radius: Metrics.sliderTrackRadius
        color: Colors.sliderRail
    }

    Rectangle {
        objectName: "fill"
        y: (parent.height - height) / 2
        width: root.value >= 1 ? root.width : root.centre
        height: Metrics.sliderTrack
        radius: Metrics.sliderTrackRadius
        color: area.pressed ? Colors.sliderFillPressed : area.containsMouse ? Colors.sliderFillHover : Colors.sliderFill
    }

    Rectangle {
        objectName: "thumb"
        visible: root.thumb
        x: root.centre - width / 2
        y: (parent.height - height) / 2
        width: Metrics.sliderThumb
        height: Metrics.sliderThumb
        radius: width / 2
        color: Colors.sliderThumbOuter
        border.width: 1
        border.color: Colors.sliderThumbStroke

        Rectangle {
            objectName: "inner"
            property alias growing: growing
            anchors.centerIn: parent
            width: Metrics.sliderInnerThumb
            height: Metrics.sliderInnerThumb
            radius: width / 2
            color: area.pressed ? Colors.sliderFillPressed : area.containsMouse ? Colors.sliderFillHover : Colors.sliderFill
            scale: area.pressed ? Metrics.sliderThumbPressed : area.containsMouse ? Metrics.sliderThumbHover : 1

            Behavior on scale {
                NumberAnimation {
                    id: growing
                    duration: Motion.controlNormal
                    easing.bezierCurve: Curve.easing(Motion.curveControl)
                }
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onPressed: mouse => root.moved(root.at(mouse.x))
        onPositionChanged: mouse => { if (pressed) root.moved(root.at(mouse.x)) }
        onWheel: turn => root.moved(Volume.wheel(root.value, turn.angleDelta.y))
    }
}
