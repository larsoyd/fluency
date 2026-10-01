import QtQuick
import qs.tokens
import "../logic/acrylic.mjs" as Acrylic
import "../logic/curve.mjs" as Curve
import "../logic/glyphs.mjs" as Glyphs
import "../logic/launches.mjs" as Launches
import "../logic/searchpane.mjs" as Pane

Item {
    id: root

    property var entries: []
    property var links: []
    property var pins: []
    property var taskbarPins: []
    property var launches: ({})
    property alias query: input.text
    property string tab: "all"
    property bool typing: true
    property int selectedIndex: 0
    readonly property bool home: Pane.home(tab, query)
    readonly property var results: Pane.results(tab, query, entries, links)
    readonly property var hit: results[selectedIndex] ?? null
    readonly property var placed: Pane.placed(results, query.trim() !== "", {
        top: Metrics.searchHeaderY - Metrics.searchResultsY, header: Type.bodyStrong.lineHeight, gap: Metrics.startListGap,
        best: Metrics.searchBest, row: Metrics.searchResult, section: Metrics.searchSection,
    })
    readonly property int column: (width - 2 * Metrics.searchInset - Metrics.searchTileGap) / 2
    readonly property int rightX: Metrics.searchInset + column + Metrics.searchTileGap
    readonly property int tileWidth: (width - 2 * Metrics.searchInset - (Metrics.searchTiles - 1) * Metrics.searchTileGap) / Metrics.searchTiles
    readonly property var fill: Acrylic.fill({
        tint: [Colors.flyoutTint.r, Colors.flyoutTint.g, Colors.flyoutTint.b],
        luminosityOpacity: Colors.flyoutLuminosityOpacity,
    })

    signal acted(string action, string kind, string key)
    signal dismissed()

    width: Metrics.searchWidth
    height: Metrics.searchHeight

    onResultsChanged: {
        selectedIndex = 0
        list.contentY = 0
    }

    function select(delta) {
        selectedIndex = Pane.step(selectedIndex, delta, results.length)
        const row = placed.rows.find(row => row.kind === "hit" && row.index === selectedIndex)
        if (row) list.contentY = Math.max(0, Math.min(row.y, Math.max(list.contentY, row.y + row.height - list.height)))
    }

    // keys typed before the box takes focus still go into it
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) root.dismissed()
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { if (root.hit) root.acted("open", root.hit.kind, root.hit.key) }
        else if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) root.select(event.key === Qt.Key_Down ? 1 : -1)
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

    Rectangle {
        objectName: "search"
        x: Metrics.searchInset
        y: Metrics.searchTop
        width: root.width - 2 * Metrics.searchInset
        height: Metrics.searchBox
        radius: Metrics.buttonRadius
        color: Colors.startSearchFill
        border.width: Metrics.flyoutBorder
        border.color: Colors.startSearchStroke
        clip: true

        Glyph {
            objectName: "searchIcon"
            x: Metrics.searchBoxIconX
            anchors.verticalCenter: parent.verticalCenter
            text: Glyphs.glyph("search")
        }

        Label {
            objectName: "placeholder"
            visible: !input.text
            x: Metrics.searchBoxTextX
            anchors.verticalCenter: parent.verticalCenter
            text: "Type here to search"
            color: Colors.startPlaceholder
            font.pixelSize: Type.body.size
        }

        TextInput {
            id: input
            objectName: "searchInput"
            x: Metrics.searchBoxTextX
            width: parent.width - x - Metrics.searchBoxIconX
            anchors.verticalCenter: parent.verticalCenter
            focus: root.typing
            clip: true
            renderType: Text.NativeRendering
            color: Colors.textPrimary
            selectionColor: Colors.accent
            font.family: Type.family
            font.pixelSize: Type.body.size
        }

        // a focused text box draws its bottom edge in the accent
        Rectangle {
            objectName: "underline"
            visible: input.activeFocus
            anchors.bottom: parent.bottom
            width: parent.width
            height: Metrics.searchUnderline
            color: Colors.accentLight2
        }
    }

    Row {
        id: tabs
        x: Metrics.searchInset
        y: Metrics.searchTabsY
        spacing: Metrics.searchTabGap

        Repeater {
            id: tabItems
            model: Pane.tabs

            Item {
                required property var modelData
                objectName: `tab:${modelData.key}`
                width: Math.ceil(name.implicitWidth)
                height: Metrics.searchTabHeight

                Label {
                    id: name
                    objectName: "label"
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.modelData.name
                    color: root.tab === parent.modelData.key ? Colors.textPrimary : Colors.textSecondary
                    font.pixelSize: Type.body.size
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.tab = parent.modelData.key
                }
            }
        }
    }

    Rectangle {
        objectName: "pill"
        readonly property Item under: tabItems.count ? tabItems.itemAt(Pane.tabs.findIndex(tab => tab.key === root.tab)) : null
        x: tabs.x + (under ? under.x + (under.width - width) / 2 : 0)
        y: tabs.y + Metrics.searchTabHeight - height
        width: Metrics.searchPillWidth
        height: Metrics.searchPillHeight
        radius: height / 2
        color: Colors.accentLight2

        Behavior on x {
            NumberAnimation {
                duration: Motion.controlNormal
                easing.bezierCurve: Curve.easing(Motion.curvePointToPoint)
            }
        }
    }

    component Label: Text {
        renderType: Text.NativeRendering
        color: Colors.textPrimary
        font.family: Type.family
        font.pixelSize: Type.caption.size
    }

    component Header: Label {
        height: Type.bodyStrong.lineHeight
        verticalAlignment: Text.AlignVCenter
        font.pixelSize: Type.bodyStrong.size
        font.weight: Type.bodyStrong.weight
    }

    component Glyph: Text {
        renderType: Text.NativeRendering
        color: Colors.textPrimary
        font.family: Type.iconFamily
        font.pixelSize: Metrics.startGlyph
    }

    // an app draws its icon, a folder its glyph in the same box
    component Picture: Item {
        property string icon: ""
        property string glyph: ""
        property int glyphSize: height
        Image {
            anchors.fill: parent
            visible: !parent.glyph
            source: parent.icon
            sourceSize: Qt.size(width, height)
        }
        Glyph {
            anchors.centerIn: parent
            text: parent.glyph
            font.pixelSize: parent.glyphSize
        }
    }

    component Line: StartButton {
        id: line
        property string icon: ""
        property string glyph: ""
        property string label: ""
        property string detail: ""
        property int iconSize: Metrics.startListIcon
        Picture {
            x: Metrics.searchRowIconX
            anchors.verticalCenter: parent.verticalCenter
            width: line.iconSize
            height: line.iconSize
            glyphSize: Math.min(line.iconSize, Metrics.startGlyph)
            icon: line.icon
            glyph: line.glyph
        }
        Column {
            x: Metrics.searchRowIconX + line.iconSize + Metrics.searchRowIconX
            width: parent.width - x - Metrics.searchRowIconX
            anchors.verticalCenter: parent.verticalCenter
            Label {
                width: parent.width
                text: line.label
                elide: Text.ElideRight
                font.pixelSize: line.detail ? Type.body.size : Type.caption.size
            }
            Label {
                visible: line.detail !== ""
                text: line.detail
                color: Colors.textSecondary
            }
        }
    }

    Item {
        objectName: "home"
        anchors.fill: parent
        visible: root.home

        Header {
            objectName: "topHeader"
            x: Metrics.searchInset
            y: Metrics.searchHeaderY
            text: "Top apps"
        }

        Repeater {
            model: root.home ? Launches.top(root.launches, root.entries, Metrics.searchTiles, root.pins) : []

            StartButton {
                id: tile
                required property var modelData
                required property int index
                objectName: `top:${modelData.id}`
                x: Metrics.searchInset + index * (root.tileWidth + Metrics.searchTileGap)
                y: Metrics.searchTilesY
                width: root.tileWidth
                height: Metrics.searchTile
                onClicked: root.acted("open", "app", modelData.id)

                Rectangle {
                    anchors.fill: parent
                    z: -1
                    radius: Metrics.buttonRadius
                    color: Colors.cardFill
                    border.width: Metrics.flyoutBorder
                    border.color: Colors.cardStroke
                }

                Picture {
                    x: (parent.width - width) / 2
                    y: Metrics.searchTileIconY
                    width: Metrics.startTileIcon
                    height: Metrics.startTileIcon
                    icon: tile.modelData.icon
                }

                Label {
                    x: Metrics.startTileTextX
                    y: Metrics.searchTileTextY
                    width: parent.width - 2 * x
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: tile.modelData.name
                }
            }
        }

        Header {
            objectName: "recentHeader"
            x: Metrics.searchInset
            y: Metrics.searchListsY
            text: "Recent"
        }

        Label {
            objectName: "recentEmpty"
            visible: !Object.keys(root.launches).length
            x: Metrics.searchInset
            y: Metrics.searchListsY + Type.bodyStrong.lineHeight + Metrics.startListGap
            height: Metrics.searchRow
            verticalAlignment: Text.AlignVCenter
            text: "Apps you open show up here"
            color: Colors.textSecondary
        }

        Repeater {
            model: root.home ? Launches.recent(root.launches, root.entries, Metrics.searchRows) : []

            Line {
                required property var modelData
                required property int index
                objectName: `recent:${modelData.id}`
                x: Metrics.searchInset
                y: Metrics.searchListsY + Type.bodyStrong.lineHeight + Metrics.startListGap + index * Metrics.searchRow
                width: root.column
                height: Metrics.searchRow
                icon: modelData.icon
                label: modelData.name
                onClicked: root.acted("open", "app", modelData.id)
            }
        }

        Header {
            objectName: "linksHeader"
            x: root.rightX
            y: Metrics.searchListsY
            text: "Quick links"
        }

        Repeater {
            model: root.links.slice(0, Metrics.searchRows)

            Line {
                required property var modelData
                required property int index
                objectName: `link:${modelData.name}`
                x: root.rightX
                y: Metrics.searchListsY + Type.bodyStrong.lineHeight + Metrics.startListGap + index * Metrics.searchRow
                width: root.column
                height: Metrics.searchRow
                glyph: modelData.glyph
                label: modelData.name
                onClicked: root.acted("open", "folder", modelData.path)
            }
        }
    }

    Flickable {
        id: list
        objectName: "results"
        visible: !root.home
        x: Metrics.searchInset
        y: Metrics.searchResultsY
        width: root.column
        height: root.height - Metrics.searchTop - y
        clip: true
        contentWidth: width
        contentHeight: root.placed.height
        boundsBehavior: Flickable.StopAtBounds

        Repeater {
            model: root.home ? [] : root.placed.rows

            Loader {
                required property var modelData
                y: modelData.y
                sourceComponent: modelData.kind === "header" ? groupHeader : resultRow
            }
        }

        Component {
            id: groupHeader

            Header {
                objectName: parent.modelData.text === "Best match" ? "bestHeader" : "moreHeader"
                text: parent.modelData.text
            }
        }

        Component {
            id: resultRow

            Line {
                readonly property var result: parent.modelData.hit
                objectName: `result:${result.kind === "app" ? result.key : result.name}`
                width: root.column
                height: parent.modelData.height
                iconSize: height === Metrics.searchBest ? Metrics.startTileIcon : Metrics.startListIcon
                icon: result.icon
                glyph: result.glyph
                label: result.name
                detail: height === Metrics.searchBest ? result.kindName : ""
                forceHovered: parent.modelData.index === root.selectedIndex
                onClicked: root.acted("open", result.kind, result.key)
            }
        }
    }

    Label {
        objectName: "noResults"
        visible: !root.home && !root.results.length
        x: Metrics.searchInset
        y: Metrics.searchHeaderY
        text: `No results for “${root.query.trim()}”`
        font.pixelSize: Type.body.size
    }

    Rectangle {
        objectName: "preview"
        visible: root.hit !== null
        x: root.rightX
        y: Metrics.searchHeaderY
        width: root.column
        height: root.height - Metrics.searchTop - y
        radius: Metrics.flyoutRadius
        color: Colors.cardFill
        border.width: Metrics.flyoutBorder
        border.color: Colors.cardStroke

        Picture {
            objectName: "previewIcon"
            x: (parent.width - width) / 2
            y: 2 * Metrics.searchPreviewPad
            width: Metrics.searchPreviewIcon
            height: Metrics.searchPreviewIcon
            glyphSize: height * 3 / 4
            icon: root.hit?.icon ?? ""
            glyph: root.hit?.glyph ?? ""
        }

        Label {
            id: title
            objectName: "previewName"
            x: Metrics.searchPreviewPad
            y: 2 * Metrics.searchPreviewPad + Metrics.searchPreviewIcon + Metrics.searchPreviewPad
            width: parent.width - 2 * x
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.hit?.name ?? ""
            font.pixelSize: Type.subtitle.size
            font.weight: Type.subtitle.weight
        }

        Label {
            id: kind
            objectName: "previewKind"
            x: title.x
            y: title.y + Type.subtitle.lineHeight
            width: title.width
            horizontalAlignment: Text.AlignHCenter
            text: root.hit?.kindName ?? ""
            color: Colors.textSecondary
        }

        Rectangle {
            id: rule
            objectName: "previewRule"
            x: Metrics.searchPreviewPad
            y: kind.y + Type.caption.lineHeight + Metrics.searchPreviewPad
            width: parent.width - 2 * x
            height: 1
            color: Colors.divider
        }

        Column {
            x: Metrics.flyoutBorder + Metrics.startListGap
            y: rule.y + Metrics.startListGap + 1
            width: parent.width - 2 * x

            Repeater {
                model: root.hit ? Pane.actions(root.hit, root.pins, root.taskbarPins) : []

                Line {
                    required property var modelData
                    objectName: `action:${modelData.action}`
                    width: parent.width
                    height: Metrics.searchResult
                    iconSize: Metrics.startGlyph
                    glyph: modelData.glyph
                    label: modelData.text
                    onClicked: root.acted(modelData.action, root.hit.kind, root.hit.key)
                }
            }
        }
    }
}
