-- Rendering and menu functions
local ui = {}
local game = require("game")
local config = require("config")
local player = require("player") 

local kaartHoogte = config.cardHeight
local schaal = config.scale
local kaartBreedte = config.cardWidth
local padding = config.cardPadding
local cardBack = love.graphics.newImage("png/back.png")

--fonts for titles
local groteTitelFont = love.graphics.newFont(40)
local kleineTitelFont = love.graphics.newFont(20)



--------------------------------------------------------------------
-- Hulpfuncties om de Y-posities van de rijen terug te geven
--------------------------------------------------------------------
local CARD_H_SRC, CARD_W_SRC = 500, 300      -- bron-afmetingen
local CARD_H      = 160
local SCALE_BASE  = CARD_H / CARD_H_SRC
--------------------------------------------------------------------
-- Kaart-constanten & helpers
--------------------------------------------------------------------
local TARGET_H = 140            -- alle kaarten komen 140 px hoog op scherm
local PADDING  = 15             -- ruimte tussen kaarten

-- schaal elke afbeelding naar TARGET_H
local function scale_to_target(img)
    return TARGET_H / img:getHeight()
end

--------------------------------------------------------------------
-- Y-posities voor open- en blind-rijen
-- • speler 1 (onderaan): rijen boven de hand
-- • speler 2 (AI, boven): rijen onder de hand
--------------------------------------------------------------------
-- Stel doelhoogte (TARGET_H) staat al bovenin op 140 px
local EXTRA_GAP = 70          -- extra afstand voor AI-rij

local function row_faceDown_Y(boxY, index)
    if index == 1 then                    -- Mens (onder): rij boven hand
        return boxY - TARGET_H - 10       -- 10 px marge
    else                                  -- AI (boven): rij onder hand
        return boxY + TARGET_H + EXTRA_GAP
    end
end

-- open kaart moet exact op de rug liggen → zelfde Y
local function row_faceUp_Y(boxY, index)
    return row_faceDown_Y(boxY, index)
end

-- Exporteer voor gebruik in mousepressed e.d.
ui.row_faceUp_Y    = row_faceUp_Y
ui.row_faceDown_Y  = row_faceDown_Y


----------------------MENU---------------------------------------
function ui.draw_menu(mouseX, mouseY)--------------------------------------------------------------------
-- Kaart-constanten & helpers
--------------------------------------------------------------------
--------------------------------------------------------------------
-- Y-posities voor open- en blind-rijen
-- • speler 1 (onderaan): rijen boven de hand
-- • speler 2 (AI, boven): rijen onder de hand
--------------------------------------------------------------------
local function row_faceDown_Y(boxY, index)
    if index == 1 then               -- mens
        return boxY - TARGET_H - 10  -- 10 px marge boven de hand
    else                              -- AI
        return boxY + TARGET_H + 10  -- 10 px onder zijn hand
    end
end

-- open kaart moet exact op de rug liggen → zelfde Y
local function row_faceUp_Y(boxY, index)
    return row_faceDown_Y(boxY, index)
end

