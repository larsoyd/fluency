import QtQuick
import qs.tokens
import "../logic/tray.mjs" as Tray

TrayButton {
    id: root

    property var glyphs: []
    readonly property var places: Tray.omni(glyphs.map(() => ({ width: Metrics.trayGlyphSize })), Metrics)

    width: places.width

    component Glyph: FluentIcon {
        anchors.centerIn: parent
        color: root.foreground
        size: Metrics.trayGlyphSize
    }

    Repeater {
        model: root.glyphs

        Item {
            required property var modelData
            required property int index
            objectName: modelData.name
            x: root.places.at[index] ?? 0
            y: (root.height - height) / 2
            width: Metrics.trayGlyphSize
            height: Metrics.trayGlyphSize

            Glyph {
                objectName: "underlay"
                visible: name !== ""
                name: modelData.underlay ?? ""
                opacity: Metrics.trayUnderlayOpacity
            }

            Glyph {
                objectName: "base"
                name: modelData.base
            }
        }
    }
}
