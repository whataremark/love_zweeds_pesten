-- browser.lua
local state = require("state")
local net   = require("net")

local b     = {}
local bigF  = love.graphics.newFont(26)
local smaF  = love.graphics.newFont(18)

function b.load()
    b.hosts       = {}
    b.selected    = 1
    b.manualIP    = ""
    b.typing      = false
    b.scanTimer   = 0
end

function b.update(dt)
    b.scanTimer = b.scanTimer - dt
    if b.scanTimer <= 0 then
        b.scanTimer = 2
        b.hosts     = net.scan_lan()
        if #b.hosts == 0 then b.selected = 1 end
    end
end

function b.textinput(t)
    if b.typing then
        b.manualIP = b.manualIP .. t
    end
end

function b.keypressed(key)
    ----------------------------------------------------------------------
    -- 1.  Typ-modus: handmatig IP invoeren
    ----------------------------------------------------------------------
    if b.typing then
        if key == "return" then
            local ip = b.manualIP
            net.connect(ip)                                 -- ↩ verbind
            state.enter(require("client_lobby"), { ip = ip })-- ↩ ga lobby in
        elseif key == "backspace" then
            b.manualIP = b.manualIP:sub(1, -2)
        end
        return
    end

    ----------------------------------------------------------------------
    -- 2.  Navigeren in gevonden hosts-lijst
    ----------------------------------------------------------------------
    if key == "up"   then b.selected = (b.selected - 2) % #b.hosts + 1 end
    if key == "down" then b.selected =  b.selected      % #b.hosts + 1 end

    if key == "return" and #b.hosts > 0 then
        local ip = b.hosts[b.selected].ip
        net.connect(ip)                                   -- ↩ verbind
        state.enter(require("client_lobby"), { ip = ip }) -- ↩ ga lobby in
    elseif key == "i" then
        b.typing = true                                   -- start typen
    elseif key == "escape" then
        state.enter(require("menu"))                      -- terug
    end
end

function b.draw()
    love.graphics.setFont(bigF)
    love.graphics.printf("Zoek lobby's (druk I voor IP)", 0, 40, love.graphics.getWidth(), "center")

    local y = 100
    love.graphics.setFont(smaF)
    if #b.hosts == 0 then
        love.graphics.printf("Geen servers gevonden...",0,y, love.graphics.getWidth(), "center")
    else
        for i,h in ipairs(b.hosts) do
            local line = h.ip .. "  –  " .. h.name
            if i == b.selected then line = "→ " .. line end
            love.graphics.printf(line, 0, y, love.graphics.getWidth(), "center")
            y = y + 24
        end
    end

    if b.typing then
        love.graphics.printf("IP: " .. b.manualIP .. "_", 0, y+40, love.graphics.getWidth(), "center")
    end
end

return b
