import { launch } from "./hypr.mjs"
import { glyph } from "./glyphs.mjs"

const plans = {
    signout: () => ["hl.dsp.exit()"],
    sleep: () => launch(["systemctl", "suspend"]),
    shutdown: () => launch(["systemctl", "poweroff"]),
    restart: () => launch(["systemctl", "reboot"]),
}

export const actions = Object.keys(plans)

export const powerRows = [
    { action: "sleep", text: "Sleep", glyph: glyph("sleep") },
    { action: "shutdown", text: "Shut down", glyph: glyph("power") },
    { action: "restart", text: "Restart", glyph: glyph("restart") },
]

export const userRows = [{ action: "signout", text: "Sign out" }]

// a test shell inside a nested hyprland would switch off the real machine
export function plan(action, nested) {
    if (!Object.prototype.hasOwnProperty.call(plans, action)) throw new Error(`refused: unknown session action ${JSON.stringify(action)}`)
    if (nested) throw new Error(`refused: ${action} from a nested session`)
    return plans[action]()
}

export function displayName(passwdLine, user) {
    const full = (passwdLine.split(":")[4] ?? "").split(",")[0].trim()
    return full || user
}
