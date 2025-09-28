-- menu.lua  (met AI-keuze)
local state      = require("state")
local menu       = {}
local aiCount = 1   -- standaard 1 AI

local menu = {
  useTwoDecks = false,   -- ⬅️ nieuwe toggle
  hoverIndex  = 1,
}

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


local cardBack = love.graphics.newImage("png/back.png")

local cards = {}


------------------------------ menu-opties
local function startAI(n)
  state.enter(require("game"), {
    mode      = "ai",
    aiCount   = n,
    deckCount = (menu.useTwoDecks and 2 or 1),
  })
end

local function startHost()
  state.enter(require("host_lobby"), {
    name      = "My Lobby",
    deckCount = (menu.useTwoDecks and 2 or 1),  -- doorgeven aan host lobby
  })
end

local function startJoin()
  state.enter(require("browser")) -- host bepaalt aantal decks
end

------------------------------ menu-opties
local options = {
  { key="1", label="Play vs 1 AI", next=function() startAI(1) end },
  { key="2", label="Play vs 2 AI", next=function() startAI(2) end },
  { key="3", label="Play vs 3 AI", next=function() startAI(3) end },
  { key="h", label="Host game",    next=function() startHost() end },
  { key="j", label="Join game",    next=function() startJoin() end },
}


-- hulpfunctie: teken een vinkje
local function draw_checkmark(x, y, s)
  love.graphics.setLineWidth(3)
  love.graphics.line(x, y + s*0.55, x + s*0.35, y + s, x + s, y)
  love.graphics.setLineWidth(1)
end


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

    -- cache de image op het 'menu' table (NIET op de functie zelf)
    if not menu._backImg then
        menu._backImg = love.graphics.newImage("png/back.png")
    end
    local backImg = menu._backImg
    local backW, backH = backImg:getWidth(), backImg:getHeight()

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

        -- gewenste afmeting (zelfde verhouding als je had)
        local cardW = card.size
        local cardH = card.size * 1.45

        -- schaal back.png exact naar cardW × cardH
        local sx = cardW / backW
        local sy = cardH / backH

        love.graphics.push()
        love.graphics.translate(x, y)
        love.graphics.rotate(rot)

        -- schaduw (kleine offset)
        love.graphics.setColor(0, 0, 0, 0.20)
        love.graphics.draw(backImg, 8, 10, 0, sx, sy, backW/2, backH/2)

        -- kaart (image)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(backImg, 0, 0, 0, sx, sy, backW/2, backH/2)

        -- witte outline
        love.graphics.setColor(1, 1, 1, 0.85)
        love.graphics.setLineWidth(4)
        love.graphics.rectangle("line", -cardW/2, -cardH/2, cardW, cardH, 20, 20)

        love.graphics.pop()
    end

    love.graphics.setFont(prevFont)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end


