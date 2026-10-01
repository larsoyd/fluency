import QtQuick
import QtQuick.Effects
import qs.tokens
import "../logic/glyphs.mjs" as Glyphs

// a title row over the window, the row fades as the window grows back to its place
Item {
    id: root

    property string title: ""
    property url icon: ""
    property bool selected: false
    property rect home
    property rect target
    property real zoom: 0
    property alias holder: holder
    property bool live: false
    readonly property bool hovered: area.containsMouse

    signal clicked()
    signal closeClicked()
    signal middleClicked()

    x: home.x + (target.x - home.x) * zoom
    y: home.y + (target.y - home.y) * zoom
    width: home.width + (target.width - home.width) * zoom
    height: home.height + (target.height - home.height) * zoom

    Rectangle {
        objectName: "plate"
        anchors.fill: parent
        anchors.margins: -Metrics.notifyInset
        radius: Metrics.flyoutRadius
        opacity: 1 - root.zoom
        color: root.hovered || root.selected ? Colors.itemFillPrimary : "transparent"
    }

    Rectangle {
        objectName: "ring"
        anchors.fill: parent
        anchors.margins: -Metrics.notifyInset
        visible: root.selected && !root.zoom
        radius: Metrics.flyoutRadius
        color: "transparent"
        border.width: Metrics.taskViewRing
        border.color: Colors.focusStroke
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => mouse.button === Qt.MiddleButton ? root.middleClicked() : root.clicked()
    }

    Item {
        width: parent.width
        height: Metrics.taskViewTitle
        opacity: 1 - root.zoom

        Image {
            x: 0
            anchors.verticalCenter: parent.verticalCenter
            width: Metrics.taskViewIcon
            height: Metrics.taskViewIcon
            sourceSize: Qt.size(width, height)
            source: root.icon
        }

        Text {
            objectName: "title"
            x: Metrics.taskViewIcon + Metrics.notifyInset
            width: close.x - x - Metrics.notifyInset
            anchors.verticalCenter: parent.verticalCenter
            renderType: Text.NativeRendering
            text: root.title
            elide: Text.ElideRight
            color: Colors.textPrimary
            font.family: Type.family
            font.pixelSize: Type.caption.size
        }

        Rectangle {
            id: close
            objectName: "close"
            visible: root.hovered || root.selected
            x: parent.width - width
            anchors.verticalCenter: parent.verticalCenter
            width: Metrics.taskViewClose
            height: Metrics.taskViewClose
            radius: Metrics.buttonRadius
            color: shut.containsMouse ? Colors.menuItemHover : "transparent"

            Text {
                anchors.centerIn: parent
                text: Glyphs.glyph("close")
                color: Colors.textPrimary
                font.family: Type.iconFamily
                font.pixelSize: Type.caption.size
            }

            MouseArea {
                id: shut
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.closeClicked()
            }
        }
    }

    Rectangle {
        objectName: "thumb"
        y: Metrics.taskViewTitle
        width: parent.width
        height: parent.height - y
        radius: Metrics.flyoutRadius * (1 - root.zoom)
        color: Colors.cardFill
        clip: true

        Image {
            objectName: "fallback"
            visible: !root.live
            anchors.centerIn: parent
            width: Metrics.searchPreviewIcon
            height: Metrics.searchPreviewIcon
            sourceSize: Qt.size(width, height)
            source: root.icon
        }

        // clip does not follow a radius, the mask rounds the live picture
        Item {
            id: holder
            objectName: "holder"
            anchors.fill: parent
            layer.enabled: root.live
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: corners
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }
        }

        Rectangle {
            id: corners
            anchors.fill: parent
            radius: parent.radius
            visible: false
            layer.enabled: true
        }
    }
}
