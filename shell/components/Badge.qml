import QtQuick
import qs.tokens

Rectangle {
    id: root

    property string text: ""

    visible: text !== ""
    width: Math.max(height, Math.ceil(label.implicitWidth) + 2 * Metrics.badgePaddingX)
    height: Metrics.badgeHeight
    radius: height / 2
    color: Colors.badgeFill

    Text {
        id: label
        objectName: "label"
        anchors.centerIn: parent
        text: root.text
        color: Colors.badgeText
        font.family: Type.family
        font.pixelSize: Metrics.badgeFontSmall
    }
}
