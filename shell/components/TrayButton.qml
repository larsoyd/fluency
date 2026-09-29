import QtQuick
import qs.tokens

Item {
    id: root

    property bool checked: false
    property int inset: Metrics.trayPaddingY
    property bool forceHovered: false
    property bool forcePressed: false
    readonly property bool hovered: area.containsMouse || forceHovered
    readonly property bool pressed: area.pressed || forcePressed
    readonly property color foreground: plate.look.text
    readonly property point pointer: Qt.point(area.mouseX, area.mouseY)
    default property alias content: holder.data

    signal clicked()
    signal middleClicked()
    signal menuRequested()
    signal scrolled(int delta)

    height: Metrics.taskbarHeight

    Plate {
        id: plate
        objectName: "plate"
        y: root.inset
        width: parent.width
        height: parent.height - 2 * root.inset
        radius: Metrics.trayRadius
        tray: true
        checked: root.checked
        hovered: root.hovered
        pressed: root.pressed
    }

    Item {
        id: holder
        anchors.fill: parent
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) root.menuRequested()
            else mouse.button === Qt.MiddleButton ? root.middleClicked() : root.clicked()
        }
        onWheel: turn => root.scrolled(turn.angleDelta.y)
    }
}
