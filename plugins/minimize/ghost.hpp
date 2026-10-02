#pragma once

#include <chrono>

#include <hyprland/src/desktop/state/Fadeout.hpp>

#include "compat.hpp"

// a picture of a window that flies between its place and its taskbar button above the taskbar
class CGhost final : public Desktop::IFadeout {
  public:
    static SP<CGhost>        create(PHLMONITOR monitor, SP<Render::IFramebuffer> picture, const CBox& window, const CBox& from, const CBox& to, const std::string& leaf);

    PHLMONITORREF            monitor() const override;
    Desktop::eFadeoutPlane   plane() const override;
    int                      zIndex() const override;
    CBox                     renderBox() const override;
    float                    alpha() const override;
    bool                     done() const override;

    CBox                     now() const;
    double                   scale() const;
    CBox                     window() const;
    SP<Render::IFramebuffer> picture() const;
    void                     repaint(SP<Render::IFramebuffer> picture);
    void                     stop();

    int                                   m_frames = 0;
    std::chrono::steady_clock::time_point m_start  = std::chrono::steady_clock::now();

  private:
    CGhost() = default;

    PHLMONITORREF m_monitor;
    CBox          m_window;
};
