-- manual.lua — Spelregels / Handleiding (thumb fix + 4 kaarten bij BRUNZYN, no emojis/arrows)
local manual = {}
local state  = require("state")

-- ========== THEME ==========
local theme = {
  bg        = {0.10, 0.10, 0.11},
  panelFill = {1,1,1,0.04},
  panelLine = {1,1,1,0.08},
  text      = {0.96, 0.96, 0.98},
  textDim   = {0.78, 0.78, 0.82},
  callWarnFill = {1.00, 0.85, 0.25, 0.10},
  callWarnLine = {1.00, 0.85, 0.25, 0.90},
  callInfoFill = {0.28, 0.64, 0.94, 0.10},
  callInfoLine = {0.28, 0.64, 0.94, 0.90},
  chipFill  = {1,1,1,0.06},
  chipLine  = {1,1,1,0.18},
  imgBg     = {0,0,0,0.25},
  shadow    = {0,0,0,0.25},
}

-- ========== LAYOUT ==========
local MARGIN   = 24
local PADDING  = 20
local RADIUS   = 14
local TOPBAR_H = 56

manual._fonts = {}
manual._scroll = 0
manual._contentH = 0
manual._backRect = nil
manual._hoverBack = false

-- Kaart thumbnails
manual._cardImgs = {
  ["2"]  = nil,
  ["3"]  = nil,
  ["7"]  = nil,
  ["8"]  = nil,
  ["10"] = nil,
  BRUNZYN = nil, -- decoratief/keuze voor meerdere
}

-- ========== HELPERS ==========
local function clamp(v, a, b) return math.max(a, math.min(b, v)) end
local function hit(x,y,r) return r and x>=r.x and x<=r.x+r.w and y>=r.y and y<=r.y+r.h end
local function setColor(c) love.graphics.setColor(c[1], c[2], c[3], c[4] or 1) end

local function fakeBold(font, txt, x, y)
  love.graphics.setFont(font)
  love.graphics.print(txt, math.floor(x), math.floor(y))
  love.graphics.print(txt, math.floor(x)+1, math.floor(y)) -- simpele bold
end

local function drawShadowRect(x,y,w,h,rx,ry)
  setColor(theme.shadow);    love.graphics.rectangle("fill", x+2, y+3, w, h, rx, ry)
  setColor(theme.panelFill); love.graphics.rectangle("fill", x, y, w, h, rx, ry)
  setColor(theme.panelLine); love.graphics.rectangle("line", x, y, w, h, rx, ry)
  setColor(theme.text)
end

-- paragraph met wrapping, geeft hoogte terug
local function paragraph(text, font, x, y, w, color)
  setColor(color or theme.text)
  love.graphics.setFont(font)
  local _, wrapped = font:getWrap(text, w)
  local h = #wrapped * font:getHeight()
  love.graphics.printf(text, math.floor(x), math.floor(y), w, "left")
  return h
end

local function heading(text, fonts, x, y)
  fakeBold(fonts.heading, text, x, y)
  return fonts.heading:getHeight() + 8
end

local function bullet(text, fonts, x, y, w)
  local dot = "* "
  local bx = x + fonts.body:getWidth(dot)
  setColor(theme.text)
  love.graphics.setFont(fonts.body)
  love.graphics.print(dot, math.floor(x), math.floor(y))
  local h = paragraph(text, fonts.body, bx, y, w - (bx - x))
  return h
end

