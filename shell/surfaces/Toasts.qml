import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.tokens
import qs.components
import qs.services
import "../logic/curve.mjs" as Curve
import "../logic/tasks.mjs" as Tasks
import "../logic/toast.mjs" as Logic

// toasts slide in and out here, hyprland would fade a snapshot whose blur shows the wallpaper
PanelWindow {
    id: root

    property var byKey: ({})

    function keys() {
        const out = []
        for (let i = 0; i < slots.count; i++) out.push(slots.get(i).key)
        return out
    }

    function sync() {
        const plan = Logic.order(keys(), Notifications.toasts.map(Logic.key))
        const found = {}
        for (const k of plan.keys) found[k] = byKey[k]
        for (const n of Notifications.toasts) found[Logic.key(n)] = { n, leaving: false }
        for (const k of plan.leaving) found[k] = { n: byKey[k].n, leaving: true }
        byKey = found
        for (const step of Tasks.sync(keys(), plan.keys)) {
            if (step.op === "remove") slots.remove(step.at)
            if (step.op === "insert") slots.insert(step.at, { key: step.key })
            if (step.op === "move") slots.move(step.from, step.to, 1)
        }
    }

    function gone(key) {
        const at = keys().indexOf(key)
        if (at >= 0) slots.remove(at)
    }

    visible: slots.count > 0
    anchors { right: true; bottom: true }
    margins.bottom: Metrics.toastGap
    implicitWidth: Metrics.toastWidth + Metrics.toastGap
    implicitHeight: Math.max(1, column.height)
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "fluency-toast"
    WlrLayershell.layer: WlrLayer.Overlay

    Connections {
        target: Notifications
        function onToastsChanged() { root.sync() }
    }

    ListModel { id: slots }

    Column {
        id: column
        objectName: "toasts"
        width: parent.width
        spacing: Metrics.toastGap

        Repeater {
            model: slots

            Item {
                id: slot

                required property string key
                required property int index
                readonly property var entry: root.byKey[key]
                readonly property var words: Logic.text(entry.n)
                property real slide: 1
                property alias sliding: sliding
                objectName: "toast:" + index
                width: Metrics.toastWidth
                height: toast.height

                Component.onCompleted: slide = 0
                // set before the slide starts, a binding on leaving could still hold the way in
                onEntryChanged: if (entry?.leaving) {
                    sliding.duration = Motion.calmed(Motion.toastOut)
                    slide = 1
                }

                Behavior on slide {
                    NumberAnimation {
                        id: sliding
                        duration: Motion.calmed(Motion.toastIn)
                        easing.bezierCurve: Curve.easing(Motion.curveDecelerate)
                        onRunningChanged: if (!running && slot.entry?.leaving) root.gone(slot.key)
                    }
                }

                Toast {
                    id: toast
                    objectName: "card"
                    x: slot.slide * (Metrics.toastWidth + Metrics.toastGap)
                    opacity: slot.entry?.leaving ? 1 - slot.slide : 1
                    app: slot.words.app
                    icon: Logic.source(slot.entry.n, name => Quickshell.iconPath(name, "application-x-executable"))
                    title: slot.words.title
                    body: slot.words.body
                    enabled: !slot.entry?.leaving
                    onActivated: Notifications.activate(slot.entry.n)
                    onDismissed: Notifications.dismiss(slot.entry.n)
                }

                Timer {
                    running: !slot.entry?.leaving
                    interval: Logic.shown(slot.entry.n.expireTimeout, Motion.toastShown)
                    onTriggered: Notifications.expire(slot.entry.n)
                }
            }
        }
    }
}
