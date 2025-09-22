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
    scene = "playing"
    game.ronde = game.ronde or 1
    game.invalidTimer = 0
    game.showPotOverlay = false

    ui.layout(love.graphics.getWidth(), love.graphics.getHeight())
    ui.game = game
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

    -- Reveal-timer (blinde kaart)
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

    if ui and ui.update then
        ui.update(dt)
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

    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    ui.layout(w, h)
    ui.draw(game, drawPile)
end

function game.is_playing()
    return scene == "playing"
end

----------------------------------------------------------------------
-- 6.  Input-callbacks (uit je oude main.lua)
----------------------------------------------------------------------
function game.mousepressed(x, y, button) end
function game.mousereleased(x, y, button) end
function game.mousemoved(x, y, dx, dy) end
function game.wheelmoved(dx, dy) end
function game.touchpressed(id, x, y, dx, dy, pressure) end
function game.touchreleased(id, x, y, dx, dy, pressure) end
function game.touchmoved(id, x, y, dx, dy, pressure) end

function game.keypressed(key)
    if key == "space" and scene == "playing" then
        if ui.activate then
            ui.activate("play")
        end
    end
end

--------------------------------------------------------------------
-- game.start(mode)  – nieuwe ronde opzetten
--------------------------------------------------------------------
function game.start(mode)
    -------------------------------------------------------------- 0
    -- Trekstapel maken en schudden  ➜  **alleen de host doet dit**
    --------------------------------------------------------------
    if mode ~= "multiplayer-client" then
        drawPile.init(game.deckCount)        -- host: deck & shuffle
        player.init(drawPile)                -- host: kaarten delen
        game.maxPlayers = #player.players
    else
        -- client wacht op eerste STATE, weet maxPlayers nog niet
        game.maxPlayers = 2                  -- fallback, wordt overschreven
    end

    -------------------------------------------------------------- 1
    -- Basis‑status resetten
    --------------------------------------------------------------
    game.mode = (mode == "multiplayer-host" or mode == "multiplayer-client")
                and "multiplayer" or (mode or "ai")

    game.currentPlayer = 1
    game.waitingForAI  = false
    game.extraTurn     = false
    game.winner        = nil
    game.ronde         = 1
    game.state         = "setupSelectOpen"   -- mens kiest open kaarten
    game.showPotOverlay = false

    -------------------------------------------------------------- 2
    -- Lege pot & start‑speler bepalen  ➜  host alleen
    --------------------------------------------------------------
    game.pot = {}
    game.nextMustBeUnder7 = false

    -------------------------------------------------------------- 3
    -- Netwerk‑koppeling
    --------------------------------------------------------------
    if mode == "multiplayer-host" then
        net.set_game(game)
        net.send_state()
    elseif mode == "multiplayer-client" then
        net.set_game(game)     -- snapshot zal alles vullen
    end
end


----------------------------------------------------------------------
-- nadat álle spelers hun 3 open kaarten hebben gekozen
----------------------------------------------------------------------
local function all_open_selected()
    for id = 1, game.maxPlayers do
        if #player.players[id].faceUp < config.SETUP_OPEN then
            return false
        end
    end
    return true
end

function game.finalize_setup()
    if not all_open_selected() then return end   -- nog niet klaar

    -- bepaal wie mag beginnen: eerste 4, dan 5, 6, …
    local order = {"4","5","6","7","8","9","10","jack","queen","king","ace"}
    local found
    for _,v in ipairs(order) do
        for pid = 1, game.maxPlayers do
            for _,c in ipairs(player.players[pid].faceUp) do
                if c.waarde==v then
                    game.currentPlayer = pid
                    found = v
                    break
                end
            end
            if found then break end
        end
        if found then break end
    end
    print(found and
          string.format("[INIT] P%d starts with %s", game.currentPlayer, found)
          or "[INIT] no 4/5/… found")

    utils.update_phase_for_player(game, game.currentPlayer)
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
    utils.update_phase_for_player(game, game.currentPlayer)

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
