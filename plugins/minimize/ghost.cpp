#include "ghost.hpp"

#include <hyprland/src/animation/AnimationManager.hpp>
#include <hyprland/src/config/shared/animation/AnimationTree.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/render/Renderer.hpp>

SP<CGhost> CGhost::create(PHLMONITOR monitor, SP<Render::IFramebuffer> picture, const CBox& window, const CBox& from, const CBox& to, const std::string& leaf) {
    auto ghost           = SP<CGhost>(new CGhost());
    ghost->m_monitor     = monitor;
    ghost->m_framebuffer = picture;
    ghost->m_window      = window;

    const auto config = Config::animationTree()->getAnimationPropertyConfig(leaf);
    Animation::mgr()->createAnimation(from.pos(), ghost->m_realPosition, config, AVARDAMAGE_NONE);
    Animation::mgr()->createAnimation(from.size(), ghost->m_realSize, config, AVARDAMAGE_NONE);

    const WP<CGhost> weak   = ghost;
    const auto       damage = [weak](auto) {
        if (const auto ghost = weak.lock(); ghost)
            if (const auto monitor = ghost->m_monitor.lock(); monitor)
                g_pHyprRenderer->damageMonitor(monitor);
    };
    ghost->m_realPosition->setUpdateCallback(damage);
    ghost->m_realSize->setUpdateCallback(damage);

    ghost->m_realPosition->setValueAndWarp(from.pos());
    ghost->m_realSize->setValueAndWarp(from.size());
    *ghost->m_realPosition = to.pos();
    *ghost->m_realSize     = to.size();
    return ghost;
}

PHLMONITORREF CGhost::monitor() const {
    return m_monitor;
}

Desktop::eFadeoutPlane CGhost::plane() const {
    return Desktop::FADEOUT_PLANE_LAYER_TOP;
}

int CGhost::zIndex() const {
    return 0;
}

// the picture covers the whole monitor, so it is scaled the way the window box is
CBox CGhost::renderBox() const {
    const auto monitor = m_monitor.lock();
    if (!monitor || m_window.w <= 0 || m_window.h <= 0)
        return {};

    const auto     box    = now();
    const Vector2D factor = {box.w / m_window.w, box.h / m_window.h};
    const Vector2D offset = m_window.pos() - monitor->m_position;
    return {(box.x - monitor->m_position.x - offset.x * factor.x) * monitor->m_scale, (box.y - monitor->m_position.y - offset.y * factor.y) * monitor->m_scale,
            monitor->m_transformedSize.x * factor.x, monitor->m_transformedSize.y * factor.y};
}

float CGhost::alpha() const {
    return 1.F;
}

bool CGhost::done() const {
    return !m_realPosition->isBeingAnimated() && !m_realSize->isBeingAnimated();
}

CBox CGhost::now() const {
    return {m_realPosition->value(), m_realSize->value()};
}

double CGhost::scale() const {
    return m_window.w > 0 ? m_realSize->value().x / m_window.w : 0;
}

CBox CGhost::window() const {
    return m_window;
}

SP<Render::IFramebuffer> CGhost::picture() const {
    return m_framebuffer;
}

void CGhost::stop() {
    m_realPosition->warp();
    m_realSize->warp();
}
