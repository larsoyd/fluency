import QtQuick
import qs.tokens
import "../logic/acrylic.mjs" as Acrylic
import "../logic/bounce.mjs" as Bounce
import "../logic/layout.mjs" as Layout
import "../logic/tasks.mjs" as Tasks
import "../logic/glyphs.mjs" as Glyphs

Item {
    id: root

    property int trayWidth: 0
    property string openName: ""
    property var tasks: []
    property var byKey: ({})
    property var drag: ({ from: -1, by: 0 })
    property bool jumping: false
    property string settling: ""
    property real settleBy: 0
    property bool settleAnimated: false
    readonly property int dragTo: drag.from < 0 ? -1 : Tasks.slot(drag.from, drag.by, Metrics.buttonExtent, slots.count)
    property var icon: appId => ""
    property var progress: appId => -1
    property var badge: appId => ""
    readonly property var fill: Acrylic.fill({
        tint: [Colors.taskbarTint.r, Colors.taskbarTint.g, Colors.taskbarTint.b],
        tintOpacity: Colors.taskbarTintOpacity,
        luminosityOpacity: Colors.taskbarLuminosityOpacity,
    })
    readonly property var system: [
        { name: "start", source: Qt.resolvedUrl("../assets/start.svg") },
        { name: "search", glyph: Glyphs.glyph("search") },
        { name: "taskview", glyph: Glyphs.glyph("taskView") },
    ]

    signal activated(string name)
    signal requested(var action)
    signal reordered(var keys)
    signal jumpAsked(string key, real x)

    function ask(action) {
        if (action.action !== "none") requested(action)
    }

    function keys() {
        const out = []
        for (let i = 0; i < slots.count; i++) out.push(slots.get(i).key)
        return out
    }

    function pull(index, dx) {
        settling = ""
        drag = { from: index, by: Tasks.reach(index, dx, Metrics.buttonExtent, slots.count) }
    }

    // the others jump back while the list takes the new order, only the dropped one glides
    function drop() {
        const from = drag.from, to = dragTo, was = from * Metrics.buttonExtent + drag.by, key = slots.get(from).key
        jumping = true
        settleAnimated = false
        settleBy = drag.by
        settling = key
        drag = { from: -1, by: 0 }
        if (to !== from) reordered(Tasks.moved(keys(), from, to))
        settleBy = was - keys().indexOf(key) * Metrics.buttonExtent
        settleAnimated = true
        settleBy = 0
        jumping = false
    }

    // buttons that go are removed before the lookup loses them
    onTasksChanged: {
        const steps = Tasks.sync(keys(), tasks.map(task => task.key))
        const count = task => ({ windows: task.windows.length, minimized: task.minimized })
        const moves = tasks.map(task => byKey[task.key] ? Bounce.trigger(count(byKey[task.key]), count(task)) : "")
        for (const step of steps) if (step.op === "remove") slots.remove(step.at)
        const found = {}
        for (const task of tasks) found[task.key] = task
        byKey = found
        for (const step of steps) {
            if (step.op === "insert") slots.insert(step.at, { key: step.key })
            if (step.op === "move") slots.move(step.from, step.to, 1)
        }
        moves.forEach((name, at) => name && buttons.itemAt(at).bounce(name))
    }

    ListModel { id: slots }

    Rectangle {
        objectName: "backdrop"
        anchors.fill: parent
        color: Qt.rgba(root.fill.color[0], root.fill.color[1], root.fill.color[2], root.fill.alpha)
    }

    Rectangle {
        objectName: "topStroke"
        width: parent.width
        height: Metrics.topStroke
        color: Colors.topStroke
    }

    Row {
        objectName: "group"
        x: Layout.groupX(root.width, width, root.trayWidth)
        height: parent.height

        Repeater {
            model: root.system

            TaskbarButton {
                required property var modelData
                objectName: modelData.name
                active: modelData.name === root.openName
                glyph: modelData.glyph ?? ""
                source: modelData.source ?? ""
                onClicked: root.activated(modelData.name)
            }
        }

        Repeater {
            id: buttons
            model: slots

            TaskbarButton {
                required property string key
                required property int index
                readonly property var task: root.byKey[key]
                readonly property bool grabbed: index === root.drag.from
                readonly property bool dropping: key === root.settling
                objectName: "task:" + key
                source: root.icon(task.appId)
                windows: task.windows.length
                active: task.active
                attention: task.attention
                progress: root.progress(task.appId)
                badge: root.badge(task.appId)
                onClicked: root.ask(Tasks.click(task))
                onMiddleClicked: root.ask(Tasks.middleClick(task))
                onMenuRequested: root.jumpAsked(key, mapToItem(root, width / 2, 0).x)
                z: grabbed ? 1 : 0
                slide: dropping ? root.settleBy : grabbed ? root.drag.by : Tasks.shift(index, root.drag.from, root.dragTo) * Metrics.buttonExtent
                slideAnimated: dropping ? root.settleAnimated : !root.jumping
                onScrolled: steps => root.ask(Tasks.scroll(task, steps))
                onDragged: dx => root.pull(index, dx)
                onDropped: root.drop()
            }
        }
    }
}
