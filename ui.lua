-- Rendering and menu functions
local ui = {}
local game = require("game")
local config = require("config")
local player = require("player") 
local net = require("net")

local kaartHoogte = config.cardHeight
local schaal = config.scale
local kaartBreedte = config.cardWidth
local padding = config.cardPadding
local cardBack = love.graphics.newImage("png/back.png")

--fonts for titles
local groteTitelFont = love.graphics.newFont(40)
local kleineTitelFont = love.graphics.newFont(20)

-- Turn-indicator styling
local TURN_GLOW_COLOR = {1.00, 0.85, 0.20} -- goud
local function draw_turn_glow(x, y, w, h, radius)
    local t = love.timer.getTime()
    local a = 0.55 + 0.35 * math.sin(t * 3.2)       -- pulserende alpha
    local lw = 3 + 2 * (0.5 + 0.5 * math.sin(t*4))  -- pulserende lijndikte
    love.graphics.setColor(TURN_GLOW_COLOR[1], TURN_GLOW_COLOR[2], TURN_GLOW_COLOR[3], a)
    love.graphics.setLineWidth(lw)
    love.graphics.rectangle("line", x, y, w, h, radius or 18, radius or 18)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1,1,1)
end

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
-- helpers voor de Y‑positie van de face‑down / face‑up rijen
-- TARGET_H staat al elders op 140 px
local EXTRA_GAP  = 70
local net        = require("net")

local function row_faceDown_Y(boxY, index)
    -- host‑only (ai) → localId is nil, dus fallback naar speler 1
    local isMe = (index == (net.localId or 1))

    if isMe then
        return boxY - TARGET_H - 10          -- eigen rij boven hand
    else
        return boxY + TARGET_H + EXTRA_GAP   -- andere speler(s)
    end
end

local function row_faceUp_Y(boxY, index)
    return row_faceDown_Y(boxY, index)
end

-- helper voor selectie bij facedown
-- Gele selectie-rand (axis-aligned, ongeroteerd) — NULL-SAFE
local function draw_selected_outline_rect(x, y, w, h, scale)
    if type(x) ~= "number" or type(y) ~= "number"
       or type(w) ~= "number" or type(h) ~= "number" then
        -- ontbrekende metrics? niet tekenen i.p.v. crashen
        return
    end
    if w <= 0 or h <= 0 then return end

    love.graphics.setColor(1,1,0)
    love.graphics.setLineWidth(3 / (scale or 1))
    love.graphics.rectangle("line", x, y, w, h, 16, 16)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1,1,1)
end

-- Gele selectie-rand (geroteerd rond het midden) — NULL-SAFE
local function draw_selected_outline_rot(cx, cy, iw, ih, s, rot)
    if type(cx) ~= "number" or type(cy) ~= "number"
       or type(iw) ~= "number" or type(ih) ~= "number"
       or type(s)  ~= "number" then
        return
    end
    if iw <= 0 or ih <= 0 or s <= 0 then return end

    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(rot or 0)
    love.graphics.setColor(1,1,0)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", -(iw*s)/2, -(ih*s)/2, iw*s, ih*s, 16, 16)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1,1,1)
    love.graphics.pop()
end
---


