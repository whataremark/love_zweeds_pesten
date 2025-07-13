-- host_lobby.lua
local state = require("state")
local net   = require("net")

local host  = {}
local bigF  = love.graphics.newFont(28)
local smallF= love.graphics.newFont(18)

function host.load(params)
    host.name       = params.name or "My Lobby"
    host.players    = { "You (host)" }
    host.ready      = false
    net.host()                          -- start TCP-server
end

-- host.update wordt in de main-update elke frame aangeroepen
function host.update(dt)
    net.update()                        -- reguliere netwerklogica
    net.update_lan(dt, host.name)       -- stuur beacon uit

    -- check nieuwe clients (placeholder – vul aan met echte net-code)
    local newName = net.poll_new_client_name and net.poll_new_client_name()
    if newName then
        table.insert(host.players, newName)
    end
end

function host.keypressed(key)
    if key == "s" and #host.players >= 2 then
        state.enter(require("game"), {mode="multiplayer-host"})
    elseif key == "escape" then
        state.enter(require("menu"))
    end
end

function host.draw()
    love.graphics.setFont(bigF)
    love.graphics.printf("Lobby: " .. host.name, 0, 60, love.graphics.getWidth(), "center")

    love.graphics.setFont(smallF)
    love.graphics.printf("Druk S om te starten, Esc om terug te gaan", 0, 110, love.graphics.getWidth(), "center")

    local y = 160
    for _,p in ipairs(host.players) do
        love.graphics.printf(p, 0, y, love.graphics.getWidth(), "center")
        y = y + 26
    end
end

return host
