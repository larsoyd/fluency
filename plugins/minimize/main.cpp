#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/desktop/state/WindowState.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/managers/eventLoop/EventLoopManager.hpp>
#include <hyprland/src/output/Monitor.hpp>

#include <format>
#include <unordered_map>

#include "compat.hpp"

// the config binds one of these to each monitor, the shell and the window keys use the same names
static const std::string PREFIX = "special:minimized";

static std::unordered_map<Desktop::View::CWindow*, CHyprSignalListener> g_listeners;

static bool minimized(const PHLWORKSPACE& ws) {
    return ws && compat::workspaceName(ws).starts_with(PREFIX);
}

// hyprland reads fullscreen and maximize from a state change and drops minimize
static void onMinimize(PHLWINDOW w) {
    const auto monitor = w->m_monitor.lock();
    if (!compat::mapped(w) || !monitor || minimized(w->m_workspace))
        return;

    const auto call = std::format("hl.dsp.window.move({{ window = \"address:0x{:x}\", workspace = \"{}-{}\", follow = false }})", rc<uintptr_t>(w.get()), PREFIX, monitor->m_name);
    const auto out  = HyprlandAPI::invokeHyprctlCommand("dispatch", call);
    LOG(Log::INFO, "[fluencyminimize] asked=minimize window={:x} monitor={} result={}", rc<uintptr_t>(w.get()), monitor->m_name, out);
}

static void watch(const PHLWINDOW& w) {
    if (auto listener = compat::onMinimizeRequest(w, onMinimize))
        g_listeners[w.get()] = std::move(listener);
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
        LOG(Log::INFO, "[fluencyminimize] focus=cleared window={:x}", rc<uintptr_t>(w.get()));
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
        if (compat::mapped(w))
            watch(w);

    return {"fluencyminimize", "minimize on a client's request and let go of the focus of a minimized window", "larsoyd", "0.2"};
}

APICALL EXPORT void PLUGIN_EXIT() {
    g_listeners.clear();
}
