// hyprland sends a press, a press and a release, or only a release for a click bind
export function edge(held, name, pressed) {
    const next = Object.assign({}, held, { [name]: pressed })
    return { held: next, fire: pressed || !held[name] }
}
