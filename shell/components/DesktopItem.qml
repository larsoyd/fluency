import QtQuick
import QtQuick.Shapes
import qs.tokens
import "../logic/desktop.mjs" as Desktop
import "../logic/glyphs.mjs" as Glyphs

Item {
    id: root

    required property var m
    property url source
    property string label
    property bool link: false
    property bool hovered: false
    property bool selected: false
    property bool active: false
    property bool current: false
    property bool cue: false
    property bool cut: false
    property bool editing: false
    readonly property bool whole: selected && active && current
    readonly property int lines: Math.max(1, label.lineCount)

    width: m.plateWidth
    height: Desktop.plateHeight(m, lines)

    Rectangle {
        id: plate
        objectName: "plate"
        width: parent.width
        height: parent.height
        visible: root.hovered || root.selected
        color: !root.selected ? Colors.desktopHoverFill
             : !root.active ? Colors.desktopIdleFill
             : root.hovered ? Colors.desktopHotFill : Colors.desktopSelectedFill
        border.width: 1
        border.color: !root.selected ? Colors.desktopHoverStroke
                    : !root.active ? Colors.desktopIdleFill
                    : root.hovered ? Colors.desktopHotStroke : Colors.desktopSelectedStroke
    }

    Shape {
        objectName: "cue"
        anchors.fill: parent
        visible: root.cue && root.current && root.active

        ShapePath {
            strokeColor: Colors.desktopLabel
            strokeWidth: 1
            strokeStyle: ShapePath.DashLine
            dashPattern: [1, 1]
            fillColor: "transparent"
            startX: 0.5; startY: 0.5
            PathLine { x: root.width - 0.5; y: 0.5 }
            PathLine { x: root.width - 0.5; y: root.height - 0.5 }
            PathLine { x: 0.5; y: root.height - 0.5 }
            PathLine { x: 0.5; y: 0.5 }
        }
    }

    Image {
        id: icon
        objectName: "icon"
        x: (root.width - root.m.icon) / 2
        y: root.m.pad
        width: root.m.icon
        height: root.m.icon
        sourceSize: Qt.size(root.m.icon, root.m.icon)
        source: root.source
        opacity: root.cut ? 0.5 : 1
        asynchronous: true

        // no measurement behind the arrow, it follows the look of the shortcut overlay
        Rectangle {
            objectName: "arrow"
            visible: root.link
            width: Math.round(root.m.icon / 3)
            height: width
            y: parent.height - height
            radius: 2
            color: "white"
            border.width: 1
            border.color: "#40000000"

            Text {
                anchors.centerIn: parent
                text: Glyphs.glyph("shortcut")
                color: Colors.desktopArrow
                font.family: Type.iconFamily
                font.pixelSize: parent.width - 4
            }
        }
    }

    // offset copies stand in for the blurred shadow, effects draw nothing without a gpu
    Repeater {
        model: Metrics.desktopShadow

        Text {
            required property var modelData
            required property int index
            objectName: "shadow:" + index
            visible: !root.editing
            x: label.x + modelData[0]
            y: label.y + modelData[1]
            width: label.width
            text: root.label
            color: Colors.desktopShadow
            opacity: modelData[2]
            font: label.font
            horizontalAlignment: label.horizontalAlignment
            wrapMode: label.wrapMode
            maximumLineCount: label.maximumLineCount
            elide: label.elide
            lineHeightMode: label.lineHeightMode
            lineHeight: label.lineHeight
        }
    }

    Text {
        id: label
        objectName: "label"
        visible: !root.editing
        x: (root.width - width) / 2
        y: root.m.pad + root.m.icon
        width: root.m.labelWidth
        text: root.label
        color: Colors.desktopLabel
        font.family: Type.family
        font.pixelSize: 12
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        maximumLineCount: root.whole ? 100 : 2
        elide: Text.ElideRight
        lineHeightMode: Text.FixedHeight
        lineHeight: root.m.line
    }
}
