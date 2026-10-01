#include "hyprland-lock-notify-v1-client-protocol.h"
#include <wayland-client.h>
#include <algorithm>
#include <csignal>
#include <cstdarg>
#include <cstring>
#include <filesystem>
#include <poll.h>
#include <string>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <vector>

namespace fs = std::filesystem;

struct Daemon {
    wl_display*                     display  = nullptr;
    hyprland_lock_notifier_v1*      notifier = nullptr;
    hyprland_lock_notification_v1*  notice   = nullptr;
    fs::path                        dir;
    int                             server = -1;
    std::vector<int>                clients;
    bool                            locked = false;
};

static Daemon                d;
static volatile sig_atomic_t stopping = 0;

// one write per line, two daemons may share a log
static void say(const char* format, ...) {
    char    line[512];
    va_list args;
    va_start(args, format);
    std::vsnprintf(line, sizeof line, format, args);
    va_end(args);
    std::fprintf(stderr, "[sessiond] %s\n", line);
}

static std::string env(const char* name, const std::string& fallback) {
    const char* value = std::getenv(name);
    return value && *value ? value : fallback;
}

static std::string stateLine() {
    return d.locked ? "{\"locked\":true}\n" : "{\"locked\":false}\n";
}

static bool sendTo(int fd, const std::string& line) {
    for (size_t done = 0; done < line.size();) {
        ssize_t sent = send(fd, line.data() + done, line.size() - done, MSG_NOSIGNAL);
        if (sent <= 0) {
            say("event=client_dropped fd=%d reason=%s", fd, std::strerror(errno));
            return false;
        }
        done += sent;
    }
    return true;
}

static void dropClient(int fd) {
    close(fd);
    std::erase(d.clients, fd);
}

static void lockChanged(bool locked) {
    d.locked = locked;
    say("event=%s clients=%zu", locked ? "locked" : "unlocked", d.clients.size());
    for (int fd : std::vector(d.clients))
        if (!sendTo(fd, stateLine()))
            dropClient(fd);
}

static void onLocked(void*, hyprland_lock_notification_v1*) {
    lockChanged(true);
}

static void onUnlocked(void*, hyprland_lock_notification_v1*) {
    lockChanged(false);
}

static const hyprland_lock_notification_v1_listener noticeListener = {.locked = onLocked, .unlocked = onUnlocked};

static void global(void*, wl_registry* registry, uint32_t name, const char* interface, uint32_t) {
    if (!std::strcmp(interface, hyprland_lock_notifier_v1_interface.name))
        d.notifier = (hyprland_lock_notifier_v1*)wl_registry_bind(registry, name, &hyprland_lock_notifier_v1_interface, 1);
}

static void globalRemove(void*, wl_registry*, uint32_t) {}

static const wl_registry_listener registryListener = {.global = global, .global_remove = globalRemove};

static int connectTo(const fs::path& path, int timeoutMs) {
    int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    sockaddr_un address{.sun_family = AF_UNIX};
    std::strncpy(address.sun_path, path.c_str(), sizeof address.sun_path - 1);
    timeval limit{.tv_sec = timeoutMs / 1000, .tv_usec = (timeoutMs % 1000) * 1000};
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &limit, sizeof limit);
    if (fd >= 0 && connect(fd, (sockaddr*)&address, sizeof address) == 0)
        return fd;
    if (fd >= 0)
        close(fd);
    return -1;
}

static int listenOn(const fs::path& path) {
    int probe = connectTo(path, 200);
    if (probe >= 0) {
        close(probe);
        return -1;
    }
    unlink(path.c_str());
    int         fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC | SOCK_NONBLOCK, 0);
    sockaddr_un address{.sun_family = AF_UNIX};
    std::strncpy(address.sun_path, path.c_str(), sizeof address.sun_path - 1);
    if (bind(fd, (sockaddr*)&address, sizeof address) != 0 || listen(fd, 8) != 0) {
        close(fd);
        return -1;
    }
    return fd;
}

