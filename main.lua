-- Main entry file controlling scenes and user input

local deck  = require("deck")
local player = require("player")
local ui    = require("ui")
local rules = require("rules")
local game  = require("game")
local ai    = require("ai")
local utils = require("utils")

local bgCanvas


local scene = "menu"  -- "menu" | "playing"
local selectedMode    -- "ai" | "human"


local pot = {}
local ronde = 0
local ongeldigeZetTimer = 0

toonPotOverlay = false

function love.load()
    -- Pre-render the background felt texture once
    bgCanvas = utils.generate_green_felt_background(love.graphics.getWidth(), love.graphics.getHeight())
end


function startGame(mode)
    selectedMode = mode
    scene        = "playing"

    deck.init()
    player.init(deck)

    pot = { deck.draw() }
    
    -- Als de eerste kaart een 7 is → activeer de 7-regel
    local startkaart = pot[#pot]
    if startkaart.waarde == "7" then
        game.nextMustBeUnder7 = true
        print("[INIT] Eerste kaart is een 7 → nextMustBeUnder7 = true")
    end

    ronde = 0
    ongeldigeZetTimer = 0

    game.mode = mode
    game.currentPlayer = 1
    game.waitingForAI  = false

    -- koppel hand van de mens aan game-model
    game.players[1].hand = player.hand

    -- deel 7 kaarten aan de AI
    game.players[2].hand = {}
    for i = 1, 7 do
        table.insert(game.players[2].hand, deck.draw())
    end

    -- Debug
    print("\n=== GAME START ===")
    print("AI heeft nu " .. #game.players[2].hand .. " kaarten op hand:")
    for i, c in ipairs(game.players[2].hand) do
        print(string.format("  [%d] %s of %s", i, c.waarde, c.kleur))
    end
end


function love.update(dt)
    if scene == "playing" then
        player.updateDragging()
        if ongeldigeZetTimer > 0 then
            ongeldigeZetTimer = ongeldigeZetTimer - dt
        end
        ai.update(dt, game, pot)
    end
end



function love.draw()
    love.graphics.setBackgroundColor(0.1, 0.4, 0.1)
    if scene=="menu" then
        ui.draw_menu(love.mouse.getX(),love.mouse.getY())
        return
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(bgCanvas, 0, 0)
    
    ui.draw_pot(pot, ongeldigeZetTimer > 0, toonPotOverlay)
    ui.draw_other_players()
    ui.draw_hand(player.hand, player.draggingCard)
    
    

    love.graphics.print("Aan de beurt: Speler " .. game.currentPlayer, 20, 20)

    love.graphics.setColor(0, 0, 0)
    love.graphics.print("Ronde: " .. ronde, 20, 20)
    love.graphics.print("Kaarten in pot: " .. #pot, 20, 40)
    
    --debug ish
    love.graphics.print("Speler aan zet: " .. game.currentPlayer, 20, 60)
    love.graphics.print("AI-timer: " .. string.format("%.2f", game.aiTimer), 20, 80)

    buttons = drawActionButtons()

end

function love.mousepressed(x, y, button)
    if scene == "menu" and button == 1 then
        if utils.inside(x, y, ui.aiX, ui.aiY, ui.aiW, ui.aiH) then
            startGame("ai")
            return
        elseif utils.inside(x, y, ui.hX, ui.hY, ui.hW, ui.hH) then
            startGame("human")
            return
        end
    end

    -- Spelerkaart slepen
    if button == 1 then
        player.startDrag(x, y)
    end

    -- Knoppen onderaan controleren (Pak kaart & Pot bekijken)
    if button == 1 and buttons then
        -- Pak kaart knop
        local b = buttons.pickup
        if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
            if game.currentPlayer == 1 then
                -- Alle kaarten uit de pot naar de speler overzetten
                utils.transfer_all_cards(player.hand, pot)
                print("Speler pakt pot op (" .. #player.hand .. " kaarten)")
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


function love.mousereleased(x, y, button)
    if button ~= 1 then return end

    local kaart = player.stopDrag()
    if not kaart then return end

    local px, py = love.graphics.getWidth()/2 - 50, love.graphics.getHeight()/2 - 70
    local pw, ph = 100, 140
    -- Controleer of de kaart in het potgebied wordt losgelaten
    local inPot = utils.inside(x, y, px, py, pw, ph)

    if game.currentPlayer ~= 1 then
        table.insert(player.hand, kaart)
        return
    end

    if inPot then
        if rules.is_speelbaar(kaart, pot, game.nextMustBeUnder7) then
            rules.handle_card_effects(game, 1, kaart, pot)
            ronde = ronde + 1
        else
            table.insert(player.hand, kaart)
            ongeldigeZetTimer = 1.0
        end
    else
        table.insert(player.hand, kaart)
    end
end
