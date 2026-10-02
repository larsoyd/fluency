pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../logic/anchors.mjs" as Anchors

// tells the minimize plugin where each window's taskbar button is
Singleton {
    id: root

    property var screens: ({})
    property string sent: ""

    function put(screen: string, points: var): void {
        const next = Object.assign({}, screens)
        next[screen] = points
        screens = next
        settle.restart()
    }

    function send(): void {
        if (teller.running) return settle.restart()
        const all = Object.assign({}, ...Object.values(screens))
        let code = ""
        try {
            code = Anchors.lua(all)
        } catch (e) {
            return console.warn(`[flights] action=send result="${e.message}"`)
        }
        if (code === sent) return
        sent = code
        teller.windows = Object.keys(all).length
        teller.command = ["timeout", "5", "hyprctl", "eval", code]
        teller.running = true
    }

    Timer {
        id: settle
        interval: 50
        onTriggered: root.send()
    }

    Process {
        id: teller
        property int windows: 0
        stdout: StdioCollector { id: said }
        onExited: code => {
            const result = code === 0 ? said.text.trim() : `exit ${code}`
            if (result !== "ok") root.sent = ""
            console.log(`[flights] action=send windows=${windows} result="${result}"`)
        }
    }

    // a plugin that was just loaded starts with no anchors and hyprland reloads its config after loading
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "configreloaded") return
            root.sent = ""
            settle.restart()
        }
    }
}
