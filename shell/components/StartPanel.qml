import QtQuick
import qs.tokens
import "../logic/acrylic.mjs" as Acrylic
import "../logic/glyphs.mjs" as Glyphs

Item {
    id: root

    property string userName: ""
    property url avatar: ""
    property var entries: []
    property var pins: []
    property alias query: input.text
    property bool typing: true
    property alias power: power
    property alias user: user
    readonly property var fill: Acrylic.fill({
        tint: [Colors.flyoutTint.r, Colors.flyoutTint.g, Colors.flyoutTint.b],
        luminosityOpacity: Colors.flyoutLuminosityOpacity,
    })

    signal powerAsked()
    signal userAsked()
    signal launched(string id)
    signal appAsked(string id, bool tile, point at)
    signal dismissed()

    width: Metrics.startWidth
    height: Metrics.startHeight

    // keys typed before the box takes focus still go into it
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) root.dismissed()
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { if (body.results.length) root.launched(body.results[body.selectedIndex].id) }
        else if (body.searching && (event.key === Qt.Key_Down || event.key === Qt.Key_Up)) body.moveSelection(event.key === Qt.Key_Down ? 1 : -1)
        else if (!input.activeFocus && event.text >= " ") input.insert(input.cursorPosition, event.text)
        else return
        event.accepted = true
    }

    Rectangle {
        objectName: "backdrop"
        anchors.fill: parent
        radius: Metrics.flyoutRadius
        color: Qt.rgba(root.fill.color[0], root.fill.color[1], root.fill.color[2], root.fill.alpha)
        border.width: Metrics.flyoutBorder
        border.color: Colors.startStroke
    }

    component Band: Item {
        property bool upper: true
        property alias color: shade.color
        x: Metrics.flyoutBorder
        width: parent.width - 2 * Metrics.flyoutBorder
        height: Metrics.startBand - Metrics.flyoutBorder
        clip: true

        // rounded on the outer edge only
        Rectangle {
            id: shade
            y: parent.upper ? 0 : -radius
            width: parent.width
            height: parent.height + radius
            radius: Metrics.flyoutRadius - Metrics.flyoutBorder
        }
    }

    Band {
        objectName: "searchBand"
        y: Metrics.flyoutBorder
        color: Colors.startBand
    }

    Band {
        objectName: "footerBand"
        upper: false
        y: root.height - Metrics.startBand
        color: Colors.startBand
    }

    Rectangle {
        objectName: "search"
        x: Metrics.startSearchMarginX
        y: (Metrics.startBand - height) / 2
        width: root.width - 2 * Metrics.startSearchMarginX
        height: Metrics.startSearchHeight
        radius: height / 2
        color: Colors.startSearchFill
        border.width: Metrics.flyoutBorder
        border.color: Colors.startSearchStroke

        Text {

            renderType: Text.NativeRendering
            objectName: "searchIcon"
            x: Metrics.startSearchIconX
            anchors.verticalCenter: parent.verticalCenter
            text: Glyphs.glyph("search")
            color: Colors.textPrimary
            font.family: Type.iconFamily
            font.pixelSize: Metrics.startGlyph
        }

        Text {

            renderType: Text.NativeRendering
            objectName: "placeholder"
            visible: !input.text
            x: Metrics.startSearchTextX
            anchors.verticalCenter: parent.verticalCenter
            text: "Search for apps, settings, and documents"
            color: Colors.startPlaceholder
            font.family: Type.family
            font.pixelSize: Type.body.size
        }

        TextInput {
            id: input
            objectName: "searchInput"
            x: Metrics.startSearchTextX
            width: parent.width - x - Metrics.startSearchIconX
            anchors.verticalCenter: parent.verticalCenter
            focus: root.typing
            clip: true
            renderType: Text.NativeRendering
            color: Colors.textPrimary
            selectionColor: Colors.accent
            font.family: Type.family
            font.pixelSize: Type.body.size
        }
    }

    Item {
        objectName: "body"
        y: Metrics.startBand
        width: root.width
        height: root.height - 2 * Metrics.startBand

        StartBody {
            id: body
            objectName: "scroller"
            query: input.text
            anchors.fill: parent
            entries: root.entries
            pins: root.pins
            onLaunched: id => root.launched(id)
            onAppAsked: (id, tile, at) => root.appAsked(id, tile, mapToItem(root, at.x, at.y))
        }
    }

    StartButton {
        id: user
        objectName: "user"
        x: Metrics.startFooterPaddingX
        y: root.height - Metrics.startBand + (Metrics.startBand - height) / 2
        width: 3 * Metrics.startUserPadding + Metrics.startAvatar + Math.ceil(name.implicitWidth)
        onClicked: root.userAsked()

        Item {
            objectName: "avatar"
            x: Metrics.startUserPadding
            anchors.verticalCenter: parent.verticalCenter
            width: Metrics.startAvatar
            height: Metrics.startAvatar

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Colors.itemFillPrimary
                visible: picture.status !== Image.Ready
            }

            Text {

                renderType: Text.NativeRendering
                objectName: "avatarGlyph"
                anchors.centerIn: parent
                visible: picture.status !== Image.Ready
                text: Glyphs.glyph("user")
                color: Colors.textPrimary
                font.family: Type.iconFamily
                font.pixelSize: Metrics.startGlyph
            }

            Image {
                id: picture
                source: root.avatar
                visible: false
                onStatusChanged: if (status === Image.Ready) disc.loadImage(source)
            }

            // a centred square of the picture inside a circle
            Canvas {
                id: disc
                anchors.fill: parent
                visible: picture.status === Image.Ready
                onImageLoaded: requestPaint()

                onPaint: {
                    const ctx = getContext("2d"), side = Math.min(picture.implicitWidth, picture.implicitHeight)
                    ctx.clearRect(0, 0, width, height)
                    if (!isImageLoaded(root.avatar)) return
                    ctx.save()
                    ctx.beginPath()
                    ctx.arc(width / 2, height / 2, width / 2, 0, 2 * Math.PI)
                    ctx.clip()
                    ctx.drawImage(root.avatar, (picture.implicitWidth - side) / 2, (picture.implicitHeight - side) / 2, side, side, 0, 0, width, height)
                    ctx.restore()
                }
            }
        }

        Text {

            renderType: Text.NativeRendering
            id: name
            objectName: "name"
            x: 2 * Metrics.startUserPadding + Metrics.startAvatar
            anchors.verticalCenter: parent.verticalCenter
            text: root.userName
            color: Colors.textPrimary
            font.family: Type.family
            font.pixelSize: Type.caption.size
        }
    }

    StartButton {
        id: power
        objectName: "power"
        x: root.width - Metrics.startFooterPaddingRight - width
        y: user.y
        width: Metrics.startFooterButton
        onClicked: root.powerAsked()

        Text {

            renderType: Text.NativeRendering
            objectName: "powerGlyph"
            anchors.centerIn: parent
            text: Glyphs.glyph("power")
            color: Colors.textPrimary
            font.family: Type.iconFamily
            font.pixelSize: Metrics.startGlyph
        }
    }
}
