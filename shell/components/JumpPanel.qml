import QtQuick
import qs.tokens
import "../logic/acrylic.mjs" as Acrylic
import "../logic/jump.mjs" as Jump

Item {
    id: root

    property var rows: []
    property url icon: ""
    readonly property var fill: Acrylic.fill({
        tint: [Colors.flyoutTint.r, Colors.flyoutTint.g, Colors.flyoutTint.b],
        luminosityOpacity: Colors.flyoutLuminosityOpacity,
    })

    signal chosen(int index)

    width: Metrics.jumpWidth
    height: Jump.height(rows, Metrics)

    Rectangle {
        objectName: "backdrop"
        anchors.fill: parent
        radius: Metrics.flyoutRadius
        color: Qt.rgba(root.fill.color[0], root.fill.color[1], root.fill.color[2], root.fill.alpha)
        border.width: Metrics.flyoutBorder
        border.color: Colors.flyoutStroke
    }

    Column {
        x: Metrics.flyoutBorder
        y: Metrics.flyoutBorder + Metrics.jumpPaddingY
        width: parent.width - 2 * Metrics.flyoutBorder

        Repeater {
            model: root.rows

            Item {
                id: row

                required property var modelData
                required property int index
                readonly property bool item: modelData.kind === "item"
                readonly property color ink: !item ? Colors.textSecondary : modelData.enabled ? Colors.textPrimary : Colors.textDisabled
                objectName: "row:" + index
                width: parent.width
                height: modelData.kind === "header" ? Metrics.jumpHeader : modelData.kind === "separator" ? Metrics.jumpSeparator : Metrics.jumpRow

                Rectangle {
                    objectName: "line:" + row.index
                    visible: row.modelData.kind === "separator"
                    y: Math.floor((parent.height - height) / 2)
                    width: parent.width
                    height: Metrics.menuSeparator
                    color: Colors.menuSeparator
                }

                Rectangle {
                    objectName: "fill:" + row.index
                    visible: row.item
                    x: Metrics.menuItemMarginX
                    y: Metrics.jumpRowMargin
                    width: parent.width - 2 * Metrics.menuItemMarginX
                    height: parent.height - 2 * Metrics.jumpRowMargin
                    radius: Metrics.menuItemRadius
                    color: !row.modelData.enabled ? "transparent" : area.pressed ? Colors.menuItemPressed : area.containsMouse ? Colors.menuItemHover : "transparent"
                }

                Image {
                    objectName: "icon:" + row.index
                    visible: !!row.modelData.icon
                    x: Metrics.jumpIconX - Metrics.flyoutBorder
                    anchors.verticalCenter: parent.verticalCenter
                    width: Metrics.jumpIconSize
                    height: Metrics.jumpIconSize
                    source: row.modelData.icon ? root.icon : ""
                    sourceSize: Qt.size(width, height)
                }

                FluentIcon {
                    objectName: "glyph:" + row.index
                    visible: !!row.modelData.glyph
                    x: Metrics.jumpIconX - Metrics.flyoutBorder + (Metrics.jumpIconSize - width) / 2
                    anchors.verticalCenter: parent.verticalCenter
                    name: row.modelData.glyph ?? ""
                    color: row.ink
                    size: Metrics.jumpIconSize
                }

                Text {
                    renderType: Text.NativeRendering
                    objectName: "text:" + row.index
                    visible: row.modelData.kind !== "separator"
                    x: (row.item ? Metrics.jumpTextX : Metrics.jumpIconX) - Metrics.flyoutBorder
                    width: parent.width - x - Metrics.menuItemMarginX - Metrics.menuItemPaddingX
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.text ?? ""
                    elide: Text.ElideRight
                    color: row.ink
                    font.family: Type.family
                    font.pixelSize: row.item ? Type.body.size : Type.caption.size
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    enabled: row.item && row.modelData.enabled
                    hoverEnabled: true
                    onClicked: root.chosen(row.index)
                }
            }
        }
    }
}
