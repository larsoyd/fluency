import QtQuick
import qs.tokens
import "../logic/desktop.mjs" as Desktop

Item {
    id: root

    property var items: []
    property var settings: ({ icon: 48, auto: false, grid: true, shown: true })
    property var places: ({})
    property bool active: false
    property var cut: []
    property var selected: []
    property string anchor: ""
    property string current: ""
    property string hovered: ""
    property bool cue: false
    property bool dragging: false
    property point dragBy: Qt.point(0, 0)
    property string editing: ""
    property string target: ""
    readonly property bool pressing: area.pressedButtons !== 0
    property alias band: band
    readonly property var m: Desktop.metrics(settings.icon)
    readonly property var order: items.map(item => item.name)
    readonly property var spots: Desktop.arrange(order, places, { width, height }, m, settings)

    signal opened(var names)
    signal menu(var names, real x, real y)
    signal moved(var places, var order)
    signal keyed(string action)
    signal renamed(string name, string text)
    signal touched()
    signal dropped(var names, string folder)

    function entry(name) {
        return items.find(item => item.name === name) ?? {}
    }

    function drawn() {
        const out = []
        if (!settings.shown) return out
        for (let i = 0; i < icons.count; i++) {
            const it = icons.itemAt(i)
            if (it) out.push({ name: it.name, x: it.x, y: it.y, h: it.height })
        }
        return out
    }

    function hit(x, y) {
        if (!settings.shown) return ""
        const found = drawn().find(s => x >= s.x && x < s.x + m.plateWidth && y >= s.y && y < s.y + s.h)
        return found ? found.name : ""
    }

    function apply(next) {
        selected = next.selected
        anchor = next.anchor
        current = next.focus
    }

    function choose(name, mods) {
        apply(Desktop.click({ selected, anchor, focus: current }, order, name, mods))
    }

    // the focused item when it is chosen, else the first chosen one
    function focusName() {
        return selected.includes(current) ? current : selected[0] ?? ""
    }

    function clear() {
        apply({ selected: [], anchor: "", focus: current })
    }

    function rename(from, to) {
        const swap = name => name === from ? to : name
        apply({ selected: selected.map(swap), anchor: swap(anchor), focus: swap(current) })
    }

    // a folder under the pointer takes what is dragged onto it
    function folderAt(x, y) {
        const name = hit(x, y)
        return name && entry(name).dir && !selected.includes(name) ? name : ""
    }

    function open(names) {
        if (!names.length) return
        opened(names)
        apply({ selected: [], anchor: "", focus: current })
    }

    function focusPoint() {
        const s = drawn().find(spot => spot.name === (current || selected[0]))
        return s ? Qt.point(s.x + m.plateWidth / 2, s.y + m.pad + m.icon / 2) : Qt.point(width / 2, height / 2)
    }

    // typing a letter jumps to the next name that starts with it
    function seek(letter) {
        if (!settings.shown) return ""
        const from = order.indexOf(current)
        for (let i = 1; i <= order.length; i++) {
            const name = order[(from + i + order.length) % order.length]
            if ((entry(name).label ?? "").toLowerCase().startsWith(letter)) return name
        }
        return ""
    }

    function edit(name) {
        const spot = drawn().find(s => s.name === name)
        if (!spot) return
        editing = name
        editor.text = entry(name).label ?? name
        editor.selectAll()
        editor.forceActiveFocus()
    }

    function finish(keep) {
        if (!editing) return
        const name = editing
        editing = ""
        root.forceActiveFocus()
        if (keep) renamed(name, editor.text)
    }

    function walk(key, mods) {
        const next = Desktop.step(drawn(), current, key)
        if (!next) return
        cue = true
        if (mods.ctrl) current = next
        else choose(next, { shift: mods.shift })
    }

    focus: true
    activeFocusOnTab: true

    onItemsChanged: if (editing && !items.some(item => item.name === editing)) finish(false)

    Repeater {
        id: icons
        model: root.spots

        DesktopItem {
            required property var modelData
            readonly property string name: modelData.name
            objectName: "item:" + name
            x: modelData.x
            y: modelData.y
            m: root.m
            visible: root.settings.shown
            source: root.entry(name).source ?? ""
            label: root.entry(name).label ?? name
            link: root.entry(name).link ?? false
            hovered: root.dragging ? root.target === name : root.hovered === name
            editing: root.editing === name
            selected: root.selected.includes(name)
            active: root.active
            current: root.current === name
            cue: root.cue
            cut: root.cut.includes(name)
        }
    }

    Repeater {
        model: root.dragging ? root.selected : []

        DesktopItem {
            required property var modelData
            readonly property var spot: root.spots.find(s => s.name === modelData) ?? { x: 0, y: 0 }
            objectName: "ghost:" + modelData
            x: spot.x + root.dragBy.x
            y: spot.y + root.dragBy.y
            m: root.m
            opacity: 0.5
            source: root.entry(modelData).source ?? ""
            label: root.entry(modelData).label ?? modelData
            link: root.entry(modelData).link ?? false
        }
    }

    Rectangle {
        id: band
        objectName: "band"
        visible: false
        color: Colors.marqueeFill
        border.width: 1
        border.color: Colors.marqueeStroke
    }

    MouseArea {
        id: area

        property point from
        property string grabbed: ""
        property bool deferred: false
        property bool banding: false
        property bool swallow: false
        property var base: []

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true

        onPressed: mouse => {
            root.finish(true)
            root.forceActiveFocus()
            root.cue = false
            swallow = false
            const name = root.hit(mouse.x, mouse.y)
            const mods = { ctrl: !!(mouse.modifiers & Qt.ControlModifier), shift: !!(mouse.modifiers & Qt.ShiftModifier) }
            if (mouse.button === Qt.RightButton) {
                if (!name || !root.selected.includes(name)) root.choose(name, {})
                root.menu(name ? root.selected : [], mouse.x, mouse.y)
                return
            }
            from = Qt.point(mouse.x, mouse.y)
            grabbed = name
            deferred = !!name && root.selected.includes(name) && !mods.ctrl && !mods.shift
            if (name && !deferred) root.choose(name, mods)
            if (!name) {
                if (!mods.ctrl) root.choose("", {})
                banding = true
                base = root.selected
            }
        }

        onPositionChanged: mouse => {
            root.hovered = root.hit(mouse.x, mouse.y)
            if (!(mouse.buttons & Qt.LeftButton)) return
            const dx = mouse.x - from.x, dy = mouse.y - from.y
            if (grabbed && !root.dragging && Math.hypot(dx, dy) > Metrics.dragThreshold && root.selected.includes(grabbed)) root.dragging = true
            if (root.dragging) {
                root.dragBy = Qt.point(dx, dy)
                root.target = root.folderAt(mouse.x, mouse.y)
            }
            if (!banding) return
            band.x = Math.min(from.x, mouse.x)
            band.y = Math.min(from.y, mouse.y)
            band.width = Math.abs(dx)
            band.height = Math.abs(dy)
            band.visible = true
            root.selected = Desktop.band({ x: band.x, y: band.y, width: band.width, height: band.height }, root.drawn(), root.m, base)
        }

        // taking the keyboard lets go of every button, so it waits for the release
        onReleased: mouse => {
            if (mouse.button !== Qt.LeftButton || swallow) return
            root.touched()
            if (root.dragging && root.target) {
                root.dropped(root.selected, root.target)
            } else if (root.dragging) {
                const done = Desktop.drop(root.spots, root.selected, root.dragBy.x, root.dragBy.y, root.order, { width: root.width, height: root.height }, root.m, root.settings)
                root.moved(done.places, done.order)
            } else if (deferred) {
                root.choose(grabbed, {})
            }
            root.dragging = false
            root.target = ""
            banding = false
            band.visible = false
            grabbed = ""
        }

        onDoubleClicked: mouse => {
            const name = root.hit(mouse.x, mouse.y)
            if (!name || mouse.button !== Qt.LeftButton) return
            swallow = true
            root.open(root.selected.includes(name) ? root.selected : [name])
        }

        onExited: root.hovered = ""

        onWheel: wheel => {
            if (!(wheel.modifiers & Qt.ControlModifier)) {
                wheel.accepted = false
                return
            }
            root.keyed(wheel.angleDelta.y > 0 ? "grow" : "shrink")
        }
    }

    Rectangle {
        objectName: "editorFill"
        readonly property var spot: root.drawn().find(s => s.name === root.editing) ?? { x: 0, y: 0 }
        visible: root.editing !== ""
        // the box hugs the name and grows with it up to the cell
        x: spot.x + (root.m.plateWidth - width) / 2
        y: spot.y + root.m.pad + root.m.icon
        width: Math.min(root.m.plateWidth, Math.ceil(typed.advanceWidth) + 8)
        height: editor.height + 2

        TextMetrics {
            id: typed
            font: editor.font
            text: editor.text
        }
        color: "white"
        border.width: 1
        border.color: "black"

        TextEdit {
            id: editor
            objectName: "editor"
            x: 1
            y: 1
            width: parent.width - 2
            visible: root.editing !== ""
            color: "black"
            selectionColor: Colors.accent
            selectedTextColor: "white"
            font.family: Type.family
            font.pixelSize: Type.caption.size
            horizontalAlignment: TextEdit.AlignHCenter
            wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.finish(true)
                else if (event.key === Qt.Key_Escape) root.finish(false)
                else return
                event.accepted = true
            }
        }
    }

    // the digit keys are read by place so shift does not turn them into symbols
    readonly property var sizeKeys: ({ 11: "size:96", 12: "size:48", 13: "size:32" })
    readonly property var digits: ({ [Qt.Key_2]: "size:96", [Qt.Key_3]: "size:48", [Qt.Key_4]: "size:32" })
    readonly property var arrows: ({ [Qt.Key_Up]: "up", [Qt.Key_Down]: "down", [Qt.Key_Left]: "left", [Qt.Key_Right]: "right", [Qt.Key_Home]: "home", [Qt.Key_End]: "end" })
    readonly property var plain: ({ [Qt.Key_Delete]: "delete", [Qt.Key_F2]: "rename", [Qt.Key_F5]: "refresh" })
    readonly property var withCtrl: ({ [Qt.Key_C]: "copy", [Qt.Key_X]: "cut", [Qt.Key_V]: "paste" })

    Keys.onPressed: event => {
        const ctrl = !!(event.modifiers & Qt.ControlModifier), shift = !!(event.modifiers & Qt.ShiftModifier)
        const said = ctrl && shift ? (event.key === Qt.Key_C ? "path" : digits[event.key] ?? sizeKeys[event.nativeScanCode])
                   : ctrl ? withCtrl[event.key] : plain[event.key]
        event.accepted = true
        if (said) root.keyed(said)
        else if (arrows[event.key]) root.walk(arrows[event.key], { ctrl, shift })
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.open(root.selected)
        else if (ctrl && event.key === Qt.Key_A) root.selected = root.drawn().map(spot => spot.name)
        else if (ctrl && event.key === Qt.Key_Space && root.current) root.choose(root.current, { ctrl: true })
        else if (event.key === Qt.Key_Menu || (shift && event.key === Qt.Key_F10)) {
            const at = root.focusPoint()
            root.menu(root.selected, at.x, at.y)
        } else if (!ctrl && /^\S$/.test(event.text)) {
            const name = root.seek(event.text.toLowerCase())
            if (name) { root.cue = true; root.choose(name, {}) }
        } else event.accepted = false
    }
}
