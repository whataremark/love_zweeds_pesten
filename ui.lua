-- User interface and rendering helpers
-- Provides scalable, well commented layout for all game elements
local ui = {}

-- Modules
local config = require("config")
local game   = require("game")
local player = require("player")
local utils  = require("utils")

-- Image for card backs used throughout the UI
local cardBack = love.graphics.newImage("/png/back.png")

-- Fonts for titles and smaller texts
local titleFont = love.graphics.newFont(40)
local smallFont = love.graphics.newFont(20)

-- Precomputed layout table filled each frame
ui.pos = {}

-- Slots used during the setup phase when players choose face up cards
ui.setupSlots = {}

-----------------------------------------------------------------------
-- Layout calculation
-----------------------------------------------------------------------
--[[
    calculate() must be called before drawing. It stores absolute
    positions for all zones based on the current window size. Using
    the screen width/height makes the UI independent of resolution.
--]]
function ui.calculate()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local ch = config.cardHeight
    local cw = config.cardWidth
    local gap = 10             -- space between rows

    -- Player 2 (AI) rows at the top
    ui.pos.aiDownY = gap
    ui.pos.aiUpY   = ui.pos.aiDownY + ch + gap
    ui.pos.aiHandY = ui.pos.aiUpY   + ch + gap

    -- Center zone for pot and draw pile
    ui.pos.potX = w/2 - cw/2
    ui.pos.potY = h/2 - ch/2
    ui.pos.deckX = ui.pos.potX + cw + 40
    ui.pos.deckY = ui.pos.potY

    -- Player 1 rows at the bottom
    ui.pos.downY  = h - ch - gap
    ui.pos.upY    = ui.pos.downY - ch - gap
    ui.pos.handY  = ui.pos.upY   - ch - 15

    -- Action buttons below the player hand
    ui.pos.btnY   = ui.pos.downY + ch + 10
end

-----------------------------------------------------------------------
-- Helper to center a row of cards horizontally
-----------------------------------------------------------------------
local function row_start(count)
    local w = love.graphics.getWidth()
    return (w - (count * (config.cardWidth + config.cardPadding) - config.cardPadding)) / 2
end

-----------------------------------------------------------------------
-- Draw deck as stacked backs with a card counter
-----------------------------------------------------------------------
function ui.draw_deck(deck)
    local count = deck.count()
    local x = ui.pos.deckX
    local y = ui.pos.deckY
    local s = config.scale

    -- Draw up to five backs with small offsets for a stack look
    local visible = math.min(count, 5)
    for i=0, visible-1 do
        love.graphics.setColor(1,1,1,1 - i*0.15)
        love.graphics.draw(cardBack, x + i*2, y - i*2, math.rad(-i*2), s, s)
    end

    -- Counter below the stack
    love.graphics.setColor(0,0,0)
    love.graphics.setFont(smallFont)
    love.graphics.printf("Deck: "..count, x, y + config.cardHeight + 5, config.cardWidth, "center")
end

