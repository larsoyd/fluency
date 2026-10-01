pragma Singleton
import QtQuick

QtObject {
    readonly property int taskbarHeight: 48
    readonly property int topStroke: 1
    readonly property int iconSize: 24

    readonly property int buttonExtent: 44
    readonly property int buttonMarginX: 2
    readonly property int buttonMarginY: 4
    readonly property int buttonRadius: 4
    readonly property int buttonOutline: 1
    readonly property int strokeGradientExtent: 3
    readonly property real strokeGradientStart: 0.33
    readonly property real iconPressedOpacity: 0.8
    // no source for the squeeze yet, taken by eye
    readonly property real iconPressedScale: 0.875
    readonly property int dragThreshold: 4
    readonly property int multiWindowInset: 5
    readonly property int multiWindowInsetLargeIcon: 7

    readonly property int indicatorHeight: 3
    readonly property real indicatorRadius: 1.5
    readonly property int indicatorBottomMargin: 1
    readonly property int indicatorWidthActive: 16
    readonly property int indicatorWidthInactive: 6

    readonly property int progressHeight: 3
    readonly property real progressRadius: 1.5

    readonly property int badgeFontSmall: 11
    readonly property int badgeFontLarge: 13
    readonly property int badgeGlyphSmall: 12
    readonly property int badgeGlyphLarge: 14
    readonly property int badgeMinWidth: 24
    readonly property int badgePaddingX: 4
    readonly property int badgeHeight: 16
    readonly property int badgeOffset: 4

    readonly property int tooltipOffset: 12
    readonly property int tooltipFontSize: 12
    readonly property int tooltipMaxWidth: 320
    readonly property int tooltipBorder: 1
    readonly property var tooltipPadding: [9, 6, 9, 8]

    readonly property int searchPillMinWidth: 100
    readonly property int searchPillRadius: 16
    readonly property int searchPillMarginX: 1
    readonly property int searchPillMarginY: 4
    readonly property int searchBoxExtent: 220
    readonly property int searchBoxIconMargin: 11

    readonly property int trayIconSize: 16
    readonly property int trayIconMinWidth: 32
    readonly property int trayIconPaddingX: 4
    readonly property int trayPaddingY: 4
    readonly property int trayRadius: 4
    readonly property int trayGlyphSize: 16
    readonly property real trayUnderlayOpacity: 0.2
    readonly property int chevronTurn: 180
    readonly property int omniBorder: 1
    readonly property int omniEdgePadding: 4
    readonly property var clockMargin: [0, -2, -1, 0]

    readonly property int showDesktopWidth: 12
    readonly property int showDesktopPipeWidth: 1
    readonly property int showDesktopPipeHeight: 16
    readonly property real showDesktopPipeRadius: 0.5

    readonly property int overflowPadding: 12
    readonly property int overflowCell: 40
    readonly property int overflowColumns: 5
    readonly property int overflowGridMargin: 4
    readonly property int flyoutRadius: 8
    readonly property int flyoutBorder: 1
    readonly property int flyoutOffset: 12
    readonly property int menuPaddingY: 2
    readonly property int menuItemMarginX: 4
    readonly property int menuItemMarginY: 2
    readonly property int menuItemPaddingX: 11
    readonly property int menuItemPaddingTop: 8
    readonly property int menuItemPaddingBottom: 9
    readonly property int menuItemRadius: 4
    readonly property int menuLine: 20
    readonly property int menuSeparator: 1
    readonly property int menuSeparatorMarginY: 1
    readonly property int menuCheckWidth: 28
    readonly property int menuMaxWidth: 360
    readonly property real menuClosedRatio: 0.5
    // measured from jump list captures at 100 and 175 percent
    readonly property int jumpWidth: 294
    readonly property int jumpRow: 32
    readonly property int jumpRowMargin: 2
    readonly property int jumpHeader: 33
    readonly property int jumpSeparator: 6
    readonly property int jumpPaddingY: 1
    readonly property int jumpIconX: 16
    readonly property int jumpIconSize: 16
    readonly property int jumpTextX: 44
    readonly property int toastWidth: 364
    readonly property int toastPadding: 16
    readonly property int toastGap: 12
    readonly property int toastsShown: 3
    readonly property int toastCloseSize: 32

    readonly property int startCellWidth: 96
    readonly property int startCellHeight: 84
    readonly property int startWidth: 642
    readonly property int startHeight: 726
    readonly property int startWindowWidth: 666
    readonly property int startWindowHeight: 750
    readonly property int startShadowMargin: 12
    readonly property int startBand: 64
    readonly property int startSearchMarginX: 32
    readonly property int startSearchHeight: 32
    readonly property int startSearchIconX: 16
    readonly property int startSearchTextX: 45
    readonly property int startFooterPaddingX: 52
    readonly property int startFooterPaddingRight: 54
    readonly property int startFooterButton: 40
    readonly property int startAvatar: 32
    readonly property int startUserPadding: 12
    readonly property int startGlyph: 16
    readonly property int startColumns: 6
    readonly property int startPinnedRows: 2
    readonly property int startHeaderX: 63
    readonly property int startHeaderY: 30
    readonly property int startHeaderHeight: 20
    readonly property int startHeaderRight: 64
    readonly property int startGridX: 32
    readonly property int startGridGap: 14
    readonly property int startSectionGap: 38
    readonly property int startListGap: 6
    readonly property int startListEnd: 12
    readonly property int startListItem: 40
    readonly property int startLetter: 32
    readonly property int startLetterAbove: 12
    readonly property int startLetterBelow: 8
    readonly property int startListX: 52
    readonly property int startListIcon: 24
    readonly property int startListIconX: 12
    readonly property int startListTextX: 56
    readonly property int startTileIcon: 32
    readonly property int startTileTop: 12
    readonly property int startTileGap: 4
    readonly property int startTileTextX: 2
    readonly property int startMoreHeight: 22
    readonly property int startMorePadLeft: 7
    readonly property int startMorePadRight: 6
    readonly property int startMoreTextGap: 10
    readonly property int startMoreGlyph: 10

    // search pane measured from a capture at scale 0.895
    readonly property int searchWidth: 760
    readonly property int searchHeight: 550
    readonly property int searchInset: 24
    readonly property int searchTop: 32
    readonly property int searchBox: 36
    readonly property int searchBoxIconX: 14
    readonly property int searchBoxTextX: 40
    readonly property int searchUnderline: 2
    readonly property int searchTabsY: 88
    readonly property int searchTabHeight: 32
    readonly property int searchTabGap: 20
    readonly property int searchPillWidth: 16
    readonly property int searchPillHeight: 3
    readonly property int searchHeaderY: 146
    readonly property int searchTilesY: 180
    readonly property int searchTile: 90
    readonly property int searchTileGap: 8
    readonly property int searchTiles: 5
    readonly property int searchTileIconY: 16
    readonly property int searchTileTextY: 56
    readonly property int searchListsY: 292
    readonly property int searchRow: 50
    readonly property int searchRows: 4
    readonly property int searchRowIconX: 12
    readonly property int searchRowTextX: 48
    readonly property int searchResultsY: 136
    readonly property int searchBest: 64
    readonly property int searchResult: 40
    readonly property int searchSection: 14
    readonly property int searchPreviewIcon: 64
    readonly property int searchPreviewPad: 16

    // measured at 150% from the capture of build 22533 in the announcement
    readonly property int osdWidth: 170
    readonly property int osdHeight: 45
    readonly property int osdGap: 7
    readonly property int osdGlyphX: 14
    readonly property int osdRailX: 45
    readonly property int osdRailWidth: 110

    readonly property int sliderHeight: 32
    readonly property int sliderTrack: 4
    readonly property int sliderTrackRadius: 2
    readonly property int sliderThumb: 18
    readonly property int sliderInnerThumb: 12
    readonly property real sliderThumbHover: 1.167
    readonly property real sliderThumbPressed: 0.833

    // measured at 100% from a capture of build 23493
    readonly property int quickWidth: 360
    readonly property int soundHeader: 48
    readonly property int soundSection: 28
    readonly property int soundRow: 40
    readonly property int soundDivider: 9
    readonly property int soundAppRow: 48
    readonly property int soundBottom: 16
    readonly property int soundFooter: 48
    readonly property int soundInsetX: 4
    readonly property int soundTextX: 16
    readonly property int soundRowIconX: 18
    readonly property int soundRowTextX: 40
    readonly property int soundPillWidth: 3
    readonly property int soundPillHeight: 16
    readonly property int soundTitleX: 48
    readonly property int soundBackX: 8
    readonly property int soundAppIcon: 20
    readonly property int soundAppIconX: 17
    readonly property int soundSliderX: 45
    readonly property int soundSliderRight: 22

    // no source for the first page, set by eye
    readonly property int quickPaddingX: 16
    readonly property int quickPaddingTop: 12
    readonly property int quickRow: 48
    readonly property int quickButton: 40
    // x, y, opacity of each copy, a dark core one down and right fading out around it
    readonly property var desktopShadow: [[0, 0, 0.5], [1, 1, 1], [1, 0, 0.5], [0, 1, 0.5], [2, 1, 0.35], [1, 2, 0.35], [2, 2, 0.3], [-1, 0, 0.15], [0, -1, 0.15]]
    // desktop context menu, measured at 125 percent
    readonly property var context: ({ pad: 4, border: 1, row: 32, separator: 9, buttons: 40, button: 40, minWidth: 256, fillX: 4, fillY: 2, glyph: 16, radius: 4 })
}
