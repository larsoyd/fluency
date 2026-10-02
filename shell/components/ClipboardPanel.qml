import QtQuick
import qs.tokens
import "../logic/acrylic.mjs" as Acrylic
import "../logic/clipboard.mjs" as Clip
import "../logic/curve.mjs" as Curve
import "../logic/glyphs.mjs" as Glyphs

FocusScope {
    id: root

    property var entries: []
    property real now: 0
    property int maxHeight: 0
    property string query: ""
    property var nameOf: app => app
    property var iconOf: app => ""
    property int cursor: -1
    property int opened: -1
    property alias resizing: resizing
    readonly property var found: Clip.filter(entries, query)
    readonly property int shown: list.count
    readonly property int listTop: Metrics.clipHeader + (query ? Metrics.clipSearch + Metrics.clipGap : 0)
    readonly property var fill: Acrylic.fill({
        tint: [Colors.flyoutTint.r, Colors.flyoutTint.g, Colors.flyoutTint.b],
        luminosityOpacity: Colors.flyoutLuminosityOpacity,
    })

    signal picked(int id)
    signal asText(int id)
    signal pinned(int id, bool on)
    signal removed(int id)
    signal cleared()
    signal dismissed()

    function source(entry) {
        const name = entry.app ? root.nameOf(entry.app) : ""
        const age = Clip.age(entry.time, root.now)
        return name ? `${name} · ${age}` : age
    }

    function chosen() {
        return found[Math.max(cursor, 0)]
    }

    function act(entry, name) {
        opened = -1
        if (name === "text") asText(entry.id)
        if (name === "delete") removed(entry.id)
    }

    width: Metrics.clipWidth
    height: Math.min(maxHeight, Metrics.clipMaxHeight, listTop + (list.count ? list.contentHeight + Metrics.clipInset : Metrics.clipEmpty))
    onQueryChanged: cursor = -1

    Behavior on height {
        NumberAnimation {
            id: resizing
            duration: Motion.resize
            easing.bezierCurve: Curve.easing(Motion.curvePointToPoint)
        }
    }
    onCursorChanged: if (cursor >= 0) list.positionViewAtIndex(cursor, ListView.Contain)

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) query ? query = "" : dismissed()
        else if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) cursor = Clip.step(cursor, event.key === Qt.Key_Down ? 1 : -1, list.count)
        else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && list.count) picked(chosen().id)
        else if (event.key === Qt.Key_Delete && cursor >= 0) removed(chosen().id)
        else if (event.key === Qt.Key_Backspace) query = query.slice(0, -1)
        else if (event.text && event.text >= " " && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier))) query += event.text
        else return
        event.accepted = true
    }

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

    Item {
        objectName: "header"
        width: parent.width
        height: Metrics.clipHeader

        Label {
            objectName: "title"
            x: Metrics.clipInset
            anchors.verticalCenter: parent.verticalCenter
            text: "Clipboard"
            font.weight: Type.bodyStrong.weight
        }

        Rectangle {
            objectName: "clearAll"
            visible: root.entries.length > 0
            x: parent.width - width - Metrics.clipInset
            anchors.verticalCenter: parent.verticalCenter
            width: Math.ceil(label.implicitWidth) + 2 * Metrics.clipPad
            height: Metrics.clipButton
            radius: Metrics.controlRadius
            color: clear.pressed ? Colors.controlFillPressed : clear.containsMouse ? Colors.controlFillHover : Colors.controlFill
            border.width: 1
            border.color: Colors.controlStroke

            Label {
                id: label
                objectName: "label"
                anchors.centerIn: parent
                text: "Clear all"
            }

            MouseArea {
                id: clear
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.cleared()
            }
        }
    }

    Rectangle {
        objectName: "searchBox"
        visible: root.query !== ""
        x: Metrics.clipInset
        y: Metrics.clipHeader
        width: parent.width - 2 * Metrics.clipInset
        height: Metrics.clipSearch
        radius: Metrics.controlRadius
        color: Colors.startSearchFill
        border.width: 1
        border.color: Colors.startSearchStroke

        FluentIcon {
            x: Metrics.clipPad
            anchors.verticalCenter: parent.verticalCenter
            name: Glyphs.glyph("search")
            color: Colors.textSecondary
            size: Type.caption.size
        }

        Label {
            objectName: "query"
            x: Metrics.clipPad + 24
            width: parent.width - x - Metrics.clipPad
            anchors.verticalCenter: parent.verticalCenter
            text: root.query
            elide: Text.ElideLeft
        }
    }

    Column {
        objectName: "empty"
        visible: opacity > 0
        opacity: list.count === 0 ? 1 : 0
        y: root.listTop + (Metrics.clipEmpty - height) / 2
        x: Metrics.clipInset
        width: parent.width - 2 * Metrics.clipInset
        spacing: 4

        Behavior on opacity {
            NumberAnimation { duration: Motion.controlFaster }
        }

        Label {
            objectName: "emptyTitle"
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.query ? "No results" : "Nothing here"
            font.weight: Type.bodyStrong.weight
        }

        Label {
            objectName: "emptyBody"
            visible: !root.query
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: "You'll see your clipboard history here once you've copied something."
            color: Colors.textSecondary
            font.pixelSize: Type.caption.size
        }
    }

    ListView {
        id: list
        objectName: "list"
        x: Metrics.clipInset
        y: root.listTop
        width: parent.width - 2 * Metrics.clipInset
        height: parent.height - y - Metrics.clipInset
        clip: true
        spacing: Metrics.clipGap
        boundsBehavior: Flickable.StopAtBounds
        model: root.found

        delegate: ClipboardCard {
            required property var modelData
            required property int index
            objectName: `card:${modelData.id}`
            width: list.width
            entry: modelData
            source: root.source(modelData)
            icon: modelData.app ? root.iconOf(modelData.app) : ""
            focused: index === root.cursor
            expanded: modelData.id === root.opened
            onPicked: root.picked(modelData.id)
            onPinToggled: root.pinned(modelData.id, !modelData.pinned)
            onMoreToggled: root.opened = expanded ? -1 : modelData.id
            onActed: name => root.act(modelData, name)
        }
    }

    WheelGlide {
        view: list
        anchors.fill: list
    }

    HoverHandler { id: over }

    ScrollRail {
        objectName: "scrollBar"
        view: list
        x: parent.width - width
        y: list.y
        height: list.height
        watching: over.hovered
    }
}
