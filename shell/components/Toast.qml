import QtQuick
import qs.tokens
import "../logic/acrylic.mjs" as Acrylic
import "../logic/glyphs.mjs" as Glyphs

Item {
    id: root

    property string app: ""
    property url icon: ""
    property string title: ""
    property string body: ""
    property bool card: false
    property real progress: -1
    property string status: ""
    property string valueText: ""
    property var buttons: []
    readonly property var fill: Acrylic.fill({
        tint: [Colors.flyoutTint.r, Colors.flyoutTint.g, Colors.flyoutTint.b],
        luminosityOpacity: Colors.flyoutLuminosityOpacity,
    })

    signal activated()
    signal dismissed()
    signal invoked(string id)

    width: Metrics.toastWidth
    height: column.height + 2 * Metrics.toastPadding + (actions.visible ? Metrics.toastSectionGap + actions.height : 0)

    Rectangle {
        objectName: "backdrop"
        anchors.fill: parent
        radius: Metrics.flyoutRadius
        color: root.card ? Colors.cardFill : Qt.rgba(root.fill.color[0], root.fill.color[1], root.fill.color[2], root.fill.alpha)
        border.width: Metrics.flyoutBorder
        border.color: root.card ? Colors.cardStroke : Colors.flyoutStroke
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.activated()
    }

    Column {
        id: column
        x: Metrics.toastPadding
        y: Metrics.toastPadding
        width: parent.width - 2 * Metrics.toastPadding - Metrics.toastCloseSize
        spacing: 4

        Item {
            width: parent.width
            height: Math.max(16, appName.implicitHeight)

            Image {
                id: appIcon
                objectName: "appIcon"
                width: 16
                height: 16
                anchors.verticalCenter: parent.verticalCenter
                source: root.icon
                sourceSize: Qt.size(16, 16)
            }

            Text {
                id: appName
                objectName: "app"
                renderType: Text.NativeRendering
                x: 24
                width: parent.width - x
                anchors.verticalCenter: parent.verticalCenter
                text: root.app
                elide: Text.ElideRight
                color: Colors.textSecondary
                font.family: Type.family
                font.pixelSize: Type.caption.size
            }
        }

        Text {
            objectName: "title"
            renderType: Text.NativeRendering
            width: parent.width
            text: root.title
            elide: Text.ElideRight
            color: Colors.textPrimary
            font.family: Type.family
            font.pixelSize: Type.bodyStrong.size
            font.weight: Type.bodyStrong.weight
        }

        Text {
            objectName: "body"
            renderType: Text.NativeRendering
            width: parent.width
            text: root.body
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            color: Colors.textSecondary
            font.family: Type.family
            font.pixelSize: Type.body.size
        }

        // the column's own spacing is part of the gap above the bar
        Item {
            objectName: "progress"
            visible: root.progress >= 0
            width: parent.width
            height: Metrics.toastSectionGap - column.spacing + Metrics.toastProgressHeight + 4 + statusText.height

            Rectangle {
                objectName: "track"
                y: Metrics.toastSectionGap - column.spacing + (Metrics.toastProgressHeight - height) / 2
                width: parent.width
                height: Metrics.toastProgressTrack
                color: Colors.toastProgressTrack
            }

            Rectangle {
                objectName: "fill"
                y: Metrics.toastSectionGap - column.spacing
                width: parent.width * Math.min(1, Math.max(0, root.progress))
                height: Metrics.toastProgressHeight
                radius: height / 2
                color: Colors.toastProgressFill
            }

            Text {
                id: statusText
                objectName: "status"
                renderType: Text.NativeRendering
                y: Metrics.toastSectionGap - column.spacing + Metrics.toastProgressHeight + 4
                width: parent.width - valueLabel.width - 8
                text: root.status
                elide: Text.ElideRight
                color: Colors.textSecondary
                font.family: Type.family
                font.pixelSize: Type.caption.size
            }

            Text {
                id: valueLabel
                objectName: "value"
                renderType: Text.NativeRendering
                anchors.right: parent.right
                y: statusText.y
                text: root.valueText
                color: Colors.textSecondary
                font.family: Type.family
                font.pixelSize: Type.caption.size
            }
        }
    }

    Row {
        id: actions
        objectName: "buttons"
        visible: root.buttons.length > 0
        x: Metrics.toastPadding
        y: column.y + column.height + Metrics.toastSectionGap
        width: root.width - 2 * Metrics.toastPadding
        spacing: Metrics.toastButtonGap

        Repeater {
            model: root.buttons

            Rectangle {
                required property var modelData
                objectName: "button:" + modelData.id
                width: (actions.width - actions.spacing * (root.buttons.length - 1)) / root.buttons.length
                height: Metrics.toastButtonHeight
                radius: Metrics.controlRadius
                color: press.pressed ? Colors.controlFillPressed : press.containsMouse ? Colors.controlFillHover : Colors.controlFill
                border.width: 1
                border.color: Colors.controlStroke

                Text {
                    objectName: "label"
                    renderType: Text.NativeRendering
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, parent.width - 16)
                    text: parent.modelData.text
                    elide: Text.ElideRight
                    color: press.pressed ? Colors.textSecondary : Colors.textPrimary
                    font.family: Type.family
                    font.pixelSize: Type.body.size
                }

                MouseArea {
                    id: press
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.invoked(parent.modelData.id)
                }
            }
        }
    }

    Text {
        objectName: "close"
        anchors.right: parent.right
        anchors.top: parent.top
        width: Metrics.toastCloseSize
        height: Metrics.toastCloseSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: Glyphs.glyph("close")
        color: Colors.textSecondary
        font.family: Type.iconFamily
        font.pixelSize: Type.caption.size

        MouseArea {
            anchors.fill: parent
            onClicked: root.dismissed()
        }
    }
}
