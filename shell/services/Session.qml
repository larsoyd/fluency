pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../logic/session.mjs" as Logic

Singleton {
    id: root

    readonly property string user: Quickshell.env("USER") ?? ""
    property string name: user
    readonly property url avatar: "file:///var/lib/AccountsService/icons/" + user
    readonly property var powerRows: Logic.powerRows.map(row => Object.assign({ kind: "item", enabled: true }, row))
    readonly property var userRows: Logic.userRows.map(row => Object.assign({ kind: "item", enabled: true }, row))

    function run(action: string): string {
        let result = "ok"
        try {
            for (const line of Logic.plan(action, Quickshell.env("FLUENCY_NESTED") === "1")) Hyprland.dispatch(line)
        } catch (e) {
            result = e.message
        }
        console.log(`[session] action=${action} result="${result}"`)
        return result
    }

    Process {
        command: ["timeout", "5", "getent", "passwd", root.user]
        running: root.user !== ""
        stdout: StdioCollector { onStreamFinished: root.name = Logic.displayName(text.trim(), root.user) }
    }
}
