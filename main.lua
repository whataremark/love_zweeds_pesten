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

function startGame(mode)
    selectedMode = mode          -- bewaren voor later
    scene        = "playing"

    love.graphics.setBackgroundColor(0.9,0.9,0.9)

    deck.init()
    player.init(deck)

    pot = { deck.draw() }
    ronde = 0
    ongeldigeZetTimer = 0

    game.mode = mode             -- AI of human
    game.players[1].hand = player.hand
    game.players[2].hand = {}    -- blijft zo bij AI; bij human-code straks vullen
    game.currentPlayer = 1
    game.waitingForAI  = false
end


function love.load()
    love.graphics.setBackgroundColor(0.9, 0.9, 0.9)
    deck.init()
    player.init(deck)

    -- Startkaart op de pot
    pot = {}
    table.insert(pot, deck.draw())
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

    --debug ish
    love.graphics.print("Speler aan zet: " .. game.currentPlayer, 20, 60)
    love.graphics.print("AI-timer: " .. string.format("%.2f", game.aiTimer), 20, 80)


end

function love.mousepressed(x, y, button)
      if scene=="menu" and button==1 then
        local inside = function(mx,my,bx,by,bw,bh)
            return mx>bx and mx<bx+bw and my>by and my<by+bh
        end
        if inside(x,y,ui.aiX,ui.aiY,ui.aiW,ui.aiH) then
            startGame("ai")
            return
        elseif inside(x,y,ui.hX,ui.hY,ui.hW,ui.hH) then
            startGame("human")
            return
        end
    end
    
    if button == 1 then
        player.startDrag(x, y)
    end
    -- Toggle toonPotOverlay
    if x > love.graphics.getWidth() - 150 and y > love.graphics.getHeight() - 50 then
    toonPotOverlay = not toonPotOverlay
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
            -- Speciale regels verwerken
            if kaart.waarde == "10" then
                for i = #pot, 1, -1 do
                    table.remove(pot, i)
                end
                game.play_card(1, kaart, pot)
                ronde = ronde + 1
                -- next turn wegehaald want speler mag nog een keer
                return
            elseif kaart.waarde == "2" or kaart.waarde == "3" then
                game.play_card(1, kaart, pot)
                ronde = ronde + 1
                game.next_turn()
                return
            elseif kaart.waarde == "8" then
                game.play_card(1, kaart, pot)
                ronde = ronde + 1
                -- zelf nog een keer
                return
            elseif kaart.waarde == "7" then
                game.play_card(1, kaart, pot)
                ronde = ronde + 1
                game.nextMustBeUnder7 = true
                game.next_turn()
                return
            else
                game.play_card(1, kaart, pot)
                ronde = ronde + 1
                game.next_turn()
                return
            end
        else
            -- Ongeldige zet
            table.insert(player.hand, kaart)
            ongeldigeZetTimer = 1.0
        end
    else
        -- Niet op de pot gelegd
        table.insert(player.hand, kaart)
    end
end
