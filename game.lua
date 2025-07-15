-- game.lua  – complete speel-state (data + callbacks)

----------------------------------------------------------------------
-- 0.  Imports
----------------------------------------------------------------------
local game      = {}                     -- module-tabel die we teruggeven
local drawPile  = require("drawpile")
local player    = require("player")
local utils     = require("utils")
local config    = require("config")
local net       = require("net")
local ui        -- later laden voor circular dependency
local rules     -- later laden voor circular dependency
local ai        --- later laden voor circular dependency

----------------------------------------------------------------------
-- 1.  Interne variabelen (voorheen globals in main.lua)
----------------------------------------------------------------------
local bgCanvas
local scene             = "playing"       -- "playing" | "gameover"
local ronde             = 0
local ongeldigeZetTimer = 0
local toonPotOverlay    = false
local buttons           = nil             -- actie-knoppen van ui

----------------------------------------------------------------------
-- 2.  Kern-state (onveranderd uit je oude game.lua)
----------------------------------------------------------------------
game.mode              = "ai"
game.pot               = {}
game.deckCount         = 1
game.currentPlayer     = 1
game.maxPlayers        = 2
game.aiTimer           = 0
game.waitingForAI      = false
game.nextMustBeUnder7  = false
game.extraTurn         = false
game.winner            = nil
game.reveal            = { timer = 0, player = nil, card = nil }

----------------------------------------------------------------------
-- Hulp: fase bepalen
----------------------------------------------------------------------
local function phase_for_player(i)
    return utils.phase_for_player(i)
end

----------------------------------------------------------------------
-- 3.  Initialisatie wanneer de state ge-enterd wordt
----------------------------------------------------------------------
function game.load(cfg)
    ui = ui or require("ui")   -- lazy require, pas nu is de lus weg
    rules = rules or require("rules")
    ai    = ai    or require("ai")

    -- achtergrond één keer prerenderen
    bgCanvas = utils.generate_green_felt_background(
                   love.graphics.getWidth(), love.graphics.getHeight())

    -- start een nieuwe ronde in gevraagde modus (ai / host / client)
    game.start(cfg and cfg.mode or "ai")

    -- reset lokale timers / flags
    scene             = "playing"
    ronde             = 0
    ongeldigeZetTimer = 0
    toonPotOverlay    = false
    buttons           = nil
end

----------------------------------------------------------------------
-- 4.  Hoofd-update (was je oude love.update)
----------------------------------------------------------------------
function game.update(dt)
    if scene ~= "playing" then return end

    -- Netwerk-sync
    if net.isMultiplayer() then
        net.update()
        if net.isHost() then net.send_state() end
    end

    -- A) Ongeldige-zet-timer
    if ongeldigeZetTimer > 0 then
        ongeldigeZetTimer = ongeldigeZetTimer - dt
    end

    -- B) Reveal-timer (blinde kaart)
    if game.reveal.timer > 0 then
        game.reveal.timer = game.reveal.timer - dt
        if game.reveal.timer <= 0 then
            local p  = game.reveal.player
            local k  = game.reveal.card
            local ok = rules.is_speelbaar(k, game.pot, game.nextMustBeUnder7)

            if ok then
                rules.handle_card_effects(game, p, k)
            else
                local pl = player.players[p]
                utils.transfer_all_cards(pl.hand, game.pot)
                table.insert(pl.hand, k)
                if p == net.localId then utils.deselect_all(pl.hand) end
                game.next_turn()
            end

            game.reveal.timer  = 0
            game.reveal.player = nil
            game.reveal.card   = nil
        end
        return
    end

    -- C) AI
    utils.update_reveal_logic(dt, game)
    if game.mode == "ai" then
        ai.update(dt, game, game.pot)
    end

    -- D) Winner-check
    if game.winner then
        scene = "gameover"
    end
end

