// hyprland has no public way to add an animation leaf, its tree keeps them over config reloads
#define private public
#include <hyprland/src/config/shared/animation/AnimationTree.hpp>
#undef private

void makeLeaves() {
    Config::animationTree()->m_animationTree.createNode("fluencyMinimize", "windowsOut");
    Config::animationTree()->m_animationTree.createNode("fluencyRestore", "windowsIn");
}
