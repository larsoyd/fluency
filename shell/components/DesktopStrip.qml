import QtQuick
import qs.tokens
import "../logic/glyphs.mjs" as Glyphs

// one tile per desktop and a last one that makes a new one, centred as a group
Item {
    id: root

    property var desktops: []
    property url wallpaper: ""
    readonly property int tiles: desktops.length + 1
    readonly property int used: tiles * Metrics.deskTileWidth + (tiles - 1) * Metrics.deskGap

    signal switched(int id)
    signal created()

    height: Metrics.taskViewStrip

    component Tile: Item {
        id: tile
        property string name: ""
        property bool pressed: area.pressed
        property bool hovered: area.containsMouse
        default property alias content: face.data
        signal clicked()
        width: Metrics.deskTileWidth
        height: Metrics.deskNameHeight + Metrics.deskTileHeight

        Text {
            objectName: "name"
            width: parent.width
            height: Metrics.deskNameHeight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            renderType: Text.NativeRendering
            text: tile.name
            elide: Text.ElideRight
            color: Colors.textPrimary
            font.family: Type.family
            font.pixelSize: Type.caption.size
        }

        Rectangle {
            id: face
            y: Metrics.deskNameHeight
            width: parent.width
            height: Metrics.deskTileHeight
            radius: Metrics.flyoutRadius
            color: Colors.cardFill
            border.width: tile.hovered ? Metrics.taskViewRing : Metrics.flyoutBorder
            border.color: tile.hovered ? Colors.focusStroke : Colors.cardStroke
            clip: true
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: tile.clicked()
        }
    }

    Row {
        x: Math.floor((root.width - root.used) / 2)
        y: (root.height - Metrics.deskNameHeight - Metrics.deskTileHeight) / 2
        spacing: Metrics.deskGap

        Repeater {
            model: root.desktops

            Tile {
                id: desk
                required property var modelData
                objectName: `desk:${modelData.id}`
                name: modelData.name
                onClicked: root.switched(modelData.id)

                Image {
                    anchors.fill: parent
                    anchors.margins: Metrics.flyoutBorder
                    source: root.wallpaper
                    sourceSize: Qt.size(width, height)
                    fillMode: Image.PreserveAspectCrop
                }

                Repeater {
                    model: desk.modelData.windows

                    Rectangle {
                        required property var modelData
                        required property int index
                        objectName: `mini:${index}`
                        x: Math.round(modelData.x * Metrics.deskTileWidth)
                        y: Math.round(modelData.y * Metrics.deskTileHeight)
                        width: Math.round(modelData.w * Metrics.deskTileWidth)
                        height: Math.round(modelData.h * Metrics.deskTileHeight)
                        radius: Metrics.buttonRadius / 2
                        color: Colors.flyoutTint
                        border.width: Metrics.flyoutBorder
                        border.color: Colors.cardStroke
                    }
                }

                Rectangle {
                    objectName: "pill"
                    visible: desk.modelData.active
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Metrics.notifyInset
                    width: Metrics.searchPillWidth
                    height: Metrics.searchPillHeight
                    radius: height / 2
                    color: Colors.accentLight2
                }
            }
        }

        Tile {
            objectName: "newDesk"
            name: "New desktop"
            onClicked: root.created()

            Text {
                anchors.centerIn: parent
                text: Glyphs.glyph("plus")
                color: Colors.textPrimary
                font.family: Type.iconFamily
                font.pixelSize: Metrics.trayGlyphSize
            }
        }
    }
}
