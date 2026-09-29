export function groupX(bar, group, tray) {
    const centred = Math.floor((bar - group) / 2)
    return Math.max(0, Math.min(centred, bar - tray - group))
}

export function plate(metrics) {
    return {
        x: metrics.buttonMarginX,
        y: metrics.buttonMarginY,
        width: metrics.buttonExtent - 2 * metrics.buttonMarginX,
        height: metrics.taskbarHeight - 2 * metrics.buttonMarginY,
    }
}
