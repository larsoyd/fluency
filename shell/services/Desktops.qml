pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../logic/hypr.mjs" as Hypr
import "../logic/taskview.mjs" as TaskView

// hyprland drops empty workspaces, a desktop made here keeps a persistent rule over reloads
Singleton {
    id: root

    property var kept: []
    property var queue: []

    function make(monitor: string): int {
        const id = TaskView.fresh(Hyprland.workspaces.values.map(space => ({ id: space.id })).concat(kept))
        let result = "ok"
        try {
            evaluate(Hypr.rule(id, monitor, true))
            kept = kept.concat([{ id, monitor }])
            saved.setText(JSON.stringify(kept))
        } catch (e) {
            result = e.message
        }
        console.log(`[desktops] action=make id=${id} monitor=${monitor} result="${result}"`)
        return result === "ok" ? id : 0
    }

    function close(id: int, monitor: string, desktops: var): string {
        let result = "ok"
        try {
            const target = TaskView.neighbour(desktops, id)
            if (!target) throw new Error(`refused: desktop ${id} is the last one`)
            for (const line of Hypr.evacuate(Windows.windows, id, target)) Hyprland.dispatch(line)
            const shown = Hyprland.monitors.values.find(m => m.name === monitor)?.activeWorkspace?.id
            if (shown === id) for (const line of Hypr.workspace(target)) Hyprland.dispatch(line)
            evaluate(Hypr.rule(id, monitor, false))
            kept = kept.filter(desk => desk.id !== id)
            saved.setText(JSON.stringify(kept))
        } catch (e) {
            result = e.message
        }
        console.log(`[desktops] action=close id=${id} monitor=${monitor} result="${result}"`)
        return result
    }

    function apply(): void {
        const rules = []
        for (const desk of kept) {
            try { rules.push(Hypr.rule(desk.id, desk.monitor, true)) } catch (e) { console.warn(`[desktops] action=apply id=${desk.id} result="${e.message}"`) }
        }
        console.log(`[desktops] action=apply count=${rules.length}`)
        if (rules.length) evaluate(rules.join("\n"))
    }

    function evaluate(code: string): void {
        queue.push(code)
        if (!evaluator.running) next()
    }

    function next(): void {
        if (!queue.length) return
        evaluator.command = ["timeout", "5", "hyprctl", "eval", queue.shift()]
        evaluator.running = true
    }

    Process {
        id: evaluator
        stdout: StdioCollector { id: said }
        onExited: code => {
            if (code !== 0 || said.text.trim() !== "ok") console.warn(`[desktops] action=eval code=${code} said="${said.text.trim()}"`)
            root.next()
        }
    }

    FileView {
        id: saved
        path: Quickshell.statePath("desktops.json")
        blockLoading: true
        printErrors: false
        Component.onCompleted: {
            try {
                const value = JSON.parse(text() || "[]")
                root.kept = Array.isArray(value) ? value.filter(desk => Number.isInteger(desk?.id) && typeof desk?.monitor === "string") : []
            } catch (e) {
                console.warn(`[desktops] action=load path=${path} result="${e.message}"`)
            }
        }
        onSaveFailed: error => console.warn(`[desktops] action=save path=${path} result="${error}"`)
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded") root.apply()
        }
    }
}
