import QtQuick
import qs.tokens

// the preview waits for a resting pointer, then follows it from button to button at once
QtObject {
    id: root

    property string hoveredKey: ""
    property bool panelHovered: false
    property int delay: Motion.previewDelay
    property int linger: Motion.previewLinger
    property string key: ""
    property string muted: ""

    function dismiss() {
        muted = hoveredKey
        key = ""
    }

    function settle() {
        if (muted) forgetting.restart()
        if (hoveredKey) {
            closing.stop()
            if (key) key = hoveredKey
            else opening.restart()
            return
        }
        if (key && !panelHovered) closing.restart()
        else closing.stop()
    }

    onHoveredKeyChanged: settle()
    onPanelHoveredChanged: settle()

    property Timer opening: Timer {
        interval: root.delay
        onTriggered: if (root.hoveredKey !== root.muted) root.key = root.hoveredKey
    }

    // a button that only passes under the pointer is no new hover, it has to stay away a while
    property Timer forgetting: Timer {
        interval: root.linger
        onTriggered: if (root.hoveredKey !== root.muted) root.muted = ""
    }

    property Timer closing: Timer {
        interval: root.linger
        onTriggered: root.key = ""
    }
}
