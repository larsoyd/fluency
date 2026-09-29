pragma Singleton
import QtQuick
import Quickshell
import "../logic/clock.mjs" as Logic

Singleton {
    readonly property date now: clock.date
    readonly property var pictures: Logic.pictures(Qt.locale().timeFormat(Locale.ShortFormat), Qt.locale().dateFormat(Locale.ShortFormat))

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
