import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.tokens
import qs.components
import qs.services
import "../logic/curve.mjs" as Curve
import "../logic/jump.mjs" as Jump
import "../logic/tray.mjs" as Tray

PanelWindow {
    id: root

    property bool open: false
    property string key: ""
    property var task: null
    property real anchorX: 0
    property real shift: 1
    property alias sliding: sliding
    readonly property var entry: task ? Windows.entry(task.appId) : null
    readonly property int reach: panel.height + Metrics.flyoutOffset

    function show(key: string, x: real): void {
        root.key = key
        anchorX = x
        open = true
    }

    function choose(index: int): string {
        if (!open) return "refused: the jump list is closed"
        const row = panel.rows[index]
        if (!row || row.kind !== "item" || !row.enabled) return `refused: no choosable row ${index}`
        const plan = Jump.actions(row, task)
        open = false
        const said = plan.map(action => Windows.run(action))
        return said.find(result => result !== "ok") ?? "ok"
    }

    // a task that goes away takes its list with it
    onTaskChanged: if (!task) open = false

    visible: open || shift < 1
    anchors { left: true; bottom: true }
    margins.left: Tray.flyoutX(anchorX, panel.width, screen.width, Metrics.flyoutOffset)
    implicitWidth: panel.width
    implicitHeight: reach
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "fluency-jump"

    onOpenChanged: shift = open ? 0 : 1

    Behavior on shift {
        NumberAnimation {
            id: sliding
            duration: root.open ? Motion.flyoutOpen : Motion.flyoutClose
            easing.bezierCurve: Curve.easing(Motion.curveDecelerate)
        }
    }

    Item {
        objectName: "jump"
        anchors.fill: parent
        clip: true

        JumpPanel {
            id: panel
            objectName: "panel"
            y: root.shift * root.reach
            opacity: root.open ? 1 : 0
            onChosen: index => root.choose(index)

            Behavior on opacity {
                NumberAnimation { duration: Motion.controlFaster }
            }
        }

        // the rows hold still while the list slides away
        Binding {
            target: panel
            property: "rows"
            value: root.task ? Jump.rows(root.task, root.entry) : []
            when: root.open && root.task !== null
            restoreMode: Binding.RestoreNone
        }

        Binding {
            target: panel
            property: "icon"
            value: Windows.icon(root.task?.appId ?? "")
            when: root.open && root.task !== null
            restoreMode: Binding.RestoreNone
        }
    }
}
