#pragma once

#include <functional>

#if __has_include(<hyprland/src/desktop/view/window/WindowBackend.hpp>)
#include <hyprland/src/desktop/view/window/Window.hpp>
#include <hyprland/src/desktop/view/window/WindowBackend.hpp>
#include <hyprland/src/desktop/view/window/WindowPresentation.hpp>
#include <hyprland/src/workspace/HLWorkspace.hpp>

namespace compat {
    inline bool mapped(const PHLWINDOW& w) {
        return w->mapped();
    }
    inline const std::string& workspaceName(const PHLWORKSPACE& ws) {
        return ws->addressableName();
    }
    inline bool visible(const PHLWORKSPACE& ws) {
        return ws->visible();
    }
    inline PHLANIMVAR<float>& alpha(const PHLWINDOW& w, Desktop::View::eWindowAlpha which) {
        return w->presentation().alpha(which);
    }
    inline CHyprSignalListener onMinimizeRequest(const PHLWINDOW& w, std::function<void(PHLWINDOW)> fn) {
        return w->backend().m_events.stateRequest.listen([weak = PHLWINDOWREF{w}, fn](const Desktop::View::SBackendStateRequest& request) {
            if (const auto w = weak.lock(); w && request.minimized.value_or(false))
                fn(w);
        });
    }
}
#else
// TODO: temporary compat maintained for a few months after release then removed
#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/desktop/Workspace.hpp>
#include <hyprland/src/protocols/XDGShell.hpp>
#include <hyprland/src/xwayland/XSurface.hpp>

#define LOG(level, fmt, ...) Log::logger->log(level, fmt __VA_OPT__(, ) __VA_ARGS__)

namespace compat {
    inline bool mapped(const PHLWINDOW& w) {
        return w->m_isMapped;
    }
    inline const std::string& workspaceName(const PHLWORKSPACE& ws) {
        return ws->m_name;
    }
    inline bool visible(const PHLWORKSPACE& ws) {
        return ws->isVisible();
    }
    inline PHLANIMVAR<float>& alpha(const PHLWINDOW& w, Desktop::View::eWindowAlpha which) {
        return w->alpha(which);
    }
    inline std::optional<bool> asked(const PHLWINDOW& w) {
        if (const auto xdg = w->m_xdgSurface.lock(); xdg && xdg->m_toplevel)
            return xdg->m_toplevel->m_state.requestsMinimize;
        if (const auto x11 = w->m_xwaylandSurface.lock())
            return x11->m_state.requestsMinimize;
        return std::nullopt;
    }
    inline CHyprSignalListener onMinimizeRequest(const PHLWINDOW& w, std::function<void(PHLWINDOW)> fn) {
        auto handler = [weak = PHLWINDOWREF{w}, fn] {
            if (const auto w = weak.lock(); w && asked(w).value_or(false))
                fn(w);
        };
        if (const auto xdg = w->m_xdgSurface.lock(); xdg && xdg->m_toplevel)
            return xdg->m_toplevel->m_events.stateChanged.listen(handler);
        if (const auto x11 = w->m_xwaylandSurface.lock())
            return x11->m_events.stateChanged.listen(handler);
        return nullptr;
    }
}
#endif
