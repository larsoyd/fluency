#include "store.hpp"
#include "ext-data-control-v1-client-protocol.h"
#include <wayland-client.h>
#include <algorithm>
#include <chrono>
#include <csignal>
#include <cstdarg>
#include <cstring>
#include <fcntl.h>
#include <filesystem>
#include <fstream>
#include <map>
#include <memory>
#include <poll.h>
#include <set>
#include <sstream>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <utility>

using namespace clip;
namespace fs = std::filesystem;
using Formats = std::shared_ptr<const std::vector<Format>>;

static constexpr int64_t captureMs = 3000, serveMs = 10000, hyprMs = 500;

static void say(const char* format, ...) {
    va_list args;
    va_start(args, format);
    std::fputs("[clipd] ", stderr);
    std::vfprintf(stderr, format, args);
    std::fputc('\n', stderr);
    va_end(args);
}

static int64_t now() {
    return std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch()).count();
}

static std::string env(const char* name, const std::string& fallback) {
    const char* value = std::getenv(name);
    return value && *value ? value : fallback;
}

static std::vector<std::string> split(const std::string& text, char by) {
    std::vector<std::string> out;
    std::stringstream        stream(text);
    for (std::string item; std::getline(stream, item, by);)
        if (!item.empty())
            out.push_back(item);
    return out;
}

static int connectTo(const std::string& path, int64_t timeoutMs) {
    int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    sockaddr_un address{.sun_family = AF_UNIX};
    std::strncpy(address.sun_path, path.c_str(), sizeof address.sun_path - 1);
    timeval limit{.tv_sec = timeoutMs / 1000, .tv_usec = (timeoutMs % 1000) * 1000};
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &limit, sizeof limit);
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &limit, sizeof limit);
    if (fd >= 0 && connect(fd, (sockaddr*)&address, sizeof address) == 0)
        return fd;
    if (fd >= 0)
        close(fd);
    return -1;
}

// the window that has the keyboard when the selection changes is the one that copied
static std::pair<std::string, std::string> activeWindow() {
    const char* signature = std::getenv("HYPRLAND_INSTANCE_SIGNATURE");
    if (!signature)
        return {};
    int fd = connectTo(env("XDG_RUNTIME_DIR", "/tmp") + "/hypr/" + signature + "/.socket.sock", hyprMs);
    if (fd < 0)
        return {};
    std::string reply;
    if (write(fd, "activewindow", 12) == 12) {
        char buffer[4096];
        for (ssize_t got; (got = read(fd, buffer, sizeof buffer)) > 0;)
            reply.append(buffer, got);
    }
    close(fd);
    std::pair<std::string, std::string> out;
    for (const auto& line : split(reply, '\n')) {
        if (line.starts_with("\tclass: "))
            out.first = line.substr(8);
        if (line.starts_with("\ttitle: "))
            out.second = line.substr(8);
    }
    return out;
}

struct Read {
    std::string mime;
    int         fd;
    std::string data;
};

struct Capture {
    ext_data_control_offer_v1*          offer = nullptr;
    std::vector<Read>                   reads;
    std::pair<std::string, std::string> window;
    int64_t                             started = 0;
    size_t                              total   = 0;
};

struct Write {
    int     fd;
    Formats formats;
    size_t  index;
    size_t  done = 0;
    int64_t deadline;
};

struct Client {
    int         fd;
    std::string in;
};

struct Pending {
    int         fd;
    std::string request;
    int64_t     deadline;
};

struct Daemon {
    wl_display*                                                     display = nullptr;
    wl_seat*                                                        seat    = nullptr;
    ext_data_control_manager_v1*                                    manager = nullptr;
    ext_data_control_device_v1*                                     device  = nullptr;
    std::map<ext_data_control_offer_v1*, std::vector<std::string>> offers;
    std::unique_ptr<Capture>                                        capture;
    std::map<ext_data_control_source_v1*, Formats>                  sources;
    Formats                                                         served;
    uint64_t                                                        current = 0;
    std::vector<Write>                                              writes;
    std::vector<Client>                                             clients;
    Store                                                           store;
    std::set<std::string>                                           ignored;
    fs::path                                                        dir, images, pins;
    std::string                                                     stamp = std::to_string(now());
    int                                                             server  = -1;
    bool                                                            initial = true;
    std::vector<Pending>                                            pending;
};

