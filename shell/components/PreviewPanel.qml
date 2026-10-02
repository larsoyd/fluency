import QtQuick
import qs.tokens
import "../logic/acrylic.mjs" as Acrylic
import "../logic/previews.mjs" as Previews
import "../logic/curve.mjs" as Curve

// the windows of one taskbar button side by side, drawn as the task view cards
Item {
    id: root

    property var items: []
    property Component preview: null
    property int room: 0
    property bool glides: true
    property alias resizing: resizing
    readonly property var laid: Previews.layout(items.map(item => item.size), {
        width: Metrics.previewWidth, height: Metrics.previewHeight, gap: Metrics.previewGap, pad: Metrics.previewPad, title: Metrics.taskViewTitle,
    }, room)
    readonly property var fill: Acrylic.fill({
        tint: [Colors.flyoutTint.r, Colors.flyoutTint.g, Colors.flyoutTint.b],
        luminosityOpacity: Colors.flyoutLuminosityOpacity,
    })

    signal picked(string address)
    signal closeAsked(string address)

    width: laid.width
    height: laid.height

    Behavior on width {
        enabled: root.glides
        NumberAnimation {
            id: resizing
            duration: Motion.resize
            easing.bezierCurve: Curve.easing(Motion.curvePointToPoint)
        }
    }

    Behavior on height {
        enabled: root.glides
        NumberAnimation {
            duration: Motion.resize
            easing.bezierCurve: Curve.easing(Motion.curvePointToPoint)
        }
    }

    Rectangle {
        objectName: "backdrop"
        anchors.fill: parent
        radius: Metrics.flyoutRadius
        color: Qt.rgba(root.fill.color[0], root.fill.color[1], root.fill.color[2], root.fill.alpha)
        border.width: Metrics.flyoutBorder
        border.color: Colors.flyoutStroke
    }

    Repeater {
        model: root.items

        TaskViewItem {
            id: card
            required property var modelData
            required property int index
            readonly property var place: root.laid.cards[index] ?? { x: 0, y: 0, w: 0, h: 0 }
            objectName: `item:${modelData.address}`
            home: Qt.rect(place.x, place.y, place.w, place.h + Metrics.taskViewTitle)
            title: modelData.title
            icon: modelData.icon
            live: loader.status === Loader.Ready && (loader.item.ready ?? true)
            onClicked: root.picked(modelData.address)
            onMiddleClicked: root.closeAsked(modelData.address)
            onCloseClicked: root.closeAsked(modelData.address)

            Loader {
                id: loader
                objectName: "preview"
                parent: card.holder
                anchors.fill: parent
                active: root.preview !== null
                sourceComponent: root.preview
                readonly property string address: card.modelData.address
            }
        }
    }
}
