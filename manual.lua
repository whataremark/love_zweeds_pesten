-- manual.lua — Spelregels / Handleiding
local manual = {}
local state  = require("state")

-- layout
local MARGIN   = 24
local TOP_PAD  = 16
local LINE     = 22

manual._fonts = {}

local function hit(x,y,r) return r and x>=r.x and x<=r.x+r.w and y>=r.y and y<=r.y+r.h end
local function bold(font, txt, x, y)
  love.graphics.setFont(font)
  love.graphics.print(txt, x, y)
  love.graphics.print(txt, x+1, y) -- simpele bold
end

function manual.load()
  manual._fonts.title   = love.graphics.newFont(32)
  manual._fonts.heading = love.graphics.newFont(20)
  manual._fonts.body    = love.graphics.newFont(16)
  manual._fonts.small   = love.graphics.newFont(12)
end

function manual.update(dt) end

function manual.draw()
  local W, H = love.graphics.getWidth(), love.graphics.getHeight()
  love.graphics.clear(0.12, 0.12, 0.12)

  -- paneel
  local panelW = W - MARGIN*2
  local panelH = H - MARGIN*2
  local panelX = MARGIN
  local panelY = MARGIN

  love.graphics.setColor(1,1,1,0.06)
  love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 12, 12)
  love.graphics.setColor(1,1,1,0.50)
  love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 12, 12)
  love.graphics.setColor(1,1,1,1)

  -- TERUG-knop: linksboven IN het paneel
  manual._backRect = { x = panelX + 12, y = panelY + 12, w = 52, h = 40 }
  local r = manual._backRect
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 8, 8)
  love.graphics.setFont(manual._fonts.body)
  love.graphics.print("ESC", r.x + 9, r.y + 9)
  love.graphics.setFont(manual._fonts.small)

-- GECENTREERDE TITEL …
local titleY = panelY + TOP_PAD
love.graphics.setFont(manual._fonts.title)
love.graphics.printf("Spelregels Zweeds Pesten", panelX, titleY, panelW, "center")

-- cursor voor content (start net onder de titel)
local x, y = panelX + 20, titleY + 56

-- Multiplayer callout (onder de titel)
do
  local bx, by, bw = panelX + 20, y, panelW - 40
  local bh = 60
  love.graphics.setColor(1, 0.85, 0.25, 0.10)
  love.graphics.rectangle("fill", bx, by, bw, bh, 10, 10)
  love.graphics.setColor(1, 0.85, 0.25, 0.9)
  love.graphics.rectangle("line", bx, by, bw, bh, 10, 10)
  love.graphics.setColor(1,1,1,1)

  local tx, ty = bx + 12, by + 10
  bold(manual._fonts.body, "Let op:", tx, ty)
  love.graphics.setFont(manual._fonts.body)
  love.graphics.print(
    " Multiplayer werkt in principe alleen lokaal. Voor online spelen gebruik RadminVPN (zat bij instalatiee van de game).",
    tx + manual._fonts.body:getWidth("Let op:"), ty
  )

  -- verplaats content onder de callout
  y = by + bh + 16
end


  local function h(txt)
    bold(manual._fonts.heading, txt, x, y)
    y = y + LINE + 6
  end
  local function line(txt)
    love.graphics.setFont(manual._fonts.body)
    love.graphics.print(txt, x, y)
    y = y + LINE
  end
  local function pair(labelBold, rest)
    love.graphics.setFont(manual._fonts.body)
    bold(manual._fonts.body, labelBold, x, y)
    local ox = x + manual._fonts.body:getWidth(labelBold .. " ")
    love.graphics.print(rest, ox, y)
    y = y + LINE
  end

  -- Doel
  h("Doel")
  line("Speel al je kaarten weg in de volgorde: hand → open (faceUp) → blind (faceDown).")

  -- Setup
  h("Setup")
  line("• Kies 3 open (faceUp) kaarten uit je hand.")
  line("• Startspeler: degene met de laagste startkaart in de hand (4; anders 5; anders 6; …).")

  -- Basisregels (gebruikers-perspectief)
  h("Basisregels")
  line("• Je speelt om beurten een kaart op de aflegstapel (de pot).")
  line("• Je mag alleen spelen als je kaart past volgens de regels bij de bovenste kaart.")
  line("• Kun of wil je niet spelen? Gebruik de knoppen in de UI (bijv. Pak pot of Pass) als dat kan.")

  -- Speciale kaarten (2,3,7,8,10)
  h("Speciale kaarten")
  pair("• 2 — Altijd toegestaan:", " je mag een 2 altijd spelen, ongeacht wat er ligt.")
  pair("• 3 — Doorzichtig:",      " telt niet mee voor de regels; kijk naar de kaart eronder.")
  pair("• 7 — ≤ 7 verplicht:",    " de volgende speler moet ≤ 7 spelen.")
  pair("• 8 — Extra beurt:",      " je mag nog een keer spelen (UI toont ‘PASS’ indien relevant).")
  pair("• 10 — Burn + extra beurt:", " de pot wordt leeggemaakt en je krijgt een extra beurt.")

  -- Beurtverloop
  h("Beurtverloop")
  pair("• Handfase:",  " speel 1 of meerdere kaarten met dezelfde waarde.")
  pair("• Openfase:",  " hand leeg? Dan speel je uit je open kaarten (zelfde regels).")
  pair("• Blindfase:", " open leeg? Klik een blinde kaart; wordt die geweigerd, dan neem je de hele pot en gaat de kaart naar je hand.")

  -- Overig
  h("Overig")
  line("• Multi-select: je mag meerdere gelijke waardes tegelijk spelen.")
  line("• Je kunt de pot in een overlay bekijken.")
  line("• Het spel eindigt als n−1 spelers klaar zijn; de UI toont de winnaar.")
  line("• BRUNZYN — vier-op-een-rij: leg je in één zet vier gelijke waardes (óf vul je twee gelijke op de pot aan met nog twee gelijke), dan is het burn met hetzelfde effect als 10 (pot leeg + extra beurt).")
  

  -- Besturing
  h("Besturing")
  line("• Klik selecteert kaarten en knoppen.")
  line("• Muiswiel: horizontaal scrollen door je hand.")
  line("• ESC of ← linksboven: terug naar het menu.")
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
  end
end

function manual.quit() end

return manual
