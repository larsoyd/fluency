import { place } from "./hypr.mjs"

// a window hyprland has not sized yet is drawn at the shape of a screen
const aspect = size => size.h > 0 ? Math.min(2.5, Math.max(0.5, size.w / size.h)) : 16 / 9

function wrap(sizes, height, width, gap) {
    const rows = [[]]
    let used = 0
    for (let i = 0; i < sizes.length; i++) {
        const w = Math.round(height * aspect(sizes[i]))
        if (rows[rows.length - 1].length && used + gap + w > width) {
            rows.push([])
            used = 0
        }
        used += (rows[rows.length - 1].length ? gap : 0) + w
        rows[rows.length - 1].push({ index: i, w })
    }
    return rows
}

function fits(sizes, height, area, opts) {
    const rows = wrap(sizes, height, area.w, opts.gap)
    const wide = rows.every(row => row.reduce((sum, item) => sum + item.w, 0) + (row.length - 1) * opts.gap <= area.w)
    return wide && rows.length * (height + opts.title) + (rows.length - 1) * opts.gap <= area.h
}

// the tallest thumbnails that still fit, every row centred on its own
export function layout(sizes, area, opts) {
    if (!sizes.length) return []
    let low = 1, high = Math.floor(area.h * opts.most)
    while (low < high) {
        const mid = Math.ceil((low + high) / 2)
        if (fits(sizes, mid, area, opts)) low = mid
        else high = mid - 1
    }
    const rows = wrap(sizes, low, area.w, opts.gap), item = low + opts.title
    const block = rows.length * item + (rows.length - 1) * opts.gap
    const out = []
    rows.forEach((row, at) => {
        const used = row.reduce((sum, cell) => sum + cell.w, 0) + (row.length - 1) * opts.gap
        let x = area.x + Math.floor((area.w - used) / 2)
        const y = area.y + Math.floor((area.h - block) / 2) + at * (item + opts.gap)
        for (const cell of row) {
            out[cell.index] = { x, y, w: cell.w, h: item, thumb: { w: cell.w, h: low } }
            x += cell.w + opts.gap
        }
    })
    return out
}

// left and right walk the order, up and down keep to the closest centre in the next row
export function nearest(rects, from, dir) {
    if (dir === "left" || dir === "right") return Math.max(0, Math.min(rects.length - 1, from + (dir === "right" ? 1 : -1)))
    const at = rects[from], centre = r => r.x + r.w / 2
    const ys = [...new Set(rects.map(r => r.y))].sort((a, b) => a - b)
    const row = ys[ys.indexOf(at.y) + (dir === "down" ? 1 : -1)]
    let best = from
    rects.forEach((r, i) => {
        if (r.y === row && (best === from || Math.abs(centre(r) - centre(at)) < Math.abs(centre(rects[best]) - centre(at)))) best = i
    })
    return best
}

// the window in front first, a window hyprland has not ranked yet last
export function byFocus(windows) {
    const rank = win => win.focus >= 0 ? win.focus : Infinity
    return windows.map((win, index) => ({ win, index }))
        .sort((a, b) => rank(a.win) - rank(b.win) || a.index - b.index)
        .map(({ win }) => win)
}

export function items(windows, monitor, workspace) {
    return byFocus(windows.filter(win => win.monitor === monitor && (win.workspace === workspace || win.workspace === place(monitor))))
}

export function desktops(workspaces, monitor, active) {
    return workspaces.filter(space => space.monitor === monitor && space.id > 0)
        .sort((a, b) => a.id - b.id)
        .map(space => ({ id: space.id, name: `Desktop ${space.id}`, active: space.id === active }))
}

export function fresh(workspaces) {
    const taken = new Set(workspaces.map(space => space.id))
    let id = 1
    while (taken.has(id)) id++
    return id
}

export function miniature(windows, screen) {
    return windows.map(win => ({
        x: (win.at[0] - screen.x) / screen.width, y: (win.at[1] - screen.y) / screen.height,
        w: win.size[0] / screen.width, h: win.size[1] / screen.height,
    }))
}
