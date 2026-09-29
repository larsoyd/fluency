import { glyph } from "./glyphs.mjs"

const pinGlyph = glyph("pin"), unpinGlyph = glyph("unpin"), closeGlyph = glyph("dismiss")

// the app's own tasks come first under a header, then the app, the pin and the close
export function rows(task, entry) {
    const out = []
    const tasks = entry?.actions ?? []
    if (tasks.length) {
        out.push({ kind: "header", text: "Tasks" })
        tasks.forEach((action, index) => out.push({ kind: "item", text: action.name, action: "task", task: index }))
        out.push({ kind: "separator" })
    }
    out.push({ kind: "item", text: entry?.name || task.appId, icon: true, action: "launch", enabled: !!entry })
    // a pin needs an entry to start the app again, an unpin never does
    if (task.pinned) out.push({ kind: "item", text: "Unpin from taskbar", glyph: unpinGlyph, action: "unpin" })
    else if (entry) out.push({ kind: "item", text: "Pin to taskbar", glyph: pinGlyph, action: "pin" })
    if (task.windows.length) out.push({ kind: "item", text: task.windows.length > 1 ? "Close all windows" : "Close window", glyph: closeGlyph, action: "close" })
    return out.map(row => row.kind === "item" ? Object.assign({ enabled: true }, row) : row)
}

const plans = {
    launch: (row, task) => [{ action: "launch", appId: task.appId }],
    task: (row, task) => [{ action: "launch", appId: task.appId, task: row.task }],
    pin: (row, task) => [{ action: "pin", appId: task.appId }],
    unpin: (row, task) => [{ action: "unpin", appId: task.appId }],
    close: (row, task) => task.windows.map(w => ({ action: "close", address: w.address })),
}

export function actions(row, task) {
    if (!Object.prototype.hasOwnProperty.call(plans, row.action)) throw new Error(`refused: unknown jump action ${JSON.stringify(row.action)}`)
    return plans[row.action](row, task)
}

export function height(list, m) {
    const size = { header: m.jumpHeader, separator: m.jumpSeparator, item: m.jumpRow }
    return 2 * (m.flyoutBorder + m.jumpPaddingY) + list.reduce((sum, row) => sum + size[row.kind], 0)
}