ui.row_faceUp_Y   = row_faceUp_Y
ui.row_faceDown_Y = row_faceDown_Y
----------------------MENU---------------------------------------
function ui.draw_menu(mouseX, mouseY)--------------------------------------------------------------------
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
    -- Basis
    ------------------------------------------------------------------
    local w, h    = love.graphics.getWidth(), love.graphics.getHeight()
    local hand    = playerData.hand or {}
    local isMe    = (index == (net.localId or 1))

    -- seat mapping (1=bottom, 2=top, 3=left, 4=right)
    local seat = "top"
    if isMe then seat = "bottom"
    elseif index == 2 then seat = "top"
    elseif index == 3 then seat = "left"
    else seat = "right" end

    -- kaartafmetingen
    local CARD_H_SRC, CARD_W_SRC = 500, 300
    local CARD_H      = 160
    local SCALE_BASE  = CARD_H / CARD_H_SRC
    local CARD_W      = CARD_W_SRC * SCALE_BASE
    local PADDING     = 15

    local function safe_draw_card(img, x, y, sx, sy)
        if img and img.typeOf and img:typeOf("Image") then
            love.graphics.draw(img, x, y, 0, sx, sy)
        else
            love.graphics.draw(cardBack, x, y, 0, sx, sy)
        end
    end

    local function draw_name(labelX, labelY, alignRight)
        love.graphics.setColor(0,0,0)
        love.graphics.print(
            ("Speler %d%s"):format(index, isMe and " (YOU)" or ""),
            alignRight and (labelX - 120) or labelX,
            labelY
        )
        love.graphics.setColor(1,1,1)
    end

    ------------------------------------------------------------------
    -- SEAT: BOTTOM (local) – scrollbare hand + rijen erboven
    ------------------------------------------------------------------
    if seat == "bottom" then
        local boxH = CARD_H + 40
        local boxY = h - boxH - 10
        local boxX = 40
        local boxW = w - 80

        love.graphics.setColor(1,1,1,0.97)
        love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 18, 18)
        
        if index == game.currentPlayer then
            draw_turn_glow(boxX-6, boxY-6, boxW+12, boxH+12, 18)
        end

        love.graphics.setColor(1,1,1)

        -- scrollbare hand
        local cardSpace    = CARD_W + PADDING
        local minVisible   = 6
        local fitVisible   = math.floor((boxW - 2 * PADDING) / cardSpace)
        local visibleCards = math.max(minVisible, fitVisible)

        playerData.scrollOffset = playerData.scrollOffset or 0
        local maxScroll = math.max(0, (#hand - visibleCards) * cardSpace)
        playerData.scrollOffset = math.min(math.max(playerData.scrollOffset, 0), maxScroll)

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
            safe_draw_card(kaart.afbeelding, 0, 0, 1, 1)

            if kaart.selected then
                love.graphics.setColor(60, 1, 0)
                love.graphics.setLineWidth(3 / SCALE_BASE)
                love.graphics.rectangle("line", 0, 0,
                    kaart.afbeelding and kaart.afbeelding:getWidth() or cardBack:getWidth(),
                    kaart.afbeelding and kaart.afbeelding:getHeight() or cardBack:getHeight())
                love.graphics.setLineWidth(1)
                love.graphics.setColor(1, 1, 1)
            end
            love.graphics.pop()
        end

        draw_name(20, boxY - 25, false)

        -- FACE-DOWN rij
        local faceDown = playerData.faceDown or {}
        if #faceDown > 0 then
            local yRow   = row_faceDown_Y(boxY, index)
            local s      = scale_to_target(cardBack)
            local space  = cardBack:getWidth() * s + PADDING
            local totalW = #faceDown * space - PADDING
            local xStart2 = (w - totalW) / 2
            for i=1,#faceDown do
                love.graphics.draw(cardBack, xStart2 + (i-1)*space, yRow, 0, s, s)
            end
        end

        -- FACE-UP rij
        local faceUp = playerData.faceUp or {}
        if #faceUp > 0 then
            local first  = faceUp[1].afbeelding or cardBack
            local s      = scale_to_target(first)
            local space  = first:getWidth()*s + PADDING
            local totalW = #faceUp * space - PADDING
            local xStart3 = (w - totalW) / 2
            local yRow   = row_faceUp_Y(boxY, index)
            for i, kaart in ipairs(faceUp) do
                love.graphics.setColor(1,1,1)
                safe_draw_card(kaart.afbeelding, xStart3+(i-1)*space, yRow, s, s)
                
                -- na: safe_draw_card(kaart.afbeelding, xStart3+(i-1)*space, yRow, s, s)
                if kaart.selected then
                    local img = kaart.afbeelding or cardBack
                    local rx  = xStart3 + (i-1)*space   -- zelfde X als waar je de kaart tekent
                    local ry  = yRow                    -- zelfde Y
                    local rw  = img:getWidth()  * s     -- geschaalde breedte
                    local rh  = img:getHeight() * s     -- geschaalde hoogte

                    love.graphics.setColor(60, 1, 0)
                    love.graphics.setLineWidth(3)       -- schermruimte; niet delen door s
                    love.graphics.rectangle("line", rx, ry, rw, rh, 12, 12)
                    love.graphics.setLineWidth(1)
                    love.graphics.setColor(1, 1, 1)
                end
            end
            end
    

    ----------------------------s--------------------------------------
    -- SEAT: TOP – horizontale backs, rijen via helpers
    ------------------------------------------------------------------
    elseif seat == "top" then
        local boxH = CARD_H + 40
        local boxY = 10
        local boxX = 40
        local boxW = w - 80

        love.graphics.setColor(1,1,1,0.97)
        love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 18, 18)
        if index == game.currentPlayer then
            draw_turn_glow(boxX-6, boxY-6, boxW+12, boxH+12, 18)
        end
        love.graphics.setColor(1,1,1)

        local totalCards = #hand
        local FIXED_PAD  = 8
        local backW_src  = cardBack:getWidth()
        local backH_src  = cardBack:getHeight()
        local maxScale   = CARD_H / backH_src

        local availW     = boxW - 2*PADDING - (math.max(totalCards,1)-1) * FIXED_PAD
        local scaleOpp   = math.min(maxScale, availW / (math.max(totalCards,1) * backW_src))
        scaleOpp         = math.max(scaleOpp, 0.1)

        local backW      = backW_src * scaleOpp
        local contentW   = totalCards * backW + (math.max(totalCards,1)-1) * FIXED_PAD
        local xStart     = (w - contentW) / 2
        local yCards     = boxY + 20

        for i = 1, totalCards do
            local x = xStart + (i - 1) * (backW + FIXED_PAD)
            love.graphics.draw(cardBack, x, yCards, 0, scaleOpp, scaleOpp)
        end

        draw_name(20, boxY - 25, false)

        -- FACE-DOWN en FACE-UP
        local faceDown = playerData.faceDown or {}
        if #faceDown > 0 then
            local yRow  = row_faceDown_Y(boxY, index)
            local s     = scale_to_target(cardBack)
            local space = cardBack:getWidth()*s + PADDING
            local totalW = #faceDown * space - PADDING
            local xStart2 = (w - totalW) / 2
            for i=1,#faceDown do
                love.graphics.draw(cardBack, xStart2+(i-1)*space, yRow, 0, s, s)
            end
        end

        local faceUp = playerData.faceUp or {}
        if #faceUp > 0 then
            local first = faceUp[1].afbeelding or cardBack
            local s     = scale_to_target(first)
            local space = first:getWidth()*s + PADDING
            local totalW = #faceUp * space - PADDING
            local xStart3 = (w - totalW) / 2
            local yRow   = row_faceUp_Y(boxY, index)
            for i, kaart in ipairs(faceUp) do
                safe_draw_card(kaart.afbeelding, xStart3+(i-1)*space, yRow, s, s)
            end
        end

------------------------------------------------------------------
    -- SEAT: LEFT / RIGHT – geroteerde hand + open/blind kolom + border
    ------------------------------------------------------------------
    else
        local total       = #hand
        local backW_src   = cardBack:getWidth()
        local backH_src   = cardBack:getHeight()

        local rotHand     = (seat == "left") and math.pi/2 or -math.pi/2

        -- 1) Kleinere schaal dan top/bottom (20% kleiner → pas aan naar smaak)
        local baseScale   = CARD_H / backW_src      -- zou hoogte 160 geven
        local SIDE_SHRINK = 0.5                    -- ⬅️ maak alles kleiner
        local sHand       = baseScale * SIDE_SHRINK

        -- afmetingen na rotatie
        local cardW_rot   = backH_src * sHand       -- ‘breedte’ op scherm
        local cardH_rot   = backW_src * sHand       -- ‘hoogte’  op scherm

        -- verticale spacing (géén overlap)
        local GAP_HAND    = math.floor(cardH_rot * 0.18)
        local stepH       = cardH_rot + GAP_HAND

        -- kolom in hoogte passen
        local topMargin, bottomMargin = 120, 180
        local availH     = math.max(120, h - topMargin - bottomMargin)
        local needH      = (total > 0) and (cardH_rot + (total - 1) * stepH) or 0
        if needH > availH then
            local f = availH / needH
            sHand     = sHand * f
            cardW_rot = backH_src * sHand
            cardH_rot = backW_src * sHand
            GAP_HAND  = math.floor(cardH_rot * 0.18)
            stepH     = cardH_rot + GAP_HAND
            needH     = (total > 0) and (cardH_rot + (total - 1) * stepH) or 0
        end

        -- 2) Extra horizontale ruimte tussen hand en open/blind
        local SIDE_GAP_X  = 36                      -- ⬅️ meer/ minder X-ruimte

        -- X-positie van de hand-kolom (linker rand van de kolom)
        local xCol  = (seat == "left") and 28 or (w - cardW_rot - 28)
        local yTop  = topMargin + (availH - needH) / 2

        -- X-positie van open/blind-kolom (linker rand)
        local xStack = (seat == "left")
                        and (xCol + cardW_rot + SIDE_GAP_X)
                        or  (xCol - SIDE_GAP_X - cardW_rot)

        -- 3) Witte border (verticale box) rond beide kolommen
    -- ▸ Border: alleen rond de HAND-kolom (niet om open/blind)
    do
        local PAD   = 6         -- dunne rand, dicht rond de hand
        local boxX  = xCol - PAD
        local boxY  = yTop - PAD
        local boxW  = cardW_rot + 2*PAD
        local boxH  = needH + 2*PAD
        love.graphics.setColor(1,1,1,0.97)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 18, 18)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1,1,1)
         if index == game.currentPlayer then
            draw_turn_glow(boxX-6, boxY-6, boxW+12, boxH+12, 18)
        end
    end



        -- HAND-kolom (backs) met spacing
        for i = 1, total do
            local cx = (xCol + cardW_rot/2)
            local cy = yTop + (i-1) * stepH + cardH_rot/2
            love.graphics.draw(cardBack, cx, cy, rotHand, sHand, sHand, backW_src/2, backH_src/2)
        end

        -- label
        local nameX = (seat=="left") and xCol or (xCol - 10)
        local nameY = yTop - 24
        draw_name(nameX, nameY, seat=="right")

        ------------------------------------------------------------------
        -- Open & Blind als VERTICALE kolom naast de hand
        --  - schaal per kaart zodat geroteerde hoogte == back-hoogte (→ even groot)
        --  - gebruikt dezelfde spacing als hand
        ------------------------------------------------------------------
        local function vertical_stack(cards, isFaceDown)
            local count = #cards
            if count == 0 then return end

            local oneH   = backW_src * sHand          -- doel-hoogte na 90°
            local GAP_S  = math.floor(oneH * 0.18)
            local stepS  = oneH + GAP_S

            local needS  = oneH + (count - 1) * stepS
            local yStart = yTop + (needH - needS) / 2

            -- teken exact naast de hand
            local cxLeft = xStack

            for i = 1, count do
                local img = isFaceDown and cardBack or (cards[i] and cards[i].afbeelding)
                local iw  = (img and img.getWidth)  and img:getWidth()  or backW_src
                local ih  = (img and img.getHeight) and img:getHeight() or backH_src

                -- schaal ieder front zodat hoogte == oneH
                local sImg = sHand * (backW_src / iw)

                local ox, oy = iw/2, ih/2
                local cx     = cxLeft + (seat=="left" and (iw*sImg/2) or (cardW_rot - iw*sImg/2))
                local cy     = yStart + (i-1) * stepS + oneH/2

                love.graphics.draw(img or cardBack, cx, cy, rotHand, sImg, sImg, ox, oy)
            end
        end

        vertical_stack(playerData.faceDown or {}, true)     -- blind (backs)
        vertical_stack(playerData.faceUp   or {}, false)    -- open (fronts)
    end


    ------------------------------------------------------------------
    -- Reveal overlay (geldig voor elke seat)
    ------------------------------------------------------------------
    if game.reveal and game.reveal.card and game.reveal.player == index then
        local img   = game.reveal.card.afbeelding or cardBack
        local s     = scale_to_target(img)
        local cx    = (w - img:getWidth()*s) / 2
        local cy    = (h - img:getHeight()*s) / 2
        love.graphics.setColor(1,1,1)
        love.graphics.draw(img, cx, cy, 0, s, s)
    end
end


function ui.draw_action_buttons()
    local w, h      = love.graphics.getWidth(), love.graphics.getHeight()
    local btnW,btnH = 150, 40
    local spacing   = 20

    -- Pas-knop alleen tijdens extra beurt van speler 1
    local allowPass = (game.extraTurn and game.currentPlayer == net.localId)

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
    local p = require("player").players[net.localId or 1]
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
  local w,h = love.graphics.getWidth(), love.graphics.getHeight()

  local seatForIndex = { [1]="bottom", [2]="top", [3]="left", [4]="right" }
  local count = #players

  -- eerst anderen, dan jij (zodat jouw hand bovenop ligt)
  for i=2, math.min(count,4) do
    ui.draw_player_area(players[i], i, count, seatForIndex[i])
  end
  ui.draw_player_area(players[1], 1, count, "bottom")
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