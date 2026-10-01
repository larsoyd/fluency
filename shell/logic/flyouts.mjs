// the taskbar shows one flyout at a time, asking for the open one closes it
export function toggle(states, name) {
    if (!(name in states)) throw new Error(`refused: unknown flyout ${name}`)
    const out = {}
    for (const key of Object.keys(states)) out[key] = key === name && !states[key]
    return out
}

export function shown(states) {
    return Object.keys(states).find(key => states[key]) ?? ""
}
