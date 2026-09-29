import QtQuick
import qs.tokens

Item {
    id: root

    property bool forceHovered: false
    property bool forcePressed: false
    property point point: Qt.point(width / 2, height / 2)
    readonly property bool hovered: area.containsMouse || forceHovered
    readonly property bool pressed: area.pressed || forcePressed

    signal clicked()
    signal menuRequested()

    height: Metrics.startFooterButton

    Rectangle {
        objectName: "fill"
        anchors.fill: parent
        radius: Metrics.buttonRadius
        color: root.pressed ? Colors.menuItemPressed : root.hovered ? Colors.menuItemHover : "transparent"

        Behavior on color {
            ColorAnimation { duration: Motion.plateFade }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button !== Qt.RightButton) return root.clicked()
            root.point = Qt.point(mouse.x, mouse.y)
            root.menuRequested()
        }
    }
}
