-- Main entry file controlling scenes and user input
local drawPile  = require("drawpile")
local player = require("player")
local ui    = require("ui")
local rules = require("rules")
local game  = require("game")
local ai    = require("ai")
local utils = require("utils")
local config = require("config")

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
    
    love.graphics.setColor(0, 0, 0)
    love.graphics.print("Ronde: " .. ronde, 20, 20)
    love.graphics.print("Kaarten in pot: " .. #game.pot, 20, 40)
    
    --debug ish
    love.graphics.print("Speler aan zet: " .. game.currentPlayer, 20, 60)
    love.graphics.print("AI-timer: " .. string.format("%.2f", game.aiTimer), 20, 80)

    buttons = ui.draw_action_buttons()
end

--codex-- Handle mouse clicks for menus, buttons en kaart-acties
function love.mousepressed(x, y, button)
    ------------------------------------------------------------------
    --  MENU-SCENE
    ------------------------------------------------------------------
    if scene == "menu" and button == 1 then
        if utils.inside(x, y, ui.d1x, ui.d1y, ui.d1w, ui.d1h) then
            game.deckCount = 1;   return
        elseif utils.inside(x, y, ui.d2x, ui.d2y, ui.d2w, ui.d2h) then
            game.deckCount = 2;   return
        elseif utils.inside(x, y, ui.aiX, ui.aiY, ui.aiW, ui.aiH) then
            game.start("ai");     scene = "playing"
            ronde = 0;            ongeldigeZetTimer = 0
            return
        elseif utils.inside(x, y, ui.hX, ui.hY, ui.hW, ui.hH) then
            game.start("human");  scene = "playing"
            ronde = 0;            ongeldigeZetTimer = 0
            return
        end
    end
----------------------------------------------------------------
--  OPEN-fase  –  speler mag op zijn faceUp-kaarten klikken
----------------------------------------------------------------
if scene == "playing"
   and game.state == "playingOpen"
   and game.currentPlayer == 1
   and button == 1 then

    local boxY   = love.graphics.getHeight()                      -- of bewaar boxY
                    - (160 + 40) - 10                              -- CARD_H + 40 + margin
    local yRow   = ui.row_faceUp_Y(boxY)

    -- ligt de klik in de verticale band van de open-rij?
    if y >= yRow and y <= yRow + 160 then                          -- 160 = CARD_H
        local c = table.remove(player.players[1].faceUp, 1)        -- pak 1e kaart
        rules.handle_card_effects(game, 1, c, true)
        return
    end
end

----------------------------------------------------------------
--  BLIND-fase  –  klik op een faceDown-kaart (rug)
----------------------------------------------------------------
if scene == "playing"
   and game.state == "playingBlind"
   and game.currentPlayer == 1
   and button == 1 then

    local boxY   = love.graphics.getHeight()
                    - (160 + 40) - 10
    local yRow   = ui.row_faceDown_Y(boxY)

    if y >= yRow and y <= yRow + 160 then
        local c = table.remove(player.players[1].faceDown, 1)
        table.insert(game.pot, c)                                   -- direct op pot

        if not rules.is_speelbaar(c, game.pot, game.nextMustBeUnder7) then
            utils.transfer_all_cards(player.players[1].hand, game.pot)
        end
        game.next_turn()
        return
    end
end
    ------------------------------------------------------------------
    --  PLAYING-SCENE
    ------------------------------------------------------------------
    if scene == "playing" and button == 1 then
        --------------------------------------------------------------
        -- 1. UI-knoppen (Pak pot / Speel / Bekijk pot / Deselect)
        --    Eerst afhandelen → bij hit meteen RETURN
        --------------------------------------------------------------
        if buttons then
            local b = buttons.pickup
            if b and utils.inside(x, y, b.x, b.y, b.w, b.h) then
                if game.currentPlayer == 1 then
                    utils.transfer_all_cards(player.players[1].hand, game.pot)
                    utils.deselect_all(player.players[1].hand)
                    print("Speler pakt pot op (" .. #player.players[1].hand .. " kaarten)")
                    game.next_turn()
                else
                    print("Niet jouw beurt.")
                end
                return
            end

            local bp = buttons.play
            if bp and utils.inside(x, y, bp.x, bp.y, bp.w, bp.h) then
                if game.currentPlayer == 1 then
                    local ok = require("rules").play_selected_cards(game, 1)
                    if ok then
                        local speler = player.players[1]
                        utils.refill_hand(speler.hand, drawPile, config.HAND_SIZE)
                        ronde = ronde + 1
                        for _, k in ipairs(speler.hand) do k.selected = false end
                    else
                        ongeldigeZetTimer = 1.0   -- rood randje
                    end
                else
                    print("Niet jouw beurt.")
                end
                return
            end

            local bv = buttons.pot
            if bv and utils.inside(x, y, bv.x, bv.y, bv.w, bv.h) then
                toonPotOverlay = not toonPotOverlay
                return
            end

            -- (optioneel) Deselect-knop
            local bd = buttons.deselect
            if bd and utils.inside(x, y, bd.x, bd.y, bd.w, bd.h) then
                utils.deselect_all(player.players[1].hand)
                return
            end
        end

        --------------------------------------------------------------
        -- 2.  Géén knop geraakt → kaarten proberen selecteren
        --------------------------------------------------------------
        local hand      = player.players[1].hand
        local positions = ui.get_card_positions(hand)

        -- loop van rechts-naar-links zodat bovenliggende kaart wint
        for i = #positions, 1, -1 do
            local p = positions[i]
            if utils.inside(x, y, p.x, p.y, p.w, p.h) then
                player.toggle_select(hand, i, game.state)
                return
            end
        end
    end
end


function love.wheelmoved(x, y)
    if game.currentPlayer == 1 then
        -- zelfde maatvoering als ui.draw_player_area
        local CARD_H_SRC, CARD_W_SRC = 500, 300
        local CARD_H  = 160
        local SCALE   = CARD_H / CARD_H_SRC
        local CARD_W  = CARD_W_SRC * SCALE
        local PADDING = 15
        local cardSpace = CARD_W + PADDING

        local p = player.players[1]           -- ← één bron
        p.scrollOffset = math.max(0, (p.scrollOffset or 0) - y * cardSpace)
    end
end


function love.keypressed(key)
    -- Alleen als we in de speel-scène zijn en de speler aan zet is
    if key == "space" and scene == "playing" and game.currentPlayer == 1 then
        local b = buttons.play
        if b then
            -- Simuleer een muisklik in het midden van de Play-knop
            local clickX = b.x + b.w/2
            local clickY = b.y + b.h/2
            love.mousepressed(clickX, clickY, 1)
        end
    end
end