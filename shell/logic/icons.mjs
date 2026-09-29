export function pick(names, has) {
    return names.find(name => name.startsWith("/") || (name !== "" && has(name))) ?? ""
}

export function source(name) {
    if (name === "") return ""
    return (name.startsWith("/") ? "file://" : "image://icon/") + name
}