static Daemon                d;
static volatile sig_atomic_t stopping = 0;

static fs::path imagePath(const Entry& entry) {
    auto format = image(entry);
    if (!format)
        return {};
    auto type = format->mime.substr(6);
    return d.images / (d.stamp + "-" + std::to_string(entry.id) + "." + type.substr(0, type.find(';')));
}

static std::string entriesLine() {
    std::string out = "{\"type\":\"entries\",\"entries\":[";
    for (const auto& entry : d.store.entries())
        out += (out.ends_with("[") ? "" : ",") + json(entry, imagePath(entry).string(), entry.id == d.current);
    return out + "]}\n";
}

static void sendTo(Client& client, const std::string& line) {
    for (size_t done = 0; done < line.size();) {
        ssize_t sent = send(client.fd, line.data() + done, line.size() - done, MSG_NOSIGNAL);
        if (sent <= 0) {
            say("event=client_dropped fd=%d reason=%s", client.fd, std::strerror(errno));
            shutdown(client.fd, SHUT_RDWR);
            return;
        }
        done += sent;
    }
}

// pictures live in the runtime dir so the shell can draw them, pins are kept on disk
static void syncFiles() {
    std::set<fs::path> keep;
    for (const auto& entry : d.store.entries()) {
        auto path = imagePath(entry);
        if (path.empty())
            continue;
        keep.insert(path);
        if (!fs::exists(path))
            std::ofstream(path, std::ios::binary) << image(entry)->data;
    }
    std::error_code error;
    for (const auto& file : fs::directory_iterator(d.images, error))
        if (!keep.contains(file.path()))
            fs::remove(file.path(), error);
    std::set<std::string> pinned;
    for (const auto& entry : d.store.entries()) {
        if (!entry.pinned)
            continue;
        auto folder = d.pins / std::to_string(entry.id);
        pinned.insert(folder.filename());
        if (fs::exists(folder / "meta"))
            continue;
        fs::create_directories(folder, error);
        std::ofstream meta(folder / "meta");
        meta << "time " << entry.time << "\napp " << entry.app << "\n";
        auto title = entry.title;
        std::ranges::replace(title, '\n', ' ');
        meta << "title " << title << "\n";
        for (size_t i = 0; i < entry.formats.size(); i++) {
            meta << "mime " << i << " " << entry.formats[i].mime << "\n";
            std::ofstream(folder / std::to_string(i), std::ios::binary) << entry.formats[i].data;
        }
    }
    for (const auto& folder : fs::directory_iterator(d.pins, error))
        if (!pinned.contains(folder.path().filename()))
            fs::remove_all(folder.path(), error);
}

static void reply(int fd, const std::string& request, const std::string& result) {
    say("event=request request=\"%s\" result=\"%s\"", request.c_str(), result.c_str());
    auto it = std::ranges::find(d.clients, fd, &Client::fd);
    if (it != d.clients.end())
        sendTo(*it, "{\"type\":\"result\",\"request\":\"" + escape(request) + "\",\"result\":\"" + escape(result) + "\"}\n");
}

// a paste sent on the answer must find the new selection, so the answer waits for hyprland to show it
static void confirm(const char* result) {
    for (const auto& wait : d.pending)
        reply(wait.fd, wait.request, result);
    d.pending.clear();
}

static void changed() {
    syncFiles();
    auto line = entriesLine();
    for (auto& client : d.clients)
        sendTo(client, line);
}

static void loadPins() {
    std::error_code              error;
    std::vector<Entry>           loaded;
    for (const auto& folder : fs::directory_iterator(d.pins, error)) {
        Entry entry{.pinned = true};
        try {
            entry.id = std::stoull(folder.path().filename());
        } catch (...) { continue; }
        std::ifstream meta(folder.path() / "meta");
        for (std::string line; std::getline(meta, line);) {
            auto space = line.find(' ');
            auto key = line.substr(0, space), value = space == std::string::npos ? "" : line.substr(space + 1);
            if (key == "time")
                entry.time = std::stoll(value);
            else if (key == "app")
                entry.app = value;
            else if (key == "title")
                entry.title = value;
            else if (key == "mime") {
                auto          parts = value.find(' ');
                std::ifstream data(folder.path() / value.substr(0, parts), std::ios::binary);
                entry.formats.push_back({value.substr(parts + 1), {std::istreambuf_iterator<char>(data), {}}});
            }
        }
        loaded.push_back(std::move(entry));
    }
    std::ranges::sort(loaded, {}, &Entry::time);
    for (auto& entry : loaded)
        if (!d.store.add(std::move(entry)))
            say("event=pin_dropped reason=empty_or_too_big");
    say("event=pins_loaded count=%zu dir=%s", loaded.size(), d.pins.c_str());
}

