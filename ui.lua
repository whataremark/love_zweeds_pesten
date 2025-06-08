local ui = {}

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
            love.graphics.print("❌ Ongeldige zet!", x - 10, y + kaart_hoogte + 5)
        end
    end

    -- Pot bekijken knop
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", w - 150, h - 50, 140, 40, 8)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("📂 Pot bekijken", w - 140, h - 40)

    -- Overlay met alle kaarten
    if toonOverlay then
        love.graphics.setColor(1, 1, 1, 0.92)
        love.graphics.rectangle("fill", 20, 20, w - 40, h - 40, 12)  -- met afgeronde hoeken

        local startX = 60
        local startY = 80
        local maxPerRow = 7
        local padding = 20
        local kaart_hoogte = 100

        for i, kaart in ipairs(pot) do
            local rij = math.floor((i - 1) / maxPerRow)
            local kolom = (i - 1) % maxPerRow
            local schaal = kaart_hoogte / kaart.afbeelding:getHeight()
            local x = startX + kolom * (90 + padding)
            local y = startY + rij * (kaart_hoogte + padding)
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(kaart.afbeelding, x, y, 0, schaal, schaal)
        end

        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Klik nogmaals op de knop om te sluiten", startX, startY - 30)
    end
end

function ui.draw_other_players()
    local w = love.graphics.getWidth()
    love.graphics.setColor(0, 0, 0)
    love.graphics.print("Speler 2", w / 2 - 25, 30)
    love.graphics.rectangle("line", w / 2 - 100, 50, 200, 100)
end

function ui.draw_hand(hand, draggingCard)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local kaart_hoogte = 120
    local padding = 15
    local schaal = kaart_hoogte / 500 -- schatting originele PNG hoogte
    local kaart_breedte = 300 * schaal
    local x_start = (w - (#hand * (kaart_breedte + padding))) / 2
    local y = h - kaart_hoogte - 50

    -- Teken alle kaarten in hand
    for i, kaart in ipairs(hand) do
        local x = x_start + (i - 1) * (kaart_breedte + padding)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(kaart.afbeelding, x, y, 0, schaal, schaal)
    end

    -- Teken gesleepte kaart boven cursor
    if draggingCard then
        local mx, my = love.mouse.getPosition()
        local schaal = kaart_hoogte / draggingCard.afbeelding:getHeight()
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(draggingCard.afbeelding, mx - 40, my - 60, 0, schaal, schaal)
    end
end

-----------------------------------------------------------------
-- MENU  --------------------------------------------------------
function ui.draw_menu(mouseX, mouseY)
    local w,h = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(1,1,1)
    love.graphics.printf("Zweeds Pesten",0,150,w,"center")

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
end

return ui
