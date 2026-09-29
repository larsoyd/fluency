#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/desktop/Workspace.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/desktop/state/WindowState.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/managers/eventLoop/EventLoopManager.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/protocols/XDGShell.hpp>
#include <hyprland/src/xwayland/XSurface.hpp>

#include <format>
#include <unordered_map>

// the config binds one of these to each monitor, the shell and the window keys use the same names
static const std::string PREFIX = "special:minimized";

static std::unordered_map<Desktop::View::CWindow*, CHyprSignalListener> g_listeners;

static bool minimized(const PHLWORKSPACE& ws) {
    return ws && ws->m_name.starts_with(PREFIX);
}

static std::optional<bool> asked(const PHLWINDOW& w) {
    if (const auto xdg = w->m_xdgSurface.lock(); xdg && xdg->m_toplevel)
        return xdg->m_toplevel->m_state.requestsMinimize;
    if (const auto x11 = w->m_xwaylandSurface.lock())
        return x11->m_state.requestsMinimize;
    return std::nullopt;
}

// hyprland reads fullscreen and maximize from a state change and drops minimize
static void onStateChanged(const PHLWINDOW& w) {
    const auto monitor = w->m_monitor.lock();
    if (!asked(w).value_or(false) || !w->m_isMapped || !monitor || minimized(w->m_workspace))
        return;

    const auto call = std::format("hl.dsp.window.move({{ window = \"address:0x{:x}\", workspace = \"{}-{}\", follow = false }})", rc<uintptr_t>(w.get()), PREFIX, monitor->m_name);
    const auto out  = HyprlandAPI::invokeHyprctlCommand("dispatch", call);
    Log::logger->log(Log::INFO, "[fluencyminimize] asked=minimize window={:x} monitor={} result={}", rc<uintptr_t>(w.get()), monitor->m_name, out);
}

static void watch(const PHLWINDOW& w) {
    auto handler = [weak = PHLWINDOWREF{w}] {
        if (const auto w = weak.lock())
            onStateChanged(w);
    };
    if (const auto xdg = w->m_xdgSurface.lock(); xdg && xdg->m_toplevel)
        g_listeners[w.get()] = xdg->m_toplevel->m_events.stateChanged.listen(handler);
    else if (const auto x11 = w->m_xwaylandSurface.lock())
        g_listeners[w.get()] = x11->m_events.stateChanged.listen(handler);
}

// with nothing left where it was, hyprland keeps the focus on the hidden window and it gets the keys
static void onMoved(PHLWINDOW w, PHLWORKSPACE ws) {
    if (!minimized(ws))
        return;
    g_pEventLoopManager->doLater([weak = PHLWINDOWREF{w}] {
        const auto w = weak.lock();
        if (!w || !minimized(w->m_workspace) || Desktop::focusState()->window() != w)
            return;
        Desktop::focusState()->rawWindowFocus(nullptr, Desktop::FOCUS_REASON_OTHER);
        Log::logger->log(Log::INFO, "[fluencyminimize] focus=cleared window={:x}", rc<uintptr_t>(w.get()));
    });
}

APICALL EXPORT std::string PLUGIN_API_VERSION() {
    return HYPRLAND_API_VERSION;
}

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    if (__hyprland_api_get_hash() != std::string{__hyprland_api_get_client_hash()}) {
        HyprlandAPI::addNotification(handle, "[fluencyminimize] refused: built for another hyprland", CHyprColor{1.0, 0.2, 0.2, 1.0}, 5000);
        throw std::runtime_error("[fluencyminimize] refused: version mismatch");
    }

    static auto opened    = Event::bus()->m_events.window.openEarly.listen([](PHLWINDOW w) { watch(w); });
    static auto destroyed = Event::bus()->m_events.window.destroy.listen([](PHLWINDOWREF w) { g_listeners.erase(w.get()); });
    static auto moved     = Event::bus()->m_events.window.moveToWorkspace.listen(onMoved);
    for (const auto& w : Desktop::windowState()->windows())
        if (w->m_isMapped)
            watch(w);

    return {"fluencyminimize", "minimize on a client's request and let go of the focus of a minimized window", "larsoyd", "0.2"};
}

APICALL EXPORT void PLUGIN_EXIT() {
    g_listeners.clear();
}
