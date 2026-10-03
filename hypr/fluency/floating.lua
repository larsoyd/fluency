-- steam, games and every thunderbird window but the main one keep their own size and place
local rules = {
    { name = "float-steam", match = { class = "^steam$" } },
    { name = "float-games", match = { class = "^(steam_app_[0-9]+|gamescope|.*\\.exe)$" } },
    { name = "float-game-content", match = { content = "game" } },
    { name = "float-thunderbird-dialogs", match = {
        class         = "^(org\\.mozilla\\.Thunderbird|thunderbird)$",
        initial_title = "negative:^Mozilla Thunderbird$",
    } },
}

for _, rule in ipairs(rules) do
    hl.window_rule({ name = rule.name, match = rule.match, float = true })
end