static void sourceSend(void*, ext_data_control_source_v1* source, const char* mime, int32_t fd) {
    const auto& formats = d.sources[source];
    auto        it      = std::ranges::find(*formats, std::string_view(mime), &Format::mime);
    if (it == formats->end()) {
        say("event=serve result=refused mime=%s reason=unknown_mime", mime);
        close(fd);
        return;
    }
    fcntl(fd, F_SETFL, O_NONBLOCK);
    d.writes.push_back({.fd = fd, .formats = formats, .index = size_t(it - formats->begin()), .deadline = now() + serveMs});
}

static void sourceCancelled(void*, ext_data_control_source_v1* source) {
    ext_data_control_source_v1_destroy(source);
    d.sources.erase(source);
}

static const ext_data_control_source_v1_listener sourceListener = {.send = sourceSend, .cancelled = sourceCancelled};

// the marker tells our own offer apart when the selection comes back to us
// an old source lives on until cancelled, destroying the current one would empty the selection
static void own(Formats formats, const char* why) {
    auto source = ext_data_control_manager_v1_create_data_source(d.manager);
    ext_data_control_source_v1_add_listener(source, &sourceListener, nullptr);
    for (const auto& format : *formats)
        ext_data_control_source_v1_offer(source, format.mime.c_str());
    ext_data_control_source_v1_offer(source, std::string(marker).c_str());
    d.sources[source] = formats;
    d.served          = formats;
    ext_data_control_device_v1_set_selection(d.device, source);
    wl_display_flush(d.display);
    say("event=owned why=%s formats=%zu", why, formats->size());
}

static void dropCapture() {
    if (!d.capture)
        return;
    for (auto& read : d.capture->reads)
        if (read.fd >= 0)
            close(read.fd);
    ext_data_control_offer_v1_destroy(d.capture->offer);
    d.capture.reset();
}

// a source that just quit may have left its data in the pipes
static void drain() {
    for (auto& read : d.capture->reads) {
        char buffer[65536];
        for (ssize_t got; read.fd >= 0;) {
            got = ::read(read.fd, buffer, sizeof buffer);
            if (got > 0) {
                read.data.append(buffer, got);
                d.capture->total += got;
                if (d.capture->total > Limits{}.entryBytes)
                    return;
                continue;
            }
            if (got < 0 && errno == EAGAIN)
                break;
            close(read.fd);
            read.fd = -1;
        }
    }
}

static void finishCapture(const char* why) {
    drain();
    auto&       capture = *d.capture;
    Entry       entry{.time = now(), .app = capture.window.first, .title = capture.window.second};
    const bool  whole   = std::ranges::all_of(capture.reads, [](const Read& read) { return read.fd < 0; });
    for (auto& read : capture.reads)
        if (!read.data.empty())
            entry.formats.push_back({read.mime, std::move(read.data)});
    const auto ms = now() - capture.started;
    dropCapture();
    if (!whole || entry.formats.empty()) {
        say("event=capture result=refused reason=%s formats=%zu ms=%lld", whole ? "empty" : why, entry.formats.size(), (long long)ms);
        d.current = 0;
        return changed();
    }
    // another manager taking our offer over would bounce the same data back and forth
    auto formats = std::make_shared<const std::vector<Format>>(entry.formats);
    if (!d.served || !same(*d.served, *formats))
        own(formats, "captured");
    auto stored    = d.store.add(std::move(entry));
    d.current      = stored ? stored->id : 0;
    say("event=stored id=%llu kind=%s bytes=%zu app=%s ms=%lld", (unsigned long long)d.current, stored ? kind(*stored).c_str() : "none",
        stored ? bytes(*stored) : 0, stored ? stored->app.c_str() : "", (long long)ms);
    changed();
}

