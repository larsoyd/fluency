import QtQuick
import qs.tokens
import "../logic/scroll.mjs" as Scroll

// wayland wheels never reached a handler in a flickable, no buttons so the rows keep their clicks
MouseArea {
    id: root

    required property Flickable view
    property alias glide: glide

    acceptedButtons: Qt.NoButton
    onWheel: event => {
        if (!event.angleDelta.y || event.pixelDelta.y) {
            event.accepted = false
            return
        }
        glide.to = Scroll.wheelTarget(glide.running ? glide.to : view.contentY, event.angleDelta.y, view.height, view.contentHeight)
        glide.restart()
    }

    NumberAnimation {
        id: glide
        target: root.view
        property: "contentY"
        duration: Motion.controlNormal
        easing.type: Easing.OutCubic
    }
}
