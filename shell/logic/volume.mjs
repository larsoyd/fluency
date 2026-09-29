const notch = 120, perNotch = 0.02

export function clamp(level) {
    return Math.max(0, Math.min(1, level))
}

export function wheel(level, delta) {
    return clamp(Math.round((level + delta / notch * perNotch) * 100) / 100)
}

export function percent(level) {
    return Math.round(level * 100)
}

export function outputs(nodes, current) {
    return nodes.filter(node => node.kind === "sink")
        .map(node => ({ id: node.id, label: node.description || node.nickname || node.name, selected: node.id === current }))
}

// the mixer has one row per app however many streams it plays
export function apps(nodes) {
    const rows = []
    for (const node of nodes.filter(node => node.kind === "stream")) {
        const key = node.app || node.name
        const row = rows.find(row => row.key === key)
        if (row) row.ids.push(node.id)
        else rows.push({ key, label: key, icons: [node.icon, node.binary].filter(name => name), ids: [node.id], volume: node.volume, muted: node.muted })
    }
    return rows
}

// a new output or the first reading after start is no change the user made
export function osd(prev, next) {
    if (!prev.ready || !next.ready || prev.sink !== next.sink) return false
    return prev.muted !== next.muted || Math.abs(prev.volume - next.volume) >= 0.005
}

export function soundHeight(outputs, apps, m) {
    return m.soundHeader + 2 * m.soundSection + outputs * m.soundRow + m.soundDivider + apps * m.soundAppRow + m.soundBottom + m.soundFooter
}
