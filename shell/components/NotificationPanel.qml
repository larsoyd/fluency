import QtQuick
import qs.tokens
import "../logic/glyphs.mjs" as Glyphs
import "../logic/acrylic.mjs" as Acrylic
import "../logic/notify.mjs" as Notify
import "../logic/toast.mjs" as Words

Item {
    id: root

    property var groups: []
    property bool dnd: false
    property int maxHeight: 0
    property var iconOf: n => ""
    readonly property var fill: Acrylic.fill({
        tint: [Colors.flyoutTint.r, Colors.flyoutTint.g, Colors.flyoutTint.b],
        luminosityOpacity: Colors.flyoutLuminosityOpacity,
    })

    signal activated(var n)
    signal dismissed(var n)
    signal invoked(var n, string id)
    signal cleared()
    signal clearedApp(string app)
    signal dndToggled()

    width: Metrics.notifyWidth
    height: Math.min(maxHeight, Metrics.notifyHeader + (groups.length ? column.height + Metrics.notifyInset : Metrics.notifyEmpty))

    Rectangle {
        objectName: "backdrop"
        anchors.fill: parent
        radius: Metrics.flyoutRadius
        color: Qt.rgba(root.fill.color[0], root.fill.color[1], root.fill.color[2], root.fill.alpha)
        border.width: Metrics.flyoutBorder
        border.color: Colors.flyoutStroke
    }

    component Label: Text {
        renderType: Text.NativeRendering
        color: Colors.textPrimary
        font.family: Type.family
        font.pixelSize: Type.body.size
    }

    component Button: Item {
        id: button
        default property alias content: holder.data
        property bool checked: false
        signal clicked()
        height: Metrics.toastCloseSize

        Rectangle {
            objectName: "fill"
            anchors.fill: parent
            radius: Metrics.buttonRadius
            color: area.pressed ? Colors.controlFillPressed : area.containsMouse || button.checked ? Colors.controlFillHover : "transparent"
        }

        Item {
            id: holder
            anchors.fill: parent
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: button.clicked()
        }
    }

    Item {
        objectName: "header"
        width: parent.width
        height: Metrics.notifyHeader

        Label {
            objectName: "title"
            x: Metrics.toastPadding
            anchors.verticalCenter: parent.verticalCenter
            text: "Notifications"
            font.weight: Type.bodyStrong.weight
        }

        Button {
            id: clear
            objectName: "clearAll"
            visible: root.groups.length > 0
            x: dnd.x - width - Metrics.notifyInset / 2
            anchors.verticalCenter: parent.verticalCenter
            width: label.implicitWidth + 2 * Metrics.notifyInset
            onClicked: root.cleared()

            Label {
                id: label
                objectName: "label"
                anchors.centerIn: parent
                text: "Clear all"
                font.pixelSize: Type.caption.size
            }
        }

        Button {
            id: dnd
            objectName: "dnd"
            x: parent.width - width - (Metrics.notifyHeader - height) / 2
            anchors.verticalCenter: parent.verticalCenter
            width: height
            checked: root.dnd
            onClicked: root.dndToggled()

            Text {
                objectName: "glyph"
                anchors.centerIn: parent
                text: Notify.bell(0, root.dnd).glyph
                color: Colors.textPrimary
                font.family: Type.iconFamily
                font.pixelSize: Metrics.trayGlyphSize
            }
        }
    }

    Label {
        objectName: "empty"
        visible: !root.groups.length
        y: Metrics.notifyHeader
        width: parent.width
        height: Metrics.notifyEmpty
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: "No new notifications"
        color: Colors.textSecondary
    }

    Flickable {
        id: list
        objectName: "list"
        y: Metrics.notifyHeader
        width: parent.width
        height: parent.height - y
        clip: true
        contentWidth: width
        contentHeight: column.height + Metrics.notifyInset
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: column
            x: Metrics.notifyInset
            width: parent.width - 2 * Metrics.notifyInset
            spacing: Metrics.notifyInset

            Repeater {
                model: root.groups

                Column {
                    id: group
                    required property var modelData
                    required property int index
                    width: parent.width
                    spacing: Metrics.notifyInset

                    Label {
                        id: name
                        objectName: `group:${group.index}`
                        width: parent.width
                        height: Metrics.notifyGroup
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: Metrics.notifyInset
                        text: group.modelData.app
                        font.pixelSize: Type.caption.size
                        font.weight: Type.bodyStrong.weight

                        HoverHandler { id: hover }

                        Button {
                            objectName: `groupClose:${group.index}`
                            visible: hover.hovered
                            x: parent.width - width
                            anchors.verticalCenter: parent.verticalCenter
                            width: height
                            onClicked: root.clearedApp(group.modelData.app)

                            Text {
                                anchors.centerIn: parent
                                text: Glyphs.glyph("close")
                                color: Colors.textSecondary
                                font.family: Type.iconFamily
                                font.pixelSize: Type.caption.size
                            }
                        }
                    }

                    Repeater {
                        model: group.modelData.items

                        Toast {
                            required property var modelData
                            readonly property var words: Words.text(modelData)
                            readonly property var bar: Words.progress(modelData)
                            objectName: `card:${modelData.id}`
                            width: parent.width
                            card: true
                            app: words.app
                            icon: root.iconOf(modelData)
                            title: words.title
                            body: words.body
                            progress: bar ? bar.value : -1
                            status: bar ? bar.status : ""
                            valueText: bar ? bar.text : ""
                            buttons: Words.buttons(modelData)
                            onActivated: root.activated(modelData)
                            onDismissed: root.dismissed(modelData)
                            onInvoked: id => root.invoked(modelData, id)
                        }
                    }
                }
            }
        }
    }
}
