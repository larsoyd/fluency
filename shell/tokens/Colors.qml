pragma Singleton
import QtQuick

QtObject {
    readonly property color accent: "#0078D4"
    readonly property color accentLight2: "#60CDFF"

    readonly property color itemFillTransparent: "#00FFFFFF"
    readonly property color itemFillTertiary: "#0AFFFFFF"
    readonly property color itemFillSecondary: "#0FFFFFFF"
    readonly property color itemFillPrimary: "#15FFFFFF"
    readonly property color itemStrokeSecondaryTop: "#1AFFFFFF"
    readonly property color itemStrokeSecondaryBottom: "#0FFFFFFF"
    readonly property color itemStrokePrimaryTop: itemStrokeSecondaryTop
    readonly property color itemStrokePrimaryBottom: itemStrokeSecondaryBottom
    readonly property color itemStrokeQuinary: "#0AFFFFFF"
    readonly property color trayStrokePrimaryTop: "#20FFFFFF"
    readonly property color trayStrokePrimaryBottom: "#15FFFFFF"

    readonly property color attentionFill: "#442726"
    readonly property color attentionFillHover: "#543938"
    readonly property color attentionFillPressed: "#4C302F"

    readonly property color indicatorInactive: "#8BFFFFFF"
    readonly property color indicatorActive: accentLight2
    readonly property color indicatorAttention: "#FF99A4"
    readonly property color progressFill: "#8BFFFFFF"
    readonly property color progressTrack: "#0BFFFFFF"
    readonly property color toastProgressFill: accentLight2
    readonly property color toastProgressTrack: "#8BFFFFFF"
    readonly property color badgeFill: accentLight2
    readonly property color badgeText: "#FFFFFF"

    readonly property color taskbarTint: "#202020"
    readonly property color taskbarFallback: "#1C1C1C"
    readonly property real taskbarTintOpacity: 0.5
    readonly property real taskbarLuminosityOpacity: 0.96
    readonly property color flyoutTint: "#2C2C2C"
    readonly property color flyoutFallback: "#2C2C2C"
    readonly property real flyoutTintOpacity: 0.15
    readonly property real flyoutLuminosityOpacity: 0.96

    readonly property color topStroke: "#66757575"
    readonly property color textPrimary: "#FFFFFF"
    readonly property color textSecondary: "#C5FFFFFF"
    readonly property color showDesktopPipe: "#8BFFFFFF"
    readonly property color showDesktopPipePressed: "#28FFFFFF"
    readonly property color flyoutStroke: "#33000000"
    readonly property color menuItemHover: "#0FFFFFFF"
    readonly property color menuItemPressed: "#0AFFFFFF"
    readonly property color menuSeparator: "#15FFFFFF"
    readonly property color textDisabled: "#5DFFFFFF"
    readonly property color startStroke: "#66757575"
    readonly property color startBand: "#38000000"
    readonly property color startSearchFill: "#B21D1D1D"
    readonly property color startSearchStroke: "#12FFFFFF"
    readonly property color startPlaceholder: "#87FFFFFF"
    readonly property color controlFill: "#0FFFFFFF"
    readonly property color controlFillHover: "#15FFFFFF"
    readonly property color controlFillPressed: "#08FFFFFF"
    readonly property color controlStroke: "#12FFFFFF"
    readonly property color sliderRail: "#8BFFFFFF"
    readonly property color sliderThumbOuter: "#454545"
    readonly property color sliderThumbStroke: "#18FFFFFF"
    readonly property color sliderFill: accentLight2
    readonly property color sliderFillHover: "#E660CDFF"
    readonly property color sliderFillPressed: "#CC60CDFF"
    readonly property color divider: "#15FFFFFF"
    readonly property color cardFill: "#0DFFFFFF"
    readonly property color cardStroke: "#19000000"
    readonly property color textOnAccent: "#000000"
    readonly property color taskViewDim: "#66000000"
    readonly property color focusStroke: "#FFFFFF"
    readonly property color footerBand: "#09FFFFFF"
    // the explorer list palette, drawn see through over the wallpaper
    readonly property color desktopHoverFill: "#24E5F3FF"
    readonly property color desktopHoverStroke: "#3DE5F3FF"
    readonly property color desktopSelectedFill: "#52CCE8FF"
    readonly property color desktopSelectedStroke: "#6BCCE8FF"
    readonly property color desktopHotFill: "#4A99D1FF"
    readonly property color desktopHotStroke: "#6999D1FF"
    readonly property color desktopIdleFill: "#52D9D9D9"
    readonly property color desktopLabel: "#FFFFFF"
    readonly property color desktopShadow: "#000000"
    readonly property color marqueeFill: "#460066CC"
    readonly property color marqueeStroke: "#0078D7"
}
