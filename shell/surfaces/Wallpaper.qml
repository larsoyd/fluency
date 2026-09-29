import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

PanelWindow {
    id: root

    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "black"
    // with input a minimized window keeps the focus, hyprland finds this surface under the pointer
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "fluency-wallpaper"

    Image {
        anchors.fill: parent
        source: Desktop.wallpaper
        sourceSize: Qt.size(width, height)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        onStatusChanged: if (status === Image.Error) console.log(`[wallpaper] result=fail reason=cannot_load screen=${root.screen.name} source=${source}`)
    }
}