static void offerMime(void*, ext_data_control_offer_v1* offer, const char* mime) {
    d.offers[offer].push_back(mime);
}

static const ext_data_control_offer_v1_listener offerListener = {.offer = offerMime};

static void deviceOffer(void*, ext_data_control_device_v1*, ext_data_control_offer_v1* offer) {
    d.offers[offer] = {};
    ext_data_control_offer_v1_add_listener(offer, &offerListener, nullptr);
}

static void deviceSelection(void*, ext_data_control_device_v1*, ext_data_control_offer_v1* offer) {
    // the selection sent on bind was made before we were here, whoever has focus now did not copy it
    const bool initial = std::exchange(d.initial, false);
    if (d.capture)
        finishCapture("superseded");
    // hyprland tells data control clients nothing when a source dies, so captures are owned at once
    if (!offer)
        return say("event=selection offer=none");
    auto mimes = d.offers[offer];
    d.offers.erase(offer);
    if (ours(mimes)) {
        confirm("ok");
        return ext_data_control_offer_v1_destroy(offer);
    }
    auto window = initial ? std::pair<std::string, std::string>{} : activeWindow();
    if (secret(mimes) || d.ignored.contains(window.first)) {
        say("event=selection result=skipped reason=%s app=%s", secret(mimes) ? "secret" : "ignored_app", window.first.c_str());
        ext_data_control_offer_v1_destroy(offer);
        d.current = 0;
        return changed();
    }
    d.capture = std::make_unique<Capture>(Capture{.offer = offer, .window = window, .started = now()});
    for (const auto& mime : wanted(mimes)) {
        int ends[2];
        if (pipe2(ends, O_CLOEXEC | O_NONBLOCK) != 0)
            continue;
        ext_data_control_offer_v1_receive(offer, mime.c_str(), ends[1]);
        close(ends[1]);
        d.capture->reads.push_back({mime, ends[0], {}});
    }
    wl_display_flush(d.display);
    say("event=selection offered=%zu reading=%zu app=%s", mimes.size(), d.capture->reads.size(), window.first.c_str());
    if (d.capture->reads.empty())
        finishCapture("no_formats");
}

static void deviceFinished(void*, ext_data_control_device_v1*) {
    say("event=device_finished");
    stopping = 1;
}

static void devicePrimary(void*, ext_data_control_device_v1*, ext_data_control_offer_v1* offer) {
    if (!offer)
        return;
    d.offers.erase(offer);
    ext_data_control_offer_v1_destroy(offer);
}

static const ext_data_control_device_v1_listener deviceListener = {
    .data_offer = deviceOffer, .selection = deviceSelection, .finished = deviceFinished, .primary_selection = devicePrimary};

static void global(void*, wl_registry* registry, uint32_t name, const char* interface, uint32_t) {
    if (!std::strcmp(interface, wl_seat_interface.name) && !d.seat)
        d.seat = (wl_seat*)wl_registry_bind(registry, name, &wl_seat_interface, 1);
    if (!std::strcmp(interface, ext_data_control_manager_v1_interface.name))
        d.manager = (ext_data_control_manager_v1*)wl_registry_bind(registry, name, &ext_data_control_manager_v1_interface, 1);
}

static void globalRemove(void*, wl_registry*, uint32_t) {}

static const wl_registry_listener registryListener = {.global = global, .global_remove = globalRemove};

static std::string answer(const std::string& request) {
    auto     words = split(request, ' ');
    auto     verb  = words.empty() ? "" : words[0];
    uint64_t id    = 0;
    if (words.size() > 1)
        try {
            id = std::stoull(words[1]);
        } catch (...) { return "refused: bad id " + words[1]; }
    if (verb == "list")
        return "ok";
    if (verb == "clear") {
        auto count = d.store.clear();
        return "ok cleared=" + std::to_string(count);
    }
    auto entry = d.store.find(id);
    if (!entry)
        return verb == "select" || verb == "text" || verb == "pin" || verb == "unpin" || verb == "delete" ? "refused: unknown id " + std::to_string(id) :
                                                                                                             "refused: unknown request " + verb;
    if (verb == "select" || verb == "text") {
        auto formats = verb == "text" ? textOnly(*entry) : entry->formats;
        if (formats.empty())
            return "refused: no text in " + std::to_string(id);
        d.current = id;
        d.store.touch(id, now());
        own(std::make_shared<const std::vector<Format>>(std::move(formats)), verb == "text" ? "picked_text" : "picked");
        return "ok";
    }
    if (verb == "pin" || verb == "unpin")
        return d.store.pin(id, verb == "pin") ? "ok" : "refused: pin failed";
    if (verb == "delete")
        return d.store.remove(id) ? "ok" : "refused: delete failed";
    return "refused: unknown request " + verb;
}

