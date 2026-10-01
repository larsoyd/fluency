require("fluency.animations")
require("fluency.looks")
require("fluency.alone")
require("fluency.cursor")
require("fluency.xwayland")
require("fluency.minimized")
require("fluency.shell")
require("fluency.titlebar")
require("fluency.startkey")
require("fluency.clipboard")
require("fluency.keys")
require("fluency.autostart")

for name, value in pairs(require("fluency.machine").env) do
    hl.env(name, value)
end
