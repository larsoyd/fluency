#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/config/lua/bindings/LuaBindingsInternal.hpp>
#include <hyprland/src/desktop/state/FadingOutState.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/desktop/state/WindowState.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/managers/eventLoop/EventLoopManager.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/state/MonitorState.hpp>

#include <algorithm>
#include <chrono>
#include <format>
#include <unordered_map>

#include "compat.hpp"
#include "ghost.hpp"

void makeLeaves();
void watchToast(const PHLWINDOW& w);
void forgetToast(Desktop::View::CWindow* w);
void dropToasts();
bool hookCapture(HANDLE handle);
void dropRefused();

// the config binds one of these to each monitor, the shell and the window keys use the same names
static const std::string PREFIX = "special:minimized";

using Clock = std::chrono::steady_clock;
using Desktop::View::IGeometric;

struct SFlight {
    int          id = 0;
    std::string  kind;
    PHLWINDOWREF window;
    SP<CGhost>   ghost;
    bool         hidden = false;
};

static std::unordered_map<Desktop::View::CWindow*, CHyprSignalListener> g_listeners;
static std::unordered_map<Desktop::View::CWindow*, PHLWORKSPACEREF>      g_last;
static std::unordered_map<uintptr_t, Vector2D>                           g_anchors;
static std::unordered_map<uintptr_t, Clock::time_point>                  g_still;
static std::vector<SFlight>                                              g_flights;
static std::vector<PHLWINDOWREF>                                         g_restores;
static int                                                               g_ids = 0;

static bool minimized(const PHLWORKSPACE& ws) {
    return ws && compat::workspaceName(ws).starts_with(PREFIX);
}

static uintptr_t address(const PHLWINDOW& w) {
    return rc<uintptr_t>(w.get());
}

static std::string text(const CBox& box) {
    return std::format("{:.0f},{:.0f},{:.0f},{:.0f}", box.x, box.y, box.w, box.h);
}

static CBox current(const PHLWINDOW& w) {
    return {w->position(IGeometric::GEOMETRIC_CURRENT), w->size(IGeometric::GEOMETRIC_CURRENT)};
}

// the shell tells where each button is, without one the window goes to the middle of the taskbar
static Vector2D anchorOf(const PHLWINDOW& w, const PHLMONITOR& monitor, std::string& source) {
    if (const auto it = g_anchors.find(address(w)); it != g_anchors.end()) {
        source = "shell";
        return it->second;
    }
    source = "fallback";
    return {monitor->m_position.x + monitor->m_size.x / 2, monitor->m_position.y + monitor->m_size.y - monitor->m_reservedArea.bottom() / 2};
}

static SFlight* flightOf(const PHLWINDOW& w) {
    const auto it = std::ranges::find_if(g_flights, [&w](const SFlight& f) { return f.window.lock() == w; });
    return it == g_flights.end() ? nullptr : &*it;
}

static void show(const SFlight& flight) {
    if (const auto w = flight.window.lock(); w && flight.hidden)
        compat::alpha(w, Desktop::View::WINDOW_ALPHA_MOVE_FROM_WORKSPACE)->setValueAndWarp(1.F);
}

static void skip(const PHLWINDOW& w, const char* kind, const char* reason) {
    LOG(Log::INFO, "[fluencyminimize] flight=skip id={} kind={} window={:x} reason={}", ++g_ids, kind, address(w), reason);
}

static bool still(const PHLWINDOW& w) {
    const auto it = g_still.find(address(w));
    if (it == g_still.end())
        return false;
    const bool fresh = Clock::now() - it->second < std::chrono::seconds(2);
    g_still.erase(it);
    return fresh;
}

static void fly(const char* kind, const PHLWINDOW& w, SP<CGhost> ghost, const CBox& to, bool hidden, const std::string& source, const Vector2D& anchor, const std::string& takeover) {
    Desktop::fadingOutState()->add(ghost);
    g_flights.push_back({++g_ids, kind, w, ghost, hidden});
    LOG(Log::INFO, "[fluencyminimize] flight={} id={} window={:x} from={} to={} anchor={:.0f},{:.0f} source={} takeover={}", kind, g_ids, address(w), text(ghost->now()),
        text(to), anchor.x, anchor.y, source, takeover.empty() ? "none" : takeover);
}

// the window already counts as moved, so for its picture it is put back on the workspace it left for a moment
static void minimizeFlight(const PHLWINDOW& w, const PHLWORKSPACE& old) {
    const auto monitor = w->m_monitor.lock();
    if (!monitor)
        return;
    if (w->m_ruleApplicator->noAnim().valueOrDefault())
        return skip(w, "minimize", "no_anim");

    SP<Render::IFramebuffer> picture;
    CBox                     window = current(w), from = window;
    std::string              takeover;
    if (const auto prev = flightOf(w)) {
        picture = prev->ghost->picture(), window = prev->ghost->window(), from = prev->ghost->now(), takeover = prev->kind;
        show(*prev);
        prev->ghost->stop();
        std::erase_if(g_flights, [prev](const SFlight& f) { return &f == prev; });
    } else {
        const auto now = w->m_workspace;
        w->m_workspace = old;
        picture        = g_pHyprRenderer->makeSnapshotFB(w);
        w->m_workspace = now;
    }
    if (!picture)
        return skip(w, "minimize", "no_snapshot");

    std::string source;
    const auto  anchor = anchorOf(w, monitor, source);
    compat::alpha(w, Desktop::View::WINDOW_ALPHA_MOVE_TO_WORKSPACE)->setValueAndWarp(0.F);
    const CBox to = {anchor, {0, 0}};
    fly("minimize", w, CGhost::create(monitor, picture, window, from, to, "fluencyMinimize"), to, false, source, anchor, takeover);
}

