-- menu.lua  (met AI-keuze)
local state      = require("state")
local menu       = {}

------------------------------ fonts één keer maken
local titleFont
local subtitleFont
local optionFont
local hintFont
local cardFont

local function ensureFonts()
    if titleFont then return end

    titleFont    = love.graphics.newFont(52)
    subtitleFont = love.graphics.newFont(24)
    optionFont   = love.graphics.newFont(22)
    hintFont     = love.graphics.newFont(16)
    cardFont     = love.graphics.newFont(26)
end

------------------------------ achtergrondkaartjes
local palette = {
    {0.14, 0.33, 0.24},
    {0.20, 0.46, 0.30},
    {0.11, 0.26, 0.20},
    {0.24, 0.52, 0.34},
}

local cards = {}

------------------------------ menu-opties
local options = {
    {key="a", label="Play vs AI",      next=function()
        state.enter(require("game"), {mode="ai"})
    end},
    {key="h", label="Host game",       next=function()
        state.enter(require("host_lobby"), {name="My Lobby"})
    end},
    {key="j", label="Join game",       next=function()
        state.enter(require("browser"))
    end},
    --AUTOMATISCH JOIN PC UTRECHT
    {key   = "d",
    label = "Debug-join 192.168.178.166",
    next  = function()
        require("net").connect("192.168.178.166")
        state.enter(require("client_lobby"), { ip = "192.168.178.166" })
    end
},
}

local function activateSelected()
    local index = menu.selected or 1
    local opt   = options[index]
    if not opt then
        return
    end
    menu.selected = index
    if opt.next then
        opt.next()
    end
end

function menu.load()
    menu.time     = 0
    menu.selected = 1

    ensureFonts()


    cards = {}
    local cardCount = 8
    for i = 1, cardCount do
        local angle = (i - 1) / cardCount * math.pi * 2
        cards[i] = {
            angle        = angle,
            radius       = 0.36 + 0.04 * (i % 3),
            phase        = love.math.random() * math.pi * 2,
            speed        = 0.6 + love.math.random() * 0.8,
            wobble       = 18 + love.math.random() * 14,
            baseRotation = -0.2 + 0.4 * love.math.random(),
            size         = 150 + love.math.random() * 20,
            color        = palette[(i - 1) % #palette + 1],
        }
    end
end

function menu.update(dt)
    menu.time = menu.time + dt
end

local function drawBackground(w, h)
    local steps = 12
    for i = 0, steps - 1 do
        local t   = i / (steps - 1)
        local r   = 0.03 * (1 - t) + 0.01 * t
        local g   = 0.18 * (1 - t) + 0.09 * t
        local b   = 0.11 * (1 - t) + 0.06 * t
        love.graphics.setColor(r, g, b)
        local y   = h * (i / steps)
        love.graphics.rectangle("fill", 0, y, w, h / steps + 1)
    end
    -- zachte spotlight
    love.graphics.setColor(1, 1, 1, 0.04)

    love.graphics.circle("fill", w * 0.6, h * 0.35, math.max(w, h) * 0.55)
end

local function drawFloatingCards(w, h)
    ensureFonts()
    local cx, cy   = w * 0.5, h * 0.52
    local radius   = math.min(w, h) * 0.42
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(cardFont)
    for _, card in ipairs(cards) do
        local wave  = math.sin(menu.time * card.speed + card.phase)
        local baseX = cx + math.cos(card.angle) * radius * 0.8
        local baseY = cy + math.sin(card.angle) * radius * 0.5
        local x     = baseX + wave * card.wobble
        local y     = baseY + math.cos(menu.time * (card.speed * 0.8) + card.phase) * card.wobble * 0.6
        local rot   = card.baseRotation + wave * 0.25
        local cardW = card.size
        local cardH = card.size * 1.45

        love.graphics.push()
        love.graphics.translate(x, y)
        love.graphics.rotate(rot)

        love.graphics.setColor(0, 0, 0, 0.18)
        love.graphics.rectangle("fill", -cardW / 2 + 8, -cardH / 2 + 10, cardW, cardH, 20, 20)

        love.graphics.setColor(card.color[1], card.color[2], card.color[3], 0.85)
        love.graphics.rectangle("fill", -cardW / 2, -cardH / 2, cardW, cardH, 20, 20)

        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.setLineWidth(4)
        love.graphics.rectangle("line", -cardW / 2, -cardH / 2, cardW, cardH, 20, 20)

        love.graphics.setColor(1, 1, 1, 0.85)
        love.graphics.printf("Zweeds\nPesten", -cardW / 2 + 14, -cardH / 2 + 26, cardW - 28, "center")

        love.graphics.pop()
    end
    love.graphics.setFont(prevFont)
    love.graphics.setLineWidth(1)
end

function menu.draw()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    ensureFonts()

    drawBackground(w, h)
    drawFloatingCards(w, h)

    local panelW   = math.min(560, w * 0.64)
    local panelH   = math.min(440, h * 0.7)
    local panelX   = (w - panelW) / 2
    local panelY   = (h - panelH) / 2
    local pulse    = 0.5 + 0.5 * math.sin(menu.time * 2.6)

    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle("fill", panelX + 10, panelY + 14, panelW, panelH, 24, 24)

    love.graphics.setColor(0.07, 0.14, 0.11, 0.94)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 24, 24)

    love.graphics.setColor(1, 1, 1, 0.08)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 24, 24)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(titleFont)
    love.graphics.printf("Zweeds Pesten", panelX, panelY + 36, panelW, "center")

    love.graphics.setFont(subtitleFont)
    love.graphics.setColor(1, 1, 1, 0.72)
    love.graphics.printf("A modern take on Dutch card chaos", panelX, panelY + 96, panelW, "center")

    local optionY = panelY + 150
    local optionH = 48
    love.graphics.setFont(optionFont)

    for i, opt in ipairs(options) do
        local isSelected = i == menu.selected
        local y          = optionY + (i - 1) * (optionH + 12)

        if isSelected then
            local glow = 0.18 + pulse * 0.22
            love.graphics.setColor(0.16 + glow * 0.4, 0.38 + glow, 0.21 + glow * 0.35, 0.94)
            love.graphics.rectangle("fill", panelX + 40, y - 6, panelW - 80, optionH + 12, 16, 16)
        end

        love.graphics.setColor(1, 1, 1, isSelected and 1 or 0.8)
        love.graphics.printf(opt.label, panelX + 60, y + 4, panelW - 120, "left")

        love.graphics.setColor(1, 1, 1, isSelected and 0.9 or 0.5)
        love.graphics.printf("Press " .. opt.key:upper(), panelX + 60, y + 4, panelW - 120, "right")

    end
    
    love.graphics.setFont(hintFont)
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.printf("Use ↑ ↓ or your mouse • Press Enter to launch", panelX, panelY + panelH - 44, panelW, "center")
end

