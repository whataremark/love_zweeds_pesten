local state = require("state")
local net   = require("net")
local profile = require("profile")

local lobby = {}

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

function lobby.load(info)
  ensureFonts()
  lobby.ip = info.ip
  lobby.time = 0
  lobby.cards = createCards()
  lobby.connected = false

  net.send({
    cmd  = "JOIN",
    id   = net.localId,             -- client = 2
    name = require("profile").get_name()
  })
end

function lobby.update(dt)
    lobby.time = (lobby.time or 0) + dt

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
    ensureFonts()

    local w, h = love.graphics.getWidth(), love.graphics.getHeight()

    drawBackground(w, h)
    drawFloatingCards(w, h, lobby.cards, lobby.time or 0)

    local panelW = math.min(620, w * 0.7)
    local panelH = math.min(420, h * 0.68)
    local panelX = (w - panelW) / 2
    local panelY = (h - panelH) / 2
    local pulse  = 0.5 + 0.5 * math.sin((lobby.time or 0) * 2.3)

    love.graphics.setColor(0, 0, 0, 0.32)
    love.graphics.rectangle("fill", panelX + 10, panelY + 14, panelW, panelH, 26, 26)

    love.graphics.setColor(0.07, 0.14, 0.11, 0.95)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 26, 26)

    love.graphics.setColor(1, 1, 1, 0.08)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 26, 26)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(titleFont)
    love.graphics.printf("Joining Lobby", panelX, panelY + 36, panelW, "center")

    love.graphics.setFont(subtitleFont)
    love.graphics.setColor(1, 1, 1, 0.78)
    love.graphics.printf("Connecting to " .. (lobby.ip or "?"), panelX, panelY + 90, panelW, "center")

    love.graphics.setFont(bodyFont)
    love.graphics.setColor(1, 1, 1, 0.85)
    local statusY = panelY + 150
    love.graphics.printf("Waiting for the host to start the match…", panelX + 60, statusY, panelW - 120, "center")

    local dots = string.rep(".", 1 + math.floor(((lobby.time or 0) * 3) % 3))
    love.graphics.printf("Ready" .. dots, panelX + 60, statusY + 46, panelW - 120, "center")

    local barW = panelW - 160
    local barH = 14
    local barX = panelX + 80
    local barY = statusY + 104

    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", barX, barY, barW, barH, 8, 8)

    local progress = 0.4 + 0.3 * math.sin((lobby.time or 0) * 3.4)
    love.graphics.setColor(0.2 + pulse * 0.25, 0.52 + pulse * 0.28, 0.26 + pulse * 0.22, 0.9)
    love.graphics.rectangle("fill", barX, barY, barW * progress, barH, 8, 8)

    love.graphics.setFont(smallFont)
    love.graphics.setColor(1, 1, 1, 0.65)
    love.graphics.printf("Sit tight! The game will launch automatically.\nPress Esc to return to the menu.", panelX, panelY + panelH - 72, panelW, "center")
end

return lobby
