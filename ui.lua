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


--helper voor name  displayen
local function disp_name(id)
  local p = require("player").players[id]
  return (p and p.name and p.name ~= "") and p.name or ("Speler " .. tostring(id or "?"))
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
    love.graphics.setColor(1,1,1,1)
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

-- Overlay met alle kaarten (compact, iets links en lager qua S I Z E)
if toonOverlay then
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    local overlayW = 300
    -- Maak 'm duidelijk minder hoog dan voorheen:
    -- kies max 360px hoog, en laat nog wat marge naar de randen
    local overlayH = math.min(360, screenH - 220)

    -- ⬇️ alleen iets naar links, NIET naar beneden shiften
    local SHIFT_X       = 0 -- OP NUL GGEZET WANT TOCH GEWOON  IN HET MIDDEN  HAHAHAH
    local SHADOW_ALPHA  = 0.50 -- donkerder schaduw (minder transparant)
    local PANEL_ALPHA   = 0.98 -- bijna opaak panel

    local overlayX = (screenW - overlayW) / 2 + SHIFT_X
    local overlayY = (screenH - overlayH) / 2

    -- schaduw
    love.graphics.setColor(0, 0, 0, SHADOW_ALPHA)
    love.graphics.rectangle("fill", overlayX + 8, overlayY + 10, overlayW, overlayH, 12)

    -- panel
    love.graphics.setColor(0.20, 0.50, 0.30, PANEL_ALPHA)
    love.graphics.rectangle("fill", overlayX, overlayY, overlayW, overlayH, 12)

    -- subtiele rand
    love.graphics.setColor(1, 1, 1, 0.10)
    love.graphics.rectangle("line", overlayX, overlayY, overlayW, overlayH, 12)

    -- header
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(" Pot kaarten", overlayX, overlayY + 10, overlayW, "center")

    -- kaarten (geclipt binnen het panel)
    local contentPadTop  = 40
    local contentPadSide = 20
    local startX         = overlayX + contentPadSide
    local startY         = overlayY + contentPadTop

    -- Iets kleinere kaartjes zodat er meer passen in lagere hoogte
    local maxPerRow      = 5
    local padding        = 2
    local kaart_hoogte   = 64

    -- Clip alles binnen het paneel
    love.graphics.setScissor(overlayX, overlayY, overlayW, overlayH)

    for i, kaart in ipairs(pot) do
        local rij    = math.floor((i - 1) / maxPerRow)
        local kolom  = (i - 1) % maxPerRow
        local schaal = kaart_hoogte / kaart.afbeelding:getHeight()
        local x      = startX + kolom * (50 + padding)
        local y      = startY + rij   * (kaart_hoogte + padding)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(kaart.afbeelding, x, y, 0, schaal, schaal)
    end

    love.graphics.setScissor()

    -- footer
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Klik op de knop om te sluiten",
        overlayX, overlayY + overlayH - 25, overlayW, "center")
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
        local p = player.players[index]
        love.graphics.print(disp_name(i), x, y)
        local txt  = isMe and (base .. " (YOU)") or base
        love.graphics.setColor(1,1,1)
        love.graphics.print(txt, alignRight and (labelX - 160) or labelX, labelY)
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

        draw_name(20, boxY - 25, false, index, isMe, playerData)


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

        draw_name(20, boxY +10, false, index, isMe, playerData)


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
        draw_name(nameX, nameY, seat=="right", index, isMe, playerData)

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

    draw("Pak pot", "pickup", 0.8, 0.2, 0.2)
    draw("Speel",      "play",   0.2,0.6,0.2)
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
  local count = #players
  local me = (require("net").localId or 1)

  local order = {}
  for i = 1, count do if i ~= me then table.insert(order, i) end end
  table.insert(order, me) -- jij als laatste → bovenop

  for _, i in ipairs(order) do
    ui.draw_player_area(players[i], i, count)
  end
end


