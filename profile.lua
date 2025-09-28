-- profile.lua
local json = require("json")

local profile = { filename = "profile.json", data = nil }

local function load_raw()
  if profile.data then return profile.data end
  if love.filesystem.getInfo(profile.filename) then
    local s = love.filesystem.read(profile.filename)
    local ok, obj = pcall(json.decode, s or "")
    if ok and type(obj) == "table" then
      profile.data = obj
    end
  end
  if not profile.data then
    -- simpele default
    local rnd = tostring(math.random(1000, 9999))
    profile.data = { name = "Speler " .. rnd }
  end
  return profile.data
end

function profile.get_name()
  local d = load_raw()
  return d.name or "Speler"
end

function profile.set_name(n)
  local d = load_raw()
  d.name = tostring(n or ""):match("^%s*(.-)%s*$")
  if d.name == "" then d.name = "Speler" end
  love.filesystem.write(profile.filename, json.encode(d))
end

function profile.has_custom_name()
  local d = load_raw()
  return d and d.name and not d.name:match("^Speler %d+$")
end

return profile
