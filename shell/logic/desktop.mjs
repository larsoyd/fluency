import { glyph } from "./glyphs.mjs"

// measured on the stock desktop at 100 percent with 48 px icons
const base = { plate: 75, gap: 1, label: 8, line: 17, pad: 1, below: 45, originX: 2, originY: 7 }

export function metrics(icon) {
    const plateWidth = Math.max(base.plate, icon + base.plate - 48)
    return {
        icon,
        plateWidth,
        labelWidth: plateWidth - base.label,
        pitchX: plateWidth + base.gap,
        pitchY: icon + base.below,
        line: base.line,
        pad: base.pad,
        originX: base.originX,
        originY: base.originY,
    }
}

export function plateHeight(m, lines) {
    return 2 * m.pad + m.icon + lines * m.line
}

export function grid(area, m) {
    return {
        columns: Math.max(1, Math.floor((area.width - m.originX) / m.pitchX)),
        rows: Math.max(1, Math.floor((area.height - m.originY) / m.pitchY)),
    }
}

export function cell(index, area, m) {
    const rows = grid(area, m).rows
    return { x: m.originX + Math.floor(index / rows) * m.pitchX, y: m.originY + (index % rows) * m.pitchY }
}

function nearest(point, free, area, m) {
    let best = -1, far = Infinity
    for (const index of free) {
        const at = cell(index, area, m), d = (at.x - point.x) ** 2 + (at.y - point.y) ** 2
        if (d < far) { far = d; best = index }
    }
    return best
}

const overlaps = (a, b, m) => a.x < b.x + m.pitchX && b.x < a.x + m.pitchX && a.y < b.y + m.pitchY && b.y < a.y + m.pitchY

// places are pixel spots, the grid snaps them and a taken spot goes to the nearest free cell
export function arrange(names, places, area, m, opts) {
    const g = grid(area, m), count = Math.max(g.columns * g.rows, names.length)
    const free = new Set(Array.from({ length: count }, (_, i) => i))
    const spot = {}
    const take = index => { free.delete(index); return cell(index, area, m) }
    if (!opts.auto) {
        for (const name of names) {
            const at = places[name]
            if (!at) continue
            if (opts.grid) {
                const shown = [...free].filter(i => i < g.columns * g.rows)
                spot[name] = take(shown.length ? nearest(at, shown, area, m) : Math.min(...free))
                continue
            }
            spot[name] = {
                x: Math.max(0, Math.min(at.x, area.width - m.pitchX)),
                y: Math.max(0, Math.min(at.y, area.height - m.pitchY)),
            }
            for (const index of [...free]) if (overlaps(cell(index, area, m), spot[name], m)) free.delete(index)
        }
    }
    const order = [...free].sort((a, b) => a - b)
    return names.map(name => Object.assign({ name }, spot[name] ?? take(order.find(i => free.has(i)))))
}

function range(order, from, to) {
    const a = order.indexOf(from), b = order.indexOf(to)
    return a < 0 || b < 0 ? [to] : order.slice(Math.min(a, b), Math.max(a, b) + 1)
}

const inOrder = (order, names) => order.filter(name => names.has(name))

// shift runs from the anchor in desktop order, ctrl keeps what was there
export function click(state, order, name, mods) {
    if (!name) return mods.ctrl ? state : { selected: [], anchor: "", focus: state.focus }
    if (mods.shift && state.anchor) {
        const run = range(order, state.anchor, name)
        const kept = mods.ctrl ? state.selected : []
        return { selected: inOrder(order, new Set([...kept, ...run])), anchor: state.anchor, focus: name }
    }
    if (mods.ctrl) {
        const next = new Set(state.selected)
        if (next.has(name)) next.delete(name)
        else next.add(name)
        return { selected: inOrder(order, next), anchor: name, focus: name }
    }
    return { selected: [name], anchor: name, focus: name }
}

export function band(rect, spots, m, base) {
    const hit = spot => spot.x < rect.x + rect.width && rect.x < spot.x + m.plateWidth
        && spot.y < rect.y + rect.height && rect.y < spot.y + spot.h
    const kept = new Set(base)
    return spots.filter(spot => kept.has(spot.name) || hit(spot)).map(spot => spot.name)
}

// digits compare as numbers like the explorer does
export function natural(a, b) {
    const split = text => text.toLowerCase().match(/\d+|\D+/g) ?? []
    const x = split(a), y = split(b)
    for (let i = 0; i < Math.min(x.length, y.length); i++) {
        if (x[i] === y[i]) continue
        const both = /^\d/.test(x[i]) && /^\d/.test(y[i])
        return both ? Number(x[i]) - Number(y[i]) || x[i].length - y[i].length : x[i] < y[i] ? -1 : 1
    }
    return x.length - y.length
}