function menu.keypressed(key)
    if not menu.selected then
        menu.selected = 1
    end
    if key == "up"   then
        menu.selected = (menu.selected - 2) % #options + 1
        return
    end
    if key == "down" then
        menu.selected =  menu.selected      % #options + 1
        return
    end

    local opt = options[menu.selected]
    if opt and (key == "return" or key == "kpenter" or key == "space" or key == opt.key) then
        activateSelected()

    end
end

function menu.mousepressed(x, y, button)
    if button ~= 1 then return end
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    
    local panelW = math.min(560, w * 0.64)
    local panelH = math.min(440, h * 0.7)
    local panelX = (w - panelW) / 2
    local panelY = (h - panelH) / 2
    local optionY = panelY + 150
    local optionH = 48

    for i, _ in ipairs(options) do
        local yOpt = optionY + (i - 1) * (optionH + 12)
        if x >= panelX + 40 and x <= panelX + panelW - 40 and y >= yOpt - 6 and y <= yOpt + optionH + 6 then
            menu.selected = i
            activateSelected()   -- activeer direct
            return
        end
    end
end
function menu.mousemoved(x, y)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local panelW = math.min(560, w * 0.64)
    local panelH = math.min(440, h * 0.7)
    local panelX = (w - panelW) / 2
    local panelY = (h - panelH) / 2
    local optionY = panelY + 150
    local optionH = 48

    if x < panelX or x > panelX + panelW or y < optionY - 12 or y > optionY + (#options - 1) * (optionH + 12) + optionH + 12 then
        return
    end

    for i, _ in ipairs(options) do
        local yOpt = optionY + (i - 1) * (optionH + 12)
        if x >= panelX + 40 and x <= panelX + panelW - 40 and y >= yOpt - 6 and y <= yOpt + optionH + 6 then
            menu.selected = i
            return
        end
    end
end


return menu
