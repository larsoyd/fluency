import QtQuick
import qs.tokens
import "../logic/tray.mjs" as Tray
import "../logic/glyphs.mjs" as Glyphs

TrayButton {
    id: root

    property string time: ""
    property string date: ""
    property bool bell: true
    readonly property int textWidth: Math.ceil(Math.max(first.implicitWidth, second.implicitWidth))
    readonly property var places: Tray.omni([{ width: textWidth + Metrics.clockMargin[2] }].concat(bell ? [{ width: Metrics.badgeMinWidth, bare: true }] : []), Metrics)

    width: places.width

    // the lines reach past their box on the right by the margin of the source
    component Line: Text {
        x: root.places.at[0]
        width: root.textWidth
        height: Type.caption.lineHeight
        horizontalAlignment: Text.AlignRight
        verticalAlignment: Text.AlignVCenter
        color: root.foreground
        font.family: Type.family
        font.pixelSize: Type.caption.size
        font.weight: Type.caption.weight
    }

    Line {
        id: first
        objectName: "time"
        y: Tray.clockTop(root.height, height, Metrics.clockMargin)
        text: root.time
    }

    Line {
        id: second
        objectName: "date"
        y: first.y + first.height
        text: root.date
    }

    Item {
        objectName: "bell"
        visible: root.bell
        x: root.places.at[1] ?? 0
        width: Metrics.badgeMinWidth
        height: parent.height

        Text {
            objectName: "glyph"
            anchors.centerIn: parent
            text: Glyphs.glyph("bell")
            color: root.foreground
            font.family: Type.iconFamily
            font.pixelSize: Metrics.trayGlyphSize
        }
    }
}