// state prints the line sent on connect, watch prints every line until the daemon goes
static int ctl(const fs::path& socketPath, const std::string& request) {
    if (request != "state" && request != "watch") {
        std::printf("[sessiond] ctl result=refused reason=unknown_request request=%s\n", request.c_str());
        return 2;
    }
    int fd = connectTo(socketPath, request == "state" ? 2000 : 0);
    if (fd < 0) {
        std::printf("[sessiond] ctl result=fail reason=no_daemon path=%s\n", socketPath.c_str());
        return 1;
    }
    std::string in;
    char        buffer[256];
    for (ssize_t got; (got = recv(fd, buffer, sizeof buffer, 0)) > 0;) {
        in.append(buffer, got);
        for (size_t end; (end = in.find('\n')) != std::string::npos; in.erase(0, end + 1)) {
            std::printf("%s\n", in.substr(0, end).c_str());
            std::fflush(stdout);
            if (request == "state") {
                close(fd);
                return 0;
            }
        }
    }
    close(fd);
    if (request == "state")
        std::printf("[sessiond] ctl result=fail reason=short_reply bytes=%zu\n", in.size());
    return request == "state" ? 1 : 0;
}

static void stop(int) {
    stopping = 1;
}

int main(int argc, char** argv) {
    const auto display = env("WAYLAND_DISPLAY", "wayland-0");
    d.dir              = env("FLUENCY_SESSION_DIR", env("XDG_RUNTIME_DIR", "/tmp") + "/fluency-session/" + display);
    if (argc == 3 && !std::strcmp(argv[1], "ctl"))
        return ctl(d.dir / "control", argv[2]);
    if (argc != 1) {
        std::fprintf(stderr, "[sessiond] refused: bad_args usage=\"fluency-sessiond [ctl state|watch]\"\n");
        return 2;
    }
    std::error_code error;
    fs::create_directories(d.dir, error);
    d.server = listenOn(d.dir / "control");
    if (d.server < 0) {
        say("refused: running_or_no_socket path=%s", (d.dir / "control").c_str());
        return 1;
    }
    d.display = wl_display_connect(nullptr);
    if (!d.display) {
        say("refused: no_display name=%s", display.c_str());
        return 1;
    }
    auto registry = wl_display_get_registry(d.display);
    wl_registry_add_listener(registry, &registryListener, nullptr);
    wl_display_roundtrip(d.display);
    if (!d.notifier) {
        say("refused: missing_global hyprland_lock_notifier_v1");
        return 1;
    }
    signal(SIGPIPE, SIG_IGN);
    struct sigaction action{};
    action.sa_handler = stop;
    sigaction(SIGTERM, &action, nullptr);
    sigaction(SIGINT, &action, nullptr);
    d.notice = hyprland_lock_notifier_v1_get_lock_notification(d.notifier);
    hyprland_lock_notification_v1_add_listener(d.notice, &noticeListener, nullptr);
    // a session that is locked already says so in this roundtrip
    wl_display_roundtrip(d.display);
    say("event=started display=%s dir=%s pid=%d locked=%d", display.c_str(), d.dir.c_str(), getpid(), d.locked);

    while (!stopping) {
        while (wl_display_prepare_read(d.display) != 0)
            wl_display_dispatch_pending(d.display);
        wl_display_flush(d.display);
        std::vector<pollfd> fds{{wl_display_get_fd(d.display), POLLIN, 0}, {d.server, POLLIN, 0}};
        for (int fd : d.clients)
            fds.push_back({fd, POLLIN, 0});
        int ready = poll(fds.data(), fds.size(), -1);
        if (ready < 0 && errno != EINTR) {
            wl_display_cancel_read(d.display);
            say("event=poll_failed reason=%s", std::strerror(errno));
            break;
        }
        if (ready > 0 && (fds[0].revents & POLLIN))
            wl_display_read_events(d.display);
        else
            wl_display_cancel_read(d.display);
        if (wl_display_dispatch_pending(d.display) < 0) {
            say("event=display_lost reason=%s", std::strerror(errno));
            break;
        }
        // clients only listen, anything they send is read and dropped
        for (size_t i = 2; i < fds.size(); i++) {
            if (!fds[i].revents)
                continue;
            char    buffer[256];
            ssize_t got = recv(fds[i].fd, buffer, sizeof buffer, MSG_DONTWAIT);
            if (got == 0 || (got < 0 && errno != EAGAIN))
                dropClient(fds[i].fd);
        }
        if (ready > 0 && (fds[1].revents & POLLIN))
            for (int fd; (fd = accept4(d.server, nullptr, nullptr, SOCK_CLOEXEC)) >= 0;) {
                if (sendTo(fd, stateLine()))
                    d.clients.push_back(fd);
                else
                    close(fd);
            }
    }
    unlink((d.dir / "control").c_str());
    say("event=stopped");
    return 0;
}