local function callout(kind, title, body, fonts, x, y, w)
  local fill = kind=="warn" and theme.callWarnFill or theme.callInfoFill
  local line = kind=="warn" and theme.callWarnLine or theme.callInfoLine
  local pad = 14
  local innerW = w - pad*2

  love.graphics.setFont(fonts.body)
  local titleW = fonts.body:getWidth(title .. " ")
  local _, wrapBody = fonts.body:getWrap(body, innerW - titleW)
  local bodyH = #wrapBody * fonts.body:getHeight()
  local totalH = bodyH + fonts.body:getHeight() + pad*2

  setColor(fill); love.graphics.rectangle("fill", x, y, w, totalH, 10,10)
  setColor(line); love.graphics.rectangle("line", x, y, w, totalH, 10,10)

  local cx, cy = x + pad, y + pad
  setColor(theme.text)
  love.graphics.setFont(fonts.body)
  fakeBold(fonts.body, title, cx, cy)
  local offsetX = cx + titleW
  love.graphics.print(body, math.floor(offsetX), math.floor(cy))
  return totalH + 10
end

-- Image loader met mipmaps + nette filter (voor kleine thumbnails)
local function loadCardPNG(path)
  local ok, img = pcall(love.graphics.newImage, path, {mipmaps = true})
  if ok and img then
    img:setFilter("linear", "linear", 8)  -- anisotropy voor scherpte bij verkleinen
    return img
  end
  return nil
end

-- Probeer in volgorde hearts, spades, diamonds, clubs
local function anySuitFor(rank)
  local tries = {
    "png/"..rank.."_of_hearts.png",
    "png/"..rank.."_of_spades.png",
    "png/"..rank.."_of_diamonds.png",
    "png/"..rank.."_of_clubs.png",
  }
  for i=1,#tries do
    local img = loadCardPNG(tries[i])
    if img then return img end
  end
  return nil
end

-- Tekent een nette thumbnail met vaste maat, achtergrond en border
local function drawCardThumb(img, x, y, maxW, maxH)
  if not img then
    -- vlak als placeholder
    setColor(theme.imgBg)
    love.graphics.rectangle("fill", x, y, maxW, maxH, 8,8)
    setColor(theme.chipLine)
    love.graphics.rectangle("line", x, y, maxW, maxH, 8,8)
    setColor(theme.text)
    return maxW, maxH
  end
  local iw, ih = img:getWidth(), img:getHeight()
  local scale = math.min(maxW/iw, maxH/ih)
  local rw = iw*scale
  local rh = ih*scale

  -- achtergrond voor contrast
  setColor(theme.imgBg)
  love.graphics.rectangle("fill", math.floor(x), math.floor(y), maxW, maxH, 8,8)
  setColor(theme.chipLine)
  love.graphics.rectangle("line", math.floor(x), math.floor(y), maxW, maxH, 8,8)

  -- gecentreerd tekenen, pixel-snapped
  local dx = math.floor(x + (maxW - rw)/2)
  local dy = math.floor(y + (maxH - rh)/2)
  setColor({1,1,1,1})
  love.graphics.draw(img, dx, dy, 0, scale, scale)

  return maxW, maxH
end

-- VERVANG je huidige specialCardWithThumb(...) door deze versie
-- (voorkomt overlap binnen de kaart-container voor ALLE speciale kaarten)

