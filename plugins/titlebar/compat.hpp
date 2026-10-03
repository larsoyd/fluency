#pragma once

#include <hyprland/src/config/shared/actions/ConfigActions.hpp>
#include <hyprland/src/config/supplementary/executor/Executor.hpp>
#include <hyprland/src/layout/LayoutManager.hpp>

#if __has_include(<hyprland/src/desktop/view/window/WindowBackend.hpp>)
#include <hyprland/src/desktop/view/window/Window.hpp>
#include <hyprland/src/desktop/view/window/WindowPresentation.hpp>
#include <hyprland/src/desktop/view/window/WindowMetadata.hpp>
#include <hyprland/src/desktop/view/window/WindowBackend.hpp>
#include <hyprland/src/keybinds/Manager.hpp>

namespace compat {
    inline bool mapped(const PHLWINDOW& w) {
        return w->mapped();
    }
    inline bool floating(const PHLWINDOW& w) {
        return w->isFloating();
    }
    inline bool pinned(const PHLWINDOW& w) {
        return static_cast<bool>(w->m_state & Desktop::View::WINDOW_STATE_PINNED);
    }
    inline bool wantsNoBorder(const PHLWINDOW& w) {
        return w->backend().traits().suggestsNoBorder;
    }
    inline const std::string& title(const PHLWINDOW& w) {
        return w->metadata().title();
    }
    inline const std::string& appID(const PHLWINDOW& w) {
        return w->metadata().appID();
    }
    inline const std::string& initialAppID(const PHLWINDOW& w) {
        return w->metadata().initialAppID();
    }
    inline pid_t pid(const PHLWINDOW& w) {
        return w->backend().pid();
    }
    inline float rounding(const PHLWINDOW& w) {
        return w->presentation().rounding();
    }
    inline float roundingPower(const PHLWINDOW& w) {
        return w->presentation().roundingPower();
    }
    inline int borderSize(const PHLWINDOW& w) {
        return w->presentation().borderSize();
    }
    inline const Vector2D& floatingOffset(const PHLWINDOW& w) {
        return w->presentation().floatingOffset();
    }
    inline auto decorations(const PHLWINDOW& w) {
        return w->presentation().decorations();
    }
    inline void dropDecoration(const PHLWINDOW& w, IHyprWindowDecoration* deco) {
        w->presentation().removeDecoration(deco);
    }
    inline void updateDecorations(const PHLWINDOW& w) {
        w->presentation().updateDecorations();
    }
    template <typename T>
    inline SP<T> makeDecoration(const PHLWINDOW& w) {
        return makeShared<T>(w);
    }

    inline void exec(const std::string& cmd) {
        Config::Supplementary::executor()->spawn(cmd);
    }
    inline void beginDrag(const PHLWINDOW& w) {
        g_layoutManager->beginDragTarget(w->layoutTarget(), MBIND_MOVE);
    }
    inline void endDrag() {
        g_layoutManager->endDragTarget();
    }
    inline void touchDrag(const PHLWINDOW& w, bool first, const Vector2D&) {
        if (!first)
            return;
        (void)Config::Actions::floatWindow(Config::Actions::eTogglableAction::TOGGLE_ACTION_ENABLE, w);
        // pin it so you can change workspaces while dragging a window
        (void)Config::Actions::pinWindow(Config::Actions::eTogglableAction::TOGGLE_ACTION_ENABLE, w);
        beginDrag(w);
    }
    inline void cancelDrag(bool touch) {
        if (touch)
            (void)Config::Actions::floatWindow(Config::Actions::eTogglableAction::TOGGLE_ACTION_DISABLE);
        endDrag();
    }
}
#else
// TODO: temporary compat maintained for a few months after release then removed
#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/managers/KeybindManager.hpp>

#include <format>

#define LOG(level, fmt, ...) Log::logger->log(level, fmt __VA_OPT__(, ) __VA_ARGS__)

namespace compat {
    inline bool mapped(const PHLWINDOW& w) {
        return w->m_isMapped;
    }
    inline bool floating(const PHLWINDOW& w) {
        return w->m_isFloating;
    }
    inline bool pinned(const PHLWINDOW& w) {
        return w->m_pinned;
    }
    inline bool wantsNoBorder(const PHLWINDOW& w) {
        return w->m_X11DoesntWantBorders;
    }
    inline const std::string& title(const PHLWINDOW& w) {
        return w->m_title;
    }
    inline const std::string& appID(const PHLWINDOW& w) {
        return w->m_class;
    }
    inline const std::string& initialAppID(const PHLWINDOW& w) {
        return w->m_initialClass;
    }
    inline pid_t pid(const PHLWINDOW& w) {
        return w->getPID();
    }
    inline float rounding(const PHLWINDOW& w) {
        return w->rounding();
    }
    inline float roundingPower(const PHLWINDOW& w) {
        return w->roundingPower();
    }
    inline int borderSize(const PHLWINDOW& w) {
        return w->getRealBorderSize();
    }
    inline const Vector2D& floatingOffset(const PHLWINDOW& w) {
        return w->m_floatingOffset;
    }
    inline const std::vector<UP<IHyprWindowDecoration>>& decorations(const PHLWINDOW& w) {
        return w->m_windowDecorations;
    }
    inline void updateDecorations(const PHLWINDOW& w) {
        w->updateWindowDecos();
    }
    // an unmapped window keeps a removed decoration until it maps again, past the unload of its code
    inline void dropDecoration(const PHLWINDOW& w, IHyprWindowDecoration* deco) {
        const auto IT = std::ranges::find_if(w->m_windowDecorations, [deco](const auto& d) { return d.get() == deco; });
        if (IT == w->m_windowDecorations.end())
            return;
        g_pDecorationPositioner->uncacheDecoration(deco);
        w->m_windowDecorations.erase(IT);
    }
    template <typename T>
    inline UP<T> makeDecoration(const PHLWINDOW& w) {
        return makeUnique<T>(w);
    }

