#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/protocols/ToplevelExport.hpp>
#include <hyprland/protocols/hyprland-toplevel-export-v1.hpp>

#include <algorithm>
#include <vector>

#include "compat.hpp"

using FnCapture = void (*)(CToplevelExportClient*, uint32_t, int32_t, PHLWINDOW);

// reads the private manager of a capture client through an explicit instantiation
template <auto Member>
struct SSteal {
    friend SP<CHyprlandToplevelExportManagerV1> manager(CToplevelExportClient* client) {
        return client->*Member;
    }
};
template struct SSteal<&CToplevelExportClient::m_resource>;
SP<CHyprlandToplevelExportManagerV1> manager(CToplevelExportClient* client);

static CFunctionHook*                                  g_hook = nullptr;
static std::vector<SP<CHyprlandToplevelExportFrameV1>> g_refused;

static void drop(CHyprlandToplevelExportFrameV1* frame) {
    std::erase_if(g_refused, [frame](const auto& f) { return f.get() == frame; });
}

// hyprland makes no frame for a window gone before the request and the client dies when it destroys that frame
static void onCapture(CToplevelExportClient* client, uint32_t id, int32_t cursor, PHLWINDOW window) {
    if (window) {
        rc<FnCapture>(g_hook->m_original)(client, id, cursor, window);
        return;
    }
    const auto mgr   = manager(client);
    const auto frame = makeShared<CHyprlandToplevelExportFrameV1>(mgr->client(), mgr->version(), id);
    if (!frame->resource()) {
        mgr->noMemory();
        return;
    }
    frame->setDestroy(drop);
    frame->setOnDestroy(drop);
    frame->sendFailed();
    g_refused.push_back(frame);
    LOG(Log::INFO, "[fluencyminimize] capture=failed frame={} reason=window_gone", id);
}

bool hookCapture(HANDLE handle) {
    const auto found = HyprlandAPI::findFunctionsByName(handle, "captureToplevel");
    const auto it    = std::ranges::find_if(found, [](const auto& f) { return f.demangled.starts_with("CToplevelExportClient::captureToplevel("); });
    if (it == found.end()) {
        LOG(Log::ERR, "[fluencyminimize] capture=refused reason=no_capture_function matches={}", found.size());
        return false;
    }
    g_hook = HyprlandAPI::createFunctionHook(handle, it->address, rc<void*>(onCapture));
    return g_hook && g_hook->hook();
}

void dropRefused() {
    g_refused.clear();
}