local function specialCardWithThumb(rankLabel, desc, img, fonts, x, y, w)
  local pad = 12
  local innerW = w - pad*2

  -- Layout-parameters
  local GAP = 10             -- ruimte tussen thumb en tekst
  local MIN_THUMB_W = 44     -- ondergrens breedte thumb
  local MAX_THUMB_W = 64     -- bovengrens breedte thumb
  local ASPECT = 66/48       -- zelfde verhouding als in brunzynCard

  -- Typografie
  love.graphics.setFont(fonts.body)
  local labelH = fonts.body:getHeight()

  -- Probeer eerst "thumb links, tekst rechts"
  -- Bepaal een thumb-breedte zodat tekst minstens minTextW krijgt.
  local minTextW = 160
  local maxLeftThumbW = innerW - minTextW - GAP
  local thumbW = math.floor(math.min(MAX_THUMB_W, math.max(MIN_THUMB_W, maxLeftThumbW)))
  local layoutSideBySide = (thumbW >= MIN_THUMB_W)

  -- Als side-by-side niet past, val terug op "thumb boven, tekst onder"
  if not layoutSideBySide then
    thumbW = math.floor(math.max(MIN_THUMB_W, math.min(MAX_THUMB_W, (innerW - GAP*3) / 4)))
  end

  local thumbH = math.floor(thumbW * ASPECT)

  -- Tekstbreedte
  local textW = layoutSideBySide and (innerW - (thumbW + GAP)) or innerW
  if textW < 80 then
    -- absolute veiligheidsnet: forceer stacked layout
    layoutSideBySide = false
    textW = innerW
  end

  -- Teksthoogte meten
  local _, wrapDesc = fonts.body:getWrap(desc, textW)
  local descH = #wrapDesc * fonts.body:getHeight()

  -- Kaart-hoogte bepalen
  local contentH = layoutSideBySide
    and math.max(thumbH, descH)
    or  (thumbH + 8 + descH)

  local h = pad + labelH + 6 + contentH + pad

  -- Container tekenen
  setColor(theme.chipFill); love.graphics.rectangle("fill", x, y, w, h, 12,12)
  setColor(theme.chipLine); love.graphics.rectangle("line", x, y, w, h, 12,12)

  -- Label
  setColor(theme.text)
  fakeBold(fonts.body, rankLabel, x+pad, y+pad)

  -- Content start
  local cx = x + pad
  local cy = y + pad + labelH + 6

  if layoutSideBySide then
    -- Thumb links, tekst rechts (zonder overlap)
    drawCardThumb(img, math.floor(cx), math.floor(cy), thumbW, thumbH)
    setColor(theme.textDim)
    love.graphics.printf(desc, cx + thumbW + GAP, cy, textW, "left")
  else
    -- Thumb boven, tekst onder (smalle kaarten/kolom)
    drawCardThumb(img, math.floor(cx), math.floor(cy), thumbW, thumbH)
    setColor(theme.textDim)
    love.graphics.printf(desc, cx, cy + thumbH + 8, textW, "left")
  end

  return h + 12
end


-- vervang je bestaande brunzynCard(...) door deze versie (voorkomt overlappende thumbs)
local function brunzynCard(desc, img, fonts, x, y, w)
  local pad = 12
  local innerW = w - pad*2

  -- typografie
  love.graphics.setFont(fonts.body)
  local label = "BRUNZYN - vier-op-een-rij"
  local labelH = fonts.body:getHeight()

  -- ===== Dynamische layout zonder overlap =====
  -- we proberen 4 thumbnails naast elkaar te plaatsen met een vaste gap.
  -- Past dat niet (te smal), dan stapelen we: 4 thumbs op een rij en tekst eronder.
  local GAP = 10
  local MIN_THUMB_W, MAX_THUMB_W = 44, 64        -- grenzen voor nette schaal
  local ASPECT = 66/48                            -- verhouding uit eerdere thumbs (≈ 1.375)
  local thumbW = MAX_THUMB_W

  -- Beschikbaar voor thumbs als we "side-by-side" willen (laat min. 160px voor tekst)
  local minTextW = 160
  local maxThumbsW = innerW - minTextW - 12
  thumbW = math.floor(math.min(MAX_THUMB_W, (maxThumbsW - 3*GAP) / 4))

  local layoutSideBySide = thumbW >= MIN_THUMB_W
  if not layoutSideBySide then
    -- te smal voor side-by-side: gebruik volle breedte voor 4 thumbs en zet tekst eronder
    thumbW = math.floor(math.max(MIN_THUMB_W, (innerW - 3*GAP) / 4))
  end

  local thumbH = math.floor(thumbW * ASPECT)

  -- herbereken maten voor tekst
  local thumbsTotalW = thumbW*4 + GAP*3
  local textW = layoutSideBySide and (innerW - thumbsTotalW - 12) or innerW

  -- meet teksthoogte
  local _, wrapDesc = fonts.body:getWrap(desc, textW)
  local descH = #wrapDesc * fonts.body:getHeight()

  -- hoogte van de component
  local contentH
  if layoutSideBySide then
    contentH = math.max(thumbH, descH)
  else
    contentH = thumbH + 8 + descH
  end
  local h = pad + labelH + 6 + contentH + pad

  -- ===== Teken container =====
  setColor(theme.chipFill); love.graphics.rectangle("fill", x, y, w, h, 12,12)
  setColor(theme.chipLine); love.graphics.rectangle("line", x, y, w, h, 12,12)

  -- label
  setColor(theme.text)
  fakeBold(fonts.body, label, x+pad, y+pad)

  -- content start
  local cx = x + pad
  local cy = y + pad + labelH + 6

  -- helper om 4 kaarten zonder overlap te tekenen
  local function drawFour(atX, atY)
    for i = 0, 3 do
      drawCardThumb(img, math.floor(atX + i*(thumbW + GAP)), math.floor(atY), thumbW, thumbH)
    end
  end

  if layoutSideBySide then
    -- thumbs links, tekst rechts
    drawFour(cx, cy)
    setColor(theme.textDim)
    love.graphics.printf(desc, cx + thumbsTotalW + 12, cy, textW, "left")
  else
    -- thumbs boven, tekst onder
    drawFour(cx, cy)
    setColor(theme.textDim)
    love.graphics.printf(desc, cx, cy + thumbH + 8, textW, "left")
  end

  return h + 12
