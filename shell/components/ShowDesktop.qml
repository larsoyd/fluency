import QtQuick
import qs.tokens

Item {
    id: root

    property bool forceHovered: false
    property bool forcePressed: false
    readonly property bool hovered: area.containsMouse || forceHovered
    readonly property bool pressed: area.pressed || forcePressed

    signal clicked()

    width: Metrics.showDesktopWidth
    height: Metrics.taskbarHeight

    Rectangle {
        objectName: "pipe"
        x: Math.round((parent.width - width) / 2)
        y: (parent.height - height) / 2
        width: Metrics.showDesktopPipeWidth
        height: Metrics.showDesktopPipeHeight
        radius: Metrics.showDesktopPipeRadius
        color: root.pressed ? Colors.showDesktopPipePressed : root.hovered ? Colors.showDesktopPipe : "transparent"
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
