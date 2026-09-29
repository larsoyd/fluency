pragma Singleton
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../logic/desktop.mjs" as Logic
import "../logic/hypr.mjs" as Hypr
import "../logic/icons.mjs" as Icons

Singleton {
    id: root

    readonly property url wallpaper: "file://" + (Quickshell.env("FLUENCY_WALLPAPER") ?? Quickshell.env("HOME") + "/.local/share/fluency/wallpaper.png")
    readonly property string dir: Quickshell.env("FLUENCY_DESKTOP_DIR") || Quickshell.env("HOME") + "/Desktop"
    readonly property var items: store.build(store.revision, store.entries, store.targets, settings.order, Apps.entries)
    property var settings: ({ icon: Logic.sizes.medium, auto: false, grid: true, shown: true, places: {}, order: [] })
    property var cut: []
    property string renaming: ""
    property bool pasteable: false

    signal renamed(string from, string to)

    function act(action: string, names: var, x: real, y: real): string {
        let result = "ok"
        try {
            const chosen = names.map(name => items.find(item => item.name === name)).filter(item => item)
            if (action.startsWith("size:")) store.resize(Number(action.slice(5)))
            else if (action === "grow" || action === "shrink") store.resize(Logic.resize(settings.icon, action === "grow" ? 1 : -1))
            else if (action === "auto" || action === "grid" || action === "shown") store.update({ [action]: !settings[action] })
            else if (action.startsWith("sort:")) store.sort(action.slice(5))
            else if (action === "refresh") store.refresh()
            else if (action === "pin" || action === "unpin") result = Apps.pin(action, chosen[0]?.app ?? "")
            else if (action === "rename") {
                if (!chosen.length) throw new Error("refused: nothing chosen for rename")
                renaming = chosen[0].name
            } else if (action === "paste") store.paste(x, y)
            else {
                const steps = Logic.plan(action, chosen, store.context())
                if (action === "cut") cut = chosen.map(item => item.name)
                if (action === "copy") cut = []
                for (const step of steps) store.perform(action, step, x, y)
            }
        } catch (e) {
            result = e.message
        }
        console.log(`[desktop] action=${action} names=${names.length} result="${result}"`)
        return result
    }

    function rename(name: string, text: string): string {
        let result = "ok"
        try {
            const item = items.find(item => item.name === name)
            if (!item) throw new Error(`refused: no item ${name}`)
            if (item.desktop) {
                if (!text.trim()) throw new Error("refused: a name cannot be empty")
                const view = writer.createObject(root, { path: item.path })
                view.setText(Logic.renamed(store.raws[name] ?? "[Desktop Entry]\n", text.trim()))
            } else {
                const ending = !item.dir && item.label !== name ? name.slice(item.label.length) : ""
                const wanted = text.trim() + ending
                const said = Logic.renameCheck(name, wanted, items.map(item => item.name))
                if (said.startsWith("refused")) throw new Error(said)
                if (said !== "same") {
                    store.spawn("rename", ["mv", "-n", "-T", "--", item.path, `${root.dir}/${wanted}`], "", code => {
                        if (code === 0) root.renamed(name, wanted)
                    })
                    const moved = Object.assign({}, settings.places)
                    if (moved[name]) { moved[wanted] = moved[name]; delete moved[name] }
                    store.update({ places: moved, order: settings.order.map(entry => entry === name ? wanted : entry) })
                }
            }
        } catch (e) {
            result = e.message
        }
        renaming = ""
        console.log(`[desktop] action=rename name="${name}" result="${result}"`)
        return result
    }

    function probe(): void {
        const job = reader.createObject(root, { command: ["timeout", "2", "wl-paste", "--list-types"] })
        job.done = text => root.pasteable = text.split("\n").includes("text/uri-list")
        job.failed = () => root.pasteable = false
        job.running = true
    }

    function place(places: var, order: var): void {
        store.update({ places, order })
    }

    QtObject {
        id: store

        property int revision: 0
        property var entries: ({})
        property var raws: ({})
        property var targets: ({})
        property string sortKey: ""
        property bool sortDown: false
        readonly property var locales: Logic.locales(Quickshell.env("LC_MESSAGES") || Quickshell.env("LANG") || "")

        function build() {
            const found = []
            for (let i = 0; i < files.count; i++) {
                const name = files.get(i, "fileName"), path = files.get(i, "filePath"), folder = files.get(i, "fileIsDir")
                const desktop = !folder && name.toLowerCase().endsWith(".desktop")
                const entry = desktop ? entries[name] ?? null : null
                const look = Logic.look({ name, dir: folder, entry })
                const id = desktop ? name.slice(0, -".desktop".length) : ""
                const icon = Icons.pick(look.icons, icon => Quickshell.hasThemeIcon(icon))
                found.push({
                    name, path, dir: folder, desktop,
                    type: entry?.type ?? "", url: entry?.url ?? "", target: targets[name] ?? "",
                    size: files.get(i, "fileSize"), modified: files.get(i, "fileModified").getTime(),
                    kind: folder ? "" : name.includes(".") ? name.slice(name.lastIndexOf(".") + 1).toLowerCase() : "",
                    label: look.label, link: look.link,
                    source: look.picture ? "file://" + path : Icons.source(icon || "application-x-executable"),
                    app: Apps.entries.some(app => app.id === id) ? id : "",
                })
            }
            const order = Logic.settle(settings.order, found.map(item => item.name).sort(Logic.natural))
            return order.map(name => found.find(item => item.name === name))
        }

        function context() {
            return { dir: root.dir, terminal: Quickshell.env("TERMINAL"), taken: items.map(item => item.name) }
        }

        function update(change) {
            root.settings = Object.assign({}, root.settings, change)
            saved.setText(JSON.stringify(root.settings))
        }

        function resize(icon) {
            const places = Logic.rescale(root.settings.places, Logic.metrics(root.settings.icon), Logic.metrics(icon))
            update({ icon, places })
        }

        function sort(key) {
            sortDown = sortKey === key ? !sortDown : false
            sortKey = key
            const list = items.map(item => Object.assign({}, item, { type: item.dir ? "" : item.desktop ? "desktop" : item.kind }))
            update({ order: Logic.sorted(list, key, sortDown), places: {} })
        }

        function refresh() {
            revision++
            links.running = true
            for (const view of readers.instances) view.reload()
        }

        function perform(action, step, x, y) {
            if (step.launch) {
                for (const line of Hypr.launch(step.argv, step.dir)) Hyprland.dispatch(line)
                return
            }
            spawn(action, step.argv, step.dir, code => {
                if (code !== 0 || !step.rename) return
                if (x >= 0 && y >= 0) update({ places: Object.assign({}, root.settings.places, { [step.made]: { x, y } }) })
                root.renaming = step.made
            })
        }

        function spawn(action, argv, where, after) {
            const job = runner.createObject(root, { action, after, command: ["timeout", "120", ...argv], workingDirectory: where || root.dir })
            job.running = true
        }

        function paste(x, y) {
            const job = reader.createObject(root, { command: ["timeout", "5", "wl-paste", "--no-newline", "--type", "text/uri-list"] })
            job.done = text => {
                const uris = text.split(/\r?\n/).filter(line => line)
                const moving = cut.length > 0 && uris.every(uri => cut.some(name => uri.endsWith("/" + encodeURIComponent(name))))
                for (const step of Logic.paste(uris, moving, context())) perform("paste", step, -1, -1)
                if (moving) root.cut = []
            }
            job.running = true
        }

    }

    FolderListModel {
        id: files
        folder: "file://" + root.dir
        showDirs: true
        showDotAndDotDot: false
        showHidden: false
        sortField: FolderListModel.Unsorted
        onCountChanged: store.refresh()
        onStatusChanged: if (status === FolderListModel.Ready) store.refresh()
    }

    Connections {
        target: files
        function onDataChanged() { store.revision++ }
        function onRowsInserted() { store.revision++ }
        function onRowsRemoved() { store.revision++ }
        function onModelReset() { store.revision++ }
    }

    // links point somewhere else, the menu can show where
    Process {
        id: links
        command: ["timeout", "5", "find", root.dir, "-maxdepth", "1", "-type", "l", "-exec", "sh", "-c", 'printf "%s\\t%s\\n" "${1##*/}" "$(readlink -f "$1")"', "sh", "{}", ";"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = {}
                for (const line of text.split("\n")) {
                    const at = line.indexOf("\t")
                    if (at > 0) found[line.slice(0, at)] = line.slice(at + 1)
                }
                store.targets = found
            }
        }
    }

    Variants {
        id: readers
        model: root.items.filter(item => item.desktop).map(item => item.path)

        FileView {
            required property var modelData
            path: modelData
            watchChanges: true
            printErrors: false
            onFileChanged: reload()
            onLoaded: {
                const name = modelData.slice(modelData.lastIndexOf("/") + 1)
                store.raws = Object.assign({}, store.raws, { [name]: text() })
                store.entries = Object.assign({}, store.entries, { [name]: Logic.entry(text(), store.locales) })
            }
        }
    }

    Component {
        id: runner
        Process {
            property string action
            property var after: null
            stderr: StdioCollector { id: errors }
            onExited: code => {
                console.log(`[desktop] action=${action} status=${code}${code ? ` stderr="${errors.text.trim()}"` : ""}`)
                if (after) after(code)
                destroy()
            }
        }
    }

    Component {
        id: reader
        Process {
            property var done: null
            property var failed: null
            stdout: StdioCollector { id: out }
            onExited: code => {
                if (code === 0 && done) done(out.text)
                else if (failed) failed()
                destroy()
            }
        }
    }

    Component {
        id: writer
        FileView {
            atomicWrites: true
            onSaved: destroy()
            onSaveFailed: error => {
                console.warn(`[desktop] action=rename path=${path} result="${error}"`)
                destroy()
            }
        }
    }

    FileView {
        id: saved
        path: Quickshell.env("FLUENCY_DESKTOP_STATE") || Quickshell.statePath("desktop.json")
        blockLoading: true
        printErrors: false
        Component.onCompleted: {
            try {
                const restored = Logic.restore(text())
                if (restored) root.settings = restored
            } catch (e) {
                console.warn(`[desktop] action=load path=${path} result="${e.message}"`)
            }
        }
        onSaveFailed: error => console.warn(`[desktop] action=save path=${path} result="${error}"`)
    }
}