    inline void exec(const std::string& cmd) {
        g_pKeybindManager->m_dispatchers["exec"](cmd);
    }
    inline void beginDrag(const PHLWINDOW&) {
        g_pKeybindManager->changeMouseBindMode(MBIND_MOVE);
    }
    inline void endDrag() {
        g_pKeybindManager->changeMouseBindMode(MBIND_INVALID);
    }
    inline void touchDrag(const PHLWINDOW&, bool first, const Vector2D& to) {
        if (first) {
            g_pKeybindManager->m_dispatchers["setfloating"]("activewindow");
            g_pKeybindManager->m_dispatchers["resizewindowpixel"]("exact 50% 50%,activewindow");
            g_pKeybindManager->m_dispatchers["pin"]("activewindow");
        }
        g_pKeybindManager->m_dispatchers["movewindowpixel"](std::format("exact {} {},activewindow", (int)to.x, (int)to.y));
    }
    inline void cancelDrag(bool touch) {
        if (touch)
            g_pKeybindManager->m_dispatchers["settiled"]("activewindow");
        g_pKeybindManager->m_dispatchers["mouse"]("0movewindow");
    }
}
#endif

#if __has_include(<hyprland/src/workspace/presentation/WorkspacePresentable.hpp>)
#include <hyprland/src/workspace/presentation/WorkspacePresentable.hpp>

#define COMPAT_PRESENTABLE 1

namespace compat {
    using Presentation = SP<Workspace::CWorkspacePresentable>;
    inline Presentation presentation(const PHLWINDOW& w) {
        return dynamicPointerCast<Workspace::CWorkspacePresentable>(w->m_workspace);
    }
}
#else
// TODO: temporary compat maintained for a few months after release then removed
namespace compat {
    using Presentation = PHLWORKSPACE;
    inline Presentation presentation(const PHLWINDOW& w) {
        return w->m_workspace;
    }
}
#endif

namespace compat {
    inline Vector2D renderOffset(const PHLWINDOW& w, const Presentation& p) {
        return p && !pinned(w) ? p->m_renderOffset->value() : Vector2D();
    }
}

#include <hyprland/src/render/OpenGL.hpp>
#include <hyprland/src/render/Renderer.hpp>

#if __has_include(<hyprland/src/render/Context.hpp>)
#include <hyprland/src/render/Context.hpp>

#define COMPAT_RENDER_CONTEXT 1

namespace compat {
    using RenderContext = Render::CRenderContext;
    using RectData      = Render::GL::CHyprOpenGLImpl::SRectRenderData;
    using TextureData   = Render::GL::CHyprOpenGLImpl::STextureRenderData;

    inline PHLMONITOR monitor(RenderContext& ctx) {
        return ctx.m_data.pMonitor.lock();
    }
    inline const CRegion& damage(RenderContext& ctx) {
        return ctx.m_data.damage;
    }
    inline void addPass(RenderContext& ctx, UP<IPassElement>&& element) {
        Render::IHyprRenderer::addPassElement(ctx, std::move(element));
    }
    inline void dropPasses(const std::string& type) {
        g_pHyprRenderer->context().m_pass.removeAllOfType(type);
    }
    inline void renderRect(RenderContext& ctx, const CBox& box, const CHyprColor& color, RectData data) {
        Render::GL::g_pHyprOpenGL->renderRect(ctx, box, color, data);
    }
    inline void renderTexture(RenderContext& ctx, SP<Render::ITexture> tex, const CBox& box, TextureData data) {
        Render::GL::g_pHyprOpenGL->renderTexture(ctx, tex, box, data);
    }
    inline void scissor(RenderContext& ctx, const CBox& box) {
        Render::GL::g_pHyprOpenGL->scissor(ctx, box);
    }
    inline void noScissor(RenderContext& ctx) {
        Render::GL::g_pHyprOpenGL->scissor(ctx, nullptr);
    }
}
#else
// TODO: temporary compat maintained for a few months after release then removed
namespace compat {
    struct RenderContext {};
    using RectData    = Render::GL::CHyprOpenGLImpl::SRectRenderData;
    using TextureData = Render::GL::CHyprOpenGLImpl::STextureRenderData;

    inline PHLMONITOR monitor(RenderContext&) {
        return g_pHyprRenderer->m_renderData.pMonitor.lock();
    }
    inline const CRegion& damage(RenderContext&) {
        return g_pHyprRenderer->m_renderData.damage;
    }
    inline void addPass(RenderContext&, UP<IPassElement>&& element) {
        g_pHyprRenderer->m_renderPass.add(std::move(element));
    }
    inline void dropPasses(const std::string& type) {
        g_pHyprRenderer->m_renderPass.removeAllOfType(type);
    }
    inline void renderRect(RenderContext&, const CBox& box, const CHyprColor& color, RectData data) {
        Render::GL::g_pHyprOpenGL->renderRect(box, color, data);
    }
    inline void renderTexture(RenderContext&, SP<Render::ITexture> tex, const CBox& box, TextureData data) {
        Render::GL::g_pHyprOpenGL->renderTexture(tex, box, data);
    }
    inline void scissor(RenderContext&, const CBox& box) {
        Render::GL::g_pHyprOpenGL->scissor(box);
    }
    inline void noScissor(RenderContext&) {
        Render::GL::g_pHyprOpenGL->scissor(nullptr);
    }
}
#endif
