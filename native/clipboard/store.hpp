#pragma once
#include <cstdint>
#include <string>
#include <string_view>
#include <vector>

namespace clip {

inline constexpr std::string_view marker = "application/x-fluency-clipboard";

struct Format {
    std::string mime;
    std::string data;
};

struct Entry {
    uint64_t            id   = 0;
    int64_t             time = 0;
    std::string         app;
    std::string         title;
    std::vector<Format> formats;
    bool                pinned = false;
};

struct Limits {
    size_t items      = 25;
    size_t entryBytes = 16u << 20;
    size_t totalBytes = 128u << 20;
};

std::vector<std::string> wanted(const std::vector<std::string>& offered);
bool                     secret(const std::vector<std::string>& offered);
bool                     ours(const std::vector<std::string>& offered);
size_t                   bytes(const Entry& entry);
const Format*            image(const Entry& entry);
std::string              kind(const Entry& entry);
std::string              preview(const Entry& entry, size_t max);
std::vector<Format>      textOnly(const Entry& entry);
bool                     same(const std::vector<Format>& a, const std::vector<Format>& b);
std::string              escape(std::string_view text);
std::string              json(const Entry& entry, std::string_view imagePath, bool current);

class Store {
  public:
    explicit Store(Limits limits = {});

    const Entry*              add(Entry entry);
    const Entry*              find(uint64_t id) const;
    const Entry*              touch(uint64_t id, int64_t time);
    bool                      pin(uint64_t id, bool on);
    bool                      remove(uint64_t id);
    size_t                    clear();
    const std::vector<Entry>& entries() const;

  private:
    void               trim();

    Limits             m_limits;
    std::vector<Entry> m_entries;
    uint64_t           m_next = 1;
};

}
