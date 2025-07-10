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
    -- SETUP: speler kiest 3 open kaarten
    if scene == "playing"
    and game.state == "setupSelectOpen"
    and button == 1 then
        local hand      = player.players[1].hand
        local positions = ui.get_card_positions(hand)

        for i = #positions, 1, -1 do
            local p = positions[i]
            if utils.inside(x,y,p.x,p.y,p.w,p.h) then
                local kaart = table.remove(hand,i)
                table.insert(player.players[1].faceUp, kaart)
                if #player.players[1].faceUp == config.SETUP_OPEN then
                    game.state = "setupAISelect"   -- mens klaar → AI aan zet
                end
                return
            end
        end
    end

    ----------------------------------------------------------------
    --  OPEN-fase – kaart in faceUp selecteren
    ----------------------------------------------------------------
    if scene == "playing"
        and game.state == "playingOpen"
        and game.currentPlayer == 1
        and button == 1 then

        local faceUp = player.players[1].faceUp
        if #faceUp == 0 then  -- niets te selecteren, val door naar knoppen
            -- GEEN return hier!
        else
            ------------------------------------------------------ y-band
            local TARGET_H, PADDING = 140, 15
            local boxH  = TARGET_H + 40
            local boxY  = love.graphics.getHeight() - boxH - 10
            local yRow  = ui.row_faceUp_Y(boxY, 1)

            if y >= yRow and y <= yRow + TARGET_H then     -- klik ín de rij
                -------------------------------------------------- x-positie
                local first   = faceUp[1].afbeelding
                local scale   = TARGET_H / first:getHeight()
                local cardW   = first:getWidth() * scale
                local spacing = cardW + PADDING
                local totalW  = #faceUp * spacing - PADDING
                local xStart  = (love.graphics.getWidth() - totalW) / 2
                local col     = math.floor((x - xStart) / spacing) + 1

                if faceUp[col] then            -- kaart gevonden → toggelen
                    player.toggle_select(faceUp, col, "open")
                end
                return                        -- **alleen** na échte kaart-hit
            end
            -- valt de klik buiten de y-band? → gewoon doorlopen naar knoppen
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
        local yRow = ui.row_faceDown_Y(boxY, 1)

        if y >= yRow and y <= yRow + 160 then
            local c = table.remove(player.players[1].faceDown, 1)
            
            -- checken of kaart gespeeld mag worden..
            if rules.is_speelbaar(c, game.pot, game.nextMustBeUnder7) then
                -- kaart mag: voer effecten uit en blijf in dezelfde beurt-logica
                rules.handle_card_effects(game, 1, c)
            else
                -- kaart mag NIET: hele pot + de kaart terug naar je hand
                utils.transfer_all_cards(player.players[1].hand, game.pot)
                utils.deselect_all(player.players[1].hand) -- deselecteer alles
                table.insert(player.players[1].hand, c)
                game.next_turn()                              -- beurt voorbij
            end
            return
        end
    end
    ------------------------------------------------------------------
    --  PLAYING-SCENE
    ------------------------------------------------------------------
        ------------------------------------------------------------------
    --  PLAYING-SCENE (knoppen + kaart-selectie)
    ------------------------------------------------------------------
    if scene == "playing" and button == 1 then
        ----------------------------------------------------------------
        -- 1.  UI-knoppen (Pak pot / Speel / Bekijk pot / Deselect)
        --     ⇒ bij hit altijd meteen RETURN
        ----------------------------------------------------------------
        if buttons then
            ------------- Pak-pot --------------------------------------
            local b = buttons.pickup
            if b and utils.inside(x, y, b.x, b.y, b.w, b.h) then
                if game.currentPlayer == 1 then
                    utils.transfer_all_cards(player.players[1].hand, game.pot)
                    utils.deselect_all(player.players[1].hand)
                    utils.update_phase_for_player(game, 1)
                    print("Speler pakt pot op ("..#player.players[1].hand.." kaarten)")
                    game.next_turn()
                else
                    print("Niet jouw beurt.")
                end
                return
            end

            ------------- Speel-knop (één bp-variabele!) ---------------
            local bp = buttons.play

            -- === SPEEL tijdens OPEN-fase ============================
            if bp and utils.inside(x, y, bp.x, bp.y, bp.w, bp.h)
               and game.state == "playingOpen" then

                -- rules.play_selected_open regelt pot, effecten,
                -- én game.next_turn() als er geen extra beurt volgt.
                local ok = rules.play_selected_open(game, 1)
                if not ok then
                    ongeldigeZetTimer = 1.0
                end
                return
            end

            -- === SPEEL tijdens HAND-fase ============================
            if bp and utils.inside(x, y, bp.x, bp.y, bp.w, bp.h)
               and game.state == "playingHand" then

                if game.currentPlayer ~= 1 then
                    print("Niet jouw beurt.")
                    return
                end

                local ok = rules.play_selected_cards(game, 1)
                if ok then
                    local speler = player.players[1]
                    utils.refill_hand(speler.hand, drawPile, config.CARDS_INHAND)
                    utils.update_phase_for_player(game, 1)   -- hand → open/blind?
                    -- beurt- & extraTurn-afhandeling zit in rules.handle_card_effects
                else
                    ongeldigeZetTimer = 1.0
                end
                return
            end

            ------------- Pot bekijken --------------------------------
            local bv = buttons.pot
            if bv and utils.inside(x, y, bv.x, bv.y, bv.w, bv.h) then
                toonPotOverlay = not toonPotOverlay
                return
            end

            ------------- Deselect-knop -------------------------------
            local bd = buttons.deselect
            if bd and utils.inside(x, y, bd.x, bd.y, bd.w, bd.h) then
                utils.deselect_all(player.players[1].hand)
                return
            end
        end

        ----------------------------------------------------------------
        -- 2.  Geen knop geraakt → kaarten in hand proberen selecteren
        ----------------------------------------------------------------
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