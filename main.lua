-- Main entry file controlling scenes and user input

local drawPile  = require("drawpile")
local player = require("player")
local ui    = require("ui")
local rules = require("rules")
local game  = require("game")
local ai    = require("ai")
local utils = require("utils")

local bgCanvas

local scene = "menu"  -- "menu" | "playing"

local ronde = 0
local ongeldigeZetTimer = 0

toonPotOverlay = false


--codex-- Initialize global resources
function love.load()
    -- Pre-render the background felt texture once
    bgCanvas = utils.generate_green_felt_background(love.graphics.getWidth(), love.graphics.getHeight())
end


--codex-- Game loop update handling AI and timers
function love.update(dt)
    if scene == "playing" then
        player.updateDragging()
        if ongeldigeZetTimer > 0 then
            ongeldigeZetTimer = ongeldigeZetTimer - dt
        end
        ai.update(dt, game, game.pot)
    end
end

--codex-- Render the current scene and game state
function love.draw()
    love.graphics.setBackgroundColor(0.1, 0.4, 0.1)
    if scene=="menu" then
        ui.draw_menu(love.mouse.getX(),love.mouse.getY())
        return
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(bgCanvas, 0, 0)

    ui.draw_pot(game.pot, ongeldigeZetTimer > 0, toonPotOverlay)
    ui.draw_deck(drawPile)
    ui.draw_all_players(player.players)
    -- Sleepkaart bovenop tekenen (volgt muis)
    if player.draggingCard then
        local kaart = player.draggingCard
        local mx, my = love.mouse.getPosition()
        local schaal = 160 / 500
        local x = mx - player.dragOffset.x
        local y = my - player.dragOffset.y
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(kaart.afbeelding, x, y, 0, schaal, schaal)
    end

    love.graphics.setColor(0, 0, 0)
    love.graphics.print("Ronde: " .. ronde, 20, 20)
    love.graphics.print("Kaarten in pot: " .. #game.pot, 20, 40)
    
    --debug ish
    love.graphics.print("Speler aan zet: " .. game.currentPlayer, 20, 60)
    love.graphics.print("AI-timer: " .. string.format("%.2f", game.aiTimer), 20, 80)

    buttons = ui.draw_action_buttons()
end

--codex-- Handle mouse clicks for menus and card actions
function love.mousepressed(x, y, button)
    if scene == "menu" and button == 1 then
        if utils.inside(x, y, ui.d1x, ui.d1y, ui.d1w, ui.d1h) then
            game.deckCount = 1
            return
        elseif utils.inside(x, y, ui.d2x, ui.d2y, ui.d2w, ui.d2h) then
            game.deckCount = 2
            return
        elseif utils.inside(x, y, ui.aiX, ui.aiY, ui.aiW, ui.aiH) then
            game.start("ai")
            scene = "playing"
            ronde = 0
            ongeldigeZetTimer = 0
            return
        elseif utils.inside(x, y, ui.hX, ui.hY, ui.hW, ui.hH) then
            game.start("human")
            scene = "playing"
            ronde = 0
            ongeldigeZetTimer = 0
            return
        end
    end

    -- Spelerkaart slepen
    if button == 1 then
        player.startDrag(x, y)
    end

    if game.state == "selectFaceUp" and button == 1 then
    print("selectFaceUp")
    local hand = player.hand

    -- Klik op een kaart om te selecteren of deselecteren
    for i, card in ipairs(hand) do
        local pos = ui.get_card_positions(hand)[i]
        local cardX, cardY, w, h = pos.x, pos.y, config.cardWidth, config.cardHeight
        if x > cardX and x < cardX + w and y > cardY and y < cardY + h then
            if player.selectedFaceUp[i] then
                player.selectedFaceUp[i] = nil
            elseif table.count(player.selectedFaceUp) < 3 then
                player.selectedFaceUp[i] = true
            end
        end
    end

    -- Klik op de bevestigingsknop
    if ui.confirmBtn then
        local b = ui.confirmBtn
        if x > b.x and x < b.x + b.w and y > b.y and y < b.y + b.h then
            local selected = {}
            for i, v in pairs(player.selectedFaceUp) do
                table.insert(selected, player.hand[i])
            end

            if #selected == 3 then
                player.faceUp = selected

                -- Verwijder geselecteerde kaarten uit hand
                for i = #player.hand, 1, -1 do
                    if player.selectedFaceUp[i] then
                        table.remove(player.hand, i)
                    end
                end

                game.state = "playing"
                print("Kaarten geselecteerd, spel begint")
            else
                print("Selecteer precies 3 kaarten!")
            end
        end
    end
end


    -- Knoppen onderaan controleren (Pak kaart & Pot bekijken)
    if button == 1 and buttons then
        -- Pak kaart knop
        local b = buttons.pickup
        if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
            if game.currentPlayer == 1 then
                -- Alle kaarten uit de pot naar de speler overzetten
                utils.transfer_all_cards(player.players[1].hand, game.pot)
                print("Speler pakt pot op (" .. #player.players[1].hand .. " kaarten)")
                game.next_turn()
            else
                print("Niet jouw beurt.")
            end
            return
        end

        -- Pot bekijken knop
        local b2 = buttons.pot
        if x >= b2.x and x <= b2.x + b2.w and y >= b2.y and y <= b2.y + b2.h then
            toonPotOverlay = not toonPotOverlay
            return
        end
    end
end

function love.wheelmoved(x, y)
    if game.currentPlayer == 1 then
        local scrollSnelheid = 60  -- pixels per scroll
        player.scrollOffset = math.max(0, player.scrollOffset - y * scrollSnelheid)
    end
end


--codex-- Drop a dragged card onto the table or return it
function love.mousereleased(x, y, button)
    if button ~= 1 then return end

    local kaart = player.stopDrag()
    if not kaart then return end

    local px, py = love.graphics.getWidth()/2 - 50, love.graphics.getHeight()/2 - 70
    local pw, ph = 100, 140
    -- Controleer of de kaart in het potgebied wordt losgelaten
    local inPot = utils.inside(x, y, px, py, pw, ph)

    if game.currentPlayer ~= 1 then
        table.insert(player.players[1].hand, kaart)
        return
    end


    if inPot then
        if rules.is_speelbaar(kaart, game.pot, game.nextMustBeUnder7) then
            rules.handle_card_effects(game, 1, kaart)
            ronde = ronde + 1
            utils.refill_hand(player.players[1].hand, drawPile)
        else
            table.insert(player.players[1].hand, kaart)
            ongeldigeZetTimer = 1.0
        end
    else
        table.insert(player.players[1].hand, kaart)
    end
end