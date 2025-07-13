-- menu.lua  (met AI-keuze)
local state      = require("state")
local menu       = {}

------------------------------ fonts één keer maken
local bigFont   = love.graphics.newFont(28)
local smallFont = love.graphics.newFont(20)

------------------------------ menu-opties
local options = {
    { key = "a", label = "Play vs AI",      mode = "ai"                 },
    { key = "h", label = "Host game",       mode = "multiplayer-host"   },
    { key = "j", label = "Join game",       mode = "multiplayer-client" },
}

function menu.load()
    menu.selected = 1
end

function menu.draw()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()

    love.graphics.setFont(bigFont)
    love.graphics.printf("Card Game", 0, h * 0.25, w, "center")

    love.graphics.setFont(smallFont)
    for i, opt in ipairs(options) do
        local y     = h * 0.45 + (i - 1) * 40
        local line  = opt.label .. " (press " .. opt.key:upper() .. ")"
        if i == menu.selected then line = "→ " .. line end
        love.graphics.printf(line, 0, y, w, "center")
    end
end

function menu.keypressed(key)
    if key == "up"   then menu.selected = (menu.selected - 2) % #options + 1; return end
    if key == "down" then menu.selected =  menu.selected      % #options + 1; return end

    local chosen = options[menu.selected]
    if key == "return" or key == "kpenter" or key == "space" or key == chosen.key then
        if chosen.mode == "multiplayer-host" then
            require("net").host()
        elseif chosen.mode == "multiplayer-client" then
            require("net").connect("127.0.0.1")
        end
        state.enter(require("game"), { mode = chosen.mode })
    end
end

function menu.mousepressed(x, y, button)
    if button ~= 1 then return end
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    for i, _ in ipairs(options) do
        local yOpt = h * 0.45 + (i - 1) * 40
        if y >= yOpt and y <= yOpt + 30 then
            menu.selected = i
            menu.keypressed("return")   -- activeer direct
            return
        end
    end
end

return menu