static void readClient(Client& client) {
    char    buffer[4096];
    ssize_t got = recv(client.fd, buffer, sizeof buffer, MSG_DONTWAIT);
    if (got < 0 && errno == EAGAIN)
        return;
    if (got <= 0) {
        say("event=client_left fd=%d reason=%s", client.fd, got == 0 ? "closed" : std::strerror(errno));
        shutdown(client.fd, SHUT_RDWR);
        return;
    }
    client.in.append(buffer, got);
    for (size_t end; (end = client.in.find('\n')) != std::string::npos;) {
        auto request = client.in.substr(0, end);
        client.in.erase(0, end + 1);
        auto result = answer(request);
        if (result == "ok" && (request.starts_with("select ") || request.starts_with("text ")))
            d.pending.push_back({client.fd, request, now() + 1000});
        else
            reply(client.fd, request, result);
        if (result.starts_with("ok") && request != "list")
            changed();
        else if (request == "list")
            sendTo(client, entriesLine());
    }
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

static void pumpWrites() {
    std::erase_if(d.writes, [](Write& job) {
        const auto& data = (*job.formats)[job.index].data;
        ssize_t     sent = job.done < data.size() ? write(job.fd, data.data() + job.done, data.size() - job.done) : 0;
        if (sent > 0)
            job.done += sent;
        bool over = job.done >= data.size() || (sent < 0 && errno != EAGAIN) || now() > job.deadline;
        if (over) {
            if (job.done < data.size())
                say("event=serve result=fail mime=%s sent=%zu of=%zu reason=%s", (*job.formats)[job.index].mime.c_str(), job.done, data.size(),
                    now() > job.deadline ? "timeout" : std::strerror(errno));
            close(job.fd);
        }
        return over;
    });
}

static void pumpReads(const std::vector<pollfd>& fds) {
    if (!d.capture)
        return;
    for (auto& read : d.capture->reads) {
        auto it = std::ranges::find(fds, read.fd, &pollfd::fd);
        if (read.fd < 0 || it == fds.end() || !it->revents)
            continue;
        char    buffer[65536];
        ssize_t got = ::read(read.fd, buffer, sizeof buffer);
        if (got > 0) {
            read.data.append(buffer, got);
            d.capture->total += got;
        } else if (got == 0 || errno != EAGAIN) {
            close(read.fd);
            read.fd = -1;
        }
    }
    if (d.capture->total > Limits{}.entryBytes)
        return finishCapture("too_big");
    if (std::ranges::all_of(d.capture->reads, [](const Read& read) { return read.fd < 0; }))
        finishCapture("done");
}

static int ctl(const std::string& socketPath, const std::string& request) {
    int fd = connectTo(socketPath, 2000);
    if (fd < 0) {
        std::printf("[clipd] ctl result=fail reason=no_daemon path=%s\n", socketPath.c_str());
        return 1;
    }
    auto line = request + "\n";
    send(fd, line.data(), line.size(), MSG_NOSIGNAL);
    std::string in;
    char        buffer[65536];
    // the list sent on connect comes first, a list asked for comes after its result
    auto done = [&] {
        auto at = in.find("\"type\":\"result\"");
        if (at == std::string::npos)
            return false;
        auto list = in.find("\"type\":\"entries\"", at);
        return request != "list" || (list != std::string::npos && in.find('\n', list) != std::string::npos);
    };
    for (ssize_t got; !done() && (got = recv(fd, buffer, sizeof buffer, 0)) > 0;)
        in.append(buffer, got);
    close(fd);
    std::string result, entries;
    for (const auto& line : split(in, '\n')) {
        if (line.find("\"type\":\"result\"") != std::string::npos && result.empty())
            result = line;
        else if (!result.empty() && line.find("\"type\":\"entries\"") != std::string::npos && entries.empty())
            entries = line;
    }
    if (result.empty() || (request == "list" && entries.empty())) {
        std::printf("[clipd] ctl result=fail reason=short_reply bytes=%zu\n", in.size());
        return 1;
    }
    std::printf("%s\n", request == "list" ? entries.c_str() : result.c_str());
    return result.find("\"result\":\"ok") != std::string::npos ? 0 : 1;
}

static void stop(int) {
    stopping = 1;
}

int main(int argc, char** argv) {
    const auto display = env("WAYLAND_DISPLAY", "wayland-0");
    d.dir    = env("FLUENCY_CLIP_DIR", env("XDG_RUNTIME_DIR", "/tmp") + "/fluency-clip/" + display);
    d.images = d.dir / "images";
    d.pins   = fs::path(env("FLUENCY_CLIP_STATE", env("XDG_STATE_HOME", env("HOME", "/tmp") + "/.local/state") + "/fluency-clip")) / "pinned";
    if (argc == 3 && !std::strcmp(argv[1], "ctl"))
        return ctl(d.dir / "control", argv[2]);
    if (argc != 1) {
        std::fprintf(stderr, "[clipd] refused: bad_args usage=\"fluency-clipd [ctl <request>]\"\n");
        return 2;
    }
    for (const auto& app : split(env("FLUENCY_CLIP_IGNORE", ""), ','))
        d.ignored.insert(app);
    std::error_code error;
    fs::create_directories(d.images, error);
    fs::create_directories(d.pins, error);
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
    if (!d.seat || !d.manager) {
        say("refused: missing_global seat=%d ext_data_control=%d", !!d.seat, !!d.manager);
        return 1;
    }
    signal(SIGPIPE, SIG_IGN);
    struct sigaction action{};
    action.sa_handler = stop;
    sigaction(SIGTERM, &action, nullptr);
    sigaction(SIGINT, &action, nullptr);
    loadPins();
    syncFiles();
    d.device = ext_data_control_manager_v1_get_data_device(d.manager, d.seat);
    ext_data_control_device_v1_add_listener(d.device, &deviceListener, nullptr);
    say("event=started display=%s dir=%s pid=%d", display.c_str(), d.dir.c_str(), getpid());

    while (!stopping) {
        while (wl_display_prepare_read(d.display) != 0)
            wl_display_dispatch_pending(d.display);
        wl_display_flush(d.display);
        std::vector<pollfd> fds{{wl_display_get_fd(d.display), POLLIN, 0}, {d.server, POLLIN, 0}};
        for (const auto& client : d.clients)
            fds.push_back({client.fd, POLLIN, 0});
        if (d.capture)
            for (const auto& read : d.capture->reads)
                if (read.fd >= 0)
                    fds.push_back({read.fd, POLLIN, 0});
        for (const auto& job : d.writes)
            fds.push_back({job.fd, POLLOUT, 0});
        int  timeout = d.capture || !d.writes.empty() || !d.pending.empty() ? 100 : -1;
        int  ready   = poll(fds.data(), fds.size(), timeout);
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
        // clients accepted now have no slot in this poll
        const size_t polled = d.clients.size();
        for (size_t i = 0; i < polled; i++)
            if (fds[i + 2].revents)
                readClient(d.clients[i]);
        if (ready > 0 && (fds[1].revents & POLLIN))
            for (int fd; (fd = accept4(d.server, nullptr, nullptr, SOCK_CLOEXEC)) >= 0;) {
                d.clients.push_back({fd, {}});
                sendTo(d.clients.back(), entriesLine());
            }
        std::erase_if(d.clients, [](const Client& client) {
            char probe;
            bool gone = recv(client.fd, &probe, 1, MSG_PEEK | MSG_DONTWAIT) == 0;
            if (gone)
                close(client.fd);
            return gone;
        });
        pumpReads(fds);
        if (d.capture && now() - d.capture->started > captureMs)
            finishCapture("timeout");
        if (!d.pending.empty() && now() > d.pending.front().deadline)
            confirm("refused: selection not confirmed");
        pumpWrites();
    }
    unlink((d.dir / "control").c_str());
    say("event=stopped");
    return 0;
}
