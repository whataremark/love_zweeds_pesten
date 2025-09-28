-- host_lobby.lua
local state  = require("state")
local net    = require("net")
local player = require("player")
local profile = require("profile")

local host = {}

------------------------------ fonts & visuals ------------------------------
local titleFont, subtitleFont, bodyFont, smallFont, cardFont
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
    love.graphics.rectangle("fill", -cardW/2 + 8, -cardH/2 + 10, cardW, cardH, 20, 20)

    love.graphics.setColor(card.color[1], card.color[2], card.color[3], 0.85)
    love.graphics.rectangle("fill", -cardW/2, -cardH/2, cardW, cardH, 20, 20)

    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", -cardW/2, -cardH/2, cardW, cardH, 20, 20)

    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.printf("Zweeds\nPesten", -cardW/2 + 14, -cardH/2 + 26, cardW - 28, "center")

    love.graphics.pop()
  end

  love.graphics.setFont(prevFont)
  love.graphics.setLineWidth(1)
end

------------------------------ lifecycle ------------------------------
function host.load(params)
  ensureFonts()

  host.name    = params.name or (profile.get_name() .. "'s Lobby")
  host.players = { profile.get_name() .. " (host)" }
  host.deckCount  = (params and params.deckCount) or 1     -- ⬅️ togglebaar
  host.cards      = createCards()
  host.time       = 0

  -- Host netwerk starten
  net.host()
  -- Lobby-naam voor beacon
  net.lobbyName   = host.name

  -- Host-naam instellen / broadcasten
  local myName = net.playerName or "Host"
  if net.identify then net.identify(myName) end

  host.players    = { (net.playerName or "Host") .. " (host)" }

  -- Paneel rect cache voor mouse hit-tests
  host._panelRect = nil
  host._toggleRect = nil
end

function host.update(dt)
  host.time = (host.time or 0) + dt

  -- let op: net.update verwacht dt
  net.update(dt)
  net.update_lan(dt, host.name)

  -- nieuwe client-namen uit wachtrij
  local n = net.poll_new_client_name and net.poll_new_client_name()
  while n do
    -- voorkom dubbele items naast herhaald JOIN
    local seen
    for _,v in ipairs(host.players) do if v == n then seen = true; break end end
    if not seen then table.insert(host.players, n) end
    n = net.poll_new_client_name()
  end
end

function host.keypressed(key)
  if key == "s" then
    if #host.players >= 2 then
      state.enter(require("game"), {
        mode      = "multiplayer-host",
        deckCount = host.deckCount,   -- ⬅️ doorgeven aan game
      })
    end
  elseif key == "escape" then
    state.enter(require("menu"))
  end
end

function host.mousepressed(x, y, btn)
  if btn ~= 1 then return end
  -- toggle 2-decks checkbox
  local r = host._toggleRect
  if r and x>=r.x and x<=r.x+r.w and y>=r.y and y<=r.y+r.h then
    host.deckCount = (host.deckCount == 1) and 2 or 1
    return
  end
  local s = host._startRect
  local canStart = #host.players >= 2
  if canStart and s and x>=s.x and x<=s.x+s.w and y>=s.y and y<=s.y+s.h then
    state.enter(require("game"), {
      mode      = "multiplayer-host",
      deckCount = host.deckCount,
    })
    return
  end
end

function host.draw()
  ensureFonts()
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()

  drawBackground(w, h)
  drawFloatingCards(w, h, host.cards, host.time or 0)

  local panelW = math.min(620, w * 0.7)
  local panelH = math.min(520, h * 0.76)
  local panelX = (w - panelW) / 2
  local panelY = (h - panelH) / 2
  local pulse  = 0.5 + 0.5 * math.sin((host.time or 0) * 2.3)
  local canStart = #host.players >= 2

  host._panelRect = { x=panelX, y=panelY, w=panelW, h=panelH }

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

  local yAfterList = listTop + math.max(0, #host.players) * (rowH + 10) + 10

  -- Deck toggle
  local toggleW, toggleH = 220, 36
  local toggleX = listLeft
  local toggleY = yAfterList + 4
  host._toggleRect = { x=toggleX, y=toggleY, w=toggleW, h=toggleH }

  love.graphics.setFont(smallFont)
  love.graphics.setColor(1,1,1, 0.9)
  love.graphics.print("Gebruik 2 decks:", toggleX, toggleY+8)
  local boxX = toggleX + 150
  local boxY = toggleY + 4
  local boxS = 28
  love.graphics.setColor(1,1,1, 0.9)
  love.graphics.rectangle("line", boxX, boxY, boxS, boxS, 6, 6)
  if host.deckCount == 2 then
    love.graphics.setColor(1,1,1, 0.9)
    love.graphics.setLineWidth(3)
    love.graphics.line(boxX+6, boxY+14, boxX+12, boxY+20, boxX+22, boxY+8)
    love.graphics.setLineWidth(1)
  end

  local buttonW = listRight - listLeft
  local buttonH = 56
  local buttonX = listLeft
  local buttonY = toggleY + toggleH + 18

  if canStart then
    love.graphics.setColor(0.18 + pulse * 0.25, 0.48 + pulse * 0.3, 0.24 + pulse * 0.22, 0.98)
  else
    love.graphics.setColor(0.12, 0.2, 0.16, 0.6)
  end
  love.graphics.rectangle("fill", buttonX, buttonY, buttonW, buttonH, 18, 18)

  love.graphics.setColor(1, 1, 1, canStart and 0.95 or 0.5)
  love.graphics.setFont(bodyFont)
    love.graphics.printf(
    canStart and "Game Starten" or "Wacht op minstens 1 extra speler…",
    buttonX, buttonY + 16, buttonW, "center"
  )
  host._startRect = { x = buttonX, y = buttonY, w = buttonW, h = buttonH }


  local hintY = buttonY + buttonH + 40
  love.graphics.setFont(smallFont)
  love.graphics.setColor(1, 1, 1, 0.62)
  local hint = canStart and "Game start als je S drukt" or "Waiting for at least one more player…"
  love.graphics.printf(hint .. "\nEsc om terug te gaan naar het menu", panelX, hintY, panelW, "center")
end

return host
