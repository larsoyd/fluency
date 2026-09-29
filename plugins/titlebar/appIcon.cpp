#include "appIcon.hpp"

#include <algorithm>
#include <climits>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <map>
#include <optional>
#include <sstream>
#include <vector>
#include <hyprgraphics/image/Image.hpp>

namespace fs = std::filesystem;

using Group = std::map<std::string, std::string>;

static std::string lower(std::string s) {
    std::ranges::transform(s, s.begin(), [](unsigned char c) { return std::tolower(c); });
    return s;
}

static std::string trim(const std::string& s) {
    const auto first = s.find_first_not_of(' ');
    return first == std::string::npos ? "" : s.substr(first, s.find_last_not_of(' ') - first + 1);
}

static std::vector<std::string> split(const std::string& s, char sep) {
    std::vector<std::string> out;
    std::stringstream        in(s);
    for (std::string part; std::getline(in, part, sep);)
        if (!part.empty())
            out.push_back(part);
    return out;
}

static std::map<std::string, Group> readIni(const fs::path& path) {
    std::map<std::string, Group> groups;
    std::ifstream                in(path);
    std::string                  line, group;
    while (std::getline(in, line)) {
        if (line.starts_with('[') && line.ends_with(']'))
            group = line.substr(1, line.size() - 2);
        else if (const auto eq = line.find('='); eq != std::string::npos && !line.starts_with('#'))
            groups[group].try_emplace(trim(line.substr(0, eq)), trim(line.substr(eq + 1)));
    }
    return groups;
}

static std::vector<fs::path> dataDirs() {
    const auto               home = std::getenv("HOME");
    const auto               own  = std::getenv("XDG_DATA_HOME");
    const auto               rest = std::getenv("XDG_DATA_DIRS");
    std::vector<fs::path>    dirs;
    if (own && *own)
        dirs.emplace_back(own);
    else if (home)
        dirs.push_back(fs::path(home) / ".local/share");
    for (const auto& dir : split(rest && *rest ? rest : "/usr/local/share:/usr/share", ':'))
        dirs.emplace_back(dir);
    return dirs;
}

struct SEntry {
    std::string id, icon, wmClass;
    std::vector<std::string> exec;
};

static std::vector<std::string> execArgs(const std::string& exec) {
    std::vector<std::string> args;
    std::string              arg;
    bool                     quoted = false, any = false;
    for (size_t i = 0; i < exec.size(); ++i) {
        const char c = exec[i];
        if (c == '"') {
            quoted = !quoted;
            any    = true;
        } else if (c == '\\' && quoted && i + 1 < exec.size())
            arg += exec[++i];
        else if (c == ' ' && !quoted) {
            if (any || !arg.empty())
                args.push_back(arg);
            arg.clear();
            any = false;
        } else
            arg += c;
    }
    if (any || !arg.empty())
        args.push_back(arg);
    return args;
}

// earlier data dirs win, the same id further down is shadowed
static std::vector<SEntry> desktopEntries() {
    std::vector<SEntry> entries;
    std::vector<std::string> seen;
    for (const auto& base : dataDirs()) {
        const auto apps = base / "applications";
        std::error_code ec;
        for (auto it = fs::recursive_directory_iterator(apps, ec); !ec && it != fs::recursive_directory_iterator(); it.increment(ec)) {
            if (it->path().extension() != ".desktop")
                continue;
            auto id = fs::relative(it->path(), apps).string();
            std::ranges::replace(id, '/', '-');
            if (std::ranges::find(seen, id) != seen.end())
                continue;
            seen.push_back(id);
            auto group = readIni(it->path())["Desktop Entry"];
            if (group["Hidden"] == "true")
                continue;
            entries.push_back({id, group["Icon"], group["StartupWMClass"], execArgs(group["Exec"])});
        }
    }
    return entries;
}

static const SEntry* byClass(const std::vector<SEntry>& entries, const std::string& appClass) {
    if (appClass.empty())
        return nullptr;
    const auto want = lower(appClass);
    for (const auto& e : entries)
        if (lower(e.id) == want + ".desktop" || (!e.wmClass.empty() && lower(e.wmClass) == want))
            return &e;
    return nullptr;
}

static bool numericId(const std::string& id) {
    return !id.empty() && id != "0" && id.find_first_not_of("0123456789") == std::string::npos;
}

static std::string steamId(const std::string& appClass, int pid) {
    if (appClass.starts_with("steam_app_") && numericId(appClass.substr(10)))
        return appClass.substr(10);
    if (pid <= 0)
        return {};
    std::ifstream environ("/proc/" + std::to_string(pid) + "/environ", std::ios::binary);
    std::string   field;
    while (std::getline(environ, field, '\0')) {
        if (field.starts_with("SteamAppId=") || field.starts_with("SteamGameId=")) {
            const auto value = field.substr(field.find('=') + 1);
            if (numericId(value))
                return value;
        }
    }
    return {};
}

