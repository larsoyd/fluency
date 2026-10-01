pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.tokens
import "../logic/notify.mjs" as Notify
import "../logic/toast.mjs" as Toast

Singleton {
    id: root

    property var toasts: []
    property var history: []
    property bool dnd: false
    property bool centerOpen: false

    function activate(n: var): void {
        const action = n.actions.find(a => a.identifier === "default")
        console.log(`[notify] action=activate app="${n.appName}" default=${!!action}`)
        if (action) action.invoke()
        else n.dismiss()
    }

    function dismiss(n: var): void {
        console.log(`[notify] action=dismiss app="${n.appName}"`)
        n.dismiss()
    }

    function expire(n: var): void {
        if (Notify.timeout(n.expireTimeout) === "expire") n.expire()
        else toasts = toasts.filter(t => t !== n)
    }

    function clear(): void {
        console.log(`[notify] action=clear count=${history.length}`)
        for (const n of history.slice()) n.dismiss()
    }

    function clearApp(app: string): void {
        const gone = history.filter(n => (n.appName || "Other") === app)
        console.log(`[notify] action=clear app="${app}" count=${gone.length}`)
        for (const n of gone) n.dismiss()
    }

    function setDnd(on: bool): void {
        dnd = on
        saved.setText(JSON.stringify({ dnd }))
        console.log(`[notify] action=dnd on=${on}`)
    }

    onCenterOpenChanged: if (centerOpen) toasts = []

    FileView {
        id: saved
        path: Quickshell.statePath("notifications.json")
        blockLoading: true
        printErrors: false
        Component.onCompleted: {
            try {
                root.dnd = JSON.parse(text() || "{}").dnd === true
            } catch (e) {
                console.warn(`[notify] action=load path=${path} result="${e.message}"`)
            }
        }
    }

    // apps wait on this name, without a server each notification blocked them for a minute
    NotificationServer {
        bodySupported: true
        actionsSupported: true
        keepOnReload: false
        onNotification: n => {
            n.tracked = true
            n.closed.connect(() => {
                toasts = toasts.filter(t => t !== n)
                history = Notify.remove(history, n)
            })
            history = Notify.add(history, n, Metrics.notifyKept)
            if (!dnd && !centerOpen) toasts = Toast.stack(toasts, n, Metrics.toastsShown)
            console.log(`[notify] got app="${n.appName}" summary="${n.summary}" expire=${n.expireTimeout} shown=${toasts.length} kept=${history.length} dnd=${dnd}`)
        }
    }
}
