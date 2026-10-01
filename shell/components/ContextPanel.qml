import QtQuick
import qs.tokens
import "../logic/acrylic.mjs" as Acrylic
import "../logic/context.mjs" as Context
import "../logic/icons.mjs" as Icons
import "../logic/glyphs.mjs" as Glyphs

Item {
    id: root

    property var rows: []
    property int highlight: -1
    property real drop: 0
    property bool fromTop: false
    readonly property var m: Metrics.context
    readonly property var placed: Context.placed(rows, m)
    readonly property bool marks: rows.some(row => !!row.mark)
    readonly property var fill: Acrylic.fill({
        tint: [Colors.flyoutTint.r, Colors.flyoutTint.g, Colors.flyoutTint.b],
        luminosityOpacity: Colors.flyoutLuminosityOpacity,
    })

    signal chosen(int index)
    signal hovered(int index)
    signal pressed(string action)

    FontMetrics { id: body; font.family: Type.family; font.pixelSize: Type.body.size }
    FontMetrics { id: caption; font.family: Type.family; font.pixelSize: Type.caption.size }

    function widest(metrics, key) {
        return Math.ceil(rows.reduce((most, row) => row.kind === "item" && row[key] ? Math.max(most, metrics.advanceWidth(row[key])) : most, 0))
    }

    width: Context.width(widest(body, "text"), widest(caption, "accel"), marks, m)
    height: Context.height(rows, m)
    clip: true

    Rectangle {
        objectName: "backdrop"
        y: root.fromTop ? 0 : root.drop
        width: parent.width
        height: parent.height - root.drop
        radius: Metrics.flyoutRadius
        color: Qt.rgba(root.fill.color[0], root.fill.color[1], root.fill.color[2], root.fill.alpha)
        border.width: root.m.border
        border.color: Colors.flyoutStroke
    }

    Repeater {
        model: root.placed

        Item {
            id: row

            required property var modelData
            required property int index
            readonly property bool item: modelData.kind === "item"
            readonly property bool enabled: item && modelData.enabled !== false
            objectName: "row:" + index
            x: root.m.border
            y: (root.fromTop ? -root.drop : root.drop) + modelData.y
            width: root.width - 2 * root.m.border
            height: modelData.height

            Rectangle {
                visible: row.modelData.kind === "separator"
                y: Math.floor(parent.height / 2)
                width: parent.width
                height: 1
                color: Colors.menuSeparator
            }

            Rectangle {
                objectName: "fill:" + row.index
                visible: row.item
                x: root.m.fillX
                y: root.m.fillY
                width: parent.width - 2 * root.m.fillX
                height: parent.height - 2 * root.m.fillY
                radius: root.m.radius
                color: !row.enabled ? "transparent"
                     : area.pressed ? Colors.menuItemPressed
                     : area.containsMouse || root.highlight === row.index ? Colors.menuItemHover : "transparent"
            }

            FluentIcon {
                objectName: "mark:" + row.index
                visible: row.item && !!row.modelData.checked
                x: Context.columns.markX
                anchors.verticalCenter: parent.verticalCenter
                name: row.modelData.mark === "bullet" ? Glyphs.glyph("bullet") : Glyphs.glyph("check")
                color: row.enabled ? Colors.textPrimary : Colors.textDisabled
                size: root.m.glyph
            }

            FluentIcon {
                objectName: "glyph:" + row.index
                visible: row.item && !!row.modelData.glyph
                x: root.marks ? Context.columns.markedGlyphX : Context.columns.glyphX
                anchors.verticalCenter: parent.verticalCenter
                name: row.modelData.glyph ?? ""
                color: row.enabled ? Colors.textPrimary : Colors.textDisabled
                size: root.m.glyph
            }

            Image {
                objectName: "icon:" + row.index
                visible: row.item && !!row.modelData.icon
                x: root.marks ? Context.columns.markedGlyphX : Context.columns.glyphX
                anchors.verticalCenter: parent.verticalCenter
                width: root.m.glyph
                height: root.m.glyph
                sourceSize: Qt.size(root.m.glyph, root.m.glyph)
                source: row.modelData.icon ? Icons.source(row.modelData.icon) : ""
            }

            Text {
                objectName: "text:" + row.index
                visible: row.item
                x: root.marks ? Context.columns.markedTextX : Context.columns.textX
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.text ?? ""
                color: row.enabled ? Colors.textPrimary : Colors.textDisabled
                font.family: Type.family
                font.pixelSize: Type.body.size
                renderType: Text.NativeRendering
            }

            Text {
                objectName: "accel:" + row.index
                visible: row.item && !!row.modelData.accel
                anchors.right: parent.right
                anchors.rightMargin: Context.columns.endPad
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.accel ?? ""
                color: Colors.textSecondary
                font.family: Type.family
                font.pixelSize: Type.caption.size
                renderType: Text.NativeRendering
            }

            FluentIcon {
                objectName: "more:" + row.index
                visible: row.item && !!row.modelData.more
                anchors.right: parent.right
                anchors.rightMargin: Context.columns.endPad
                anchors.verticalCenter: parent.verticalCenter
                name: Glyphs.glyph("more")
                color: Colors.textSecondary
                size: Type.caption.size
            }

            MouseArea {
                id: area
                anchors.fill: parent
                enabled: row.enabled
                hoverEnabled: true
                onContainsMouseChanged: if (containsMouse) root.hovered(row.index)
                onClicked: root.chosen(row.index)
            }

            Row {
                visible: row.modelData.kind === "buttons"
                x: root.m.pad

                Repeater {
                    model: row.modelData.buttons ?? []

                    Item {
                        id: button

                        required property var modelData
                        required property int index
                        objectName: "button:" + index
                        width: root.m.button
                        height: root.m.buttons

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: root.m.fillY
                            radius: root.m.radius
                            color: !button.modelData.enabled ? "transparent"
                                 : press.pressed ? Colors.menuItemPressed
                                 : press.containsMouse ? Colors.menuItemHover : "transparent"
                        }

                        FluentIcon {
                            objectName: "buttonglyph:" + button.index
                            anchors.centerIn: parent
                            name: button.modelData.glyph
                            color: button.modelData.enabled ? Colors.textPrimary : Colors.textDisabled
                            size: root.m.glyph
                        }

                        MouseArea {
                            id: press
                            anchors.fill: parent
                            enabled: button.modelData.enabled
                            hoverEnabled: true
                            onClicked: root.pressed(button.modelData.action)
                        }
                    }
                }
            }
        }
    }
}
