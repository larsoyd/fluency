#include "decoMode.hpp"

#include <hyprland/src/desktop/view/Window.hpp>

#define private public
#include <hyprland/src/protocols/ServerDecorationKDE.hpp>
#undef private

std::optional<bool> ownDecorations(PHLWINDOW window) {
    const auto SURFACE = window->resource();
    if (!SURFACE || !PROTO::serverDecorationKDE)
        return std::nullopt;

    for (const auto& deco : PROTO::serverDecorationKDE->m_decos) {
        if (deco->m_surf != SURFACE)
            continue;
        switch (deco->m_mostRecentlyRequested) {
            case ORG_KDE_KWIN_SERVER_DECORATION_MODE_CLIENT: return true;
            case ORG_KDE_KWIN_SERVER_DECORATION_MODE_SERVER: return false;
            default: return std::nullopt;
        }
    }
    return std::nullopt;
}