const keys = {
    name: (a, b) => natural(a.label, b.label),
    size: (a, b) => a.size - b.size,
    type: (a, b) => natural(a.type, b.type),
    modified: (a, b) => b.modified - a.modified,
}

// folders stay in front whichever way the rest runs
export function sorted(items, key, down) {
    if (!Object.prototype.hasOwnProperty.call(keys, key)) throw new Error(`refused: unknown sort key ${JSON.stringify(key)}`)
    const turn = down ? -1 : 1
    const list = items.map((item, index) => ({ item, index }))
    list.sort((a, b) => (b.item.dir - a.item.dir) || turn * (keys[key](a.item, b.item) || natural(a.item.label, b.item.label)) || a.index - b.index)
    return list.map(entry => entry.item.name)
}

export function fresh(base, ext, taken) {
    const used = new Set(taken.map(name => name.toLowerCase()))
    for (let n = 1; ; n++) {
        const name = n === 1 ? base + ext : `${base} (${n})${ext}`
        if (!used.has(name.toLowerCase())) return name
    }
}

export function locales(lang) {
    const found = /^([a-zA-Z]+)(?:_([a-zA-Z]+))?(?:\.[^@]*)?(?:@(.+))?$/.exec(lang ?? "")
    if (!found) return []
    const [, language, country, modifier] = found
    const out = []
    if (country && modifier) out.push(`${language}_${country}@${modifier}`)
    if (country) out.push(`${language}_${country}`)
    if (modifier) out.push(`${language}@${modifier}`)
    out.push(language)
    return out
}

// only the main group counts, the actions below it have names of their own
export function entry(text, wanted) {
    const values = {}
    let group = ""
    for (const raw of text.split("\n")) {
        const line = raw.trim()
        if (!line || line.startsWith("#")) continue
        if (line.startsWith("[")) { group = line; continue }
        if (group !== "[Desktop Entry]") continue
        const at = line.indexOf("=")
        if (at > 0) values[line.slice(0, at).trim()] = line.slice(at + 1).trim()
    }
    if (!("Name" in values) && !("Type" in values)) return null
    const local = wanted.map(code => values[`Name[${code}]`]).find(name => name)
    return { name: local ?? values.Name ?? "", icon: values.Icon ?? "", type: values.Type ?? "", url: values.URL ?? "", hidden: values.Hidden === "true" }
}

function nearestIndex(point, area, m) {
    const g = grid(area, m)
    const column = Math.max(0, Math.round((point.x - m.originX) / m.pitchX))
    const row = Math.min(g.rows - 1, Math.max(0, Math.round((point.y - m.originY) / m.pitchY)))
    return column * g.rows + row
}

// moved items go last so the ones that stayed keep their cells
export function drop(spots, moved, dx, dy, order, area, m, opts) {
    const going = new Set(moved)
    const places = {}
    for (const spot of spots) places[spot.name] = going.has(spot.name) ? { x: spot.x + dx, y: spot.y + dy } : { x: spot.x, y: spot.y }
    const stay = order.filter(name => !going.has(name)), move = order.filter(name => going.has(name))
    if (!opts.auto) return { places, order: [...stay, ...move] }
    const first = spots.find(spot => going.has(spot.name))
    const at = Math.min(stay.length, nearestIndex({ x: first.x + dx, y: first.y + dy }, area, m))
    return { places, order: [...stay.slice(0, at), ...move, ...stay.slice(at)] }
}

const ahead = {
    up: (from, to) => ({ along: from.y - to.y, across: Math.abs(from.x - to.x) }),
    down: (from, to) => ({ along: to.y - from.y, across: Math.abs(from.x - to.x) }),
    left: (from, to) => ({ along: from.x - to.x, across: Math.abs(from.y - to.y) }),
    right: (from, to) => ({ along: to.x - from.x, across: Math.abs(from.y - to.y) }),
}

const byPlace = (a, b) => a.x - b.x || a.y - b.y

// the nearest item that way, staying in the row or column costs least
export function step(spots, from, key) {
    const list = [...spots].sort(byPlace)
    if (!list.length) return ""
    if (key === "home") return list[0].name
    if (key === "end") return list[list.length - 1].name
    const here = spots.find(spot => spot.name === from)
    if (!here) return list[0].name
    let best = here, cost = Infinity
    for (const spot of list) {
        const d = ahead[key](here, spot)
        if (d.along <= 0) continue
        const c = d.along + 2 * d.across
        if (c < cost) { cost = c; best = spot }
    }
    return best.name
}

