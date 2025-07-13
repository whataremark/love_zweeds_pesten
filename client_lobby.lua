local state = require("state")
local net   = require("net")

local lobby = {}
local big   = love.graphics.newFont(26)
local sma   = love.graphics.newFont(18)

function lobby.load(info)           -- info.ip wordt meegegeven
    lobby.ip       = info.ip
    lobby.tick     = 0
    lobby.connected= false
end

function lobby.update(dt)
    net.update()                    -- blijf netwerk pompen
    if not lobby.connected and net.started then
        lobby.connected = true      -- eerste STATE binnen
    end
    if lobby.connected then
        state.enter(require("game"), { mode = "multiplayer-client" })
    end
end

function lobby.keypressed(key)
    if key == "escape" then state.enter(require("menu")) end
end

function lobby.draw()
    love.graphics.setFont(big)
    love.graphics.printf("Verbonden met "..lobby.ip, 0, 120,
                         love.graphics.getWidth(), "center")
    love.graphics.setFont(sma)
    love.graphics.printf("Wachten tot host S indrukt…\nEsc = terug",
                         0, 170, love.graphics.getWidth(), "center")
end

return lobby