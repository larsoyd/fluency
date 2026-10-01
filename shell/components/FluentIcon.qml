import QtQuick
import qs.tokens
import "../logic/glyphs.mjs" as Glyphs

Item {
    id: root

    property string name: ""
    property color color: Colors.textPrimary
    property int size: 16

    implicitWidth: size
    implicitHeight: size

    Image {
        objectName: "image"
        anchors.centerIn: parent
        width: root.size
        height: root.size
        visible: source != ""
        source: root.name ? Glyphs.source(root.name, root.color) : ""
        sourceSize: Qt.size(root.size, root.size)
        opacity: root.color.a
    }

    Text {
        objectName: "glyph"
        anchors.centerIn: parent
        visible: text !== ""
        text: root.name && !Glyphs.source(root.name, root.color) ? Glyphs.char(root.name) : ""
        color: root.color
        font.family: Type.iconFamily
        font.pixelSize: root.size
    }
}
