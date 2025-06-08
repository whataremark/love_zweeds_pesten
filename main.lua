local deck = require("deck")
local player = require("player")
local ui = require("ui")
local rules = require("rules")
local game = require("game")


local scene = "menu"  -- "menu" | "playing"
local selectedMode    -- "ai" | "human"


local pot = {}
local ronde = 0
local ongeldigeZetTimer = 0

toonPotOverlay = false

function love.load()
    love.graphics.setBackgroundColor(0.9, 0.9, 0.9)
end

function startGame(mode)
    selectedMode = mode
    scene        = "playing"

    deck.init()
    player.init(deck)

    pot = { deck.draw() }
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
    print("\n=== AI-START ===")
    print("AI heeft nu " .. #game.players[2].hand .. " kaarten op hand:")
    for i, c in ipairs(game.players[2].hand) do
        print(string.format("  [%d] %s of %s", i, c.waarde, c.kleur))
    end
end


function love.update(dt)
       if scene=="playing" then
        player.updateDragging()
        if ongeldigeZetTimer>0 then ongeldigeZetTimer = ongeldigeZetTimer - dt end
        game.update(dt,pot)
    end

end



function love.draw()
    if scene=="menu" then
        ui.draw_menu(love.mouse.getX(),love.mouse.getY())
        return
    end
    ui.draw_pot(pot, ongeldigeZetTimer > 0, toonPotOverlay)
    ui.draw_other_players()
    ui.draw_hand(player.hand, player.draggingCard)

    love.graphics.print("Aan de beurt: Speler " .. game.currentPlayer, 20, 20)


    love.graphics.setColor(0, 0, 0)
    love.graphics.print("Ronde: " .. ronde, 20, 20)
    love.graphics.print("Kaarten in pot: " .. #pot, 20, 40)
    
    pickupButton = drawPickupButton()

    --debug ish
    love.graphics.print("Speler aan zet: " .. game.currentPlayer, 20, 60)
    love.graphics.print("AI-timer: " .. string.format("%.2f", game.aiTimer), 20, 80)


end

function love.mousepressed(x, y, button)
    if scene == "menu" and button == 1 then
        local inside = function(mx, my, bx, by, bw, bh)
            return mx > bx and mx < bx + bw and my > by and my < by + bh
        end
        if inside(x, y, ui.aiX, ui.aiY, ui.aiW, ui.aiH) then
            startGame("ai")
            return
        elseif inside(x, y, ui.hX, ui.hY, ui.hW, ui.hH) then
            startGame("human")
            return
        end
    end

    -- Spelerkaart slepen
    if button == 1 then
        player.startDrag(x, y)
    end

    -- Toon pot overlay toggle
    if button == 1 and x > love.graphics.getWidth() - 150 and y > love.graphics.getHeight() - 50 then
        toonPotOverlay = not toonPotOverlay
    end

    -- Pickup button check
    if button == 1 and pickupButton then
        if x >= pickupButton.x and x <= pickupButton.x + pickupButton.w and
           y >= pickupButton.y and y <= pickupButton.y + pickupButton.h then

            if game.currentPlayer == 1 then
                for i = #pot, 1, -1 do
                    table.insert(player.hand, table.remove(pot, i))
                end
                print("Speler pakt pot op (" .. #player.hand .. " kaarten)")
                game.next_turn()
            else
                print("Niet jouw beurt.")
            end
        end
    end
end


function love.mousereleased(x, y, button)
    if button ~= 1 then return end

    local kaart = player.stopDrag()
    if not kaart then return end

    local px, py = love.graphics.getWidth()/2 - 50, love.graphics.getHeight()/2 - 70
    local pw, ph = 100, 140
    local inPot = x > px and x < px + pw and y > py and y < py + ph

    if game.currentPlayer ~= 1 then
        table.insert(player.hand, kaart)
        return
    end

    if inPot then
        if rules.is_speelbaar(kaart, pot, game.nextMustBeUnder7) then
            game.handle_card_effects(1, kaart, pot)
            ronde = ronde + 1
        else
            table.insert(player.hand, kaart)
            ongeldigeZetTimer = 1.0
        end
    else
        table.insert(player.hand, kaart)
    end
end