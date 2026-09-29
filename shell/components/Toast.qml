import QtQuick
import qs.tokens
import "../logic/acrylic.mjs" as Acrylic

Item {
    id: root

    property string app: ""
    property url icon: ""
    property string title: ""
    property string body: ""
    readonly property var fill: Acrylic.fill({
        tint: [Colors.flyoutTint.r, Colors.flyoutTint.g, Colors.flyoutTint.b],
        luminosityOpacity: Colors.flyoutLuminosityOpacity,
    })

    signal activated()
    signal dismissed()

    width: Metrics.toastWidth
    height: column.height + 2 * Metrics.toastPadding

    Rectangle {
        objectName: "backdrop"
        anchors.fill: parent
        radius: Metrics.flyoutRadius
        color: Qt.rgba(root.fill.color[0], root.fill.color[1], root.fill.color[2], root.fill.alpha)
        border.width: Metrics.flyoutBorder
        border.color: Colors.flyoutStroke
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
    }

    Text {
        objectName: "close"
        anchors.right: parent.right
        anchors.top: parent.top
        width: Metrics.toastCloseSize
        height: Metrics.toastCloseSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: String.fromCharCode(0xe8bb)
        color: Colors.textSecondary
        font.family: Type.iconFamily
        font.pixelSize: Type.caption.size

        MouseArea {
            anchors.fill: parent
            onClicked: root.dismissed()
        }
    }
}
