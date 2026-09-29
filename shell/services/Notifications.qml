pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.tokens
import "../logic/toast.mjs" as Toast

Singleton {
    property var toasts: []

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
        n.expire()
    }

    // apps wait on this name, without a server each notification blocked them for a minute
    NotificationServer {
        bodySupported: true
        actionsSupported: true
        keepOnReload: false
        onNotification: n => {
            n.tracked = true
            n.closed.connect(() => toasts = toasts.filter(t => t !== n))
            toasts = Toast.stack(toasts, n, Metrics.toastsShown)
            console.log(`[notify] got app="${n.appName}" summary="${n.summary}" expire=${n.expireTimeout} shown=${toasts.length}`)
        }
    }
}
