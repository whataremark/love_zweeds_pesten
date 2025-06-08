local deck = {}

function deck.init()
    deck.cards = {}

    local kaartmap = "png"
    local bestanden = love.filesystem.getDirectoryItems(kaartmap)

    for _, bestand in ipairs(bestanden) do
        if bestand:match("%.png$") then
            local naam = bestand:gsub("%.png$", "")
            local waarde, kleur = naam:match("^(.-)_of_(.-)$")

            if waarde and kleur then
                local afbeelding = love.graphics.newImage(kaartmap .. "/" .. bestand)

                table.insert(deck.cards, {
                    kleur = kleur,
                    waarde = waarde,
                    afbeelding = afbeelding,
                    naam = naam
                })
            end
        end
    end

    -- Schudden
    math.randomseed(os.time())
    for i = #deck.cards, 2, -1 do
        local j = math.random(i)
        deck.cards[i], deck.cards[j] = deck.cards[j], deck.cards[i]
    end
end

function deck.draw()
    return table.remove(deck.cards)
end

return deck