// runs before the first frame after the move, when the layout has placed the window and its fade in has begun
static void restoreFlight(const PHLWINDOW& w, const PHLMONITOR& monitor) {
    const auto ws = w->m_workspace;
    if (!ws || !compat::visible(ws))
        return skip(w, "restore", "hidden_workspace");
    if (ws->m_renderOffset->isBeingAnimated())
        return skip(w, "restore", "workspace_switch");
    if (w->m_ruleApplicator->noAnim().valueOrDefault())
        return skip(w, "restore", "no_anim");
    if (still(w))
        return skip(w, "restore", "still");

    auto& fade = compat::alpha(w, Desktop::View::WINDOW_ALPHA_MOVE_FROM_WORKSPACE);
    fade->setValueAndWarp(1.F);
    w->positionAnimation()->warp();
    w->sizeAnimation()->warp();
    const auto picture = g_pHyprRenderer->makeSnapshotFB(w);
    if (!picture)
        return skip(w, "restore", "no_snapshot");
    fade->setValueAndWarp(0.F);

    std::string source;
    const auto  anchor = anchorOf(w, monitor, source);
    const auto  box    = current(w);
    CBox        from   = {anchor, {0, 0}};
    std::string takeover;
    if (const auto prev = flightOf(w)) {
        const double s = prev->ghost->scale();
        from = {anchor + (box.pos() - anchor) * s, box.size() * s}, takeover = prev->kind;
        prev->ghost->stop();
        std::erase_if(g_flights, [prev](const SFlight& f) { return &f == prev; });
    }
    fly("restore", w, CGhost::create(monitor, picture, box, from, box, "fluencyRestore"), box, true, source, anchor, takeover);
}

// the window keeps drawing under its restore, a video goes on playing in the picture
static void repaint(const PHLMONITOR& monitor) {
    for (auto& flight : g_flights) {
        const auto w = flight.window.lock();
        if (!w || !flight.hidden || flight.ghost->monitor() != monitor || flight.ghost->done())
            continue;
        auto& fade = compat::alpha(w, Desktop::View::WINDOW_ALPHA_MOVE_FROM_WORKSPACE);
        fade->setValueAndWarp(1.F);
        const auto picture = g_pHyprRenderer->makeSnapshotFB(w);
        fade->setValueAndWarp(0.F);
        if (picture)
            flight.ghost->repaint(picture);
    }
}

static void onPreChecks(PHLMONITOR monitor) {
    repaint(monitor);
    std::erase_if(g_restores, [&monitor](const PHLWINDOWREF& ref) {
        const auto w = ref.lock();
        if (!w || !w->m_monitor)
            return true;
        if (w->m_monitor != monitor)
            return false;
        restoreFlight(w, monitor);
        return true;
    });
}

static void onRender(PHLMONITOR monitor) {
    for (auto& flight : g_flights)
        if (flight.ghost->monitor() == monitor && !flight.ghost->done())
            flight.ghost->m_frames++;
}

// the window shows in the frame its picture lands
static void onTick() {
    std::erase_if(g_flights, [](const SFlight& flight) {
        if (!flight.ghost->done())
            return false;
        show(flight);
        const auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(Clock::now() - flight.ghost->m_start).count();
        LOG(Log::INFO, "[fluencyminimize] flight=end id={} kind={} window={:x} frames={} ms={}", flight.id, flight.kind, rc<uintptr_t>(flight.window.get()), flight.ghost->m_frames, ms);
        return true;
    });
}

// hyprland reads fullscreen and maximize from a state change and drops minimize
static void onMinimize(PHLWINDOW w) {
    const auto monitor = w->m_monitor.lock();
    if (!compat::mapped(w) || !monitor || minimized(w->m_workspace))
        return;

    const auto call = std::format("hl.dsp.window.move({{ window = \"address:0x{:x}\", workspace = \"{}-{}\", follow = false }})", address(w), PREFIX, monitor->m_name);
    const auto out  = HyprlandAPI::invokeHyprctlCommand("dispatch", call);
    LOG(Log::INFO, "[fluencyminimize] asked=minimize window={:x} monitor={} result={}", address(w), monitor->m_name, out);
}

static void watch(const PHLWINDOW& w) {
    if (auto listener = compat::onMinimizeRequest(w, onMinimize))
        g_listeners[w.get()] = std::move(listener);
}

