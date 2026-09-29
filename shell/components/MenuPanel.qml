import QtQuick
import qs.tokens
import "../logic/acrylic.mjs" as Acrylic
import "../logic/menu.mjs" as Menu

Item {
    id: root

    property var rows: []
    property real drop: 0
    readonly property bool checks: rows.some(row => row.check || row.glyph)
    readonly property int indent: Metrics.menuItemPaddingX + (checks ? Metrics.menuCheckWidth : 0)
    readonly property var fill: Acrylic.fill({
        tint: [Colors.flyoutTint.r, Colors.flyoutTint.g, Colors.flyoutTint.b],
        luminosityOpacity: Colors.flyoutLuminosityOpacity,
    })

    signal chosen(int index)

    FontMetrics { id: measure; font.family: Type.family; font.pixelSize: Type.body.size }

    function widest() {
        return rows.reduce((most, row) => row.kind === "item" ? Math.max(most, measure.advanceWidth(row.text)) : most, 0)
    }

    width: Math.min(Metrics.menuMaxWidth, Math.ceil(widest()) + indent + Metrics.menuItemPaddingX + 2 * (Metrics.menuItemMarginX + Metrics.flyoutBorder))
    height: Menu.height(rows, Metrics)
    clip: true

    // the menu grows from its far edge while the rows slide in with it
    Rectangle {
        objectName: "backdrop"
        y: root.drop
        width: parent.width
        height: parent.height - root.drop
        radius: Metrics.flyoutRadius
        color: Qt.rgba(root.fill.color[0], root.fill.color[1], root.fill.color[2], root.fill.alpha)
        border.width: Metrics.flyoutBorder
        border.color: Colors.flyoutStroke
    }

    Column {
        x: Metrics.flyoutBorder
        y: root.drop + Metrics.flyoutBorder + Metrics.menuPaddingY
        width: parent.width - 2 * Metrics.flyoutBorder

        Repeater {
            model: root.rows

            Item {
                id: row

                required property var modelData
                required property int index
                readonly property bool line: modelData.kind === "separator"
                objectName: "row:" + index
                width: parent.width
                height: line ? 2 * Metrics.menuSeparatorMarginY + Metrics.menuSeparator
                             : 2 * Metrics.menuItemMarginY + Metrics.menuItemPaddingTop + Metrics.menuLine + Metrics.menuItemPaddingBottom

                Rectangle {
                    visible: row.line
                    y: Metrics.menuSeparatorMarginY
                    width: parent.width
                    height: Metrics.menuSeparator
                    color: Colors.menuSeparator
                }

                Rectangle {
                    objectName: "fill:" + row.index
                    visible: !row.line
                    x: Metrics.menuItemMarginX
                    y: Metrics.menuItemMarginY
                    width: parent.width - 2 * Metrics.menuItemMarginX
                    height: parent.height - 2 * Metrics.menuItemMarginY
                    radius: Metrics.menuItemRadius
                    color: !row.modelData.enabled ? "transparent" : area.pressed ? Colors.menuItemPressed : area.containsMouse ? Colors.menuItemHover : "transparent"
                }

                Text {

                    renderType: Text.NativeRendering
                    objectName: "mark:" + row.index
                    visible: !row.line && !!row.modelData.checked
                    x: Metrics.menuItemMarginX + Metrics.menuItemPaddingX
                    anchors.verticalCenter: parent.verticalCenter
                    text: String.fromCharCode(0xe73e)
                    color: row.modelData.enabled ? Colors.textPrimary : Colors.textDisabled
                    font.family: Type.iconFamily
                    font.pixelSize: Type.body.size
                }

                Text {

                    renderType: Text.NativeRendering
                    objectName: "glyph:" + row.index
                    visible: !row.line && !!row.modelData.glyph
                    x: Metrics.menuItemMarginX + Metrics.menuItemPaddingX
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.glyph ?? ""
                    color: row.modelData.enabled ? Colors.textPrimary : Colors.textDisabled
                    font.family: Type.iconFamily
                    font.pixelSize: Type.body.size
                }

                Text {

                    renderType: Text.NativeRendering
                    objectName: "text:" + row.index
                    visible: !row.line
                    x: Metrics.menuItemMarginX + root.indent
                    width: parent.width - x - Metrics.menuItemMarginX - Metrics.menuItemPaddingX
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.text ?? ""
                    elide: Text.ElideRight
                    color: row.modelData.enabled ? Colors.textPrimary : Colors.textDisabled
                    font.family: Type.family
                    font.pixelSize: Type.body.size
                }

                Text {

                    renderType: Text.NativeRendering
                    objectName: "more:" + row.index
                    visible: !row.line && !!row.modelData.more
                    anchors.right: parent.right
                    anchors.rightMargin: Metrics.menuItemMarginX + Metrics.menuItemPaddingX
                    anchors.verticalCenter: parent.verticalCenter
                    text: String.fromCharCode(0xe76c)
                    color: Colors.textSecondary
                    font.family: Type.iconFamily
                    font.pixelSize: Type.caption.size
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    enabled: !row.line && row.modelData.enabled
                    hoverEnabled: true
                    onClicked: root.chosen(row.index)
                }
            }
        }
    }
}
