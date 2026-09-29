import QtQuick
import qs.tokens
import "../logic/progress.mjs" as Logic

Rectangle {
    id: root

    property real value: -1

    visible: value >= 0
    height: Metrics.progressHeight
    radius: Metrics.progressRadius
    color: Colors.progressTrack

    Rectangle {
        objectName: "fill"
        width: Logic.determinate(root.width, root.value)
        height: parent.height
        radius: parent.radius
        color: Colors.progressFill
    }
}
