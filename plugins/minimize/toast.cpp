#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/config/ConfigValue.hpp>
#include <hyprland/src/helpers/MiscFunctions.hpp>
#include <hyprland/src/layout/target/Target.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/state/MonitorState.hpp>

#include <algorithm>
#include <cstdlib>
#include <unordered_map>
#include <unordered_set>

#include "compat.hpp"

// the gap fluent toasts keep from the screen edge and from the taskbar
static constexpr double GAP = 12;

static std::unordered_map<Desktop::View::CWindow*, CHyprSignalListener> g_toasts;
static std::unordered_set<Desktop::View::CWindow*>                      g_placed;

static bool steamToast(const PHLWINDOW& w) {
    const auto& t = compat::title(w);
    return compat::appID(w) == "steam" && t.starts_with("notificationtoasts_") && t.ends_with("_desktop");
}

// fluency's own toasts go to the screen of the full tray
static PHLMONITOR toastMonitor() {
    const auto& all = State::monitorState()->monitors();
    if (const char* name = std::getenv("FLUENCY_TRAY_SCREEN"))
        if (const auto it = std::ranges::find_if(all, [name](const auto& m) { return m->m_name == name; }); it != all.end())
            return *it;
    if (const auto it = std::ranges::find_if(all, [](const auto& m) { return m->m_position == Vector2D{}; }); it != all.end())
        return *it;
    return all.empty() ? nullptr : all.front();
}

static CBox x11Area(const PHLMONITOR& m, bool zeroScaling) {
    return {m->m_xwaylandPosition, zeroScaling ? m->m_transformedSize : m->m_size};
}

// steam aims at a corner of the x11 screen it picked, hyprland reads that against the wrong monitor
static void place(const PHLWINDOW& w) {
    static auto PZERO = CConfigValue<Config::INTEGER>("xwayland:force_zero_scaling");
    const auto  to    = toastMonitor();
    const auto  x11   = compat::x11Box(w);
    if (!to || x11.w < 2 || x11.h < 2)
        return;

    PHLMONITOR from;
    double     best = __FLT_MAX__;
    for (const auto& m : State::monitorState()->monitors()) {
        const auto area = x11Area(m, *PZERO);
        const auto d    = vecToRectDistanceSquared(x11.middle(), area.pos(), area.pos() + area.size() - Vector2D{1, 1});
        if (d < best)
            best = d, from = m;
    }
    const double scale = *PZERO ? from->m_scale : 1.0;
    const auto   area  = x11Area(from, *PZERO);
    // how far past the corner steam holds it, the slide in and out lives here
    const auto past   = (x11.pos() + x11.size() - area.pos() - area.size()) / scale;
    const auto size   = x11.size() / scale;
    const auto corner = to->m_position + to->m_size - Vector2D{to->m_reservedArea.right(), to->m_reservedArea.bottom()};
    const auto pos    = corner - size - Vector2D{GAP, GAP} + Vector2D{std::max(0.0, past.x - GAP), std::max(0.0, past.y - GAP)};

    g_pHyprRenderer->damageWindow(w);
    w->layoutTarget()->setPositionGlobal(CBox{pos, size}, Layout::TARGET_UPDATE_NO_CLIENT_CONFIGURE);
    w->layoutTarget()->warpPositionSize();
    w->m_workspace = to->m_activeWorkspace;
    g_pHyprRenderer->damageWindow(w);
    if (g_placed.insert(w.get()).second)
        LOG(Log::INFO, "[fluencyminimize] toast=steam window={:x} steam_monitor={} monitor={} rest={:.0f},{:.0f}", rc<uintptr_t>(w.get()), from->m_name, to->m_name,
            corner.x - size.x - GAP, corner.y - size.y - GAP);
}

// placed at map hyprland would tell x11 the new spot, steam maps it under the screen anyway
void watchToast(const PHLWINDOW& w) {
    if (!compat::overrideRedirect(w) || compat::appID(w) != "steam")
        return;
    g_toasts[w.get()] = compat::onX11Geometry(w, [weak = PHLWINDOWREF{w}] {
        if (const auto w = weak.lock(); w && steamToast(w))
            place(w);
    });
}

void forgetToast(Desktop::View::CWindow* w) {
    g_toasts.erase(w);
    g_placed.erase(w);
}

void dropToasts() {
    g_toasts.clear();
    g_placed.clear();
}
