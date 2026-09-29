// dbusmenu marks the access key with one underscore and writes a real one as two
export function label(text) {
    return text.replace(/__|_/g, found => found === "__" ? "_" : "")
}

export function rows(entries) {
    return entries.map(e => e.isSeparator ? { kind: "separator" } : {
        kind: "item",
        text: label(e.text),
        enabled: e.enabled,
        checked: e.checkState === 2,
        check: e.buttonType !== 0,
        more: e.hasChildren,
    })
}

export function height(list, m) {
    const item = 2 * m.menuItemMarginY + m.menuItemPaddingTop + m.menuLine + m.menuItemPaddingBottom
    const line = 2 * m.menuSeparatorMarginY + m.menuSeparator
    return 2 * (m.flyoutBorder + m.menuPaddingY) + list.reduce((sum, row) => sum + (row.kind === "separator" ? line : item), 0)
}
