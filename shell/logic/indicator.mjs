export function state({ windows = 0, active = false, attention = false }) {
    if (windows === 0) return "none"
    if (attention) return "attention"
    return active ? "active" : "inactive"
}

export function width(item, metrics) {
    if (state(item) === "none") return 0
    return item.active ? metrics.indicatorWidthActive : metrics.indicatorWidthInactive
}

export function fill(item, colors) {
    return {
        none: colors.indicatorInactive,
        inactive: colors.indicatorInactive,
        active: colors.indicatorActive,
        attention: colors.indicatorAttention,
    }[state(item)]
}
