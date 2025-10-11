-- settings.lua
local state = require("state")
local json  = require("json")

local settings = {
  _file = "settings.json",
  data = {
    fullscreen = false,
    width  = 1280,
    height = 720,
  },
  options = {
    { label = "1600 x 1000",  w = 1600, h = 1000 },
    { label = "1920 x 1080",  w = 1920, h = 1080 },
    { label = "2560 x 1440",  w = 2560, h = 1440 },
    { label = "1600 x 1440",  w = 1600, h = 1440 },
    { label = "3440 x 1440 (ultrawide)", w = 3440, h = 1440 },
  },
  hover = 1,

  -- achtergrond anim
  time  = 0,
  _backImg = nil,
  _cards = {},
}

-- kleine kleurenset (zelfde sfeer als menu)
local _palette = {
  {0.14, 0.33, 0.24},
  {0.20, 0.46, 0.30},
  {0.11, 0.26, 0.20},
  {0.24, 0.52, 0.34},
}

-- ---------- opslag ----------
function settings.load()
  local ok, blob = pcall(love.filesystem.read, settings._file)
  if ok and blob and #blob > 0 then
    local t = nil
    pcall(function() t = json.decode(blob) end)
    if type(t) == "table" then
      for k,v in pairs(t) do settings.data[k] = v end
    end
  end
end

function settings.save()
  local ok, blob = pcall(json.encode, settings.data)
  if ok and blob then love.filesystem.write(settings._file, blob) end
end

function settings.apply()
  local d = settings.data
  love.window.setMode(d.width, d.height, {
    fullscreen = d.fullscreen,
    resizable  = not d.fullscreen,
    highdpi    = true,
    msaa       = 0
  })
end

-- ---------- achtergrond helpers ----------
local function drawBackgroundGradient(w, h)
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

local function drawFloatingCards(w, h)
  if not settings._backImg then
    settings._backImg = love.graphics.newImage("png/back.png")
  end
  local back = settings._backImg
  local bw, bh = back:getWidth(), back:getHeight()

  local cx, cy = w * 0.5, h * 0.52
  local radius = math.min(w, h) * 0.42

  for _, card in ipairs(settings._cards) do
    local wave  = math.sin(settings.time * card.speed + card.phase)
    local baseX = cx + math.cos(card.angle) * radius * 0.8
    local baseY = cy + math.sin(card.angle) * radius * 0.5
    local x     = baseX + wave * card.wobble
    local y     = baseY + math.cos(settings.time * (card.speed * 0.8) + card.phase) * card.wobble * 0.6
    local rot   = card.baseRotation + wave * 0.25

    local cardW = card.size
    local cardH = card.size * 1.45
    local sx = cardW / bw
    local sy = cardH / bh

    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(rot)

    love.graphics.setColor(0, 0, 0, 0.20)
    love.graphics.draw(back, 8, 10, 0, sx, sy, bw/2, bh/2)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(back, 0, 0, 0, sx, sy, bw/2, bh/2)

    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", -cardW/2, -cardH/2, cardW, cardH, 18, 18)
    love.graphics.pop()
  end

  love.graphics.setLineWidth(1)
  love.graphics.setColor(1, 1, 1, 1)
end

