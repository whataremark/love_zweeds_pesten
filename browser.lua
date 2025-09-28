-- browser.lua
local state = require("state")
local net   = require("net")

local browser = {}

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
function browser.load()
  ensureFonts()
  browser.hosts     = {}
  browser.selected  = 1
  browser.manualIP  = ""
  browser.typingIP  = false
  browser.scanTimer = 0
  browser.time      = 0
  browser.cards     = createCards()
  browser._panelRect = nil
end

function browser.update(dt)
  browser.time = (browser.time or 0) + dt

  browser.scanTimer = (browser.scanTimer or 0) - dt
  if browser.scanTimer <= 0 then
    browser.scanTimer = 2
    browser.hosts     = net.scan_lan() or {}   -- { {ip=..., name=...}, ... }

    if #browser.hosts == 0 then
      browser.selected = 1
    else
      browser.selected = math.max(1, math.min(browser.selected, #browser.hosts))
    end
  end
end

local function connectTo(ip)
  if not ip or #ip == 0 then return end
  net.connect(ip)

  -- Stuur meteen onze naam als we die hebben
  local name = net.playerName or "Client"
  if net.send then
    net.send({ cmd = "JOIN", id = net.localId, name = name })
  end

  state.enter(require("client_lobby"), { ip = ip })
end

function browser.keypressed(key)
  if browser.typingIP then
    if key == "return" then
      connectTo(browser.manualIP)
    elseif key == "backspace" then
      browser.manualIP = browser.manualIP:sub(1, -2)
    elseif key == "escape" then
      browser.typingIP = false
    end
    return
  end

  local hostCount = #browser.hosts
  if key == "up" and hostCount > 0 then
    browser.selected = (browser.selected - 2) % hostCount + 1
    return
  end
  if key == "down" and hostCount > 0 then
    browser.selected = browser.selected % hostCount + 1
    return
  end

  if key == "return" and hostCount > 0 then
    local ip = browser.hosts[browser.selected].ip
    connectTo(ip)
  elseif key == "i" then
    browser.typingIP = true
  elseif key == "escape" then
    state.enter(require("menu"))
  end
end

function browser.textinput(t)
  if browser.typingIP then
    browser.manualIP = browser.manualIP .. t
  end
end

function browser.mousepressed(x, y, btn)
  if btn ~= 1 then return end
  local r = browser._panelRect
  if not r then return end

  local listLeft  = r.x + 54
  local listRight = r.x + r.w - 54
  local listTop   = r.y + 140
  local rowH      = 56
  local rowGap    = 12

  -- klik in host-rijen?
  for i, host in ipairs(browser.hosts) do
    local rowY = listTop + (i - 1) * (rowH + rowGap)
    local rx, ry, rw, rh = listLeft, rowY, (listRight - listLeft), rowH
    if x>=rx and x<=rx+rw and y>=ry and y<=ry+rh then
      browser.selected = i
      connectTo(host.ip)
      return
    end
  end

  -- klik in manual IP box?
  local manualTop   = listTop + math.max(1, #browser.hosts) * (rowH + rowGap) + 24
  local manualLeft  = listLeft
  local manualW     = listRight - listLeft
  local manualH     = 54
  if x>=manualLeft and x<=manualLeft+manualW and y>=manualTop and y<=manualTop+manualH then
    browser.typingIP = true
  else
    browser.typingIP = false
  end
end

function browser.draw()
  ensureFonts()

  local w, h = love.graphics.getWidth(), love.graphics.getHeight()

  drawBackground(w, h)
  drawFloatingCards(w, h, browser.cards, browser.time or 0)

  local panelW = math.min(720, w * 0.78)
  local panelH = math.min(540, h * 0.80)
  local panelX = (w - panelW) / 2
  local panelY = (h - panelH) / 2
  local pulse  = 0.5 + 0.5 * math.sin((browser.time or 0) * 2.4)

  browser._panelRect = { x=panelX, y=panelY, w=panelW, h=panelH }

  love.graphics.setColor(0, 0, 0, 0.34)
  love.graphics.rectangle("fill", panelX + 12, panelY + 16, panelW, panelH, 28, 28)

  love.graphics.setColor(0.07, 0.14, 0.11, 0.95)
  love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 28, 28)

  love.graphics.setColor(1, 1, 1, 0.08)
  love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 28, 28)

  love.graphics.setColor(1, 1, 1)
  love.graphics.setFont(titleFont)
  love.graphics.printf("Join a Lobby", panelX, panelY + 36, panelW, "center")

  love.graphics.setFont(subtitleFont)
  love.graphics.setColor(1, 1, 1, 0.78)
  love.graphics.printf("Scanning your network for hosts", panelX, panelY + 86, panelW, "center")

  local listTop   = panelY + 140
  local listLeft  = panelX + 54
  local listRight = panelX + panelW - 54
  local rowH      = 56
  local rowGap    = 12

  love.graphics.setFont(bodyFont)

  if #browser.hosts == 0 then
    love.graphics.setColor(1, 1, 1, 0.72)
    love.graphics.printf("No lobbies detected yet…", listLeft, listTop + 8, listRight - listLeft, "center")
  else
    for index, host in ipairs(browser.hosts) do
      local rowY = listTop + (index - 1) * (rowH + rowGap)
      local isSelected = index == browser.selected
      local highlight  = 0.16 + pulse * 0.2

      if isSelected then
        love.graphics.setColor(0.16 + highlight * 0.4, 0.38 + highlight, 0.21 + highlight * 0.35, 0.94)
      else
        love.graphics.setColor(0.11, 0.22, 0.17, 0.72)
      end
      love.graphics.rectangle("fill", listLeft, rowY, listRight - listLeft, rowH, 18, 18)

      love.graphics.setColor(1, 1, 1, isSelected and 0.94 or 0.78)
      love.graphics.printf(host.name or "Unknown host", listLeft + 20, rowY + 6, listRight - listLeft - 40, "left")

      love.graphics.setColor(1, 1, 1, isSelected and 0.85 or 0.60)
      love.graphics.printf(host.ip or "?", listLeft + 20, rowY + 26, listRight - listLeft - 40, "left")
    end
  end

  -- Manual IP box
  local manualTop   = listTop + math.max(1, #browser.hosts) * (rowH + rowGap) + 24
  local manualLeft  = listLeft
  local manualW     = listRight - listLeft
  local manualH     = 54

  if browser.typingIP then
    love.graphics.setColor(0.18 + pulse * 0.25, 0.48 + pulse * 0.3, 0.24 + pulse * 0.22, 0.98)
  else
    love.graphics.setColor(0.12, 0.2, 0.16, 0.72)
  end
  love.graphics.rectangle("fill", manualLeft, manualTop, manualW, manualH, 16, 16)

  love.graphics.setFont(bodyFont)
  love.graphics.setColor(1, 1, 1, 0.9)
  local caret = browser.typingIP and ((math.floor((browser.time or 0) * 2) % 2 == 0) and "_" or "") or ""
  local ipText = browser.manualIP
  if not browser.typingIP and #ipText == 0 then
    ipText = "Press I to enter an IP"
    love.graphics.setColor(1, 1, 1, 0.55)
    caret = ""
  end
  love.graphics.printf(ipText .. caret, manualLeft + 20, manualTop + 16, manualW - 40, "left")

  love.graphics.setFont(smallFont)
  love.graphics.setColor(1, 1, 1, 0.62)
  love.graphics.printf("Use ↑ ↓ to pick a lobby • Enter to join • I to type an IP\nEsc to return to the menu",
                       panelX, panelY + panelH - 80, panelW, "center")
end

return browser
