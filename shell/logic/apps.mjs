// names without a letter in front gather under #
export function letter(name) {
    const first = (name ?? "").charAt(0).toUpperCase()
    return first && first !== first.toLowerCase() ? first : "#"
}

// code point order is the same on every locale and puts letters like ø after z
const before = (a, b) => a < b ? -1 : a > b ? 1 : 0

export function listed(entries) {
    const seen = new Set()
    const apps = entries.filter(entry => !entry.noDisplay && !seen.has(entry.id) && seen.add(entry.id))
        .map(entry => ({ kind: "app", key: `app:${entry.id}`, id: entry.id, name: entry.name, icon: entry.icon, letter: letter(entry.name) }))
    apps.sort((a, b) => before(a.letter, b.letter) || before(a.name.toUpperCase(), b.name.toUpperCase()) || before(a.id, b.id))
    const rows = []
    for (const app of apps) {
        if (rows.length === 0 || rows[rows.length - 1].letter !== app.letter) rows.push({ kind: "letter", key: `letter:${app.letter}`, text: app.letter, letter: app.letter })
        rows.push(app)
    }
    return rows
}

export function placed(rows, sizes) {
    let y = 0
    const out = rows.map(row => {
        const letter = row.kind === "letter"
        const top = y + (letter ? sizes.above : 0), height = letter ? sizes.letter : sizes.item
        y = top + height + (letter ? sizes.below : 0)
        return Object.assign({}, row, { y: top, height })
    })
    return { rows: out, height: y }
}

// pins keep their order and a pin whose app is gone is left out
export function pinned(ids, entries, columns, rowsShown, expanded) {
    const found = ids.map(id => entries.find(entry => entry.id === id)).filter(entry => entry)
    const shown = expanded ? found : found.slice(0, columns * rowsShown)
    const cells = shown.map((entry, i) => ({ id: entry.id, name: entry.name, icon: entry.icon, column: i % columns, row: Math.floor(i / columns) }))
    return { cells, rows: Math.ceil(cells.length / columns), more: found.length > columns * rowsShown }
}

export function command(entry, terminal) {
    if (!entry.runInTerminal) return entry.command
    if (!terminal) throw new Error("refused: no terminal for a terminal app")
    return [terminal, ...entry.command]
}

// a name that starts with the text comes first, then a word that does, then the text anywhere
function rank(entry, text) {
    const name = entry.name.toLowerCase()
    if (name.startsWith(text)) return 0
    if (name.split(/\s+/).some(word => word.startsWith(text))) return 1
    if (name.includes(text)) return 2
    return entry.id.toLowerCase().includes(text) ? 3 : -1
}

export function search(entries, text) {
    const wanted = text.trim().toLowerCase()
    if (!wanted) return []
    const found = entries.filter(entry => !entry.noDisplay).map(entry => ({ entry, rank: rank(entry, wanted) })).filter(hit => hit.rank >= 0)
    found.sort((a, b) => a.rank - b.rank || before(a.entry.name.toUpperCase(), b.entry.name.toUpperCase()) || before(a.entry.id, b.entry.id))
    return found.map(hit => hit.entry)
}

const edits = {
    pin: (pins, id) => [...pins, id],
    unpin: (pins, id) => pins.filter(pin => pin !== id),
    front: (pins, id) => [id, ...pins.filter(pin => pin !== id)],
}

export function edit(pins, action, id) {
    if (!Object.prototype.hasOwnProperty.call(edits, action)) throw new Error(`refused: unknown pin action ${JSON.stringify(action)}`)
    if (!id) throw new Error("refused: no app id")
    if (action === "pin" && pins.includes(id)) throw new Error(`refused: ${id} is pinned already`)
    if (action !== "pin" && !pins.includes(id)) throw new Error(`refused: ${id} is not pinned`)
    return edits[action](pins, id)
}

const pinGlyph = "\ue718", unpinGlyph = "\ue77a"

// a tile offers move to front unless it is first already
export function menu(id, tile, start, taskbar) {
    const rows = [start.includes(id)
        ? { action: "unpin", text: "Unpin from Start", glyph: unpinGlyph }
        : { action: "pin", text: "Pin to Start", glyph: pinGlyph }]
    if (tile && start.indexOf(id) > 0) rows.push({ action: "front", text: "Move to front" })
    rows.push(taskbar.includes(id)
        ? { action: "unpin-taskbar", text: "Unpin from taskbar", glyph: unpinGlyph }
        : { action: "pin-taskbar", text: "Pin to taskbar", glyph: pinGlyph })
    return rows
}

// an empty text is a missing file, the caller keeps its defaults
export function restore(text) {
    if (!text) return null
    let value
    try { value = JSON.parse(text) } catch (e) { value = null }
    const ids = Array.isArray(value) && value.every(id => typeof id === "string" && id !== "")
    if (!ids || new Set(value).size !== value.length) throw new Error("refused: pins file is not a list of app ids")
    return value
}

// steam names a game's window steam_app_<id> and starts it with steam://rungameid/<id>
export function games(entries) {
    const found = {}
    for (const entry of entries) {
        const url = entry.command.find(word => /^steam:\/\/rungameid\/\d+$/.test(word))
        if (url) found[url.slice(18)] = entry.id
    }
    return found
}

export function game(appId, games) {
    const id = /^steam_app_(\d+)$/.exec(appId)?.[1]
    return (id && games[id]) || ""
}

// steam puts the id of a game it starts in the environment, whatever the window calls itself
export function steamId(environ) {
    for (const line of environ.split("\0")) {
        const id = /^Steam(?:App|Game)Id=(\d+)$/.exec(line)?.[1]
        if (id && id !== "0") return id
    }
    return ""
}
