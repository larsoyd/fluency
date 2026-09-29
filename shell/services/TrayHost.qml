pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import "../logic/tray.mjs" as Logic

Singleton {
    property string monitor: "DP-1"
    readonly property string screen: Logic.screen(Quickshell.screens.map(screen => screen.name), monitor)
    readonly property var items: Logic.keyed(SystemTray.items.values.map(item => ({
        id: item.id,
        title: item.tooltipTitle || item.title,
        icon: item.icon,
        status: ["passive", "active", "attention"][item.status],
        menu: item.hasMenu,
        onlyMenu: item.onlyMenu,
    })))

    signal menuAsked(var handle, var window, real x)

    function press(key: string, input: string, window: var, x: int, y: int): string {
        let result = "ok"
        try {
            const at = items.findIndex(item => item.key === key), item = SystemTray.items.values[at]
            const action = Logic.press(items[at], input)
            const entry = bus.entries[items[at]?.id]
            if (action === "activate" && entry) bus.activate(item, Logic.activation(entry, x, y), window, x, y)
            if (action === "activate" && !entry) item.activate()
            if (action === "secondary") item.secondaryActivate()
            if (action === "menu") menuAsked(item.menu, window, x)
        } catch (e) {
            result = e.message
        }
        console.log(`[tray] action=${input} target=${key} result="${result}"`)
        return result
    }

    // quickshell hides a failed activate, so the call goes out here and a missing one opens the menu
    QtObject {
        id: bus

        property var entries: ({})
        property var pending: null
        readonly property int count: SystemTray.items.values.length

        function activate(item, command, window, x, y) {
            pending = { item, window, x, y }
            activator.exec(command)
        }

        onCountChanged: lookup.running = true
    }

    Process {
        id: lookup

        command: ["sh", "-c", "list=$(timeout 2 busctl --user get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems) || exit 1\n"
            + "for e in $(printf '%s' \"$list\" | grep -o '\"[^\"]*\"' | tr -d '\"'); do\n"
            + "  s=${e%%/*}; p=/${e#*/}; [ \"$p\" = \"/$e\" ] && p=/StatusNotifierItem\n"
            + "  id=$(timeout 2 busctl --user get-property \"$s\" \"$p\" org.kde.StatusNotifierItem Id) && printf '%s\\t%s\\t%s\\n' \"$id\" \"$s\" \"$p\"\n"
            + "done"]
        stdout: StdioCollector { onStreamFinished: bus.entries = Logic.entries(text) }
    }

    Process {
        id: activator

        stderr: StdioCollector { id: complaint }
        onExited: code => {
            const next = Logic.failed(complaint.text), was = bus.pending
            console.log(`[tray] activate=${code === 0 ? "ok" : "fail"} code=${code} then="${next}" err="${complaint.text.trim()}"`)
            if (next === "menu" && was?.item.hasMenu) menuAsked(was.item.menu, was.window, was.x)
        }
    }

    function scroll(key: string, delta: int): string {
        const item = SystemTray.items.values[items.findIndex(item => item.key === key)]
        if (item) item.scroll(delta, false)
        return item ? "ok" : "refused: no tray item"
    }
}
