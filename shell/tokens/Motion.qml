pragma Singleton
import QtQuick

QtObject {
    readonly property int controlFaster: 83
    readonly property int controlFast: 167
    readonly property int controlNormal: 250
    readonly property var curveControl: [0, 0, 0, 1]

    readonly property int plateFade: 83
    readonly property int searchTextFade: 167
    readonly property int progressFade: 167
    readonly property int trayIconRotate: 300
    readonly property int trayIconRotateExponent: 3
    readonly property int chevronTurn: 250
    readonly property var curveChevron: [0.55, 0, 0, 1]

    readonly property int tooltipDelay: 800
    readonly property int tooltipReshowDelay: 400
    readonly property int tooltipReshowWindow: 200
    readonly property int tooltipShown: 5000

    readonly property int indicatorResize: 333
    readonly property var curveIndicator: [0, 0, 0, 1]
    readonly property int flyoutOpen: 167
    readonly property int flyoutClose: 167
    readonly property int reflow: 167
    readonly property int toastShown: 5000
    readonly property int toastIn: 250
    readonly property int toastOut: 167
    readonly property int startOpen: 217
    readonly property int startClose: 150
    readonly property var curveStartClose: [0.9, 0.1, 1, 0.2]
    // the real capture settles in 4 to 5 frames at 30 fps, the render in 194 ms, close as start
    readonly property int searchOpen: 167
    readonly property int searchClose: 150
    readonly property int menuOpen: 250
    readonly property int menuFade: 83
    // direct exit of the fluent motion table, a blur cannot fade so the menu folds instead
    readonly property int menuClose: 167
    // how long a submenu waits before it opens
    readonly property int menuShowDelay: 400
    readonly property int osdShown: 2000
    readonly property int pageSlide: 167

    // start and toasts run a fifth longer like the hyprland windows and layers
    readonly property real calm: 1.2
    function calmed(ms) { return Math.round(ms * calm) }

    readonly property var curveDecelerate: [0, 0, 0, 1]
    readonly property var curvePointToPoint: [0.55, 0.55, 0, 1]
    readonly property var curveEasy: [0.33, 0, 0.67, 1]
    readonly property var curveLinear: [0, 0, 1, 1]
    readonly property var iconMinimize: [
        { to: 3.25, duration: 113, curve: curveDecelerate },
        { to: 3.25, duration: 91, curve: curveLinear },
        { to: -1.4, duration: 130, curve: curveEasy },
        { to: 0, duration: 300, curve: curvePointToPoint },
    ]
    readonly property var iconRestore: [
        { to: -4.5, duration: 113, curve: curveDecelerate },
        { to: -4.5, duration: 91, curve: curveLinear },
        { to: 1.1, duration: 130, curve: curveEasy },
        { to: 0, duration: 300, curve: curvePointToPoint },
    ]

    // measured from 30 or 50 fps captures or guessed, replace when a 120 fps capture exists
    readonly property var provisional: ["indicatorResize", "curveIndicator", "flyoutOpen", "flyoutClose", "reflow", "iconMinimize", "iconRestore", "toastShown", "toastIn", "toastOut", "startOpen", "startClose", "curveStartClose", "osdShown", "pageSlide", "searchOpen", "searchClose"]
}