-- Exporteer voor gebruik in mousepressed e.d.
ui.row_faceUp_Y    = row_faceUp_Y
ui.row_faceDown_Y  = row_faceDown_Y

    local w,h = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setFont(groteTitelFont)
    love.graphics.setColor(1,1,1)
    love.graphics.printf("Zweeds Pesten", 0, 150, w, "center")
    love.graphics.setFont(kleineTitelFont)

    local function button(txt,y)
        local bw,bh = 280,60
        local bx     = (w-bw)/2
        local hover  = mouseX>bx and mouseX<bx+bw and mouseY>y and mouseY<y+bh
        love.graphics.setColor(hover and 0.8 or 0.6,0.6,0.6)
        love.graphics.rectangle("fill",bx,y,bw,bh,8,8)
        love.graphics.setColor(0,0,0)
        love.graphics.printf(txt,bx,y+18,bw,"center")
        return hover,bx, y, bw,bh
    end

    ui.btnAI,  ui.aiX,  ui.aiY,  ui.aiW,  ui.aiH  = button("Tegen AI spelen", 260)
    ui.btnH2H, ui.hX,   ui.hY,   ui.hW,   ui.hH   = button("Tegen speler (WIP)", 340)

    local function deckBtn(label,x,y,selected)
        local bw,bh = 120,40
        local hover = mouseX>x and mouseX<x+bw and mouseY>y and mouseY<y+bh
        love.graphics.setColor(selected and 0.4 or hover and 0.8 or 0.6,0.6,0.6)
        love.graphics.rectangle("fill",x,y,bw,bh,8,8)
        love.graphics.setColor(0,0,0)
        love.graphics.printf(label,x,y+10,bw,"center")
        return hover,x,y,bw,bh
    end

    love.graphics.setColor(1,1,1)
    love.graphics.printf("Aantal decks:",0, 410, w, "center")
    ui.oneX, ui.oneY = (w-260)/2, 440
    ui.twoX, ui.twoY = ui.oneX+140, 440
    ui.d1, ui.d1x, ui.d1y, ui.d1w, ui.d1h = deckBtn("1 Deck", ui.oneX, ui.oneY, game.deckCount==1)
    ui.d2, ui.d2x, ui.d2y, ui.d2w, ui.d2h = deckBtn("2 Decks", ui.twoX, ui.twoY, game.deckCount==2)
end



--Remaining cards (de POT)
function ui.draw_deck(deck)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local kaart_hoogte = 140
    local x = w / 2 + 120
    local y = h / 2 - 70
    local schaal = kaart_hoogte / cardBack:getHeight()
    local count = deck.count()
    local zichtbaar = math.min(count, 5)
    for i = 0, zichtbaar - 1 do
        love.graphics.setColor(1, 1, 1, 1 - i * 0.15)
        love.graphics.draw(cardBack, x + i * 2, y - i * 2, math.rad(-i * 2), schaal, schaal)
    end
    love.graphics.setColor(0, 0, 0)
    love.graphics.printf("Deck: " .. count, x - 30, y + kaart_hoogte + 10, 120, "center")
end

