-- Rendering and menu functions
local ui = {}
local game = require("game")

local config = require("config")
local kaartHoogte = config.cardHeight
local schaal = config.scale
local kaartBreedte = config.cardWidth
local padding = config.cardPadding

local cardBack = love.graphics.newImage("/png/back.png")

ui.setupSlots = {}

local player = require("player") -- <-- dit is essentieel!

local groteTitelFont = love.graphics.newFont(40)
local kleineTitelFont = love.graphics.newFont(20)

--codex-- Draw remaining draw pile as stacked card backs with a counter
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

--codex-- Draw the AI player's face-down cards
function ui.draw_other_players()
    local game = require("game")
    local hand = game.players[2].hand
    local kaartAantal = #hand

    -- Kaartpositie (bovenkant scherm, horizontaal gecentreerd)
    local kaartBreedte = cardBack:getWidth()
    local kaartHoogte  = cardBack:getHeight()
    local schaal       = 0.5  -- zelfde als je eigen kaarten

    local spacing = 90  -- overlap tussen kaarten
    local totalWidth = spacing * (kaartAantal - 1) + kaartBreedte * schaal
    local startX = (love.graphics.getWidth() - totalWidth) / 2
    local downY = 60

    -- Titel boven de bovenste rij
    love.graphics.setColor(0, 0, 0)
    love.graphics.printf("Speler 2", startX, downY - 20, totalWidth, "center")

    -- face-down stapel bovenaan
    for i=1,#game.players[2].faceDown do
        love.graphics.draw(cardBack, startX + (i-1)*spacing, downY, 0, schaal, schaal)
    end

    local faceY = downY + kaartHoogte*schaal + 10
    for i,card in ipairs(game.players[2].faceUp) do
        local sch = kaartHoogte*schaal / card.afbeelding:getHeight()
        love.graphics.draw(card.afbeelding, startX + (i-1)*spacing, faceY, 0, sch, sch)
    end

    local y = faceY + kaartHoogte*schaal + 20
    for i = 1, kaartAantal do
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(cardBack, startX + (i - 1) * spacing, y, 0, schaal, schaal)
    end
end

function ui.draw_setup(hand, faceUp)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local slotW, slotH = 100, 140
    local spacing = 20
    local totalW = slotW * 3 + spacing * 2
    local startX = (w - totalW) / 2
    local y = h/2 - slotH/2
    ui.setupSlots = {}
    for i=1,3 do
        local x = startX + (i-1)*(slotW+spacing)
        ui.setupSlots[i] = {x=x, y=y, w=slotW, h=slotH}
        love.graphics.setColor(1,1,1)
        love.graphics.draw(cardBack, x, y, 0, slotW/cardBack:getWidth(), slotH/cardBack:getHeight())
        local card = faceUp[i]
        if card then
            local sch = slotH / card.afbeelding:getHeight()
            love.graphics.draw(card.afbeelding, x, y, 0, sch, sch)
        end
    end
    love.graphics.setColor(1,1,1)
    love.graphics.printf("Kies 3 kaarten voor de open stapels",0,y-40,w,"center")
    ui.draw_hand(hand, player.draggingCard)
end

--codex-- Render the player's hand and follow the dragged card
function ui.draw_hand(hand, draggingCard)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local kaart_hoogte = 160
    local padding = 15
    local schaal = kaart_hoogte / 500 -- schatting originele PNG hoogte
    local kaart_breedte = 300 * schaal
    local x_start = (w - (#hand * (kaart_breedte + padding))) / 2

    -- nieuwe layout: blinde kaarten onderaan, daarboven face-up, hand daarboven
    local p = require("game").players[1]
    local downY = h - kaart_hoogte - 20
    for i=1,#p.faceDown do
        local x = x_start + (i-1)*(kaart_breedte + padding)
        love.graphics.draw(cardBack, x, downY, 0, schaal, schaal)
    end

    local upY = downY - kaart_hoogte - 10
    for i,card in ipairs(p.faceUp) do
        local x = x_start + (i-1)*(kaart_breedte + padding)
        love.graphics.draw(card.afbeelding, x, upY, 0, schaal, schaal)
    end

    local y = upY - kaart_hoogte - 20
    for i, kaart in ipairs(hand) do
        local x = x_start + (i - 1) * (kaart_breedte + padding)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(kaart.afbeelding, x, y, 0, schaal, schaal)
    end

    -- sleepkaart bovenop tekenen (volgt muis)
    if draggingCard then
        local mx, my = love.mouse.getPosition()
        local x = mx - player.dragOffset.x
        local y = my - player.dragOffset.y
        love.graphics.draw(draggingCard.afbeelding, x, y, 0, schaal, schaal)
    end
end

-----------------------------------------------------------------
-- MENU  --------------------------------------------------------
--codex-- Main menu with mode selection buttons
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

function ui.draw_end_screen(winner)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0,0,0,0.7)
    love.graphics.rectangle("fill",0,0,w,h)
    love.graphics.setColor(1,1,1)
    love.graphics.setFont(groteTitelFont)
    love.graphics.printf("Speler "..winner.." wint!",0,h/2-40,w,"center")
    love.graphics.setFont(kleineTitelFont)
    local other = winner == 1 and 2 or 1
    local game = require("game")
    local count = #game.players[other].hand
    love.graphics.printf("Andere speler heeft "..count.." kaarten over",0,h/2+20,w,"center")
end
return ui
