import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.tokens
import qs.components
import qs.services
import "../logic/taskview.mjs" as TaskView

PanelWindow {
    id: root

    property bool open: false
    property var pending: null
    property alias body: body
    readonly property var monitor: Hyprland.monitors.values.find(monitor => monitor.name === screen.name) ?? null
    readonly property var spaces: Hyprland.workspaces.values.map(space => ({ id: space.id, monitor: space.monitor?.name ?? "" }))

    // the pick runs once the view has unmapped, a focus sent while it held the keys landed elsewhere
    function run(action) {
        pending = action
        open = false
    }

    onVisibleChanged: if (!visible && pending) {
        Windows.run(pending)
        pending = null
    }

    visible: open || body.reveal > 0
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "fluency-taskview"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // the compositor fades the whole surface so the blur under it fades too
    HyprlandWindow.opacity: body.reveal

    // hyprland reports sizes and focus order only when asked
    onOpenChanged: {
        if (open) {
            Hyprland.refreshToplevels()
            Hyprland.refreshWorkspaces()
            body.forceActiveFocus()
        }
        body.shown = open
    }

    Rectangle {
        objectName: "dim"
        anchors.fill: parent
        color: Colors.taskViewDim
    }

    TaskViewBody {
        id: body
        objectName: "overview"
        anchors.fill: parent
        wallpaper: Desktop.wallpaper
        items: TaskView.items(Windows.windows, root.screen.name, root.monitor?.activeWorkspace?.name ?? "").map(win => ({
            address: win.address,
            title: win.title,
            icon: Windows.icon(win.appId),
            size: win.size,
            at: [win.at[0] - root.screen.x, win.at[1] - root.screen.y],
        }))
        desktops: TaskView.desktops(root.spaces, root.screen.name, root.monitor?.activeWorkspace?.id ?? 0).map(desk => Object.assign({
            windows: TaskView.miniature(Windows.windows.filter(win => win.workspace === String(desk.id)), root.screen),
        }, desk))
        preview: Component {
            ScreencopyView {
                readonly property bool ready: hasContent
                captureSource: Windows.toplevel(parent.address)
                live: root.open
            }
        }
        onPicked: address => root.run({ action: "focus", address, still: true })
        onCloseAsked: address => Windows.run({ action: "close", address })
        onDismissed: root.open = false
        onSwitched: id => root.run({ action: "workspace", workspace: id })
        onCreated: Desktops.make(root.screen.name)
        onDeskClosed: id => Desktops.close(id, root.screen.name, body.desktops)
    }
}
