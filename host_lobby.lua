-- host_lobby.lua
local state = require("state")
local net   = require("net")

local host  = {}

-------------------------------- fonts & visuals --------------------------------
local titleFont
local subtitleFont
local bodyFont
local smallFont
local cardFont

local palette = {
    {0.14, 0.33, 0.24},
    {0.20, 0.46, 0.30},
    {0.11, 0.26, 0.20},
    {0.24, 0.52, 0.34},
}

local function ensureFonts()
    if titleFont then return end

    titleFont    = love.graphics.newFont(44)
    subtitleFont = love.graphics.newFont(22)
    bodyFont     = love.graphics.newFont(18)
    smallFont    = love.graphics.newFont(16)
    cardFont     = love.graphics.newFont(26)
end

local function createCards()
    local cards = {}
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
    return cards
end

local function drawBackground(w, h)
    local steps = 12
    for i = 0, steps - 1 do
        local t = i / (steps - 1)
        local r = 0.03 * (1 - t) + 0.01 * t
        local g = 0.18 * (1 - t) + 0.09 * t
        local b = 0.11 * (1 - t) + 0.06 * t
        love.graphics.setColor(r, g, b)
        local y = h * (i / steps)
        love.graphics.rectangle("fill", 0, y, w, h / steps + 1)
    end

    love.graphics.setColor(1, 1, 1, 0.04)
    love.graphics.circle("fill", w * 0.6, h * 0.35, math.max(w, h) * 0.55)
end

local function drawFloatingCards(w, h, cards, time)
    if not cards then return end

    local cx, cy = w * 0.5, h * 0.52
    local radius = math.min(w, h) * 0.42
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(cardFont)

    for _, card in ipairs(cards) do
        local wave  = math.sin(time * card.speed + card.phase)
        local baseX = cx + math.cos(card.angle) * radius * 0.8
        local baseY = cy + math.sin(card.angle) * radius * 0.5
        local x     = baseX + wave * card.wobble
        local y     = baseY + math.cos(time * (card.speed * 0.8) + card.phase) * card.wobble * 0.6
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

-------------------------------- lifecycle --------------------------------

function host.load(params)
    ensureFonts()

    host.name       = params.name or "My Lobby"
    host.players    = { "You (host)" }
    host.ready      = false
    host.time       = 0
    host.cards      = createCards()

    net.host()                          -- start TCP-server
end

-- host.update wordt in de main-update elke frame aangeroepen
function host.update(dt)
    host.time = (host.time or 0) + dt

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
        state.enter(require("game"), {
        mode      = "multiplayer-host",
        deckCount = (args and args.deckCount) or 1,   -- ⬅️ uit menu
        })
    elseif key == "escape" then
        state.enter(require("menu"))
    end
end

function host.draw()
    ensureFonts()

    local w, h = love.graphics.getWidth(), love.graphics.getHeight()

    drawBackground(w, h)
    drawFloatingCards(w, h, host.cards, host.time or 0)

    local panelW = math.min(620, w * 0.7)
    local panelH = math.min(460, h * 0.72)
    local panelX = (w - panelW) / 2
    local panelY = (h - panelH) / 2
    local pulse  = 0.5 + 0.5 * math.sin((host.time or 0) * 2.3)
    local canStart = #host.players >= 2

    love.graphics.setColor(0, 0, 0, 0.32)
    love.graphics.rectangle("fill", panelX + 10, panelY + 14, panelW, panelH, 26, 26)

    love.graphics.setColor(0.07, 0.14, 0.11, 0.95)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 26, 26)

    love.graphics.setColor(1, 1, 1, 0.08)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 26, 26)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(titleFont)
    love.graphics.printf("Host Lobby", panelX, panelY + 32, panelW, "center")

    love.graphics.setFont(subtitleFont)
    love.graphics.setColor(1, 1, 1, 0.78)
    love.graphics.printf(host.name, panelX, panelY + 84, panelW, "center")

    local listTop   = panelY + 134
    local listLeft  = panelX + 48
    local listRight = panelX + panelW - 48
    local rowH      = 48

    love.graphics.setFont(bodyFont)

    for index, name in ipairs(host.players) do
        local rowY = listTop + (index - 1) * (rowH + 10)
        local highlight = 0.12 + pulse * 0.18

        love.graphics.setColor(0.12 + highlight * 0.5, 0.28 + highlight, 0.17 + highlight * 0.45, 0.92)
        love.graphics.rectangle("fill", listLeft, rowY, listRight - listLeft, rowH, 18, 18)

        love.graphics.setColor(1, 1, 1, 0.85)
        love.graphics.printf((index == 1 and "👑 " or "") .. name, listLeft + 18, rowY + 12, listRight - listLeft - 36, "left")
    end

    local infoY = listTop + math.max(0, #host.players) * (rowH + 10) + 8

    love.graphics.setFont(smallFont)
    love.graphics.setColor(1, 1, 1, 0.68)
    love.graphics.printf(string.format("Players connected: %d", #host.players), listLeft, infoY, listRight - listLeft, "left")

    infoY = infoY + 26

    local buttonW = listRight - listLeft
    local buttonH = 56
    local buttonX = listLeft
    local buttonY = infoY + 6

    if canStart then
        love.graphics.setColor(0.18 + pulse * 0.25, 0.48 + pulse * 0.3, 0.24 + pulse * 0.22, 0.98)
    else
        love.graphics.setColor(0.12, 0.2, 0.16, 0.6)
    end
    love.graphics.rectangle("fill", buttonX, buttonY, buttonW, buttonH, 18, 18)

    love.graphics.setColor(1, 1, 1, canStart and 0.95 or 0.5)
    love.graphics.setFont(bodyFont)
    love.graphics.printf("Press S to start", buttonX, buttonY + 16, buttonW, "center")

    local hintY = buttonY + buttonH + 40
    love.graphics.setFont(smallFont)
    love.graphics.setColor(1, 1, 1, 0.62)
    local hint = canStart and "Game launches once you press S." or "Waiting for at least one more player…"
    love.graphics.printf(hint .. "\nEsc to return to menu", panelX, hintY, panelW, "center")
end

return host
