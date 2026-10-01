import QtQuick
import qs.tokens
import "../logic/clipboard.mjs" as Clip
import "../logic/glyphs.mjs" as Glyphs

Rectangle {
    id: root

    required property var entry
    property string source: ""
    property string icon: ""
    property bool expanded: false
    property bool focused: false
    readonly property int textWidth: width - 2 * Metrics.clipPad - Metrics.clipButton

    signal picked()
    signal pinToggled()
    signal moreToggled()
    signal acted(string name)

    height: Math.max(Metrics.clipCard, Metrics.clipPad + content.height + Metrics.clipGap + Metrics.clipSource + Metrics.clipPad)
    radius: Metrics.flyoutRadius
    color: root.expanded ? Colors.cardFill : area.pressed ? Colors.controlFillPressed : area.containsMouse ? Colors.controlFillHover : Colors.cardFill
    border.width: root.focused ? 2 : 1
    border.color: root.focused ? Colors.focusStroke : Colors.cardStroke

    component Glyph: Text {
        anchors.centerIn: parent
        color: Colors.textPrimary
        font.family: Type.iconFamily
        font.pixelSize: Type.body.size
    }

    component Button: Item {
        id: button
        default property alias content: holder.data
        signal clicked()
        width: Metrics.clipButton
        height: Metrics.clipButton

        Rectangle {
            anchors.fill: parent
            radius: Metrics.controlRadius
            color: press.pressed ? Colors.controlFillPressed : press.containsMouse ? Colors.controlFillHover : "transparent"
        }

        Item {
            id: holder
            anchors.fill: parent
        }

        MouseArea {
            id: press
            anchors.fill: parent
            hoverEnabled: true
            onClicked: button.clicked()
        }
    }

    MouseArea {
        id: area
        objectName: "area"
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.expanded ? root.moreToggled() : root.picked()
    }

    Item {
        id: content
        x: Metrics.clipPad
        y: Metrics.clipPad
        width: root.textWidth
        height: root.entry.kind === "image" ? picture.height : body.height
        visible: !root.expanded

        Text {
            id: body
            objectName: "body"
            visible: root.entry.kind !== "image" && !root.expanded
            width: parent.width
            text: Clip.body(root.entry)
            renderType: Text.NativeRendering
            color: Colors.textPrimary
            font.family: Type.family
            font.pixelSize: Type.body.size
            lineHeight: Type.body.lineHeight
            lineHeightMode: Text.FixedHeight
            wrapMode: Text.WrapAnywhere
            maximumLineCount: Metrics.clipLines
            elide: Text.ElideRight
            textFormat: Text.PlainText
        }

        Image {
            id: picture
            objectName: "picture"
            visible: root.entry.kind === "image" && !root.expanded
            width: parent.width
            height: Metrics.clipThumb
            source: root.entry.image ? `file://${root.entry.image}` : ""
            sourceSize.height: 2 * Metrics.clipThumb
            fillMode: Image.PreserveAspectFit
            horizontalAlignment: Image.AlignLeft
            asynchronous: true
        }
    }

    Row {
        objectName: "provenance"
        x: Metrics.clipPad
        y: root.height - Metrics.clipPad - Metrics.clipSource
        height: Metrics.clipSource
        spacing: 6
        visible: !root.expanded

        Image {
            objectName: "appIcon"
            visible: root.icon !== ""
            width: Metrics.clipSource
            height: Metrics.clipSource
            source: root.icon
            sourceSize: Qt.size(Metrics.clipSource, Metrics.clipSource)
        }

        Text {
            objectName: "source"
            anchors.verticalCenter: parent.verticalCenter
            text: root.source
            renderType: Text.NativeRendering
            color: Colors.textSecondary
            font.family: Type.family
            font.pixelSize: Type.caption.size
        }
    }

    Row {
        objectName: "actions"
        x: 4
        y: 4
        visible: root.expanded
        height: root.height - 8
        spacing: 4

        Repeater {
            model: Clip.actions(root.entry)

            Item {
                id: tile
                required property var modelData
                objectName: `action:${modelData.name}`
                enabled: modelData.enabled
                width: (root.width - 16 - Metrics.clipButton) / 2
                height: parent.height

                Rectangle {
                    anchors.fill: parent
                    radius: Metrics.controlRadius
                    color: tap.pressed ? Colors.controlFillPressed : tap.containsMouse ? Colors.controlFillHover : Colors.controlFill
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 4
                    opacity: tile.enabled ? 1 : 0.4

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tile.modelData.glyph
                        color: Colors.textPrimary
                        font.family: Type.iconFamily
                        font.pixelSize: 20
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tile.modelData.label
                        renderType: Text.NativeRendering
                        color: Colors.textPrimary
                        font.family: Type.family
                        font.pixelSize: Type.caption.size
                    }
                }

                MouseArea {
                    id: tap
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.acted(tile.modelData.name)
                }
            }
        }
    }

    Button {
        objectName: "more"
        x: root.width - width - 4
        y: 4
        onClicked: root.moreToggled()

        Glyph { text: Glyphs.glyph("moreHorizontal") }
    }

    Button {
        objectName: "pin"
        x: root.width - width - 4
        y: root.height - height - 4
        onClicked: root.pinToggled()

        Glyph {
            objectName: "pinGlyph"
            text: Glyphs.glyph("pin")
            color: root.entry.pinned ? Colors.accentLight2 : Colors.textPrimary
        }
    }
}
