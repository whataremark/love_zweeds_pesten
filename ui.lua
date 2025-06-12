-- Rendering and menu functions
local ui = {}
local game = require("game")
local config = require("config")
local player = require("player") 

local kaartHoogte = config.cardHeight
local schaal = config.scale
local kaartBreedte = config.cardWidth
local padding = config.cardPadding
local cardBack = love.graphics.newImage("/png/back.png")

--fonts for titles
local groteTitelFont = love.graphics.newFont(40)
local kleineTitelFont = love.graphics.newFont(20)

----------------------MENU---------------------------------------
function ui.draw_menu(mouseX, mouseY)
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


function ui.draw_player_area(playerData, index, totalPlayers)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local hand = playerData.hand
    if not hand then return end

    local kaart_hoogte = config.cardHeight
    local schaal = config.scale
    local kaart_breedte = 300 * schaal
    local padding = 15
    local visibleCards = config.visibleCards
    local scrollOffset = player.scrollOffset or 0

    local boxHeight = kaart_hoogte + 40
    local boxY = index == 1 and (h - boxHeight - 10) or 10
    local boxX = 40
    local boxWidth = w - 80

    -- Teken achtergrondbox
    love.graphics.setColor(1, 1, 1, 0.97)
    love.graphics.rectangle("line", boxX, boxY, boxWidth, boxHeight, 18, 18)

    -- Handkaarten tekenen
    local beginIndex, eindIndex
    local zichtbareKaarten = 6
    if index == 1 then
        beginIndex = math.floor(player.scrollOffset / (kaart_breedte + padding)) + 1
    else
        beginIndex = 1
    end
    eindIndex = math.min(#hand, beginIndex + zichtbareKaarten - 1)
    local contentWidth = visibleCards * (kaart_breedte + padding)
    local x_start = (w - contentWidth) / 2

    for i = beginIndex, eindIndex do
        local x = x_start + (i - beginIndex) * (kaart_breedte + padding)
        local y = boxY + 20
        love.graphics.setColor(1, 1, 1)
        if index == 1 then
            love.graphics.draw(hand[i].afbeelding, x, y, 0, schaal, schaal)
        else
            love.graphics.draw(cardBack, x, y, 0, schaal, schaal)
        end
    end

    -- Naam (alleen AI bovenaan)
    if index ~= 1 then
        love.graphics.setColor(0, 0, 0)
        love.graphics.printf("Speler " .. index, boxX, boxY + boxHeight + 5, boxWidth, "center")
    end

    ---DICHTE KAARTEN EN OPEN KAARTEN---
    -- Zelfde schaal & afmetingen als handkaarten
    local kaartHoogte = config.cardHeight
    local schaal = config.scale * 1.5  -- iets groter
    local kaartBreedte = config.cardWidth
    local spacing = config.cardSpacing + 100
    local totaalBreedte = kaartBreedte * 3 + spacing * 2
    local startX = (w - totaalBreedte) / 2
    local w = love.graphics.getWidth()


    -- === Dichte kaarten
    if playerData.faceDown then
        local y = index == 1
            and (boxY - kaartHoogte - 10)      -- voor speler 1: boven de box
            or (boxY + boxHeight + 70)         -- voor AI: onder de box

        for i = 1, 3 do
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(cardBack, startX + (i - 1) * spacing, y, 0, schaal, schaal)
        end
    end

    -- === Open kaarten
    if playerData.faceUp and #playerData.faceUp > 0 then
        local y = index == 1
            and (boxY - 2 * kaartHoogte - 20)   -- boven faceDown bij speler 1
            or (boxY + boxHeight + kaartHoogte + 20) -- onder faceDown bij AI

        for i = 1, 3 do
            local kaart = playerData.faceUp[i]
            if kaart and kaart.afbeelding then
                love.graphics.setColor(1, 1, 1)
                love.graphics.draw(kaart.afbeelding, x, y, 0, schaal, schaal)

            end
        end
    end 

    if player.selectedFaceUp[i] then
    love.graphics.setColor(0, 1, 0)
    love.graphics.rectangle("line", x, y, kaart_breedte, kaart_hoogte)
end
    
    if game.state == "selectFaceUp" and index == 1 then
        local btnW, btnH = 200, 50
        local btnX = (love.graphics.getWidth() - btnW) / 2
        local btnY = love.graphics.getHeight() - 80
        love.graphics.setColor(0.2, 0.6, 0.2)
        love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 10)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Bevestig selectie", btnX, btnY + 15, btnW, "center")

        -- Sla positie op voor klikdetectie
        ui.confirmBtn = {x = btnX, y = btnY, w = btnW, h = btnH}
end

    -- Naam gecentreerd onder de box
    love.graphics.setColor(0, 0, 0)
    love.graphics.printf("Speler " .. index, boxX, boxY - 25, boxWidth, "center")
end


function ui.draw_all_players(players)
    for i, speler in ipairs(players) do
        ui.draw_player_area(speler, i, #players)
    end
end


-- Pickup + Pot bekijkknoppen gecombineerd en gecentreerd
--codex-- Draw buttons to pick up the pile or view it
function ui.draw_action_buttons()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local btnW, btnH = 150, 40
    local spacing = 20
    local totalW = btnW * 2 + spacing
    local startX = (w - totalW) / 2
    local y = h - btnH - 20

    -- === Pak kaart knop ===
    love.graphics.setColor(0.2, 0.6, 0.2)
    love.graphics.rectangle("fill", startX, y, btnW, btnH, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Pak kaart", startX, y + 10, btnW, "center")

    -- === Pot bekijken knop ===
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", startX + btnW + spacing, y, btnW, btnH, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Pot bekijken", startX + btnW + spacing, y + 10, btnW, "center")

    -- Return knopposities voor klikdetectie
    return {
        pickup = { x = startX, y = y, w = btnW, h = btnH },
        pot    = { x = startX + btnW + spacing, y = y, w = btnW, h = btnH }
    }
end


function ui.get_card_positions(hand)
    local positions = {}
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()

    local kaart_hoogte = 160
    local schaal = kaart_hoogte / 500 -- schatting originele PNG hoogte
    local kaart_breedte = 300 * schaal
    local padding = 15

    local zichtbareKaarten = 6
    local scrollOffset = require("player").scrollOffset or 0

    local x_start = (w - (zichtbareKaarten * (kaart_breedte + padding))) / 2 - scrollOffset
    local y = h - kaart_hoogte - 50

    for i, kaart in ipairs(hand) do
        local x = x_start + (i - 1) * (kaart_breedte + padding)
        table.insert(positions, { x = x, y = y, w = kaart_breedte, h = kaart_hoogte })
    end

    return positions
end


return ui