const line = { kind: "separator" }
const row = (action, text, extra) => Object.assign({ kind: "item", action, text, enabled: true }, extra ?? {})

export function desktopMenu(state) {
    const rows = [
        row("submenu", "View", { submenu: "view", more: true, glyph: glyph("grid") }),
        row("submenu", "Sort by", { submenu: "sort", more: true, glyph: glyph("sort") }),
        row("refresh", "Refresh", { glyph: glyph("refresh") }),
        line,
        row("submenu", "New", { submenu: "new", more: true, glyph: glyph("add") }),
        line,
        ...(state.settings === false ? [] : [
            row("display", "Display settings", { glyph: glyph("display") }),
            row("personalize", "Personalize", { glyph: glyph("personalize") }),
            line,
        ]),
        row("terminal", "Open in Terminal", { glyph: glyph("console") }),
    ]
    return state.paste ? [{ kind: "buttons", buttons: [{ action: "paste", text: "Paste", glyph: glyph("paste"), enabled: true }] }, ...rows] : rows
}

export const sizes = { large: 96, medium: 48, small: 32 }

export function viewMenu(s) {
    const size = (icon, text, accel, glyph) => row(`size:${icon}`, text, { accel, glyph, mark: "bullet", checked: s.icon === icon })
    return [
        size(sizes.large, "Large icons", "Ctrl+Shift+2", glyph("square")),
        size(sizes.medium, "Medium icons", "Ctrl+Shift+3", glyph("display")),
        size(sizes.small, "Small icons", "Ctrl+Shift+4", glyph("grid")),
        line,
        row("auto", "Auto arrange icons", { glyph: glyph("selectAll"), mark: "check", checked: s.auto }),
        row("grid", "Align icons to grid", { glyph: glyph("gridDots"), mark: "check", checked: s.grid }),
        line,
        row("shown", "Show desktop icons", { glyph: glyph("eye"), mark: "check", checked: s.shown }),
    ]
}

export function sortMenu() {
    return [row("sort:name", "Name"), row("sort:size", "Size"), row("sort:type", "Item type"), row("sort:modified", "Date modified")]
}

export function newMenu() {
    return [
        row("new:folder", "Folder", { icon: "folder" }),
        line,
        row("new:bitmap", "Bitmap image", { icon: "image-bmp" }),
        row("new:text", "Text Document", { icon: "text-plain" }),
        row("new:zip", "Compressed (zipped) Folder", { icon: "application-zip" }),
    ]
}

// what one item offers, several items share what fits them all
export function itemMenu(items, pins) {
    const one = items.length === 1 ? items[0] : null
    const buttons = [["cut", "Cut", glyph("cut")], ["copy", "Copy", glyph("copy")], ["rename", "Rename", glyph("rename")], ["delete", "Delete", glyph("delete")]]
        .map(([action, text, glyph]) => ({ action, text, glyph, enabled: action !== "rename" || one !== null }))
    const rows = [{ kind: "buttons", buttons }, row("open", "Open", { accel: "Enter", glyph: glyph("open") })]
    if (one?.link) rows.push(row("location", "Open file location", { glyph: glyph("folder") }))
    if (one?.app) rows.push(pins.includes(one.app)
        ? row("unpin", "Unpin from Start", { glyph: glyph("unpin") })
        : row("pin", "Pin to Start", { glyph: glyph("pin") }))
    rows.push(row("zip", "Compress to ZIP file", { glyph: glyph("zip") }), row("path", "Copy as path", { accel: "Ctrl+Shift+C", glyph: glyph("link") }))
    if (one?.dir) rows.push(line, row("terminal", "Open in Terminal", { glyph: glyph("console") }))
    return rows
}

const types = {
    txt: ["text-plain"], md: ["text-markdown"], log: ["text-x-log"], html: ["text-html"], sh: ["application-x-shellscript"],
    png: ["image-png"], jpg: ["image-jpeg"], jpeg: ["image-jpeg"], bmp: ["image-bmp"], gif: ["image-gif"], webp: ["image-webp"], svg: ["image-svg+xml"],
    pdf: ["application-pdf"], zip: ["application-zip"], "7z": ["application-x-7z-compressed"], gz: ["application-gzip"], xz: ["application-x-xz"],
    mp3: ["audio-mpeg"], flac: ["audio-flac"], ogg: ["audio-ogg"], wav: ["audio-x-wav"], mp4: ["video-mp4"], mkv: ["video-x-matroska"], webm: ["video-webm"],
}
const pictures = new Set(["png", "jpg", "jpeg", "bmp", "gif", "webp"])
const families = { image: "image-x-generic", audio: "audio-x-generic", video: "video-x-generic" }

