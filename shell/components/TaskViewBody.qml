import QtQuick
import qs.tokens
import "../logic/curve.mjs" as Curve
import "../logic/taskview.mjs" as TaskView

Item {
    id: root

    property var items: []
    property var desktops: []
    property url wallpaper: ""
    property Component preview: null
    property bool shown: false
    property real reveal: 0
    property int selectedIndex: -1
    property int zooming: -1
    property alias revealing: revealing
    property real zoomed: 0
    readonly property var area: ({
        x: Metrics.taskViewMargin, y: Metrics.taskViewMargin,
        w: width - 2 * Metrics.taskViewMargin, h: height - Metrics.taskViewStrip - 2 * Metrics.taskViewMargin,
    })
    readonly property var opts: ({ gap: Metrics.taskViewGap, title: Metrics.taskViewTitle, most: Metrics.taskViewMost })
    readonly property var rects: TaskView.layout(items.map(item => ({ w: item.size[0], h: item.size[1] })), area, opts)

    signal picked(string address)
    signal closeAsked(string address)
    signal dismissed()
    signal switched(int id)
    signal created()
    signal deskClosed(int id)

    function pick(index) {
        if (!items[index] || zooming >= 0) return
        zooming = index
        zoom.restart()
    }

    function step(dir) {
        selectedIndex = selectedIndex < 0 ? 0 : TaskView.nearest(rects, selectedIndex, dir)
    }

    onShownChanged: {
        revealing.duration = shown ? Motion.taskViewOpen : Motion.taskViewClose
        revealing.easing.bezierCurve = Curve.easing(shown ? Motion.curveDecelerate : Motion.curveAccelerate)
        reveal = shown ? 1 : 0
        if (shown) {
            selectedIndex = -1
            zooming = -1
            zoomed = 0
        }
    }
    onItemsChanged: selectedIndex = Math.min(selectedIndex, items.length - 1)

    Behavior on reveal {
        NumberAnimation { id: revealing }
    }

    Keys.onPressed: event => {
        const dirs = { [Qt.Key_Left]: "left", [Qt.Key_Right]: "right", [Qt.Key_Up]: "up", [Qt.Key_Down]: "down" }
        if (event.key === Qt.Key_Escape) root.dismissed()
        else if (dirs[event.key]) root.step(dirs[event.key])
        else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) && root.selectedIndex >= 0) root.pick(root.selectedIndex)
        else if (event.key === Qt.Key_Delete && root.selectedIndex >= 0) root.closeAsked(root.items[root.selectedIndex].address)
        else return
        event.accepted = true
    }

    NumberAnimation {
        id: zoom
        target: root
        property: "zoomed"
        from: 0
        to: 1
        duration: Motion.taskViewZoom
        easing.bezierCurve: Curve.easing(Motion.curveDecelerate)
        onFinished: root.picked(root.items[root.zooming].address)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.dismissed()
    }

    Text {
        objectName: "empty"
        visible: !root.items.length
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -Metrics.taskViewStrip / 2
        opacity: root.reveal
        renderType: Text.NativeRendering
        text: "No open windows"
        color: Colors.textSecondary
        font.family: Type.family
        font.pixelSize: Type.body.size
    }

    Repeater {
        id: cards
        model: root.items

        TaskViewItem {
            id: card
            required property var modelData
            required property int index
            readonly property var place: root.rects[index] ?? { x: 0, y: 0, w: 0, h: 0 }
            readonly property bool chosen: index === root.zooming
            objectName: `item:${modelData.address}`
            home: Qt.rect(place.x, place.y, place.w, place.h)
            target: Qt.rect(modelData.at[0], modelData.at[1] - Metrics.taskViewTitle, modelData.size[0], modelData.size[1] + Metrics.taskViewTitle)
            title: modelData.title
            icon: modelData.icon
            selected: index === root.selectedIndex
            z: chosen ? 1 : 0
            scale: chosen ? 1 : Metrics.taskViewScaleFrom + (1 - Metrics.taskViewScaleFrom) * root.reveal
            zoom: chosen ? root.zoomed : 0
            live: loader.status === Loader.Ready && (loader.item.ready ?? true)
            opacity: chosen ? 1 : root.reveal * (1 - root.zoomed)
            onClicked: root.pick(index)
            onMiddleClicked: root.closeAsked(modelData.address)
            onCloseClicked: root.closeAsked(modelData.address)

            // a capture lives only while the view shows
            Loader {
                id: loader
                objectName: "preview"
                parent: card.holder
                anchors.fill: parent
                active: root.preview !== null && (root.shown || root.reveal > 0)
                sourceComponent: root.preview
                readonly property string address: card.modelData.address
            }
        }
    }

    DesktopStrip {
        objectName: "strip"
        y: root.height - height + Metrics.taskViewRise * (1 - root.reveal)
        width: root.width
        opacity: root.reveal * (1 - root.zoomed)
        desktops: root.desktops
        wallpaper: root.wallpaper
        onSwitched: id => root.switched(id)
        onCreated: root.created()
        onClosed: id => root.deskClosed(id)
    }
}
