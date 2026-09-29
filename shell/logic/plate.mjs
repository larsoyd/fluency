const strokes = {
    none: ["itemFillTransparent", "itemFillTransparent"],
    secondary: ["itemStrokeSecondaryTop", "itemStrokeSecondaryBottom"],
    primary: ["itemStrokePrimaryTop", "itemStrokePrimaryBottom"],
    quinary: ["itemStrokeQuinary", "itemStrokeQuinary"],
    trayPrimary: ["trayStrokePrimaryTop", "trayStrokePrimaryBottom"],
}

const table = {
    InactiveNormal: ["itemFillTransparent", "none"],
    InactivePointerOver: ["itemFillSecondary", "secondary"],
    InactivePressed: ["itemFillTertiary", "quinary"],
    ActiveNormal: ["itemFillSecondary", "primary"],
    ActivePointerOver: ["itemFillPrimary", "secondary"],
    ActivePressed: ["itemFillTertiary", "quinary"],
    RequestingAttention: ["attentionFill", "fill"],
    RequestingAttentionPointerOver: ["attentionFillHover", "fill"],
    RequestingAttentionPressed: ["attentionFillPressed", "fill"],
    MultiWindowNormal: ["itemFillTransparent", "none"],
    MultiWindowActive: ["itemFillSecondary", "primary"],
    MultiWindowPointerOver: ["itemFillPrimary", "secondary"],
    MultiWindowPressed: ["itemFillTertiary", "quinary"],
    RequestingAttentionMulti: ["attentionFill", "fill"],
    RequestingAttentionMultiPointerOver: ["attentionFillHover", "fill"],
    RequestingAttentionMultiPressed: ["attentionFillPressed", "fill"],
    TrayNormal: ["itemFillTransparent", "none", "textPrimary"],
    TrayPointerOver: ["itemFillSecondary", "secondary", "textPrimary"],
    TrayPressed: ["itemFillTertiary", "secondary", "textSecondary"],
    TrayChecked: ["itemFillSecondary", "secondary", "textPrimary"],
    TrayCheckedPointerOver: ["itemFillPrimary", "trayPrimary", "textPrimary"],
    TrayCheckedPressed: ["itemFillTertiary", "quinary", "textSecondary"],
}

export function state({ active = false, hovered = false, pressed = false, attention = false, multi = false, tray = false, checked = false }) {
    const pointer = pressed ? "Pressed" : hovered ? "PointerOver" : "Normal"
    if (tray) return "Tray" + (checked ? "Checked" + (pointer === "Normal" ? "" : pointer) : pointer)
    if (attention) return "RequestingAttention" + (multi ? "Multi" : "") + (pointer === "Normal" ? "" : pointer)
    if (multi) return "MultiWindow" + (pointer === "Normal" && active ? "Active" : pointer)
    return (active ? "Active" : "Inactive") + pointer
}

export function tokens(name) {
    const row = table[name]
    if (!row) throw new Error(`unknown plate state ${name}`)
    const [fill, stroke, text] = row
    const [strokeTop, strokeBottom] = strokes[stroke] ?? [fill, fill]
    return text ? { fill, strokeTop, strokeBottom, text } : { fill, strokeTop, strokeBottom }
}

export function look(name, colors) {
    const out = {}
    for (const [part, token] of Object.entries(tokens(name))) {
        if (colors[token] === undefined) throw new Error(`no colour ${token} for ${name}`)
        out[part] = colors[token]
    }
    return out
}
