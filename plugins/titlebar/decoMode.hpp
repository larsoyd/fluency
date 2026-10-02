#pragma once

#include <optional>
#include <hyprland/src/desktop/DesktopTypes.hpp>

// true when the app draws its own titlebar, none when it never said
std::optional<bool> ownDecorations(PHLWINDOW window);
