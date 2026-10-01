import QtQuick
import qs.tokens
import "../logic/acrylic.mjs" as Acrylic
import "../logic/tray.mjs" as Tray

Item {
    id: root

    property real level: 0
    property bool muted: false
    readonly property bool hovered: hover.hovered
    readonly property var fill: Acrylic.fill({
        tint: [Colors.flyoutTint.r, Colors.flyoutTint.g, Colors.flyoutTint.b],
        luminosityOpacity: Colors.flyoutLuminosityOpacity,
    })

    signal moved(real value)

    width: Metrics.osdWidth
    height: Metrics.osdHeight

    HoverHandler { id: hover }

    Rectangle {
        objectName: "backdrop"
        anchors.fill: parent
        radius: Metrics.flyoutRadius
        color: Qt.rgba(root.fill.color[0], root.fill.color[1], root.fill.color[2], root.fill.alpha)
        border.width: Metrics.flyoutBorder
        border.color: Colors.flyoutStroke
    }

    Item {
        x: Metrics.osdGlyphX
        y: (parent.height - height) / 2
        width: Metrics.trayGlyphSize
        height: Metrics.trayGlyphSize

        FluentIcon {
            objectName: "glyph"
            anchors.centerIn: parent
            name: Tray.volume(root.level, root.muted)
            color: Colors.textPrimary
            size: Metrics.trayGlyphSize
        }
    }

    VolumeSlider {
        objectName: "slider"
        x: Metrics.osdRailX
        y: Math.round((parent.height - height) / 2)
        width: Metrics.osdRailWidth
        thumb: false
        value: root.level
        onMoved: value => root.moved(value)
    }
}