-----------------------------------------------------------------------
-- Draw the discard pile (pot). If empty draw an outlined box.
-----------------------------------------------------------------------
function ui.draw_pot(pot, invalidTimer, showOverlay)
    local x = ui.pos.potX
    local y = ui.pos.potY
    local ch = config.cardHeight
    local cw = config.cardWidth

    -- Background box so the pot area is always visible
    love.graphics.setColor(1,1,1,0.95)
    love.graphics.rectangle("line", x-10, y-10, cw+20, ch+20, 12,12)

    local top = pot[#pot]
    local prev = pot[#pot-1]

    -- Slightly offset previous card to give depth
    if prev then
        local s = ch / prev.afbeelding:getHeight()
        love.graphics.setColor(1,1,1,0.4)
        love.graphics.draw(prev.afbeelding, x-6, y+6, math.rad(-6), s, s)
    end

    if top then
        local s = ch / top.afbeelding:getHeight()
        love.graphics.setColor(1,1,1,1)
        love.graphics.draw(top.afbeelding, x, y, 0, s, s)
    end

    -- Flash red outline when a card was rejected
    if invalidTimer and invalidTimer > 0 then
        love.graphics.setColor(1,0,0,0.5)
        love.graphics.rectangle("line", x, y, cw, ch)
    end

    -------------------------------------------------------------------
    -- Optional overlay showing the full pile contents
    -------------------------------------------------------------------
    if showOverlay then
        local w,h = love.graphics.getWidth(), love.graphics.getHeight()
        local boxW, boxH = 300, h-300
        local bx = w - boxW - 20
        local by = ui.pos.aiHandY + 20
        love.graphics.setColor(0.2,0.5,0.3,0.97)
        love.graphics.rectangle("fill", bx, by, boxW, boxH, 12)
        love.graphics.setColor(1,1,1)
        love.graphics.printf("Pot kaarten", bx, by+10, boxW, "center")
        local startX = bx+20
        local startY = by+40
        local perRow = 3
        local pad = 15
        local thumbH = 70
        for i,card in ipairs(pot) do
            local row = math.floor((i-1)/perRow)
            local col = (i-1)%perRow
            local s = thumbH / card.afbeelding:getHeight()
            love.graphics.draw(card.afbeelding, startX + col*(90+pad), startY + row*(thumbH+pad), 0, s, s)
        end
        love.graphics.printf("Klik op de knop om te sluiten", bx, by+boxH-25, boxW, "center")
    end
end

-----------------------------------------------------------------------
-- Draw the AI (player 2) cards in three rows at the top
-----------------------------------------------------------------------
function ui.draw_other_player()
    local p = game.players[2]
    local s = config.scale

    -- Face-down row
    local x = row_start(#p.faceDown)
    for i=1,#p.faceDown do
        love.graphics.draw(cardBack, x + (i-1)*(config.cardWidth + config.cardPadding), ui.pos.aiDownY, 0, s, s)
    end

    -- Face-up row
    x = row_start(#p.faceUp)
    for i,card in ipairs(p.faceUp) do
        local sc = config.cardHeight / card.afbeelding:getHeight()
        love.graphics.draw(card.afbeelding, x + (i-1)*(config.cardWidth + config.cardPadding), ui.pos.aiUpY, 0, sc, sc)
    end

    -- Hand (hidden) row
    x = row_start(#p.hand)
    for i=1,#p.hand do
        love.graphics.draw(cardBack, x + (i-1)*(config.cardWidth + config.cardPadding), ui.pos.aiHandY, 0, s, s)
    end

    -- Label above the rows
    love.graphics.setColor(0,0,0)
    love.graphics.setFont(smallFont)
    love.graphics.printf("Speler 2", 0, ui.pos.aiDownY - 25, love.graphics.getWidth(), "center")
    love.graphics.setColor(1,1,1)
end

-----------------------------------------------------------------------
-- Draw the human player's rows and current dragging card
-----------------------------------------------------------------------
function ui.draw_hand(hand, dragging)
    local p = game.players[1]
    local s = config.scale

    -- Face-down cards (bottom row)
    local x = row_start(#p.faceDown)
    for i=1,#p.faceDown do
        love.graphics.draw(cardBack, x + (i-1)*(config.cardWidth + config.cardPadding), ui.pos.downY, 0, s, s)
    end

    -- Face-up cards above that
    x = row_start(#p.faceUp)
    for i,card in ipairs(p.faceUp) do
        local sc = config.cardHeight / card.afbeelding:getHeight()
        love.graphics.draw(card.afbeelding, x + (i-1)*(config.cardWidth + config.cardPadding), ui.pos.upY, 0, sc, sc)
    end

    -- Actual hand on the third row
    x = row_start(#hand)
    for i,card in ipairs(hand) do
        local sc = config.cardHeight / card.afbeelding:getHeight()
        love.graphics.draw(card.afbeelding, x + (i-1)*(config.cardWidth + config.cardPadding), ui.pos.handY, 0, sc, sc)
    end

    -- Dragging card follows the mouse
    if dragging then
        local mx,my = love.mouse.getPosition()
        local sc = config.cardHeight / dragging.afbeelding:getHeight()
        love.graphics.draw(dragging.afbeelding, mx - player.dragOffset.x, my - player.dragOffset.y, 0, sc, sc)
    end
end

-----------------------------------------------------------------------
-- Setup screen where the player chooses three face-up cards
-----------------------------------------------------------------------
function ui.draw_setup(hand, faceUp)
    ui.calculate()
    local slotW, slotH = config.cardWidth, config.cardHeight
    local spacing = config.cardPadding
    ui.setupSlots = {}
    local x = row_start(3)
    for i=1,3 do
        local sx = x + (i-1)*(slotW+spacing)
        ui.setupSlots[i] = {x=sx, y=ui.pos.upY, w=slotW, h=slotH}
        love.graphics.setColor(1,1,1)
        love.graphics.draw(cardBack, sx, ui.pos.upY, 0, config.scale, config.scale)
        local card = faceUp[i]
        if card then
            local sc = slotH / card.afbeelding:getHeight()
            love.graphics.draw(card.afbeelding, sx, ui.pos.upY, 0, sc, sc)
        end
    end
    love.graphics.setColor(1,1,1)
    love.graphics.printf("Kies 3 kaarten voor de open stapels", 0, ui.pos.upY - 40, love.graphics.getWidth(), "center")
    ui.draw_hand(hand, player.draggingCard)
end

-----------------------------------------------------------------------
-- Main menu drawing (mostly unchanged)
-----------------------------------------------------------------------
function ui.draw_menu(mx, my)
    local w,h = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setFont(titleFont)
    love.graphics.setColor(1,1,1)
    love.graphics.printf("Zweeds Pesten", 0, 150, w, "center")
    love.graphics.setFont(smallFont)

    local function button(label,y)
        local bw,bh = 280,60
        local bx = (w-bw)/2
        local hover = mx>bx and mx<bx+bw and my>y and my<y+bh
        love.graphics.setColor(hover and 0.8 or 0.6,0.6,0.6)
        love.graphics.rectangle("fill",bx,y,bw,bh,8)
        love.graphics.setColor(0,0,0)
        love.graphics.printf(label,bx,y+18,bw,"center")
        return hover,bx,y,bw,bh
    end

    ui.btnAI, ui.aiX, ui.aiY, ui.aiW, ui.aiH = button("Tegen AI spelen", 260)
    ui.btnH2H, ui.hX, ui.hY, ui.hW, ui.hH = button("Tegen speler (WIP)", 340)

    local function deckBtn(label,x,y,selected)
        local bw,bh = 120,40
        local hover = mx>x and mx<x+bw and my>y and my<y+bh
        love.graphics.setColor(selected and 0.4 or hover and 0.8 or 0.6,0.6,0.6)
        love.graphics.rectangle("fill",x,y,bw,bh,8)
        love.graphics.setColor(0,0,0)
        love.graphics.printf(label,x,y+10,bw,"center")
        return hover,x,y,bw,bh
    end

    love.graphics.setColor(1,1,1)
    love.graphics.printf("Aantal decks:",0,410,w,"center")
    ui.oneX, ui.oneY = (w-260)/2, 440
    ui.twoX, ui.twoY = ui.oneX+140, 440
    ui.d1, ui.d1x, ui.d1y, ui.d1w, ui.d1h = deckBtn("1 Deck", ui.oneX, ui.oneY, game.deckCount==1)
    ui.d2, ui.d2x, ui.d2y, ui.d2w, ui.d2h = deckBtn("2 Decks", ui.twoX, ui.twoY, game.deckCount==2)
end

-----------------------------------------------------------------------
-- Action buttons for picking up the pile or viewing it
-----------------------------------------------------------------------
function ui.draw_action_buttons()
    local btnW, btnH = 150,40
    local spacing = 20
    local totalW = btnW*2 + spacing
    local startX = (love.graphics.getWidth() - totalW)/2
    local y = ui.pos.btnY

    love.graphics.setColor(0.2,0.6,0.2)
    love.graphics.rectangle("fill", startX, y, btnW, btnH, 8)
    love.graphics.setColor(1,1,1)
    love.graphics.printf("Pak kaart", startX, y+10, btnW, "center")

    love.graphics.setColor(0.2,0.2,0.2)
    love.graphics.rectangle("fill", startX+btnW+spacing, y, btnW, btnH, 8)
    love.graphics.setColor(1,1,1)
    love.graphics.printf("Pot bekijken", startX+btnW+spacing, y+10, btnW, "center")

    return {
        pickup = { x=startX, y=y, w=btnW, h=btnH },
        pot    = { x=startX+btnW+spacing, y=y, w=btnW, h=btnH }
    }
end

-----------------------------------------------------------------------
-- End screen after someone wins
-----------------------------------------------------------------------
function ui.draw_end_screen(winner)
    local w,h = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0,0,0,0.7)
    love.graphics.rectangle("fill",0,0,w,h)
    love.graphics.setColor(1,1,1)
    love.graphics.setFont(titleFont)
    love.graphics.printf("Speler "..winner.." wint!",0,h/2-40,w,"center")
    love.graphics.setFont(smallFont)
    local other = winner==1 and 2 or 1
    local count = #game.players[other].hand
    love.graphics.printf("Andere speler heeft "..count.." kaarten over",0,h/2+20,w,"center")
end

return ui
