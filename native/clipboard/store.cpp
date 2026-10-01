#include "store.hpp"
#include <algorithm>
#include <array>
#include <cstdio>

namespace clip {

// x11 bookkeeping targets carry no data of their own
static constexpr std::array special = {"TARGETS", "MULTIPLE", "TIMESTAMP", "SAVE_TARGETS", "DELETE", "INSERT_PROPERTY", "INSERT_SELECTION", "LENGTH"};
static constexpr std::array texts   = {"text/plain;charset=utf-8", "UTF8_STRING", "text/plain", "STRING", "TEXT"};

static bool isImage(std::string_view mime) {
    return mime.starts_with("image/");
}

static bool has(const std::vector<std::string>& list, std::string_view item) {
    return std::ranges::find(list, item) != list.end();
}

std::vector<std::string> wanted(const std::vector<std::string>& offered) {
    const bool               png = has(offered, "image/png");
    bool                     tookImage = false;
    std::vector<std::string> out;
    for (const auto& mime : offered) {
        if (mime == marker || has(out, mime) || std::ranges::find(special, mime) != special.end())
            continue;
        if (isImage(mime)) {
            if (tookImage || (png && mime != "image/png"))
                continue;
            tookImage = true;
        }
        out.push_back(mime);
    }
    return out;
}

bool secret(const std::vector<std::string>& offered) {
    return has(offered, "x-kde-passwordManagerHint");
}

bool ours(const std::vector<std::string>& offered) {
    return has(offered, std::string(marker));
}

size_t bytes(const Entry& entry) {
    size_t sum = 0;
    for (const auto& format : entry.formats)
        sum += format.data.size();
    return sum;
}

const Format* image(const Entry& entry) {
    auto it = std::ranges::find_if(entry.formats, [](const Format& format) { return isImage(format.mime); });
    return it == entry.formats.end() ? nullptr : &*it;
}

static const Format* firstText(const Entry& entry) {
    for (auto mime : texts) {
        auto it = std::ranges::find(entry.formats, std::string_view(mime), &Format::mime);
        if (it != entry.formats.end())
            return &*it;
    }
    return nullptr;
}

std::string kind(const Entry& entry) {
    if (image(entry))
        return "image";
    if (std::ranges::find(entry.formats, std::string_view("text/uri-list"), &Format::mime) != entry.formats.end())
        return "files";
    return firstText(entry) ? "text" : "other";
}

// length of the utf-8 sequence at at, 0 when it is broken
static size_t sequence(std::string_view text, size_t at) {
    const auto lead = (unsigned char)text[at];
    size_t     size = lead < 0x80 ? 1 : (lead >> 5) == 6 ? 2 : (lead >> 4) == 14 ? 3 : (lead >> 3) == 30 ? 4 : 0;
    if (size == 0 || at + size > text.size())
        return 0;
    for (size_t i = 1; i < size; i++)
        if (((unsigned char)text[at + i] >> 6) != 2)
            return 0;
    return size;
}

std::string preview(const Entry& entry, size_t max) {
    auto format = firstText(entry);
    if (!format)
        return "";
    std::string_view text = format->data;
    std::string      out;
    for (size_t at = 0; at < text.size();) {
        size_t size = sequence(text, at);
        auto   piece = size ? text.substr(at, size) : std::string_view("\xEF\xBF\xBD");
        if (out.size() + piece.size() > max)
            break;
        out += piece;
        at += size ? size : 1;
    }
    return out;
}

std::vector<Format> textOnly(const Entry& entry) {
    std::vector<Format> out;
    for (const auto& format : entry.formats)
        if (std::ranges::find(texts, format.mime) != texts.end())
            out.push_back(format);
    return out;
}

std::string escape(std::string_view text) {
    std::string out;
    for (char c : text) {
        if (c == '"' || c == '\\')
            out += {'\\', c};
        else if (c == '\n')
            out += "\\n";
        else if (c == '\t')
            out += "\\t";
        else if (c == '\r')
            out += "\\r";
        else if ((unsigned char)c < 0x20) {
            char code[8];
            std::snprintf(code, sizeof code, "\\u%04x", c);
            out += code;
        } else
            out += c;
    }
    return out;
}

std::string json(const Entry& entry, std::string_view imagePath, bool current) {
    std::string mimes;
    for (const auto& format : entry.formats)
        mimes += (mimes.empty() ? "\"" : ",\"") + escape(format.mime) + "\"";
    return "{\"id\":" + std::to_string(entry.id) + ",\"time\":" + std::to_string(entry.time) + ",\"app\":\"" + escape(entry.app) + "\",\"title\":\"" + escape(entry.title) +
        "\",\"pinned\":" + (entry.pinned ? "true" : "false") + ",\"current\":" + (current ? "true" : "false") + ",\"kind\":\"" + kind(entry) + "\",\"text\":\"" +
        escape(preview(entry, 2000)) + "\",\"image\":\"" + escape(imagePath) + "\",\"mimes\":[" + mimes + "],\"bytes\":" + std::to_string(bytes(entry)) + "}";
}

bool same(const std::vector<Format>& a, const std::vector<Format>& b) {
    return a.size() == b.size() && std::ranges::all_of(a, [&](const Format& format) {
        auto it = std::ranges::find(b, format.mime, &Format::mime);
        return it != b.end() && it->data == format.data;
    });
}

Store::Store(Limits limits) : m_limits(limits) {}

const Entry* Store::add(Entry entry) {
    const size_t size = bytes(entry);
    if (size == 0 || size > m_limits.entryBytes)
        return nullptr;
    auto it = std::ranges::find_if(m_entries, [&](const Entry& other) { return same(other.formats, entry.formats); });
    if (it != m_entries.end()) {
        entry.id     = it->id;
        entry.pinned = entry.pinned || it->pinned;
        m_entries.erase(it);
    } else if (entry.id == 0)
        entry.id = m_next;
    m_next = std::max(m_next, entry.id + 1);
    m_entries.insert(m_entries.begin(), std::move(entry));
    trim();
    return &m_entries.front();
}

const Entry* Store::find(uint64_t id) const {
    auto it = std::ranges::find(m_entries, id, &Entry::id);
    return it == m_entries.end() ? nullptr : &*it;
}

const Entry* Store::touch(uint64_t id, int64_t time) {
    auto it = std::ranges::find(m_entries, id, &Entry::id);
    if (it == m_entries.end())
        return nullptr;
    it->time = time;
    std::rotate(m_entries.begin(), it, it + 1);
    return &m_entries.front();
}

bool Store::pin(uint64_t id, bool on) {
    auto it = std::ranges::find(m_entries, id, &Entry::id);
    if (it == m_entries.end())
        return false;
    it->pinned = on;
    trim();
    return true;
}

bool Store::remove(uint64_t id) {
    return std::erase_if(m_entries, [id](const Entry& entry) { return entry.id == id; }) > 0;
}

size_t Store::clear() {
    return std::erase_if(m_entries, [](const Entry& entry) { return !entry.pinned; });
}

const std::vector<Entry>& Store::entries() const {
    return m_entries;
}

// the oldest unpinned go first, pinned ones are never dropped
void Store::trim() {
    auto over = [&] {
        size_t count = 0, total = 0;
        for (const auto& entry : m_entries) {
            count += entry.pinned ? 0 : 1;
            total += bytes(entry);
        }
        return count > m_limits.items || total > m_limits.totalBytes;
    };
    while (over()) {
        auto last = std::ranges::find_if(m_entries.rbegin(), m_entries.rend(), [](const Entry& entry) { return !entry.pinned; });
        if (last == m_entries.rend())
            return;
        m_entries.erase(std::next(last).base());
    }
}

}