static const SEntry* bySteamId(const std::vector<SEntry>& entries, const std::string& id) {
    if (id.empty())
        return nullptr;
    const auto url = "steam://rungameid/" + id;
    for (const auto& e : entries)
        if (std::ranges::find(e.exec, url) != e.exec.end())
            return &e;
    return nullptr;
}

static std::vector<fs::path> iconBases() {
    std::vector<fs::path> bases;
    if (const auto home = std::getenv("HOME"))
        bases.push_back(fs::path(home) / ".icons");
    for (const auto& dir : dataDirs())
        bases.push_back(dir / "icons");
    return bases;
}

// the directory distance of the icon theme spec, lower is closer
static int sizeDistance(Group& dir, int size) {
    const int  wanted = std::atoi(dir["Size"].c_str());
    const auto type   = dir["Type"].empty() ? "Threshold" : dir["Type"];
    if (type == "Fixed")
        return std::abs(wanted - size);
    int low = wanted, high = wanted;
    if (type == "Scalable") {
        low  = dir["MinSize"].empty() ? wanted : std::atoi(dir["MinSize"].c_str());
        high = dir["MaxSize"].empty() ? wanted : std::atoi(dir["MaxSize"].c_str());
    } else {
        const int threshold = dir["Threshold"].empty() ? 2 : std::atoi(dir["Threshold"].c_str());
        low  = wanted - threshold;
        high = wanted + threshold;
    }
    return size < low ? low - size : size > high ? size - high : 0;
}

static std::optional<fs::path> inTheme(const std::string& theme, const std::string& name, int size, std::vector<std::string>& visited) {
    if (std::ranges::find(visited, theme) != visited.end())
        return std::nullopt;
    visited.push_back(theme);
    // the first index.theme describes the theme, its directories are looked up under every base
    const auto bases = iconBases();
    std::map<std::string, Group> index;
    for (const auto& base : bases)
        if (index = readIni(base / theme / "index.theme"); !index.empty())
            break;
    if (index.empty())
        return std::nullopt;
    std::optional<fs::path> best;
    int                     bestDistance = INT_MAX;
    for (const auto& dir : split(index["Icon Theme"]["Directories"], ',')) {
        const int distance = sizeDistance(index[dir], size);
        if (distance >= bestDistance)
            continue;
        for (const auto& base : bases)
            for (const auto ext : {".png", ".svg"})
                if (const auto file = base / theme / dir / (name + ext); distance < bestDistance && fs::exists(file)) {
                    best         = file;
                    bestDistance = distance;
                }
    }
    if (best)
        return best;
    for (const auto& parent : split(index["Icon Theme"]["Inherits"], ','))
        if (auto found = inTheme(parent, name, size, visited))
            return found;
    return std::nullopt;
}

static std::optional<fs::path> lookupIcon(const std::string& name, int size) {
    if (name.empty())
        return std::nullopt;
    if (name.starts_with('/'))
        return fs::exists(name) ? std::optional<fs::path>{name} : std::nullopt;
    std::vector<std::string> visited;
    for (const auto theme : {"Papirus-Dark", "hicolor"})
        if (auto found = inTheme(theme, name, size, visited))
            return found;
    for (const auto& dir : dataDirs())
        for (const auto ext : {".png", ".svg"})
            if (fs::exists(dir / "pixmaps" / (name + ext)))
                return dir / "pixmaps" / (name + ext);
    return std::nullopt;
}

cairo_surface_t* loadAppIcon(const std::string& appClass, const std::string& initialClass, int size, int pid) {
    const auto entries = desktopEntries();
    auto       entry   = byClass(entries, appClass);
    if (!entry && initialClass != appClass)
        entry = byClass(entries, initialClass);
    if (!entry)
        entry = bySteamId(entries, steamId(appClass, pid));

    auto path = entry ? lookupIcon(entry->icon, size) : std::nullopt;
    if (!path)
        path = lookupIcon(appClass, size);
    if (!path)
        path = lookupIcon("application-x-executable", size);
    if (!path)
        return nullptr;

    Hyprgraphics::CImage image(path->string(), {double(size), double(size)});
    if (!image.success())
        return nullptr;
    const auto source = image.cairoSurface()->cairo();
    const auto width = cairo_image_surface_get_width(source), height = cairo_image_surface_get_height(source);
    if (width <= 0 || height <= 0)
        return nullptr;
    const auto surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, size, size);
    const auto cr      = cairo_create(surface);
    const auto scale   = std::min(double(size) / width, double(size) / height);
    cairo_translate(cr, (size - width * scale) / 2, (size - height * scale) / 2);
    cairo_scale(cr, scale, scale);
    cairo_set_source_surface(cr, source, 0, 0);
    cairo_pattern_set_filter(cairo_get_source(cr), CAIRO_FILTER_GOOD);
    cairo_paint(cr);
    cairo_destroy(cr);
    cairo_surface_flush(surface);
    return surface;
}
