export const minimized = "special:minimized"

const quote = text => '"' + text.replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"'

function selector(win) {
    if (!/^0x[0-9a-f]+$/.test(win.address)) throw new Error(`refused: bad address ${JSON.stringify(win.address)}`)
    return quote("address:" + win.address)
}

// each monitor has its own, bound to it by the config, so a window stays where it was
export function place(monitor) {
    return `${minimized}-${monitor}`
}

export const hidden = win => win.workspace === minimized || win.workspace.startsWith(`${minimized}-`)

// quickshell drops a window that opens while it still reads hyprland's state, a refresh finds it again
export const unplaced = windows => windows.filter(win => !win.workspace || !win.monitor).map(win => win.address)

// back where it was minimized from, else to what its monitor shows
export function home(win, homes, shown) {
    const kept = homes[win.address]
    if (kept && !hidden({ workspace: kept })) return kept
    if (!shown[win.monitor]) throw new Error(`refused: no workspace shown on ${win.monitor} for ${win.address}`)
    return shown[win.monitor]
}

export function focus(win, workspace) {
    const window = selector(win), steps = [`hl.dsp.focus({ window = ${window} })`]
    if (!hidden(win)) return steps
    if (!workspace) throw new Error(`refused: no workspace to restore ${win.address} to`)
    return [`hl.dsp.window.move({ window = ${window}, workspace = ${quote(workspace)} })`, ...steps]
}

export function minimize(win) {
    if (!/^[A-Za-z0-9-]+$/.test(win.monitor ?? "")) throw new Error(`refused: no monitor to minimize ${win.address} on`)
    return [`hl.dsp.window.move({ window = ${selector(win)}, workspace = ${quote(place(win.monitor))}, follow = false })`]
}

// clears the shown workspaces, and with nothing left to clear it brings back what it took
export function desktop(windows, shown, cleared) {
    const open = windows.filter(win => shown.includes(win.workspace))
    const taken = open.map(win => ({ address: win.address, workspace: win.workspace, active: win.active === true }))
    if (open.length) return { lines: [].concat(...open.map(minimize)), cleared: [...cleared, ...taken] }
    const back = cleared.filter(entry => windows.some(win => win.address === entry.address && hidden(win)))
    const lines = back.map(entry => `hl.dsp.window.move({ window = ${selector(entry)}, workspace = ${quote(entry.workspace)}, follow = false })`)
    return { lines: lines.concat(...back.filter(entry => entry.active).map(entry => focus(entry))), cleared: [] }
}

export function close(win) {
    return [`hl.dsp.window.close({ window = ${selector(win)} })`]
}

const word = text => "'" + text.replace(/'/g, "'\\''") + "'"

// hyprland starts it, so the app gets the session's environment and outlives the shell
export function launch(command, dir) {
    if (!command.length || !command[0]) throw new Error("refused: empty command")
    if ([...command, dir].some(text => /[\x00-\x1f\x7f]/.test(text))) throw new Error("refused: control character in the command")
    const line = command.map(word).join(" ")
    return [`hl.dsp.exec_cmd(${quote(dir ? `cd ${word(dir)} && ${line}` : line)})`]
}

export const answerMs = 10000

// an app that already runs answers a launch by asking to be activated instead of opening a window
export function answered(launched, appId, now) {
    const at = launched[(appId ?? "").toLowerCase()]
    return at !== undefined && now >= at && now - at <= answerMs
}

// the class of an openwindow event, address,workspace,class,title
export const opened = data => data.split(",")[2] ?? ""

export function workspace(id) {
    if (!Number.isInteger(id) || id < 1) throw new Error(`refused: bad workspace ${JSON.stringify(id)}`)
    return [`hl.dsp.focus({ workspace = ${id} })`]
}
