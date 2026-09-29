import QtQuick
import qs.tokens
import "../logic/context.mjs" as Context
import "../logic/curve.mjs" as Curve

FocusScope {
    id: root

    property bool open: false
    property var rows: []
    property var subs: ({})
    property point at: Qt.point(0, 0)
    property int sub: -1
    property size area: Qt.size(width, height)
    property alias closing: closing
    property alias growing: growing
    property alias delay: delay
    // the part that shows, a window sized to it keeps the blur off the rest of the screen
    readonly property rect box: {
        const left = subPanel.visible ? Math.min(main.x, subPanel.x) : main.x
        const top = subPanel.visible ? Math.min(main.y, subPanel.y) : main.y
        const right = subPanel.visible ? Math.max(main.x + main.width, subPanel.x + subPanel.width) : main.x + main.width
        const bottom = subPanel.visible ? Math.max(main.y + main.height, subPanel.y + subPanel.height) : main.y + main.height
        return Qt.rect(left, top, right - left, bottom - top)
    }
    readonly property var subRows: sub >= 0 ? subs[rows[sub]?.submenu] ?? [] : []
    readonly property var subAt: {
        const placed = Context.placed(rows, Metrics.context)
        return Context.submenu({ x: main.x, y: main.y, width: main.width }, placed[sub]?.y ?? 0, { width: subPanel.width, height: subPanel.height }, { width: area.width, height: area.height }, Metrics.context)
    }

    signal picked(string action)
    signal closed()

    function show(list, menus, x, y) {
        rows = list
        subs = menus
        at = Qt.point(x, y)
        sub = -1
        // a hover while the last menu faded may still be pending
        delay.stop()
        main.highlight = -1
        subPanel.highlight = -1
        open = true
        closing.stop()
        subPanel.drop = 0
        growing.restart()
        forceActiveFocus()
    }

    function close() {
        if (!open) return
        open = false
        delay.stop()
        closing.restart()
        closed()
    }

    function choose(list, index, isMain) {
        const row = list[index]
        if (!row || row.kind !== "item" || row.enabled === false) return
        if (isMain && row.submenu) {
            delay.stop()
            sub = index
            main.highlight = index
            return
        }
        open = false
        delay.stop()
        closing.restart()
        picked(row.action)
    }

    readonly property bool shown: open || closing.running

    visible: shown

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        // the release lands here too, a surface gone with a button down leaves the desktop deaf
        onClicked: root.close()
    }

    ContextPanel {
        id: main
        objectName: "main"
        readonly property var spot: Context.open(root.at, { width, height }, { width: root.area.width, height: root.area.height })
        x: spot.x
        y: spot.y
        fromTop: spot.y >= root.at.y
        rows: root.rows
        onChosen: index => root.choose(root.rows, index, true)
        onPressed: action => {
            root.open = false
            delay.stop()
            closing.restart()
            root.picked(action)
        }
        onHovered: index => {
            highlight = index
            delay.pending = index
            delay.restart()
        }
    }

    ContextPanel {
        id: subPanel
        objectName: "sub"
        visible: root.sub >= 0 && root.shown
        fromTop: true
        x: root.subAt.x
        y: root.subAt.y
        rows: root.subRows
        onChosen: index => root.choose(root.subRows, index, false)
        onHovered: index => {
            highlight = index
            delay.stop()
        }
    }

    // a submenu opens and closes after the pointer rests on a row
    Timer {
        id: delay
        property int pending: -1
        interval: Motion.menuShowDelay
        onTriggered: root.sub = root.rows[pending]?.submenu ? pending : -1
    }

    NumberAnimation {
        id: growing
        target: main
        property: "drop"
        from: main.height * Metrics.menuClosedRatio
        to: 0
        duration: Motion.menuOpen
        easing.bezierCurve: Curve.easing(Motion.curveDecelerate)
    }

    // the blurred area follows the folding panels, so nothing is left to pop at the end
    ParallelAnimation {
        id: closing

        NumberAnimation {
            target: main
            property: "drop"
            to: main.height
            duration: Motion.menuClose
            easing.bezierCurve: Curve.easing(Motion.curveDecelerate)
        }

        NumberAnimation {
            target: subPanel
            property: "drop"
            to: subPanel.height
            duration: Motion.menuClose
            easing.bezierCurve: Curve.easing(Motion.curveDecelerate)
        }
    }

    Keys.onPressed: event => {
        const inSub = root.sub >= 0 && subPanel.highlight >= 0
        const panel = inSub ? subPanel : main, list = inSub ? root.subRows : root.rows
        event.accepted = true
        if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
            panel.highlight = Context.next(list, panel.highlight, event.key === Qt.Key_Down ? 1 : -1)
        } else if (event.key === Qt.Key_Right && !inSub && root.rows[main.highlight]?.submenu) {
            root.sub = main.highlight
            subPanel.highlight = Context.next(root.subRows, -1, 1)
        } else if (event.key === Qt.Key_Left && inSub) {
            root.sub = -1
            subPanel.highlight = -1
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (inSub) root.choose(root.subRows, subPanel.highlight, false)
            else if (root.rows[main.highlight]?.submenu) {
                root.sub = main.highlight
                subPanel.highlight = Context.next(root.subRows, -1, 1)
            } else root.choose(root.rows, main.highlight, true)
        } else if (event.key === Qt.Key_Escape) {
            if (root.sub >= 0) root.sub = -1
            else root.close()
        } else event.accepted = false
    }
}
