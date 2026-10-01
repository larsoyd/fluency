pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../logic/session.mjs" as Logic

Singleton {
    id: root

    readonly property string user: Quickshell.env("USER") ?? ""
    readonly property string dir: Quickshell.env("FLUENCY_SESSION_DIR") ?? `${Quickshell.env("XDG_RUNTIME_DIR")}/fluency-session/${Quickshell.env("WAYLAND_DISPLAY")}`
    readonly property bool ready: link.item?.connected ?? false
    property bool locked: false
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

    onLockedChanged: console.log(`[session] locked=${locked}`)

    // a socket that failed to connect never tries again, so each try gets a new one
    Loader {
        id: link
        sourceComponent: Socket {
            path: `${root.dir}/control`
            connected: true
            parser: SplitParser {
                onRead: line => {
                    try {
                        root.locked = Logic.lockState(line)
                    } catch (e) {
                        console.log(`[session] line=${JSON.stringify(line)} result="${e.message}"`)
                    }
                }
            }
            onConnectedChanged: console.log(`[session] connected=${connected} path=${path}`)
        }
    }

    // the daemon starts beside the shell at login and may come up later
    Timer {
        interval: 1000
        repeat: true
        running: !root.ready
        onTriggered: {
            link.active = false
            link.active = true
        }
    }

    Process {
        command: ["timeout", "5", "getent", "passwd", root.user]
        running: root.user !== ""
        stdout: StdioCollector { onStreamFinished: root.name = Logic.displayName(text.trim(), root.user) }
    }
}