----------------------------------------------------------------------
-- 5.  Hoofd-draw (was je oude love.draw)
----------------------------------------------------------------------
function game.draw()
    love.graphics.setBackgroundColor(0.1, 0.4, 0.1)

    if scene == "gameover" then
        ui.draw_end_screen(game.winner, player.players)
        return
    end

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(bgCanvas, 0, 0)

    ui.draw_pot(game.pot, ongeldigeZetTimer > 0, toonPotOverlay)
    ui.draw_deck(drawPile)
    ui.draw_all_players(player.players)

    love.graphics.setColor(0, 0, 0)
    love.graphics.print("Ronde: "           .. ronde,                  20, 20)
    love.graphics.print("Kaarten in pot: "  .. #game.pot,             20, 40)
    love.graphics.print("Speler aan zet: "  .. game.currentPlayer,    20, 60)
    love.graphics.print("AI-timer: "        .. string.format("%.2f", game.aiTimer), 20, 80)

    if game.state ~= "setupSelectOpen" and game.state ~= "setupAISelect" then
        buttons = ui.draw_action_buttons()
    else
        buttons = nil
    end
end

----------------------------------------------------------------------
-- 6.  Input-callbacks (uit je oude main.lua)
----------------------------------------------------------------------
function game.mousepressed(x, y, button)
    if game.reveal.timer > 0 then return end
    ------------------------------------------------------------------
    -- SETUP-fase: speler kiest 3 open kaarten
    ------------------------------------------------------------------
    if game.state == "setupSelectOpen" and button == 1 then
        local me        = net.localId
        local hand      = player.players[me].hand
        local positions = ui.get_card_positions(hand)

        for i = #positions, 1, -1 do
            local p = positions[i]
            if utils.inside(x, y, p.x, p.y, p.w, p.h) then
                local kaart = table.remove(hand, i)
                table.insert(player.players[me].faceUp, kaart)
                if #player.players[me].faceUp == config.SETUP_OPEN then
                    game.state = "setupAISelect"
                end
                return
            end
        end
    end

    ------------------------------------------------------------------
    -- OPEN-fase – kaart uit faceUp kiezen
    ------------------------------------------------------------------
    if game.state == "playingOpen" and game.currentPlayer == net.localId and button == 1 then
        local faceUp    = player.players[net.localId].faceUp
        if #faceUp == 0 then goto AFTER_OPEN end

        local w = love.graphics.getWidth()
        local TARGET_H, PADDING = 140, 15
        local boxH  = TARGET_H + 40
        local boxY  = love.graphics.getHeight() - boxH - 10
        local yRow  = ui.row_faceUp_Y(boxY, 1)

        if y >= yRow and y <= yRow + TARGET_H then
            local first   = faceUp[1].afbeelding
            local scale   = TARGET_H / first:getHeight()
            local cardW   = first:getWidth() * scale
            local spacing = cardW + PADDING
            local totalW  = #faceUp * spacing - PADDING
            local xStart  = (w - totalW) / 2
            local col     = math.floor((x - xStart) / spacing) + 1
            if faceUp[col] then
                player.toggle_select(faceUp, col, "open")
            end
            return
        end
    end
    ::AFTER_OPEN::

    ------------------------------------------------------------------
    -- BLIND-fase – klik op een faceDown-kaart
    ------------------------------------------------------------------
    if game.state == "playingBlind" and game.currentPlayer == net.localId and button == 1 then
        local boxY = love.graphics.getHeight() - (160 + 40) - 10
        local yRow = ui.row_faceDown_Y(boxY, 1)
        if y >= yRow and y <= yRow + 160 then
            local kaart = table.remove(player.players[net.localId].faceDown, 1)
            game.reveal.timer  = 1.0
            game.reveal.card   = kaart
            game.reveal.player = net.localId
            return
        end
    end

    ------------------------------------------------------------------
    -- ACTIE-KNOPPEN + kaartselectie in hand
    ------------------------------------------------------------------
    if button == 1 then
        if buttons then
            -- PICK-UP
            local b = buttons.pickup
            if b and utils.inside(x, y, b.x, b.y, b.w, b.h) then
                if net.isClient() then
                    net.pickup_from_client()
                elseif game.currentPlayer == net.localId then
                    utils.transfer_all_cards(player.players[net.localId].hand, game.pot)
                    utils.deselect_all(player.players[net.localId].hand)
                    game.nextMustBeUnder7 = false
                    game.next_turn()
                end
                return
            end

            -- PLAY (hand-fase)
            local bp = buttons.play
            if bp and utils.inside(x, y, bp.x, bp.y, bp.w, bp.h)
               and game.state == "playingHand" then

                if game.currentPlayer ~= net.localId then return end
                if net.isClient() then
                    local cards = {}
                    for _,k in ipairs(player.players[net.localId].hand) do
                        if k.selected then
                            table.insert(cards, {kleur=k.kleur, waarde=k.waarde})
                        end
                    end
                    net.play_from_client(cards)
                    utils.deselect_all(player.players[net.localId].hand)
                else
                    local ok = rules.play_selected_cards(game, net.localId)
                    if ok then
                        local p = player.players[net.localId]
                        utils.refill_hand(p.hand, drawPile, config.CARDS_INHAND)
                        utils.update_phase_for_player(game, net.localId)
                    else
                        ongeldigeZetTimer = 1.0
                    end
                end
                return
            end

            -- PLAY (open-fase)
            if bp and utils.inside(x, y, bp.x, bp.y, bp.w, bp.h)
               and game.state == "playingOpen" then

                local ok = rules.play_selected_open(game, net.localId)
                if not ok then ongeldigeZetTimer = 1.0 end
                return
            end

            -- PASS
            local bpass = buttons.pass
            if bpass and utils.inside(x, y, bpass.x, bpass.y, bpass.w, bpass.h) then
                if net.isClient() then
                    net.pass_from_client()
                elseif game.currentPlayer == net.localId and game.extraTurn then
                    game.extraTurn = false
                    game.next_turn()
                end
                return
            end

            -- BEKIJK POT
            local bv = buttons.pot
            if bv and utils.inside(x, y, bv.x, bv.y, bv.w, bv.h) then
                toonPotOverlay = not toonPotOverlay
                return
            end

            -- DESELECT
            local bd = buttons.deselect
            if bd and utils.inside(x, y, bd.x, bd.y, bd.w, bd.h) then
                utils.deselect_all(player.players[net.localId].hand)
                return
            end
        end

        -- Geen knop geraakt → kaart in hand (zichtbare posities)
        local hand      = player.players[net.localId].hand
        local positions = ui.get_card_positions(hand)
        for i = #positions, 1, -1 do
            local p = positions[i]
            if utils.inside(x, y, p.x, p.y, p.w, p.h) then
                player.toggle_select(hand, i, game.state)
                return
            end
        end
    end
end

function game.wheelmoved(x, y)
    if game.currentPlayer == net.localId then
        local CARD_H_SRC, CARD_W_SRC = 500, 300
        local CARD_H      = 160
        local SCALE       = CARD_H / CARD_H_SRC
        local CARD_W      = CARD_W_SRC * SCALE
        local PADDING     = 15
        local cardSpace   = CARD_W + PADDING

        local p = player.players[net.localId]
        p.scrollOffset = math.max(0, (p.scrollOffset or 0) - y * cardSpace)
    end
end

function game.keypressed(key)
    if key == "space" and scene == "playing" and game.currentPlayer == net.localId then
        local b = buttons and buttons.play
        if b then
            local cx, cy = b.x + b.w/2, b.y + b.h/2
            game.mousepressed(cx, cy, 1)
        end
    end
end

--------------------------------------------------------------------
-- game.start(mode)  – nieuwe ronde opzetten
--------------------------------------------------------------------
function game.start(mode)
    -------------------------------------------------------------- 0
    -- Trekstapel maken en schudden
    --------------------------------------------------------------
    drawPile.init(game.deckCount)            -- aantal decks → config

    -------------------------------------------------------------- 1
    -- Spelers resetten + delen
    --------------------------------------------------------------
    player.init(drawPile)                    -- vult hand & faceDown
    game.maxPlayers = #player.players

    -------------------------------------------------------------- 2
    -- Basis-status resetten
    --------------------------------------------------------------
    if mode == "multiplayer-host" or mode == "multiplayer-client" then
        game.mode = "multiplayer"
    else
        game.mode = mode or "ai"
    end
    game.currentPlayer = 1
    game.waitingForAI  = false
    game.extraTurn     = false
    game.winner        = nil
    game.ronde         = 0

    -- start in setup-fase (mens kiest open kaarten)
    game.state = "setupSelectOpen"

    -------------------------------------------------------------- 3
    -- Lege pot & startspeler bepalen
    --------------------------------------------------------------
    game.pot = {}
    game.nextMustBeUnder7 = false

    local order = {"4","5","6","7","8","9","10","jack","queen","king","ace"}
    local found
    for _,v in ipairs(order) do
        for pid=1,game.maxPlayers do
            for _,c in ipairs(player.players[pid].hand) do
                if c.waarde==v and rules.is_speelbaar(c, game.pot, false) then
                    game.currentPlayer = pid
                    found = v
                    break
                end
            end
            if found then break end
        end
        if found then break end
    end
    if found then
        print(string.format("[INIT] P%d starts with %s", game.currentPlayer, found))
    else
        print("[INIT] no 4/5/… found")
    end

    print(string.format(
        "[GAME] Nieuwe ronde: %d decks, hand=%d, blind=%d",
        game.deckCount, config.HAND_SIZE, config.BLIND_SIZE))

    -- Netwerk delen
    if mode == "multiplayer-host" then
        net.set_game(game)
        net.send_state()
    elseif mode == "multiplayer-client" then
        net.set_game(game)
    end
end


--------------------------------------------------------------------
-- game.play_card(playerIndex, kaart)  – kaart van hand naar pot
--------------------------------------------------------------------
function game.play_card(playerIndex, kaart)
    table.insert(game.pot, kaart)
    local hand = player.players[playerIndex].hand
    for i = 1, #hand do
        local k = hand[i]
        if k.waarde == kaart.waarde and k.kleur == kaart.kleur then
            table.remove(hand, i)
            return
        end
    end
end


--------------------------------------------------------------------
-- game.next_turn()  – speler-wissel + AI-timer + fase-update
--------------------------------------------------------------------
function game.next_turn()
    game.currentPlayer = (game.currentPlayer % game.maxPlayers) + 1
    game.state        = phase_for_player(game.currentPlayer)

    print(string.format("[TURN] now player id=%d", game.currentPlayer))

    if game.mode == "ai" and game.currentPlayer == 2 then
        game.waitingForAI = true
        game.aiTimer      = 0.5            -- korte denk-pauze
    else
        game.waitingForAI = false
        game.aiTimer      = 0
    end
    game.check_winner()
end


--------------------------------------------------------------------
-- game.check_winner()  – einde-spel controle
--------------------------------------------------------------------
function game.check_winner()
    for i, p in ipairs(player.players) do
        if #p.hand == 0 and #p.faceUp == 0 and #p.faceDown == 0 then
            game.winner = i
            scene       = "gameover"       -- activeer draw-scherm
            print("[GAME] Speler "..i.." wint!")
            return
        end
    end
end

return game
