import QtQuick
import qs.tokens
import "../logic/tray.mjs" as Tray

TrayButton {
    id: root

    property url source: ""

    width: Tray.cell(Metrics.trayIconSize, Metrics)

    Image {
        objectName: "image"
        anchors.centerIn: parent
        width: Metrics.trayIconSize
        height: Metrics.trayIconSize
        source: root.source
        sourceSize: Qt.size(width, height)
    }
}
