import QtQuick
import qs.tokens
import "../logic/curve.mjs" as Curve
import "../logic/scroll.mjs" as Scroll

// shows while the pointer is over the view or it moves, then fades after a pause
Item {
    id: root

    required property Flickable view
    property bool watching: false
    readonly property bool needed: view.contentHeight > view.height
    readonly property bool wide: rail.containsMouse || rail.pressed
    readonly property var place: Scroll.thumb(view.contentY, view.height, view.contentHeight, height, Metrics.scrollThumbLeast)
    property real grabbedY: 0
    property bool awake: false

    width: Metrics.scrollBar
    visible: needed
    opacity: awake || wide ? 1 : 0
    onWatchingChanged: wake()

    function wake() {
        awake = true
        sleep.restart()
    }

    Connections {
        target: root.view
        function onContentYChanged() { root.wake() }
    }

    Timer {
        id: sleep
        interval: Metrics.scrollHideDelay
        onTriggered: root.awake = root.watching
    }

    Behavior on opacity {
        NumberAnimation { duration: Motion.controlFaster }
    }

    MouseArea {
        id: rail
        anchors.fill: parent
        hoverEnabled: true
        onPressed: mouse => {
            root.grabbedY = mouse.y - thumb.y
            if (mouse.y < thumb.y || mouse.y > thumb.y + thumb.height) root.grabbedY = thumb.height / 2
            root.view.contentY = Scroll.fromThumb(mouse.y - root.grabbedY, thumb.height, root.height, root.view.height, root.view.contentHeight)
        }
        onPositionChanged: mouse => {
            if (pressed) root.view.contentY = Scroll.fromThumb(mouse.y - root.grabbedY, thumb.height, root.height, root.view.height, root.view.contentHeight)
        }
    }

    Rectangle {
        id: thumb
        objectName: "scrollThumb"
        x: root.width - width - Metrics.scrollThumbGap
        y: root.place.y
        width: root.wide ? Metrics.scrollThumbWide : Metrics.scrollThumbThin
        height: root.place.h
        radius: width / 2
        color: Colors.scrollThumb

        Behavior on width {
            NumberAnimation {
                duration: Motion.controlFast
                easing.bezierCurve: Curve.easing(Motion.curveDecelerate)
            }
        }
    }
}