-- ---------- state lifecycle ----------
function settings.load_state() settings.load() end
function settings.enter()
  settings.load()

  -- init anim cards
  settings._cards = {}
  local cardCount = 8
  for i = 1, cardCount do
    local angle = (i - 1) / cardCount * math.pi * 2
    settings._cards[i] = {
      angle        = angle,
      phase        = love.math.random() * math.pi * 2,
      speed        = 0.6 + love.math.random() * 0.8,
      wobble       = 18 + love.math.random() * 14,
      baseRotation = -0.2 + 0.4 * love.math.random(),
      size         = 140 + love.math.random() * 20,
      color        = _palette[(i - 1) % #_palette + 1],
    }
  end
end

function settings.update(dt)
  settings.time = settings.time + dt
end

-- ---------- input ----------
function settings.keypressed(key)
  if key == "escape" then
    local menu = require("menu")
    settings.save()
    settings.apply()
    state.enter(menu)
    return
  end
  if key == "return" or key == "kpenter" then
    local o = settings.options[settings.hover]
    settings.data.width  = o.w
    settings.data.height = o.h
    settings.save()
    settings.apply()
    return
  end
  if key == "up" then
    settings.hover = math.max(1, settings.hover - 1)
  elseif key == "down" then
    settings.hover = math.min(#settings.options, settings.hover + 1)
  elseif key == "f" then
    settings.data.fullscreen = not settings.data.fullscreen
    settings.save()
    settings.apply()
  end
end

function settings.mousepressed(mx, my, button)
  if button ~= 1 then return end

  local w, h   = love.graphics.getWidth(), love.graphics.getHeight()
  local panelW = math.min(680, w * 0.8)
  local panelH = math.min(520, h * 0.8)
  local panelX = (w - panelW) / 2
  local panelY = (h - panelH) / 2

  local listY = panelY + 130
  local rowH  = 52
  local padX  = 32

  -- resolutie-opties
  for i, opt in ipairs(settings.options) do
    local rowY = listY + (i-1) * rowH
    local rx, ry, rw, rh = panelX + padX, rowY, panelW - 2*padX, 42
    if mx>=rx and mx<=rx+rw and my>=ry and my<=ry+rh then
      settings.hover = i
      settings.data.width  = opt.w
      settings.data.height = opt.h
      settings.save()
      settings.apply()
      return
    end
  end

  -- fullscreen toggle
  local tx = panelX + padX
  local ty = listY + #settings.options * rowH + 20
  local fsRect = {x=tx, y=ty, w=24, h=24}
  if mx>=fsRect.x and mx<=fsRect.x+fsRect.w and my>=fsRect.y and my<=fsRect.y+fsRect.h then
    settings.data.fullscreen = not settings.data.fullscreen
    settings.save(); settings.apply()
    return
  end
end

-- ---------- draw ----------
local function draw_checkbox(x,y,checked,label)
  love.graphics.setColor(1,1,1,0.9)
  love.graphics.rectangle("line", x, y, 24, 24, 5, 5)
  if checked then
    love.graphics.setColor(0.2,0.8,0.3,0.9)
    love.graphics.rectangle("fill", x+3, y+3, 18, 18, 4, 4)
  end
  love.graphics.setColor(1,1,1,1)
  love.graphics.print(label, x+34, y+3)
end

function settings.draw()
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()

  -- 🔹 achtergrond
  drawBackgroundGradient(w, h)
  drawFloatingCards(w, h)

  -- paneel
  love.graphics.setColor(0,0,0,0.45)
  love.graphics.rectangle("fill", w*0.5-360+10, h*0.5-260+10, 720, 520, 22, 22)
  love.graphics.setColor(0.07,0.14,0.11,0.94)
  love.graphics.rectangle("fill", w*0.5-360, h*0.5-260, 720, 520, 22, 22)
  love.graphics.setColor(1,1,1,0.08)
  love.graphics.rectangle("line", w*0.5-360, h*0.5-260, 720, 520, 22, 22)

  love.graphics.setColor(1,1,1,1)
  love.graphics.setNewFont(30)
  love.graphics.printf("Instellingen", w*0.5-360, h*0.5-260+24, 720, "center")

  love.graphics.setNewFont(18)
  love.graphics.setColor(1,1,1,0.7)
  love.graphics.printf("ESC = Terug • Enter/Klik = Toepassen • F = Fullscreen", w*0.5-360, h*0.5-260+64, 720, "center")

  -- resoluties
  local listY = h*0.5-260+130
  local rowH  = 52
  local padX  = 32
  for i, opt in ipairs(settings.options) do
    local rowY = listY + (i-1)*rowH
    local isHover = (settings.hover == i)
    love.graphics.setColor(isHover and 0.32 or 0.12, 0.6, 0.28, isHover and 1 or 0.9)
    love.graphics.rectangle("fill", w*0.5-360+padX, rowY, 720-2*padX, 42, 12, 12)
    love.graphics.setColor(1,1,1,1)
    love.graphics.print(opt.label, w*0.5-360+padX+14, rowY+10)
  end

  -- fullscreen toggle
  local tx = w*0.5-360+padX
  local ty = listY + #settings.options * rowH + 20
  love.graphics.setColor(1,1,1,1)
  draw_checkbox(tx, ty, settings.data.fullscreen, "Fullscreen (F)")
end

return settings
