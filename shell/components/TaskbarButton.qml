import QtQuick
import qs.tokens
import "../logic/bounce.mjs" as Bounce
import "../logic/curve.mjs" as Curve
import "../logic/layout.mjs" as Layout
import "../logic/tasks.mjs" as Tasks

Item {
    id: root

    property string glyph: ""
    property url source: ""
    property int windows: 0
    property real progress: -1
    property string badge: ""
    property bool active: false
    property bool attention: false
    property bool forceHovered: false
    property bool forcePressed: false
    property int wheelCarry: 0
    property real slide: 0
    property bool slideAnimated: false
    property bool dragging: false
    property real grabbedAt: 0
    property bool wasDragged: false
    property alias sliding: sliding
    property var bounceFrames: []
    property real bounceClock: 0
    property alias bouncing: bouncing
    readonly property real bounceOffset: Bounce.offset(bounceFrames, bounceClock)
    readonly property bool hovered: area.containsMouse || forceHovered
    readonly property bool pressed: area.pressed || forcePressed
    readonly property bool multi: windows > 1
    readonly property var box: Layout.plate(Metrics)

    signal clicked()
    signal middleClicked()
    signal menuRequested()
    signal scrolled(int steps)
    signal dragged(real dx)
    signal dropped()

    function bounce(name: string): string {
        if (!Array.isArray(Motion[name])) return `refused: no keyframes ${name}`
        bounceFrames = Motion[name]
        bouncing.restart()
        return "ok"
    }

    width: Metrics.buttonExtent
    height: Metrics.taskbarHeight
    transform: Translate { x: root.slide }

    Behavior on slide {
        enabled: root.slideAnimated && !root.dragging
        NumberAnimation {
            id: sliding
            duration: Motion.reflow
            easing.bezierCurve: Curve.easing(Motion.curvePointToPoint)
        }
    }

    NumberAnimation {
        id: bouncing
        target: root
        property: "bounceClock"
        from: 0
        to: Bounce.total(root.bounceFrames)
        duration: to
    }

    Item {
        id: panel
        objectName: "panel"
        x: root.box.x
        y: root.box.y
        width: root.box.width
        height: root.box.height

        Plate {
            objectName: "plate"
            width: parent.width - (root.multi ? Metrics.multiWindowInset : 0)
            height: parent.height
            active: root.active
            attention: root.attention
            hovered: root.hovered
            pressed: root.pressed
            multi: root.multi
        }

        Plate {
            objectName: "stack"
            anchors.fill: parent
            visible: root.multi
            active: root.active
            attention: root.attention
            hovered: root.hovered
            pressed: root.pressed
            multi: root.multi
        }

        Indicator {
            objectName: "indicator"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Metrics.indicatorBottomMargin
            visible: !line.visible
            windows: root.windows
            active: root.active
            attention: root.attention
        }

        TaskProgress {
            id: line
            objectName: "progress"
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Metrics.indicatorBottomMargin
            width: parent.width
            value: root.progress
        }
    }

    Item {
        id: icon
        objectName: "icon"
        anchors.centerIn: parent
        width: Metrics.iconSize
        height: Metrics.iconSize
        scale: root.pressed && !root.dragging ? Metrics.iconPressedScale : 1
        opacity: root.pressed ? Metrics.iconPressedOpacity : 1
        Behavior on scale {
            NumberAnimation {
                duration: root.pressed ? Motion.controlFaster : Motion.controlFast
                easing.bezierCurve: Curve.easing(Motion.curveControl)
            }
        }
        Behavior on opacity {
            NumberAnimation { duration: Motion.plateFade }
        }
        transform: Translate { y: root.bounceOffset }

        Image {
            objectName: "image"
            anchors.fill: parent
            visible: root.glyph === ""
            source: root.source
            sourceSize: Qt.size(width, height)
            cache: false
        }

        Text {
            objectName: "glyph"
            anchors.centerIn: parent
            visible: root.glyph !== ""
            text: root.glyph
            color: Colors.textPrimary
            font.family: Type.iconFamily
            font.pixelSize: Metrics.iconSize
        }
    }

    Badge {
        objectName: "badge"
        anchors.right: icon.right
        anchors.bottom: icon.bottom
        anchors.rightMargin: -Metrics.badgeOffset
        anchors.bottomMargin: -Metrics.badgeOffset
        text: root.badge
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onPressed: mouse => {
            root.grabbedAt = mapToItem(null, mouse.x, 0).x
            root.wasDragged = false
        }
        onPositionChanged: mouse => {
            if (!(mouse.buttons & Qt.LeftButton)) return
            const dx = mapToItem(null, mouse.x, 0).x - root.grabbedAt
            if (!root.dragging && Math.abs(dx) <= Metrics.dragThreshold) return
            root.dragging = root.wasDragged = true
            root.dragged(dx)
        }
        onReleased: {
            if (!root.dragging) return
            root.dragging = false
            root.dropped()
        }
        onClicked: mouse => {
            if (root.wasDragged) return
            if (mouse.button === Qt.RightButton) root.menuRequested()
            else if (mouse.button === Qt.MiddleButton) root.middleClicked()
            else root.clicked()
        }
        onWheel: turn => {
            const { steps, carry } = Tasks.wheel(root.wheelCarry, turn.angleDelta.y)
            root.wheelCarry = carry
            if (steps) root.scrolled(steps)
        }
    }
}