function split(name) {
    const at = name.lastIndexOf(".")
    return at > 0 ? { stem: name.slice(0, at), ext: name.slice(at) } : { stem: name, ext: "" }
}

// a known type hides its ending, a shortcut shows the name inside it
export function look(item) {
    const { stem, ext } = split(item.name)
    if (!item.dir && ext.toLowerCase() === ".desktop") {
        const entry = item.entry ?? {}
        return { label: entry.name || stem, icons: [entry.icon, "application-x-executable"].filter(name => name), link: true, picture: false }
    }
    if (item.dir) return { label: item.name, icons: ["folder"], link: false, picture: false }
    const kind = ext.slice(1).toLowerCase()
    const known = types[kind]
    if (!known) return { label: item.name, icons: ["application-x-zerosize", "text-x-generic"], link: false, picture: false }
    const family = families[known[0].split("-")[0]] ?? "text-x-generic"
    return { label: stem, icons: [...known, family], link: false, picture: pictures.has(kind) }
}

const uri = path => "file://" + path.split("/").map(encodeURIComponent).join("/")
const quoted = path => `"${path}"`
const launch = (argv, dir) => ({ launch: true, argv, dir: dir ?? "" })
const run = (argv, dir, made, rename) => ({ launch: false, argv, dir: dir ?? "", made: made ?? "", rename: rename === true })

const news = {
    "new:folder": ["New folder", "", name => ["mkdir", "--", name]],
    "new:text": ["New Text Document", ".txt", name => ["touch", "--", name]],
    "new:bitmap": ["New Bitmap image", ".bmp", name => ["touch", "--", name]],
    "new:zip": ["New Compressed (zipped) Folder", ".zip", name => ["sh", "-c", `printf 'PK\\005\\006' > "$1" && head -c 18 /dev/zero >> "$1"`, "sh", name]],
}

function opener(item) {
    if (item.desktop && item.type === "Link" && item.url) return launch(["xdg-open", item.url])
    return launch(item.desktop ? ["gio", "launch", item.path] : ["xdg-open", item.path])
}

const plans = {
    open: (items) => items.map(opener),
    terminal: (items, ctx) => {
        if (!ctx.terminal) throw new Error("refused: no terminal")
        return [launch([ctx.terminal], items[0]?.dir ? items[0].path : ctx.dir)]
    },
    delete: items => [run(["gio", "trash", "--", ...items.map(item => item.path)])],
    // info-zip takes no -- so every name starts with ./
    zip: (items, ctx) => {
        const base = items[0].dir ? items[0].name : split(items[0].name).stem
        const made = fresh(base, ".zip", ctx.taken)
        return [run(["zip", "-r", "-q", `./${made}`, ...items.map(item => `./${item.name}`)], ctx.dir, made, true)]
    },
    path: items => [run(["wl-copy", "--", items.map(item => quoted(item.path)).join("\n")])],
    copy: items => [run(["wl-copy", "--type", "text/uri-list", "--", items.map(item => uri(item.path)).join("\r\n")])],
    cut: items => [run(["wl-copy", "--type", "text/uri-list", "--", items.map(item => uri(item.path)).join("\r\n")])],
    location: items => {
        const item = items[0]
        if (!item.target) throw new Error(`refused: ${item.name} points nowhere`)
        if (item.target.includes("'")) throw new Error(`refused: a quote in ${item.target}`)
        return [run(["gdbus", "call", "--session", "--dest", "org.freedesktop.FileManager1", "--object-path", "/org/freedesktop/FileManager1",
            "--method", "org.freedesktop.FileManager1.ShowItems", `['${uri(item.target)}']`, ""])]
    },
    display: () => [launch(["systemsettings", "kcm_kscreen"])],
    personalize: () => [launch(["systemsettings", "kcm_colors"])],
}

const needItems = new Set(["open", "delete", "zip", "path", "copy", "cut", "location"])

function into(folder, items, ctx) {
    if (!folder) throw new Error("refused: no folder to move into")
    if (folder.includes("/") || folder === "." || folder === "..") throw new Error(`refused: ${JSON.stringify(folder)} is not a folder here`)
    if (items.some(item => item.name === folder)) throw new Error(`refused: ${folder} cannot go into itself`)
    return [run(["mv", "-n", "-t", `${ctx.dir}/${folder}`, "--", ...items.map(item => item.path)])]
}

