-- written by the installer for this machine, absent in a plain checkout
local found, here = pcall(require, "fluency.local")
if not found then return { env = {} } end
if type(here) ~= "table" then error("refused: fluency.local must return a table, got " .. type(here), 2) end
here.env = here.env or {}
return here
