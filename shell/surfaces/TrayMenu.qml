import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.tokens
import qs.components
import "../logic/menu.mjs" as Menu
import "../logic/tray.mjs" as Tray

PanelWindow {
    id: root

    property real anchorX: 0
    property alias opener: opener
    readonly property var entries: opener.children?.values ?? []
    readonly property bool open: opener.menu !== null

    function show(handle: var, x: real): void {
        anchorX = x
        opener.menu = handle
    }

    function close(): void {
        opener.menu = null
    }

    function choose(index: int): string {
        const entry = entries[index]
        if (!entry || entry.isSeparator || !entry.enabled) return `refused: no choosable row ${index}`
        console.log(`[menu] chose="${entry.text}" more=${entry.hasChildren}`)
        if (entry.hasChildren) {
            opener.menu = entry
            return "ok"
        }
        entry.triggered()
        close()
        return "ok"
    }

    visible: open && entries.length > 0
    anchors { left: true; bottom: true }
    margins.left: Tray.flyoutX(anchorX, panel.width, screen.width, Metrics.flyoutOffset)
    margins.bottom: Metrics.flyoutOffset
    implicitWidth: panel.width
    implicitHeight: panel.height
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "fluency-menu"
    WlrLayershell.layer: WlrLayer.Overlay

    QsMenuOpener { id: opener }

    MenuPanel {
        id: panel
        objectName: "menu"
        rows: Menu.rows(root.entries)
        onChosen: index => root.choose(index)
    }

    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: root.close()
    }
}