export function plan(action, items, ctx) {
    if (action.startsWith("into:")) {
        if (!items.length) throw new Error("refused: nothing chosen for into")
        return into(action.slice(5), items, ctx)
    }
    if (news[action]) {
        const [base, ext, argv] = news[action]
        const made = fresh(base, ext, ctx.taken)
        return [run(argv(`${ctx.dir}/${made}`), "", made, true)]
    }
    if (!Object.prototype.hasOwnProperty.call(plans, action)) throw new Error(`refused: unknown desktop action ${JSON.stringify(action)}`)
    if (needItems.has(action) && !items.length) throw new Error(`refused: nothing chosen for ${action}`)
    return plans[action](items, ctx)
}

// a copy onto the desktop it came from gets the explorer's copy name
export function paste(uris, cut, ctx) {
    const taken = [...ctx.taken]
    const out = []
    for (const text of uris) {
        if (!text.startsWith("file://")) continue
        const source = decodeURIComponent(text.slice("file://".length))
        const at = source.lastIndexOf("/")
        const name = source.slice(at + 1), home = source.slice(0, at)
        if (home === ctx.dir && cut) continue
        let made = name
        if (home === ctx.dir || taken.includes(name)) {
            const { stem, ext } = split(name)
            made = fresh(`${stem} - Copy`, ext, taken)
        }
        taken.push(made)
        out.push(run(cut ? ["mv", "-n", "--", source, `${ctx.dir}/${made}`] : ["cp", "-a", "--", source, `${ctx.dir}/${made}`], "", made))
    }
    return out
}

export function renameCheck(from, to, taken) {
    if (!to.trim()) return "refused: a name cannot be empty"
    if (to.includes("/")) return "refused: a name cannot hold /"
    if (to === "." || to === "..") return `refused: ${JSON.stringify(to)} is not a name`
    if (to === from) return "same"
    if (taken.includes(to)) return `refused: ${to} is there already`
    return ""
}

// the new name wins over every translated one
export function renamed(text, name) {
    const lines = text.split("\n")
    const header = lines.indexOf("[Desktop Entry]")
    if (header < 0) throw new Error("refused: no desktop entry to rename")
    const end = lines.findIndex((line, i) => i > header && line.startsWith("["))
    const stop = end < 0 ? lines.length : end
    const body = lines.slice(header + 1, stop).filter(line => !/^Name(\[|=)/.test(line))
    return [...lines.slice(0, header + 1), `Name=${name}`, ...body, ...lines.slice(stop)].join("\n")
}

const steps = [16, 20, 24, 28, 32, 40, 48, 56, 64, 72, 80, 96, 112, 128, 160, 192, 224, 256]

export function resize(icon, dir) {
    if (dir > 0) return steps.find(size => size > icon) ?? steps[steps.length - 1]
    return [...steps].reverse().find(size => size < icon) ?? steps[0]
}

// a new size keeps each icon in its row and column
export function rescale(places, from, to) {
    const out = {}
    for (const name of Object.keys(places)) {
        const at = places[name]
        out[name] = {
            x: to.originX + (at.x - from.originX) * to.pitchX / from.pitchX,
            y: to.originY + (at.y - from.originY) * to.pitchY / from.pitchY,
        }
    }
    return out
}

export function settle(order, names) {
    const here = new Set(names)
    const kept = order.filter(name => here.has(name))
    const known = new Set(kept)
    return [...kept, ...names.filter(name => !known.has(name))]
}

const isPlace = at => at && typeof at.x === "number" && typeof at.y === "number"

export function restore(text) {
    if (!text) return null
    let value = null
    try { value = JSON.parse(text) } catch (e) { value = null }
    const bad = () => { throw new Error("refused: desktop state is not valid") }
    if (!value || typeof value !== "object" || Array.isArray(value)) bad()
    if (!Number.isInteger(value.icon) || value.icon < 16 || value.icon > 256) bad()
    const places = value.places ?? {}
    if (typeof places !== "object" || Array.isArray(places) || !Object.keys(places).every(name => isPlace(places[name]))) bad()
    const order = value.order ?? []
    if (!Array.isArray(order) || !order.every(name => typeof name === "string")) bad()
    const flag = (v, d) => typeof v === "boolean" ? v : d
    return { icon: value.icon, auto: flag(value.auto, false), grid: flag(value.grid, true), shown: flag(value.shown, true), places, order }
}