// with nothing left where it was, hyprland keeps the focus on the hidden window and it gets the keys
static void clearFocus(const PHLWINDOW& w) {
    g_pEventLoopManager->doLater([weak = PHLWINDOWREF{w}] {
        const auto w = weak.lock();
        if (!w || !minimized(w->m_workspace) || Desktop::focusState()->window() != w)
            return;
        Desktop::focusState()->rawWindowFocus(nullptr, Desktop::FOCUS_REASON_OTHER);
        LOG(Log::INFO, "[fluencyminimize] focus=cleared window={:x}", address(w));
    });
}

static void onMoved(PHLWINDOW w, PHLWORKSPACE ws) {
    const auto old  = g_last[w.get()].lock();
    g_last[w.get()] = ws;
    if (minimized(ws)) {
        if (old && !minimized(old) && compat::visible(old))
            minimizeFlight(w, old);
        clearFocus(w);
    } else if (old && minimized(old))
        g_restores.emplace_back(w);
}

static uintptr_t parseAddress(lua_State* L, int index) {
    const char* raw = lua_tostring(L, index);
    try {
        return raw ? std::stoull(raw, nullptr, 16) : 0;
    } catch (...) { return 0; }
}

// hl.plugin.fluencyminimize.anchors({ ["0x..."] = { x, y } }) replaces every anchor
static int luaAnchors(lua_State* L) {
    if (!lua_istable(L, 1))
        return Config::Lua::Bindings::Internal::configError(L, "anchors: expected a table { [\"0x...\"] = { x, y } }");
    std::unordered_map<uintptr_t, Vector2D> anchors;
    lua_pushnil(L);
    while (lua_next(L, 1)) {
        const auto key = parseAddress(L, -2);
        if (!key || !lua_istable(L, -1)) {
            lua_pop(L, 2);
            return Config::Lua::Bindings::Internal::configError(L, "anchors: each entry is \"0x...\" = { x, y }");
        }
        lua_rawgeti(L, -1, 1);
        lua_rawgeti(L, -2, 2);
        anchors[key] = {lua_tonumber(L, -2), lua_tonumber(L, -1)};
        lua_pop(L, 3);
    }
    g_anchors = std::move(anchors);
    return 0;
}

// hl.plugin.fluencyminimize.still("0x...") lets the next restore of that window go without a flight
static int luaStill(lua_State* L) {
    const auto key = parseAddress(L, 1);
    if (!key)
        return Config::Lua::Bindings::Internal::configError(L, "still: expected a window address \"0x...\"");
    g_still[key] = Clock::now();
    return 0;
}

APICALL EXPORT std::string PLUGIN_API_VERSION() {
    return HYPRLAND_API_VERSION;
}

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    if (__hyprland_api_get_hash() != std::string{__hyprland_api_get_client_hash()}) {
        HyprlandAPI::addNotification(handle, "[fluencyminimize] refused: built for another hyprland", CHyprColor{1.0, 0.2, 0.2, 1.0}, 5000);
        throw std::runtime_error("[fluencyminimize] refused: version mismatch");
    }

    if (!hookCapture(handle))
        HyprlandAPI::addNotification(handle, "[fluencyminimize] refused: no capture function to guard", CHyprColor{1.0, 0.2, 0.2, 1.0}, 5000);
    makeLeaves();
    HyprlandAPI::addLuaFunction(handle, "fluencyminimize", "anchors", luaAnchors);
    HyprlandAPI::addLuaFunction(handle, "fluencyminimize", "still", luaStill);

    static auto opened    = Event::bus()->m_events.window.openEarly.listen([](PHLWINDOW w) { watch(w); });
    static auto mapped    = Event::bus()->m_events.window.open.listen([](PHLWINDOW w) {
        g_last[w.get()] = w->m_workspace;
        watchToast(w);
    });
    static auto destroyed = Event::bus()->m_events.window.destroy.listen([](PHLWINDOWREF w) {
        g_listeners.erase(w.get());
        g_last.erase(w.get());
        forgetToast(w.get());
    });
    static auto moved     = Event::bus()->m_events.window.moveToWorkspace.listen(onMoved);
    static auto checks    = Event::bus()->m_events.render.preChecks.listen(onPreChecks);
    static auto render    = Event::bus()->m_events.render.pre.listen(onRender);
    static auto tick      = Event::bus()->m_events.tick.listen(onTick);
    for (const auto& w : Desktop::windowState()->windows())
        if (compat::mapped(w)) {
            watch(w);
            watchToast(w);
            g_last[w.get()] = w->m_workspace;
        }

    return {"fluencyminimize", "minimize on a client's request, fly windows to and from the taskbar, let go of the focus of a minimized window, put steam's toasts where fluency's show, answer a capture of a closed window with a failed frame", "larsoyd", "0.4"};
}

// the pictures live in hyprland's list but their code lives here
APICALL EXPORT void PLUGIN_EXIT() {
    for (auto& flight : g_flights) {
        show(flight);
        flight.ghost->stop();
    }
    g_flights.clear();
    for (const auto& monitor : State::monitorState()->monitors())
        Desktop::fadingOutState()->cleanupForMonitor(monitor);
    g_restores.clear();
    g_listeners.clear();
    dropToasts();
    dropRefused();
}