--codex-- Draw the pile of played cards and optional overlay
function ui.draw_pot(pot, ongeldigeZetActief, toonOverlay)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local x, y = w / 2 - 50, h / 2 - 70
    local kaart_hoogte = 140

    local bovenste = pot[#pot]
    local voorlaatste = pot[#pot - 1]

    -- Teken voorlaatste kaart iets verschoven
    if voorlaatste and voorlaatste.afbeelding then
        local schaal = kaart_hoogte / voorlaatste.afbeelding:getHeight()
        love.graphics.setColor(1, 1, 1, 0.4)  -- lage opacity
        love.graphics.draw(voorlaatste.afbeelding, x - 5, y + 5, math.rad(-10), schaal, schaal)
    end

    -- Bovenste kaart
    if bovenste and bovenste.afbeelding then
        local schaal = kaart_hoogte / bovenste.afbeelding:getHeight()
        love.graphics.setColor(1, 1, 1, 1)  -- volledige opacity
        love.graphics.draw(bovenste.afbeelding, x, y, 0, schaal, schaal)


        if ongeldigeZetActief then
            love.graphics.setColor(1, 0, 0, 0.5)
            love.graphics.rectangle("line", x, y, 100, kaart_hoogte)
            love.graphics.setColor(1, 0, 0)
            love.graphics.print("Ongeldige zet!", x - 10, y + kaart_hoogte + 5)
        end
         
        -- Teken achtergrond rechthoek achter pot-kaarten
        local potW, potH = 200, 230  -- groter dan de kaart
        local potX = (w - potW) / 2
        local potY = (h - potH) / 2
        love.graphics.setColor(1, 1, 1, 0.95)  -- bijna wit, 95% opacity
        love.graphics.rectangle("line", potX, potY, potW, potH, 18, 18)

    end

-- Overlay met alle kaarten (compact, tussen boven- en onderkant)
if toonOverlay then
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    local overlayW = 300
    local overlayH = screenH - 300  -- genoeg ruimte boven en onder
    local overlayX = screenW - overlayW - 20
    local overlayY = 130  -- onder de bovenste kaarten

    -- Achtergrond van de overlay
    love.graphics.setColor(0.2, 0.5, 0.3, 0.97)  -- zachtere groen
    love.graphics.rectangle("fill", overlayX, overlayY, overlayW, overlayH, 12)

    -- Header
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(" Pot kaarten", overlayX, overlayY + 10, overlayW, "center")

    -- Kaarten tekenen
    local startX = overlayX + 20
    local startY = overlayY + 40
    local maxPerRow = 3
    local padding = 15
    local kaart_hoogte = 70

    for i, kaart in ipairs(pot) do
        local rij = math.floor((i - 1) / maxPerRow)
        local kolom = (i - 1) % maxPerRow
        local schaal = kaart_hoogte / kaart.afbeelding:getHeight()
        local x = startX + kolom * (90 + padding)
        local y = startY + rij * (kaart_hoogte + padding)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(kaart.afbeelding, x, y, 0, schaal, schaal)
    end

    -- Footer
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Klik op de knop om te sluiten", overlayX, overlayY + overlayH - 25, overlayW, "center")
end
end


------------------------------TEKEN KAARTEN  -----------------------------------

function ui.draw_player_area(playerData, index, totalPlayers)
    ------------------------------------------------------------------
    -- Basisgegevens
    ------------------------------------------------------------------
    local w, h  = love.graphics.getWidth(), love.graphics.getHeight()
    local hand  = playerData.hand or {}
--  if #hand == 0 then return end

    -- kaartafmetingen (bron 500×300 px, doel 160 px hoog)
    local CARD_H_SRC, CARD_W_SRC = 500, 300
    local CARD_H      = 160
    local SCALE_BASE  = CARD_H / CARD_H_SRC        -- ≈ 0.32
    local CARD_W      = CARD_W_SRC * SCALE_BASE
    local PADDING     = 15

    ------------------------------------------------------------------
    -- Hand-box
    ------------------------------------------------------------------
    local boxH   = CARD_H + 40
    local boxY   = (index == 1) and (h - boxH - 10) or 10
    local boxX   = 40
    local boxW   = w - 80

    love.graphics.setColor(1, 1, 1, 0.97)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 18, 18)

    ------------------------------------------------------------------
    -- TEKENEN: Speler 1  (scrollbaar)
    ------------------------------------------------------------------
    if index == 1 then
        local cardSpace    = CARD_W + PADDING
        local minVisible   = 6
        local fitVisible   = math.floor((boxW - 2 * PADDING) / cardSpace)
        local visibleCards = math.max(minVisible, fitVisible)

        playerData.scrollOffset = playerData.scrollOffset or 0
        local maxScroll = math.max(0, (#hand - visibleCards) * cardSpace)
        playerData.scrollOffset = math.min(
            math.max(playerData.scrollOffset, 0), maxScroll)

        local beginIdx = math.floor(playerData.scrollOffset / cardSpace) + 1
        local endIdx   = math.min(#hand, beginIdx + visibleCards - 1)

        local drawn    = endIdx - beginIdx + 1
        local contentW = drawn * CARD_W + (drawn - 1) * PADDING
        local xStart   = (w - contentW) / 2
        local yCards   = boxY + 20

        for i = beginIdx, endIdx do
            local kaart = hand[i]
            local x     = xStart + (i - beginIdx) * cardSpace

            love.graphics.push()
            love.graphics.translate(x, yCards)
            love.graphics.scale(SCALE_BASE, SCALE_BASE)
            love.graphics.draw(kaart.afbeelding, 0, 0)

            if kaart.selected then
                love.graphics.setColor(60, 1, 0)
                love.graphics.setLineWidth(3 / SCALE_BASE)
                love.graphics.rectangle("line", 0, 0,
                                        kaart.afbeelding:getWidth(),
                                        kaart.afbeelding:getHeight())
                love.graphics.setLineWidth(1)
                love.graphics.setColor(1, 1, 1)
            end
            love.graphics.pop()
        end

       ------------------------------------------------------------------
    -- TEKENEN: AI / overige spelers – vaste 8 px padding
    ------------------------------------------------------------------
    else
        local totalCards    = #hand
        local FIXED_PAD     = 8                          -- constante ruimte
        local backW_src     = cardBack:getWidth()
        local backH_src     = cardBack:getHeight()

        -- AI-kaarten mogen nooit hoger zijn dan die van speler 1
        local maxScale      = CARD_H / backH_src

        -- Past alles inclusief paddings in de boxbreedte?
        local availW        = boxW - 2 * PADDING - (totalCards - 1) * FIXED_PAD
        local scaleOpp      = math.min(maxScale,
                                        availW / (totalCards * backW_src))

        -- ondergrens zodat er altijd wat zichtbaar is
        scaleOpp            = math.max(scaleOpp, 0.1)

        local backW_scaled  = backW_src * scaleOpp
        local contentW      = totalCards * backW_scaled
                            + (totalCards - 1) * FIXED_PAD
        local xStart        = (w - contentW) / 2
        local yCards        = boxY + 20

        for i = 1, totalCards do
            local x = xStart + (i - 1) * (backW_scaled + FIXED_PAD)
            love.graphics.setColor(1,1,1) --reset kleur naar wit??
            love.graphics.draw(cardBack, x, yCards, 0, scaleOpp, scaleOpp)
        end
    end   -- sluit het if-index-blok



    ------------------------------------------------------------------
    -- Naam-label
    ------------------------------------------------------------------
    love.graphics.setColor(0, 0, 0)
    love.graphics.print("Speler " .. index, 20, boxY - 25)


------------------------------------------------------------------
-- FACE-DOWN rij  (blinde rug-kaarten)
------------------------------------------------------------------
local faceDown = playerData.faceDown
if #faceDown > 0 then
    local yRow = row_faceDown_Y(boxY, index)
    local scaleDown = scale_to_target(cardBack)
    local spacing   = cardBack:getWidth() * scaleDown + PADDING
    local totalW   = #faceDown * CARD_W + (#faceDown - 1) * PADDING
    local xStart   = (w - totalW) / 2
    local imgScale = SCALE_BASE           -- zelfde hoogte als hand
    


    for i = 1, #faceDown do
        love.graphics.setColor(1,1,1) --reset kleur naar wit??
        love.graphics.draw(cardBack, xStart+(i-1)*spacing, yRow,
                   0, scaleDown, scaleDown)
    end
end

------------------------------------------------------------------
-- FACE-UP rij  (zichtbare open kaarten)
------------------------------------------------------------------
local faceUp = playerData.faceUp
if #faceUp > 0 then
    local scaleUp = scale_to_target(faceUp[1].afbeelding)
    local spacing = faceUp[1].afbeelding:getWidth()*scaleUp + PADDING
    local totalW  = #faceUp * spacing - PADDING
    local xStart  = (w - totalW) / 2
    local yRow    = row_faceUp_Y(boxY, index)

    for i, kaart in ipairs(faceUp) do
        local drawX = xStart + (i-1)*spacing

        -- kaart (altijd)
        love.graphics.setColor(1,1,1)
        love.graphics.draw(kaart.afbeelding, drawX, yRow, 0, scaleUp, scaleUp)

        -- gele selectie-rand (alleen als gekozen)
        if kaart.selected then
            love.graphics.setColor(1,1,0)
            love.graphics.setLineWidth(3 / scaleUp)
            love.graphics.rectangle(
                "line",
                drawX, yRow,
                kaart.afbeelding:getWidth()*scaleUp,
                kaart.afbeelding:getHeight()*scaleUp
            )
            love.graphics.setLineWidth(1)
            love.graphics.setColor(1,1,1)     -- kleur herstellen
        end
    end
end
    -- ===============================================
    -- Stap 3: Tijdelijke blinde kaart tonen (reveal)
    -- ===============================================
    if game.reveal and game.reveal.card and game.reveal.player == index then
        local img = game.reveal.card.afbeelding
        local scale = scale_to_target(img)
        local w, h = love.graphics.getWidth(), love.graphics.getHeight()
        local x = (w - img:getWidth() * scale) / 2
        local y = h / 2 - img:getHeight() * scale / 2

        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(img, x, y, 0, scale, scale)
    end
end


function ui.draw_action_buttons()
    local w, h      = love.graphics.getWidth(), love.graphics.getHeight()
    local btnW,btnH = 150, 40
    local spacing   = 20

    -- Pas-knop alleen tijdens extra beurt van speler 1
    local allowPass = (game.extraTurn and game.currentPlayer == 1)

    local order = { "pickup", "play" }
    if allowPass then table.insert(order, "pass") end
    table.insert(order, "pot")

    local totalW = #order * btnW + (#order - 1) * spacing
    local startX = (w - totalW) / 2
    local y      = h - btnH - 20

    local rects, i = {}, 0
    local function draw(label, key, r,g,b)
        local x = startX + i * (btnW + spacing)
        love.graphics.setColor(r,g,b)
        love.graphics.rectangle("fill", x, y, btnW, btnH, 8)
        love.graphics.setColor(1,1,1)
        love.graphics.printf(label, x, y+10, btnW, "center")
        rects[key] = { x=x, y=y, w=btnW, h=btnH }
        i = i + 1
    end

    draw("Pak pot",    "pickup", 0.2,0.6,0.2)
    draw("Speel",      "play",   0.2,0.4,0.8)
    if allowPass then  draw("Pas", "pass", 0.6,0.4,0.2) end
    draw("Bekijk Pot", "pot",    0.2,0.2,0.2)

    love.graphics.setColor(1,1,1)
    return rects
end


--------------------------------------------------------------------
-- Geeft alleen hit-boxen terug voor kaarten die nu zichtbaar zijn
--------------------------------------------------------------------
function ui.get_card_positions(hand)
    local wScr, hScr = love.graphics.getWidth(), love.graphics.getHeight()

    -- *** Dezelfde constante waarden als in draw_player_area ***
    local CARD_H_SRC, CARD_W_SRC = 500, 300
    local CARD_H      = 160
    local SCALE       = CARD_H / CARD_H_SRC
    local CARD_W      = CARD_W_SRC * SCALE
    local PADDING     = 15
    local cardSpace   = CARD_W + PADDING
    

    -- Hand-box en Y-positie matchen draw_player_area
    local boxH        = CARD_H + 40
    local yCards      = hScr - boxH - 10 + 20              -- = boxY + 20

    -- Zichtbare vensterbreedte (minimaal 6 kaarten)
    local boxW        = wScr - 80
    local minVis      = 6
    local fitVis      = math.floor((boxW - 2 * PADDING) / cardSpace)
    local visible     = math.max(minVis, fitVis)

    -- Scroll-offset komt alléén van speler-object
    local p           = require("player").players[1]
    local scroll      = p.scrollOffset or 0
    local beginIdx    = math.floor(scroll / cardSpace) + 1
    local endIdx      = math.min(#hand, beginIdx + visible - 1)

    -- X-start om het getekende venster te centreren
    local drawn       = endIdx - beginIdx + 1
    local contentW    = drawn * CARD_W + (drawn - 1) * PADDING
    local xStart      = (wScr - contentW) / 2

    -- Positielijst vullen
    local pos = {}
    for i = 1, #hand do
        if i >= beginIdx and i <= endIdx then
            local col = i - beginIdx
            local x   = xStart + col * cardSpace          -- géén -scroll meer
            pos[i]    = { x = x, y = yCards, w = CARD_W, h = CARD_H }
        else
            -- Onzichtbare kaarten krijgen lege hit-box
            pos[i]    = { x = 0, y = 0, w = 0, h = 0 }
        end
    end
    return pos
end

function ui.draw_all_players(players)
    for i, speler in ipairs(players) do
        ui.draw_player_area(speler, i, #players)
    end
end



function ui.draw_end_screen(winner, players)
    local w,h = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0,0,0,0.7)
    love.graphics.rectangle('fill',0,0,w,h)
    love.graphics.setColor(1,1,1)
    local text = "Speler "..winner.." wint!"
    love.graphics.printf(text,0,h/2-40,w,'center')
    local other = winner==1 and 2 or 1
    local rest = #players[other].hand
    love.graphics.printf("Tegenstander heeft "..rest.." kaarten over",0,h/2,w,'center')
end

return ui