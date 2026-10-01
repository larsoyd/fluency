import QtQuick
import qs.tokens
import "../logic/acrylic.mjs" as Acrylic
import "../logic/taskview.mjs" as TaskView

// the thumbnails of task view laid out once, then the panel shrinks around them
Item {
    id: root

    property var items: []
    property int selectedIndex: -1
    property Component preview: null
    property int maxWidth: 0
    property int maxHeight: 0
    readonly property var area: ({ x: 0, y: 0, w: maxWidth - 2 * Metrics.switcherPad, h: maxHeight - 2 * Metrics.switcherPad })
    readonly property var laid: TaskView.layout(items.map(item => ({ w: item.size[0], h: item.size[1] })), area, {
        gap: Metrics.taskViewGap, title: Metrics.taskViewTitle, most: Metrics.switcherThumb / Math.max(1, area.h),
    })
    readonly property var box: laid.length ? {
        x: Math.min(...laid.map(r => r.x)), y: Math.min(...laid.map(r => r.y)),
        right: Math.max(...laid.map(r => r.x + r.w)), bottom: Math.max(...laid.map(r => r.y + r.h)),
    } : { x: 0, y: 0, right: 0, bottom: 0 }
    readonly property var fill: Acrylic.fill({
        tint: [Colors.flyoutTint.r, Colors.flyoutTint.g, Colors.flyoutTint.b],
        luminosityOpacity: Colors.flyoutLuminosityOpacity,
    })

    signal picked(string address)
    signal closeAsked(string address)

    width: box.right - box.x + 2 * Metrics.switcherPad
    height: box.bottom - box.y + 2 * Metrics.switcherPad

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
            readonly property var place: root.laid[index] ?? { x: 0, y: 0, w: 0, h: 0 }
            objectName: `item:${modelData.address}`
            home: Qt.rect(place.x - root.box.x + Metrics.switcherPad, place.y - root.box.y + Metrics.switcherPad, place.w, place.h)
            title: modelData.title
            icon: modelData.icon
            selected: index === root.selectedIndex
            live: loader.status === Loader.Ready && (loader.item.ready ?? true)
            onClicked: root.picked(modelData.address)
            onCloseClicked: root.closeAsked(modelData.address)

            Loader {
                id: loader
                parent: card.holder
                anchors.fill: parent
                active: root.preview !== null
                sourceComponent: root.preview
                readonly property string address: card.modelData.address
            }
        }
    }
}
