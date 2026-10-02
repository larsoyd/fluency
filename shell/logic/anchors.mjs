import { groupX } from "./layout.mjs"

// the middle of each window's button on its own bar, from the layout not the slide
export function points(tasks, bar, screen) {
    const left = groupX(bar.width, (bar.system + tasks.length) * bar.extent, bar.tray)
    const y = screen.y + screen.height - bar.height / 2
    const out = {}
    tasks.forEach((task, at) => {
        const x = screen.x + left + (bar.system + at) * bar.extent + bar.extent / 2
        for (const win of task.windows) if (win.monitor === screen.name) out[win.address] = [x, y]
    })
    return out
}

// the plugin may not be loaded yet, it is told again when hyprland reloads its config after loading it
export function lua(points) {
    const rows = Object.keys(points).sort().map(address => {
        if (!/^0x[0-9a-f]+$/.test(address)) throw new Error(`refused: bad address ${JSON.stringify(address)}`)
        const [x, y] = points[address].map(Math.round)
        return `["${address}"] = { ${x}, ${y} }`
    })
    return `if hl.plugin.fluencyminimize then hl.plugin.fluencyminimize.anchors({ ${rows.join(", ")} }) end`
}
