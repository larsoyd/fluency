import QtQuick
import qs.tokens
import "../logic/apps.mjs" as Apps
import "../logic/scroll.mjs" as Scroll
import "../logic/glyphs.mjs" as Glyphs

Flickable {
    id: root

    property var entries: []
    property var pins: []
    property bool showAll: false
    property string query: ""
    readonly property bool searching: query.trim() !== ""
    property int selectedIndex: 0
    readonly property var results: Apps.search(entries, query)
    readonly property var grid: Apps.pinned(pins, entries, Metrics.startColumns, Metrics.startPinnedRows, showAll)
    readonly property var list: Apps.placed(Apps.listed(entries), {
        item: Metrics.startListItem, letter: Metrics.startLetter, above: Metrics.startLetterAbove, below: Metrics.startLetterBelow,
    })
    readonly property int gridY: Metrics.startHeaderY + Metrics.startHeaderHeight + Metrics.startGridGap
    readonly property int allY: gridY + grid.rows * Metrics.startCellHeight + Metrics.startSectionGap
    readonly property int listY: allY + Metrics.startHeaderHeight + Metrics.startListGap

    onResultsChanged: {
        selectedIndex = 0
        contentY = 0
    }

    function moveSelection(delta) {
        if (!results.length) return
        selectedIndex = Math.max(0, Math.min(results.length - 1, selectedIndex + delta))
        const top = Metrics.startHeaderY + Metrics.startHeaderHeight + Metrics.startListGap + selectedIndex * Metrics.startListItem
        contentY = Math.max(0, Math.min(Math.max(0, contentHeight - height),
            top < contentY ? top : Math.max(contentY, top + Metrics.startListItem - height)))
    }

    signal launched(string id)
    signal appAsked(string id, bool tile, point at)

    clip: true
    contentWidth: width
    contentHeight: searching
        ? Metrics.startHeaderY + Metrics.startHeaderHeight + Metrics.startListGap + results.length * Metrics.startListItem + Metrics.startListEnd
        : listY + list.height + Metrics.startListEnd
    boundsBehavior: Flickable.StopAtBounds

    // wayland wheels never reached a handler in the flickable, no buttons so rows keep clicks
    MouseArea {
        width: root.contentWidth
        height: root.contentHeight
        z: 1
        acceptedButtons: Qt.NoButton
        onWheel: event => {
            if (!event.angleDelta.y || event.pixelDelta.y) {
                event.accepted = false
                return
            }
            glide.to = Scroll.wheelTarget(glide.running ? glide.to : root.contentY, event.angleDelta.y, root.height, root.contentHeight)
            glide.restart()
        }
    }

    NumberAnimation {
        id: glide
        target: root
        property: "contentY"
        duration: Motion.controlNormal
        easing.type: Easing.OutCubic
    }

    component Header: Text {
        x: Metrics.startHeaderX
        height: Metrics.startHeaderHeight
        verticalAlignment: Text.AlignVCenter
        renderType: Text.NativeRendering
        color: Colors.textPrimary
        font.family: Type.family
        font.pixelSize: Type.bodyStrong.size
        font.weight: Type.bodyStrong.weight
    }

    Header {
        objectName: "pinnedHeader"
        visible: !root.searching
        y: Metrics.startHeaderY
        text: "Pinned"
    }

    Item {
        id: more
        objectName: "showAll"
        readonly property bool pressed: moreArea.pressed
        visible: root.grid.more && !root.searching
        x: root.width - Metrics.startHeaderRight - width
        y: Metrics.startHeaderY + (Metrics.startHeaderHeight - height) / 2
        width: Metrics.startMorePadLeft + moreText.implicitWidth + Metrics.startMoreTextGap + moreGlyph.implicitWidth + Metrics.startMorePadRight
        height: Metrics.startMoreHeight

        Rectangle {
            objectName: "fill"
            anchors.fill: parent
            radius: Metrics.buttonRadius
            color: more.pressed ? Colors.controlFillPressed : moreArea.containsMouse ? Colors.controlFillHover : Colors.controlFill
            border.width: Metrics.flyoutBorder
            border.color: Colors.controlStroke
        }

        Text {
            id: moreText
            objectName: "showAllText"
            renderType: Text.NativeRendering
            x: Metrics.startMorePadLeft
            anchors.verticalCenter: parent.verticalCenter
            text: root.showAll ? "Show less" : "Show all"
            color: more.pressed ? Colors.textSecondary : Colors.textPrimary
            font.family: Type.family
            font.pixelSize: Type.caption.size
        }

        FluentIcon {
            id: moreGlyph
            objectName: "showAllGlyph"
            x: moreText.x + moreText.implicitWidth + Metrics.startMoreTextGap
            anchors.verticalCenter: parent.verticalCenter
            name: Glyphs.glyph("more")
            color: moreText.color
            size: Metrics.startMoreGlyph
        }

        MouseArea {
            id: moreArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.showAll = !root.showAll
        }
    }

    Repeater {
        model: root.searching ? [] : root.grid.cells

        StartButton {
            required property var modelData
            objectName: `pin:${modelData.id}`
            x: Metrics.startGridX + modelData.column * Metrics.startCellWidth
            y: root.gridY + modelData.row * Metrics.startCellHeight
            width: Metrics.startCellWidth
            height: Metrics.startCellHeight
            onClicked: root.launched(modelData.id)
            onMenuRequested: root.appAsked(modelData.id, true, mapToItem(root, point.x, point.y))

            Image {
                objectName: "icon"
                x: (parent.width - width) / 2
                y: Metrics.startTileTop
                width: Metrics.startTileIcon
                height: Metrics.startTileIcon
                sourceSize: Qt.size(width, height)
                source: parent.modelData.icon
            }

            Text {
                objectName: "label"
                renderType: Text.NativeRendering
                x: Metrics.startTileTextX
                y: Metrics.startTileTop + Metrics.startTileIcon + Metrics.startTileGap
                width: parent.width - 2 * Metrics.startTileTextX
                text: parent.modelData.name
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                color: Colors.textPrimary
                font.family: Type.family
                font.pixelSize: Type.caption.size
            }
        }
    }

    Header {
        objectName: "allHeader"
        visible: !root.searching
        y: root.allY
        text: "All"
    }

    Repeater {
        model: root.searching ? [] : root.list.rows

        Loader {
            required property var modelData
            y: root.listY + modelData.y
            sourceComponent: modelData.kind === "letter" ? letterRow : appRow
        }
    }

    Component {
        id: letterRow

        Header {
            objectName: `letter:${parent.modelData.text}`
            x: Metrics.startHeaderX
            height: Metrics.startLetter
            text: parent.modelData.text
        }
    }

    Header {
        objectName: "resultsHeader"
        visible: root.searching
        y: Metrics.startHeaderY
        text: "Apps"
    }

    Repeater {
        model: root.results

        AppRow {
            required property var modelData
            required property int index
            entry: modelData
            objectName: `result:${modelData.id}`
            y: Metrics.startHeaderY + Metrics.startHeaderHeight + Metrics.startListGap + index * Metrics.startListItem
            forceHovered: index === root.selectedIndex
        }
    }

    Component {
        id: appRow

        AppRow {
            entry: parent.modelData
            objectName: `app:${entry.id}`
        }
    }

    component AppRow: StartButton {
        id: row
        property var entry
        x: Metrics.startListX
        width: root.width - 2 * Metrics.startListX
        height: Metrics.startListItem
        onClicked: root.launched(entry.id)
        onMenuRequested: root.appAsked(entry.id, false, mapToItem(root, point.x, point.y))

        Image {
            objectName: "icon"
            x: Metrics.startListIconX
            y: (parent.height - height) / 2
            width: Metrics.startListIcon
            height: Metrics.startListIcon
            sourceSize: Qt.size(width, height)
            source: row.entry.icon
        }

        Text {
            objectName: "label"
            renderType: Text.NativeRendering
            x: Metrics.startListTextX
            anchors.verticalCenter: parent.verticalCenter
            text: row.entry.name
            color: Colors.textPrimary
            font.family: Type.family
            font.pixelSize: Type.caption.size
        }
    }
}