end


-- ========== LOVE CALLBACKS ==========
function manual.load()
  manual._fonts.title   = love.graphics.newFont(34)
  manual._fonts.heading = love.graphics.newFont(22)
  manual._fonts.body    = love.graphics.newFont(16)
  manual._fonts.small   = love.graphics.newFont(12)

  -- Kaartafbeeldingen uit dezelfde map als je deck
  manual._cardImgs["2"]    = anySuitFor("2")
  manual._cardImgs["3"]    = anySuitFor("3")
  manual._cardImgs["7"]    = anySuitFor("7")
  manual._cardImgs["8"]    = anySuitFor("8")
  manual._cardImgs["10"]   = anySuitFor("10")
  manual._cardImgs.BRUNZYN = anySuitFor("ace") or anySuitFor("9") or anySuitFor("10")
end

function manual.update(dt)
  local mx, my = love.mouse.getPosition()
  manual._hoverBack = hit(mx, my, manual._backRect)
end

function manual.wheelmoved(dx, dy)
  local W, H = love.graphics.getWidth(), love.graphics.getHeight()
  local viewH = H - MARGIN*2 - TOPBAR_H - PADDING*2
  local maxScroll = math.max(0, manual._contentH - viewH)
  manual._scroll = clamp(manual._scroll - dy * 40, 0, maxScroll)
end

