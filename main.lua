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
        if ongeldigeZetTimer > 0 then
            ongeldigeZetTimer = ongeldigeZetTimer - dt
        end
        ai.update(dt, game, game.pot)
        if game.winner then
            scene = "gameover"
        end
    end
end

--codex-- Render the current scene and game state
function love.draw()
    love.graphics.setBackgroundColor(0.1, 0.4, 0.1)
    if scene=="menu" then
        ui.draw_menu(love.mouse.getX(),love.mouse.getY())
        return
    elseif scene=="gameover" then
        ui.draw_end_screen(game.winner, player.players)
        return
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(bgCanvas, 0, 0)

    ui.draw_pot(game.pot, ongeldigeZetTimer > 0, toonPotOverlay)
    ui.draw_deck(drawPile)
    ui.draw_all_players(player.players)
    
    love.graphics.print("Aan de beurt: Speler " .. game.currentPlayer, 20, 20)

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

    -- Kaartselectie
    if scene == "playing" and button == 1 then
        local positions = ui.get_card_positions(player.players[1].hand)
        for i,pos in ipairs(positions) do
            if utils.inside(x,y,pos.x,pos.y,pos.w,pos.h) then
                player.toggle_select(player.players[1].hand, i)
                return
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

        -- Speel knop
        local bp = buttons.play
        if x >= bp.x and x <= bp.x + bp.w and y >= bp.y and y <= bp.y + bp.h then
            if game.currentPlayer == 1 then
                for i=#player.players[1].hand,1,-1 do
                    if player.players[1].hand[i].selected then
                        local kaart = player.players[1].hand[i]
                        if rules.is_speelbaar(kaart, game.pot, game.nextMustBeUnder7) then
                            rules.handle_card_effects(game,1,kaart)
                            ronde = ronde + 1
                            utils.refill_hand(player.players[1].hand, drawPile)
                        else
                            ongeldigeZetTimer = 1.0
                        end
                        kaart.selected = false
                        break
                    end
                end
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
