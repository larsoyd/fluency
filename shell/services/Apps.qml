pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../logic/apps.mjs" as Logic
import "../logic/hypr.mjs" as Hypr
import "../logic/icons.mjs" as Icons
import "../logic/launches.mjs" as Launches
import "../logic/places.mjs" as Places

Singleton {
    id: root
    property var entries: []
    property var pins: Logic.defaults(Quickshell.env("FLUENCY_PINS"))
    property var launches: ({})
    property var links: []

    function launch(id: string): string {
        let result = "ok"
        try {
            const entry = DesktopEntries.byId(id)
            if (!entry) throw new Error(`refused: no desktop entry ${id}`)
            const line = Logic.command(entry, Quickshell.env("TERMINAL"))
            for (const step of Hypr.launch(line, entry.workingDirectory)) Hyprland.dispatch(step)
            Windows.expect(id)
            launches = Launches.record(launches, id, Date.now())
            log.setText(JSON.stringify(launches))
        } catch (e) {
            result = e.message
        }
        console.log(`[apps] action=launch id=${id} result="${result}"`)
        return result
    }

    function open(path: string): string {
        let result = "ok"
        try {
            if (!links.some(link => link.path === path)) throw new Error(`refused: not a quick link ${path}`)
            for (const step of Hypr.launch(["xdg-open", path])) Hyprland.dispatch(step)
        } catch (e) {
            result = e.message
        }
        console.log(`[apps] action=open path=${path} result="${result}"`)
        return result
    }

    function pin(action: string, id: string): string {
        let result = "ok"
        try {
            pins = Logic.edit(pins, action, id)
            saved.setText(JSON.stringify(pins))
        } catch (e) {
            result = e.message
        }
        console.log(`[apps] action=${action} id=${id} result="${result}"`)
        return result
    }

    FileView {
        id: saved
        path: Quickshell.env("FLUENCY_START_PINS") || Quickshell.statePath("start-pins.json")
        blockLoading: true
        printErrors: false
        Component.onCompleted: {
            try {
                root.pins = Logic.restore(text()) ?? root.pins
            } catch (e) {
                console.warn(`[apps] action=load path=${path} result="${e.message}"`)
            }
        }
        onSaveFailed: error => console.warn(`[apps] action=save path=${path} result="${error}"`)
    }

    FileView {
        id: log
        path: Quickshell.statePath("launches.json")
        blockLoading: true
        printErrors: false
        Component.onCompleted: {
            try {
                root.launches = Launches.restore(text()) ?? {}
            } catch (e) {
                console.warn(`[apps] action=load path=${path} result="${e.message}"`)
            }
        }
        onSaveFailed: error => console.warn(`[apps] action=save path=${path} result="${error}"`)
    }

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/user-dirs.dirs"
        blockLoading: true
        printErrors: false
        Component.onCompleted: root.links = Places.links(text(), Quickshell.env("HOME"))
    }

    // a rescan changes the list once per entry, building it once per rescan keeps the shell from freezing
    QtObject {
        id: scan

        function build() {
            root.entries = DesktopEntries.applications.values.map(entry => ({
                id: entry.id,
                name: entry.name,
                noDisplay: entry.noDisplay,
                icon: Icons.source(Icons.pick([entry.icon, entry.id, "application-x-executable"], name => Quickshell.hasThemeIcon(name))),
            }))
        }

        Component.onCompleted: build()
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { Qt.callLater(scan.build) }
    }
}
