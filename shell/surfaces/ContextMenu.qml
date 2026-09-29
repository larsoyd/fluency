import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.components

PanelWindow {
    id: root

    property alias flyout: flyout

    signal picked(string action)
    signal dismissed()

    // the item reads as hidden while its window is, so the window follows the state
    visible: flyout.shown
    anchors { left: true; top: true }
    margins.left: flyout.box.x
    margins.top: flyout.box.y
    implicitWidth: Math.max(1, flyout.box.width)
    implicitHeight: Math.max(1, flyout.box.height)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "fluency-context"
    WlrLayershell.keyboardFocus: flyout.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    ContextFlyout {
        id: flyout
        objectName: "context"
        area: Qt.size(root.screen?.width ?? 0, root.screen?.height ?? 0)
        x: -flyout.box.x
        y: -flyout.box.y
        width: flyout.area.width
        height: flyout.area.height
        onPicked: action => root.picked(action)
        onClosed: root.dismissed()
    }

    // a click outside ends the grab, the menu is only as big as itself
    HyprlandFocusGrab {
        windows: [root]
        active: flyout.open
        onCleared: flyout.close()
    }
}
