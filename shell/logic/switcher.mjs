import { hidden } from "./hypr.mjs"
import { byFocus } from "./taskview.mjs"

// every desktop on screen and every minimized window, the last used first
export function order(windows, shown) {
    return byFocus(windows.filter(win => shown.includes(win.workspace) || hidden(win)))
}

// alt tab goes back to the window used before this one
export function first(count) {
    return count > 1 ? 1 : count - 1
}

export function step(at, by, count) {
    return count ? (at + by + count) % count : -1
}