function manual.draw()
  local W, H = love.graphics.getWidth(), love.graphics.getHeight()
  setColor(theme.bg); love.graphics.clear(theme.bg)

  -- Panel
  local panelW = W - MARGIN*2
  local panelH = H - MARGIN*2
  local panelX = MARGIN
  local panelY = MARGIN
  drawShadowRect(panelX, panelY, panelW, panelH, RADIUS, RADIUS)

  -- Topbar
  setColor(theme.panelFill)
  love.graphics.rectangle("fill", panelX, panelY, panelW, TOPBAR_H, RADIUS, RADIUS)
  setColor(theme.panelLine)
  love.graphics.line(panelX, panelY+TOPBAR_H, panelX+panelW, panelY+TOPBAR_H)

  -- Back button (links in topbar)
  local bx, by, bw, bh = panelX + 12, panelY + 10, 80, TOPBAR_H - 20
  manual._backRect = {x=bx, y=by, w=bw, h=bh}
  if manual._hoverBack then
    setColor(theme.chipFill); love.graphics.rectangle("fill", bx, by, bw, bh, 10,10)
    setColor(theme.chipLine); love.graphics.rectangle("line", bx, by, bw, bh, 10,10)
  end
  setColor(theme.text)
  love.graphics.setFont(manual._fonts.body)
  love.graphics.print("ESC", math.floor(bx+16), math.floor(by + (bh - manual._fonts.body:getHeight())/2))

  -- Titel
  setColor(theme.text)
  love.graphics.setFont(manual._fonts.title)
  love.graphics.printf("Spelregels Zweeds Pesten", panelX, panelY + (TOPBAR_H - manual._fonts.title:getHeight())/2, panelW, "center")

  -- Content area
  local cx = panelX + PADDING
  local cy = panelY + TOPBAR_H + PADDING
  local cw = panelW - PADDING*2
  local ch = panelH - TOPBAR_H - PADDING*2
  love.graphics.setScissor(cx, cy, cw, ch)

  local x = cx
  local y = cy - manual._scroll

  -- Callouts
  y = y + callout("warn", "Let op:", "Multiplayer is lokaal. Voor online spelen kun je RadminVPN gebruiken (meegeleverd bij installatie).", manual._fonts, x, y, cw)
  y = y + callout("info", "Tip:", "Om je naam te in te dienen moet je na het invullen van je naam in het tekstvak op ENTER drukken.", manual._fonts, x, y, cw)
  y = y + 8

  -- Doel (zonder pijltjes)
  y = y + heading("Doel", manual._fonts, x, y)
  y = y + paragraph("Speel al je kaarten weg in de volgorde: eerst de hand, daarna de open (faceUp) kaarten, daarna de blind (faceDown) kaarten.", manual._fonts.body, x, y, cw, theme.textDim) + 12

  -- Basisregels (incl. hoger leggen)
  y = y + heading("Basisregels", manual._fonts, x, y)
  y = y + bullet("Je speelt om beurten op de aflegstapel (de pot).", manual._fonts, x, y, cw)
  y = y + bullet("Standaard leg je hoger dan de bovenste kaart volgens normale kaartvolgorde, behalve wanneer een speciale kaart iets anders afdwingt.", manual._fonts, x, y, cw)
  y = y + bullet("Kun of wil je niet spelen? Gebruik de knoppen in de UI (bijv. Pak pot of Pass) als dat kan.", manual._fonts, x, y, cw) + 8

  -- Setup
  y = y + heading("Setup", manual._fonts, x, y)
  y = y + bullet("Kies 3 open (faceUp) kaarten uit je hand.", manual._fonts, x, y, cw)
  y = y + bullet("Startspeler: degene met de laagste startkaart in de hand (4; anders 5; anders 6; enz.).", manual._fonts, x, y, cw) + 8

  -- Speciale kaarten (grid met thumbnails)
  y = y + heading("Speciale kaarten", manual._fonts, x, y)
  local col = 2
  local gap = 12
  local cardW = (cw - gap) / col
  local sx, sy = x, y

  local h1 = specialCardWithThumb("2 - Altijd toegestaan",
    "Je mag een 2 altijd spelen, ongeacht wat er ligt. De 2 reset ook de pot dus de volgende mag alles spelen. Let op: de pot blijft wel liggen.",
    manual._cardImgs["2"], manual._fonts, sx, sy, cardW)

  local h2 = specialCardWithThumb("3 - Doorzichtig",
    "Mag ook altijd gespeeld worden. Telt niet mee voor de regels; kijk naar de kaart eronder.",
    manual._cardImgs["3"], manual._fonts, sx+cardW+gap, sy, cardW)

  sy = sy + math.max(h1, h2)

  h1 = specialCardWithThumb("7 - Maximaal 7",
    "De volgende speler moet een kaart spelen die kleiner of gelijk aan 7 is.",
    manual._cardImgs["7"], manual._fonts, sx, sy, cardW)

  h2 = specialCardWithThumb("8 - Extra beurt",
    "Na het spelen van een 8 mag je direct nog een beurt nemen. Je volgende kaart moet wel een 8 of hoger zijn, als het een 8 is mag je nog een keer.",
    manual._cardImgs["8"], manual._fonts, sx+cardW+gap, sy, cardW)

  sy = sy + math.max(h1, h2)

  h1 = specialCardWithThumb("10 - Burn en extra beurt",
    "De pot wordt leeggemaakt (burn) en je krijgt een extra beurt.",
    manual._cardImgs["10"], manual._fonts, sx, sy, cardW)

  h2 = brunzynCard(
    "Leg je in één zet vier gelijke waardes (of vul je twee gelijke op de pot aan met nog twee gelijke), dan is het burn met hetzelfde effect als 10 (pot leeg en extra beurt).",
    manual._cardImgs.BRUNZYN, manual._fonts, sx+cardW+gap, sy, cardW)

  y = sy + math.max(h1, h2) + 6

  -- Beurtverloop
  y = y + heading("Beurtverloop", manual._fonts, x, y)
  y = y + bullet("Handfase: speel een of meerdere kaarten met dezelfde waarde.", manual._fonts, x, y, cw)
  y = y + bullet("Openfase: als je hand leeg is, speel je vanuit je open kaarten.", manual._fonts, x, y, cw)
  y = y + bullet("Blindfase: als je open kaarten op zijn, klik je een blinde kaart. Wordt die geweigerd, dan neem je de hele pot op hand.", manual._fonts, x, y, cw) + 8

  -- Overig
  y = y + heading("Overig", manual._fonts, x, y)
  y = y + bullet("Multi-select: je mag meerdere gelijke waardes tegelijk spelen.", manual._fonts, x, y, cw)
  y = y + bullet("Je kunt de pot in een overlay bekijken.", manual._fonts, x, y, cw)
  y = y + bullet("Het spel eindigt zodra n-1 spelers klaar zijn; de UI toont de winnaar.", manual._fonts, x, y, cw) + 10

  -- Besturing
  y = y + heading("Besturing", manual._fonts, x, y)
  y = y + bullet("Muis: klik selecteert kaarten en knoppen.", manual._fonts, x, y, cw)
  y = y + bullet("Muiswiel: horizontaal scrollen door je hand.", manual._fonts, x, y, cw)
  y = y + bullet("Met Spatie speel je een kaart.", manual._fonts, x, y, cw)
  y = y + bullet("ESC: terug naar het menu.", manual._fonts, x, y, cw) + 10

  -- Footer
  setColor(theme.textDim)
  love.graphics.setFont(manual._fonts.small)
  love.graphics.print("Handleiding v1.3", math.floor(x), math.floor(y))
  y = y + manual._fonts.small:getHeight()

  -- content hoogte (voor scroll)
  manual._contentH = y - (cy - manual._scroll)

  love.graphics.setScissor()

  -- Scrollbar
  local viewH = ch
  local maxScroll = math.max(0, manual._contentH - viewH)
  if maxScroll > 2 then
    local barH = math.max(30, (viewH / manual._contentH) * viewH)
    local t = (manual._scroll / maxScroll)
    local barY = cy + t * (viewH - barH)
    setColor(theme.chipFill)
    love.graphics.rectangle("fill", cx+cw-4, cy, 4, viewH, 2,2)
    setColor(theme.chipLine)
    love.graphics.rectangle("fill", cx+cw-6, barY, 6, barH, 3,3)
  end
end

function manual.mousepressed(x, y, button)
  if button ~= 1 then return end
  if hit(x, y, manual._backRect) then
    state.enter(require("menu"))
  end
end

function manual.keypressed(key)
  if key == "escape" then
    state.enter(require("menu"))
  elseif key == "pageup" then
    manual._scroll = clamp(manual._scroll - 200, 0, math.max(0, manual._contentH))
  elseif key == "pagedown" then
    manual._scroll = clamp(manual._scroll + 200, 0, math.max(0, manual._contentH))
  end
end

function manual.quit() end

return manual
