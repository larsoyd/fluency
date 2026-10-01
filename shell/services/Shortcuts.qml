pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../logic/shortcuts.mjs" as Logic

Singleton {
    id: root

    property var held: ({})

    signal fired(string name)

    function take(name: string, pressed: bool) {
        const step = Logic.edge(held, name, pressed)
        held = step.held
        console.log(`[shortcuts] name=${name} edge=${pressed ? "pressed" : "released"} fire=${step.fire}`)
        if (step.fire) fired(name)
    }

    GlobalShortcut {
        appid: "fluency"
        name: "start"
        description: "Open Start"
        onPressed: root.take(name, true)
        onReleased: root.take(name, false)
    }

    GlobalShortcut {
        appid: "fluency"
        name: "sound"
        description: "Open the volume mixer"
        onPressed: root.take(name, true)
        onReleased: root.take(name, false)
    }

    GlobalShortcut {
        appid: "fluency"
        name: "search"
        description: "Open Search"
        onPressed: root.take(name, true)
        onReleased: root.take(name, false)
    }

    GlobalShortcut {
        appid: "fluency"
        name: "taskview"
        description: "Open Task View"
        onPressed: root.take(name, true)
        onReleased: root.take(name, false)
    }

    GlobalShortcut {
        appid: "fluency"
        name: "notify"
        description: "Open the notification center"
        onPressed: root.take(name, true)
        onReleased: root.take(name, false)
    }

    GlobalShortcut {
        appid: "fluency"
        name: "clipboard"
        description: "Open the clipboard history"
        onPressed: root.take(name, true)
        onReleased: root.take(name, false)
    }
}