-- Toon een correct eindscherm voor 2–4 spelers (met namen en finishedOrder)
function ui.draw_end_screen(winnerId, players, finishedOrder)
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()

  local function total_cards(p)
    return #(p.hand or {}) + #(p.faceUp or {}) + #(p.faceDown or {})
  end

  local function disp_name(id)
    local p = players and players[id]
    local n = p and p.name
    if n and n ~= "" then return n end
    return "Speler " .. tostring(id or "?")
  end

  -- Als winnerId ontbreekt/ongeldig maar er is finishedOrder, gebruik die
  if (not winnerId or not (players and players[winnerId])) and finishedOrder and finishedOrder[1] and players[finishedOrder[1]] then
    winnerId = finishedOrder[1]
  end

  -- maak een pos-map uit finishedOrder (1 = winnaar)
  local pos = nil
  if type(finishedOrder) == "table" and #finishedOrder > 0 then
    pos = {}
    for i, pid in ipairs(finishedOrder) do pos[pid] = i end
  end

  -- achtergrond
  love.graphics.setColor(0, 0, 0, 0.65)
  love.graphics.rectangle("fill", w*0.15, h*0.2, w*0.70, h*0.60, 20, 20)
  love.graphics.setColor(1, 1, 1, 1)

  -- titel
  local you = (net and net.localId) and (winnerId == net.localId) and " (YOU)" or ""
  local title = ("Winnaar: %s%s"):format(disp_name(winnerId), you)
  love.graphics.printf(title, w*0.15, h*0.23, w*0.70, "center")

  -- rows verzamelen (robust: gebruik pairs ipv ipairs i.g.v. gaten)
  local rows = {}
  for id, p in pairs(players or {}) do
    if type(id) == "number" and p then
      table.insert(rows, { id = id, left = total_cards(p) })
    end
  end

  -- sorteren:
  -- 1) als finishedOrder bekend: positie (laagst = eerst)
  -- 2) anders: winnaar eerst
  -- 3) dan op meeste kaarten over (desc)
  -- 4) stabiel op id
  table.sort(rows, function(a, b)
    if pos then
      local pa = pos[a.id] or 9999
      local pb = pos[b.id] or 9999
      if pa ~= pb then return pa < pb end
    else
      if a.id == winnerId and b.id ~= winnerId then return true end
      if b.id == winnerId and a.id ~= winnerId then return false end
    end
    if a.left ~= b.left then return a.left > b.left end
    return a.id < b.id
  end)

  -- lijst
  local y = h*0.30
  local lineH = 32
  for _, r in ipairs(rows) do
    local isWin  = (r.id == winnerId)
    local tag    = isWin and "🏆 " or "• "
    local youTag = (net and net.localId == r.id) and " (YOU)" or ""
    local txt    = ("%s%s%s — %d kaarten over"):format(tag, disp_name(r.id), youTag, r.left)

    love.graphics.setColor(1,1,1, isWin and 1 or 0.90)
    love.graphics.printf(txt, w*0.20, y, w*0.60, "left")
    y = y + lineH
  end

  -- hint
  love.graphics.setColor(1,1,1,0.85)
  love.graphics.printf("Druk op Enter om terug te gaan naar het menu", w*0.15, h*0.72, w*0.70, "center")
end



function ui.draw_banners(effects)
    if not effects or #effects == 0 then return end

    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    ui._bannerFont = ui._bannerFont or love.graphics.newFont(46)

    -- state bewaren → na tekenen herstellen (voorkomt “grote” UI erna)
    local prevFont      = love.graphics.getFont()
    local prevLineWidth = love.graphics.getLineWidth()
    local _unpack       = table.unpack or unpack

    for _, e in ipairs(effects) do
        local dur   = e.dur or 1.8                -- iets langer dan eerst
        local t     = math.min(e.t or 0, dur)
        local k     = t / dur
        local alpha = 1 - (k * k)                 -- zacht uitfaden
        local scale = 0.98 + 0.08 * math.sin(k * math.pi)

        local text = e.text or ""
        local f    = ui._bannerFont
        love.graphics.setFont(f)

        local tw = f:getWidth(text)
        local th = f:getHeight()
        local padX, padY = 28, 14

        -- vaste badge-afmeting (rect zelf schaalt niet, alleen tekst pulse’t)
        local bw = tw + 2 * padX
        local bh = th + 2 * padY

        -- mooi net-boven-het-midden (iets hoger dan center)
        local cx = w * 0.50
        local cy = h * 0.36
        local bx = cx - bw / 2
        local by = cy - bh / 2 - 8 * (1 - k)     -- mini slide-in up

        -- schaduw
        love.graphics.setColor(0, 0, 0, 0.55 * alpha)
        love.graphics.rectangle("fill", bx + 4, by + 6, bw, bh, 16, 16)

        -- badge
        local cr, cg, cb = _unpack(e.color or {1, 1, 1})
        love.graphics.setColor(cr, cg, cb, 0.24 * alpha)
        love.graphics.rectangle("fill", bx, by, bw, bh, 16, 16)

        love.graphics.setColor(1, 1, 1, 0.9 * alpha)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", bx, by, bw, bh, 16, 16)

        -- tekst exact gecentreerd en geschaald rond het midden
        love.graphics.push()
        love.graphics.translate(cx, cy)
        love.graphics.scale(scale, scale)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.printf(text, -tw/2, -th/2, tw, "center")
        love.graphics.pop()
    end

    -- herstel teken-state (belangrijk!)
    love.graphics.setFont(prevFont)
    love.graphics.setLineWidth(prevLineWidth)
end




return ui