import QtQuick
import qs.tokens
import "../logic/curve.mjs" as Curve
import "../logic/tray.mjs" as Tray
import "../logic/glyphs.mjs" as Glyphs

TrayButton {
    id: root

    property alias turning: turning
    property alias turn: turner.rotation

    width: Tray.cell(Metrics.trayGlyphSize, Metrics)

    Item {
        id: turner
        objectName: "turner"
        anchors.centerIn: parent
        width: Metrics.trayGlyphSize
        height: Metrics.trayGlyphSize
        rotation: root.checked ? Metrics.chevronTurn : 0

        Behavior on rotation {
            NumberAnimation {
                id: turning
                duration: Motion.chevronTurn
                easing.bezierCurve: Curve.easing(Motion.curveChevron)
            }
        }

        Text {
            objectName: "glyph"
            anchors.centerIn: parent
            text: Glyphs.glyph("up")
            color: root.foreground
            font.family: Type.iconFamily
            font.pixelSize: Metrics.trayGlyphSize
        }
    }
}
