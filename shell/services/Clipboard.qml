pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../logic/clipboard.mjs" as Clip

Singleton {
    id: root

    readonly property string dir: Quickshell.env("FLUENCY_CLIP_DIR") ?? `${Quickshell.env("XDG_RUNTIME_DIR")}/fluency-clip/${Quickshell.env("WAYLAND_DISPLAY")}`
    readonly property bool ready: link.item?.connected ?? false
    property var entries: []

    signal answered(string request, string result)

    function send(verb: string, id: int): string {
        if (!ready) return `refused: no clipboard daemon at ${dir}`
        link.item.write(Clip.request(verb, id < 0 ? undefined : id))
        link.item.flush()
        return "ok"
    }

    function select(id: int): string { return send("select", id) }
    function asText(id: int): string { return send("text", id) }
    function pin(id: int, on: bool): string { return send(on ? "pin" : "unpin", id) }
    function remove(id: int): string { return send("delete", id) }
    function clear(): string { return send("clear", -1) }

    function take(message) {
        if (message.entries) return entries = message.entries
        if (message.refused || !message.result.startsWith("ok")) console.log(`[clipboard] request="${message.request ?? ""}" result="${message.refused ?? message.result}"`)
        if (message.request) answered(message.request, message.result)
    }

    // a socket that failed to connect never tries again, so each try gets a new one
    Loader {
        id: link
        sourceComponent: Socket {
            path: `${root.dir}/control`
            connected: true
            parser: SplitParser {
                onRead: line => root.take(Clip.read(line))
            }
            onConnectedChanged: {
                console.log(`[clipboard] connected=${connected} path=${path}`)
                if (!connected) root.entries = []
            }
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
}
