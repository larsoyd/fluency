// the desktop context menu, measured at 125 percent
const textX = 43, markedTextX = 74, accelGap = 24, endPad = 15

function rowHeight(row, m) {
    if (row.kind === "separator") return m.separator
    if (row.kind === "buttons") return m.buttons
    return m.row
}

// the button row has a separator's gap under it
export function placed(rows, m) {
    let y = m.border + m.pad
    return rows.map(row => {
        const out = Object.assign({}, row, { y, height: rowHeight(row, m) })
        y += out.height + (row.kind === "buttons" ? m.separator : 0)
        return out
    })
}

export function height(rows, m) {
    const list = placed(rows, m)
    const last = list[list.length - 1]
    const gap = last && last.kind === "buttons" ? m.separator : 0
    return (last ? last.y + last.height + gap : m.border + m.pad) + m.pad + m.border
}

export function width(text, accel, marks, m) {
    const inner = (marks ? markedTextX : textX) + text + (accel ? accelGap + accel : 0) + endPad
    return Math.max(m.minWidth, 2 * m.border + inner)
}

export const columns = { textX, markedTextX, glyphX: 15, markedGlyphX: 39, markX: 15, endPad, accelGap }

// top left at the pointer, flipped up or left where the screen ends
export function open(at, size, screen) {
    const x = at.x + size.width > screen.width ? at.x - size.width : at.x
    const y = at.y + size.height > screen.height ? at.y - size.height : at.y
    return { x: Math.max(0, Math.min(x, screen.width - size.width)), y: Math.max(0, Math.min(y, screen.height - size.height)) }
}

// the first row of a submenu lines up with the row that opened it
export function submenu(parent, rowY, size, screen, m) {
    const right = parent.x + parent.width
    const x = right + size.width > screen.width ? parent.x - size.width : right
    const y = Math.min(parent.y + rowY - m.pad - m.border, screen.height - size.height)
    return { x: Math.max(0, x), y: Math.max(0, y) }
}

const choosable = row => row.kind === "item" && row.enabled !== false

export function next(rows, from, dir) {
    for (let i = 1; i <= rows.length; i++) {
        const at = ((from + dir * i) % rows.length + rows.length) % rows.length
        if (choosable(rows[at])) return at
    }
    return -1
}
