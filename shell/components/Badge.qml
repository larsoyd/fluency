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

    FontMetrics {
        id: metrics
        font: label.font
    }

    // centre the digits, not the line box of a font with a deep descender
    Text {
        id: label
        objectName: "label"
        anchors.centerIn: parent
        anchors.verticalCenterOffset: Math.round((metrics.descent + metrics.tightBoundingRect("0").height - metrics.ascent) / 2)
        width: Math.ceil(implicitWidth)
        horizontalAlignment: Text.AlignHCenter
        text: root.text
        color: Colors.badgeText
        font.family: Type.family
        font.pixelSize: Metrics.badgeFontSmall
    }
}
