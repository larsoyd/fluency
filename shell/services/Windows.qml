pragma Singleton
import QtQuick
import "../logic/tasks.mjs" as Tasks
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../logic/hypr.mjs" as Hypr
import "../logic/icons.mjs" as Icons
import "../logic/apps.mjs" as Apps

Singleton {
    id: root
    property var pinned: Apps.defaults(Quickshell.env("FLUENCY_PINS"))
    property string mode: "own"
    property var homes: ({})
    property var order: []
    property var orders: ({})
    property var cleared: []
    property var launched: ({})
    property var recent: []
    readonly property var windows: ToplevelManager.toplevels.values.map(toplevel => {
        const hypr = toplevel.HyprlandToplevel, ipc = hypr.handle?.lastIpcObject ?? {}
        return {
            address: "0x" + hypr.address,
            appId: toplevel.appId,
            title: toplevel.title,
            active: toplevel.activated,
            urgent: hypr.handle?.urgent ?? false,
            monitor: hypr.handle?.monitor?.name ?? "",
            workspace: hypr.handle?.workspace?.name ?? "",
            at: ipc.at ?? [0, 0],
            size: ipc.size ?? [0, 0],
            focus: Hypr.rank(root.recent, "0x" + hypr.address, ipc.focusHistoryID ?? -1),
        }
    })

    Timer {
        readonly property string unplaced: Hypr.unplaced(root.windows).join(",")
        property int tries: 0
        onUnplacedChanged: tries = 0
        interval: 500
        repeat: true
        running: unplaced !== "" && tries < 20
        onTriggered: {
            tries++
            console.log(`[windows] action=refresh unplaced=${unplaced} try=${tries}`)
            Hyprland.refreshWorkspaces()
            Hyprland.refreshToplevels()
        }
    }

    function icon(appId: string): url {
        // reading the count makes every icon follow a finished rescan, once
        const entry = catalog.rescans >= 0 ? catalog.find(appId) : null
        const names = [entry?.icon ?? "", appId, "application-x-executable"]
        return Icons.source(Icons.pick(names, name => Quickshell.hasThemeIcon(name)))
    }

    function entry(appId: string): var {
        const found = catalog.rescans >= 0 ? catalog.find(appId) : null
        return found ? { name: found.name, actions: found.actions.map(action => ({ name: action.name })) } : null
    }

    function arrange(keys: var, monitor: string): void {
        orders = Tasks.remember(orders, monitor, keys)
        order = keys
        saved.setText(JSON.stringify(orders))
    }
    FileView {
        id: saved
        path: Quickshell.env("FLUENCY_TASKBAR_ORDER") || Quickshell.statePath("taskbar-order.json")
        blockLoading: true
        printErrors: false
        Component.onCompleted: {
            try {
                const value = JSON.parse(text())
                if (value && typeof value === "object" && !Array.isArray(value)) root.orders = value
            } catch (e) {}
        }
        onSaveFailed: error => console.warn("Could not save taskbar order: " + error)
    }

    function pin(action: string, id: string): string {
        let result = "ok"
        try {
            if (action === "front") throw new Error("refused: the taskbar has no front")
            pinned = Apps.edit(pinned, action, id)
            pins.setText(JSON.stringify(pinned))
        } catch (e) {
            result = e.message
        }
        console.log(`[windows] action=${action}-taskbar id=${id} result="${result}"`)
        return result
    }
    FileView {
        id: pins
        path: Quickshell.env("FLUENCY_TASKBAR_PINS") || Quickshell.statePath("taskbar-pins.json")
        blockLoading: true
        printErrors: false
        Component.onCompleted: {
            try {
                root.pinned = Apps.restore(text()) ?? root.pinned
            } catch (e) {
                console.warn(`[windows] action=load path=${path} result="${e.message}"`)
            }
        }
        onSaveFailed: error => console.warn(`[windows] action=save path=${path} result="${error}"`)
    }

    function expect(appId: string): void {
        launched[appId.toLowerCase()] = Date.now()
    }

    function answer(address: string): void {
        const win = windows.find(w => w.address === address)
        if (!win || !Hypr.answered(launched, win.appId, Date.now())) return
        delete launched[win.appId.toLowerCase()]
        run({ action: "focus", address })
    }

    function toplevel(address: string): var {
        return ToplevelManager.toplevels.values.find(toplevel => "0x" + toplevel.HyprlandToplevel.address === address) ?? null
    }

    function progress(appId: string): real { return -1 }
    function badge(appId: string): string { return "" }

    function run(action: var): string {
        let result = "ok"
        try {
            const win = windows.find(w => w.address === action.address)
            const entry = catalog.find(action.appId ?? "")
            if (action.action === "launch") {
                if (!entry) throw new Error(`refused: no desktop entry for ${action.appId}`)
                const target = action.task === undefined ? entry : entry.actions[action.task]
                if (!target) throw new Error(`refused: ${action.appId} has no task ${action.task}`)
                for (const line of Hypr.launch(target.command, entry.workingDirectory)) Hyprland.dispatch(line)
                expect(action.appId)
            } else if (action.action === "pin" || action.action === "unpin") {
                const said = pin(action.action, action.appId ?? "")
                if (said !== "ok") throw new Error(said)
            } else if (action.action === "desktop") {
                const plan = Hypr.desktop(windows, Hyprland.monitors.values.map(monitor => monitor.activeWorkspace?.name ?? ""), cleared)
                for (const entry of plan.cleared) homes[entry.address] = entry.workspace
                cleared = plan.cleared
                for (const line of plan.lines) Hyprland.dispatch(line)
            } else if (action.action === "workspace") {
                for (const line of Hypr.workspace(action.workspace)) Hyprland.dispatch(line)
            } else if (!["focus", "minimize", "close"].includes(action.action)) {
                throw new Error(`refused: unknown action ${action.action}`)
            } else if (!win) {
                throw new Error(`refused: no window ${action.address}`)
            } else {
                const shown = {}
                for (const monitor of Hyprland.monitors.values) shown[monitor.name] = monitor.activeWorkspace?.name
                const home = Hypr.hidden(win) ? Hypr.home(win, homes, shown) : win.workspace
                if (action.action === "minimize" && !Hypr.hidden(win)) homes[win.address] = win.workspace
                for (const line of Hypr[action.action](win, home)) Hyprland.dispatch(line)
            }
        } catch (e) {
            result = e.message
        }
        console.log(`[windows] action=${action.action} target=${action.address ?? action.appId ?? "all"} result="${result}"`)
        return result
    }

    QtObject {
        id: catalog
        property int rescans: 0
        property var games: ({})
        property var aliases: ({})

        function index(): void {
            games = Apps.games(DesktopEntries.applications.values.map(entry => ({ id: entry.id, command: [...entry.command] })))
        }

        function find(appId: string): var {
            const id = Apps.game(appId, games) || aliases[appId.toLowerCase()]
            return DesktopEntries.heuristicLookup(appId) ?? (id ? DesktopEntries.byId(id) : null)
        }

        function heard(appId: string, environ: string): void {
            const entry = games[Apps.steamId(environ)]
            console.log(`[windows] action=steam app=${appId} entry=${entry ?? "none"}`)
            if (!entry) return
            aliases = Object.assign({}, aliases, { [appId.toLowerCase()]: entry })
            rescans++
        }

        Component.onCompleted: index()
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "urgent") root.answer("0x" + event.data)
            else if (event.name === "activewindowv2") root.recent = Hypr.focused(root.recent, event.data)
            else if (event.name === "closewindow") root.recent = root.recent.filter(address => address !== "0x" + event.data)
            else if (event.name === "openwindow") {
                delete root.launched[Hypr.opened(event.data).toLowerCase()]
                Hyprland.refreshToplevels()
            }
        }
    }

    // an app without an entry of its own may be a steam game, its process says which
    Scope {
        id: owners
        property var tried: ({})
        readonly property var seen: Hyprland.toplevels.values.map(toplevel => ({
            appId: toplevel.lastIpcObject?.class ?? "",
            pid: toplevel.lastIpcObject?.pid ?? 0,
        }))

        onSeenChanged: {
            for (const win of seen) {
                const key = win.appId.toLowerCase()
                if (!win.pid || !key || tried[key] || catalog.find(win.appId)) continue
                tried[key] = true
                probe.createObject(owners, { appId: win.appId, path: `/proc/${win.pid}/environ` })
            }
        }

        Component {
            id: probe
            FileView {
                property string appId
                printErrors: false
                onLoaded: {
                    catalog.heard(appId, text())
                    destroy()
                }
                onLoadFailed: destroy()
            }
        }
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            catalog.index()
            catalog.rescans++
        }
    }
}