function menu.draw()
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()
  ensureFonts()
  if drawBackground then drawBackground(w, h) end
  if drawFloatingCards then drawFloatingCards(w, h) end

  -- Paneel-afmetingen (groter, zodat "Join game" niet botst met hints)
  local panelW = math.min(820, w * 0.80)
  local panelH = math.min(620, h * 0.78)
  local panelX = (w - panelW) / 2
  local panelY = (h - panelH) / 2

  -- Paneel
  love.graphics.setColor(0, 0, 0, 0.45)
  love.graphics.rectangle("fill", panelX + 10, panelY + 14, panelW, panelH, 24, 24)
  love.graphics.setColor(0.07, 0.14, 0.11, 0.94)
  love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 24, 24)
  love.graphics.setColor(1, 1, 1, 0.08)
  love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 24, 24)

  -- Titel + subtitel
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setFont(titleFont)
  local titleY = panelY + 36
  love.graphics.printf("Zweeds Pesten", panelX, titleY, panelW, "center")

  love.graphics.setFont(subtitleFont)
  love.graphics.setColor(1, 1, 1, 0.72)
  love.graphics.printf("Potje Zweeds??", panelX, titleY + 60, panelW, "center")

  -- Opties
  love.graphics.setFont(optionFont)
  local listY = titleY + 100
  local rowH  = 64
  local padX  = 40

  for i, opt in ipairs(options) do
    local y = listY + (i - 1) * rowH
    local isHover = (menu.hoverIndex == i)

    love.graphics.setColor(isHover and 0.32 or 0.12, 0.6, 0.28, isHover and 1 or 0.9)
    love.graphics.rectangle("fill", panelX + padX, y, panelW - 2 * padX, 44, 14, 14)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(opt.label, panelX + padX + 16, y + 10, panelW - 2 * padX - 32, "left")
    love.graphics.printf(("Press %s"):format(opt.key:upper()), panelX + padX, y + 10, panelW - 2 * padX - 16, "right")

    if not menu._rowRects then menu._rowRects = {} end
    menu._rowRects[i] = {
    x = panelX + padX,
    y = y,
    w = panelW - 2*padX,
    h = 44
        }
  end

  -- Checkbox “Speel met 2 decks”
  local checkY    = listY + #options * rowH + 24
  local checkX    = panelX + padX
  local checkSize = 26

  -- box rand
  love.graphics.setColor(1, 1, 1, 0.9)
  love.graphics.rectangle("line", checkX, checkY, checkSize, checkSize, 6, 6)

  -- indien aan: groen vlak + vinkje
  if menu.useTwoDecks then
    love.graphics.setColor(0.2, 0.7, 0.3, 0.9)
    love.graphics.rectangle("fill", checkX + 2, checkY + 2, checkSize - 4, checkSize - 4, 5, 5)
    love.graphics.setColor(1, 1, 1, 1)
    -- simpel vinkje
    love.graphics.setLineWidth(3)
    love.graphics.line(checkX + 4, checkY + checkSize * 0.55,
                       checkX + checkSize * 0.35, checkY + checkSize - 4,
                       checkX + checkSize - 4, checkY + 4)
    love.graphics.setLineWidth(1)
  end

  love.graphics.setColor(1, 1, 1, 0.9)
  love.graphics.setFont(optionFont)
  love.graphics.print("Speel met 2 decks", checkX + checkSize + 12, checkY + 2)

  -- Hints onderaan het paneel
  love.graphics.setFont(hintFont)
  love.graphics.setColor(1, 1, 1, 0.6)
  love.graphics.printf("• Gebrurik pijltjes of je muis •  Gebruik Enter om te starten •  D om decks te toggelen.",
    panelX + padX, checkY + checkSize + 20, panelW - 2 * padX, "left")

  -- klikgebieden bewaren (voor mousepressed)
  menu._checkRect = { x = checkX, y = checkY, w = checkSize, h = checkSize }
  menu._panelRect = { x = panelX, y = panelY, w = panelW, h = panelH }
end


function menu.mousepressed(x, y, btn)
  if btn ~= 1 then return end

  -- Checkbox togglen?
  local r = menu._checkRect
  if r and x>=r.x and x<=r.x+r.w and y>=r.y and y<=r.y+r.h then
    menu.useTwoDecks = not menu.useTwoDecks
    return
  end

  -- Klik op optie (gebruik de precieze rects uit draw)
  local rows = menu._rowRects or {}
  for i, rc in ipairs(rows) do
    if x>=rc.x and x<=rc.x+rc.w and y>=rc.y and y<=rc.y+rc.h then
      menu.hoverIndex = i
      if options and options[i] and options[i].next then
        options[i].next()
      end
      return
    end
  end
end


function menu.keypressed(key)
  if key == "down" then
    menu.hoverIndex = math.min(#options, menu.hoverIndex + 1)
  elseif key == "up" then
    menu.hoverIndex = math.max(1, menu.hoverIndex - 1)
  elseif key == "return" or key == "kpenter" then
    options[menu.hoverIndex].next()
  elseif key == "1" then options[1].next()
  elseif key == "2" then options[2].next()
  elseif key == "3" then options[3].next()
  elseif key == "h" then options[4].next()
  elseif key == "j" then options[5].next()
  elseif key == "d" then
    menu.useTwoDecks = not menu.useTwoDecks
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
