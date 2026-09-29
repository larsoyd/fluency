import QtQuick
import "../logic/tasks.mjs" as Tasks

// one row per key, a row lives as long as its key is among the items
ListModel {
    id: root

    property var items: []
    property var byKey: ({})

    onItemsChanged: {
        const have = []
        for (let i = 0; i < count; i++) have.push(get(i).key)
        const steps = Tasks.sync(have, items.map(item => item.key))
        for (const step of steps) if (step.op === "remove") remove(step.at)
        const found = {}
        for (const item of items) found[item.key] = item
        byKey = found
        for (const step of steps) {
            if (step.op === "insert") insert(step.at, { key: step.key })
            if (step.op === "move") move(step.from, step.to, 1)
        }
    }
}
