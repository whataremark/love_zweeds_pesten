local drawPile = {}

--codex-- Load and shuffle a deck with the configured amount of sets
function drawPile.init(count)
    count = count or 1
    drawPile.cards = {}

    local kaartmap = "assets/cards"
    local bestanden = love.filesystem.getDirectoryItems(kaartmap)
    local basis = {}

    for _, bestand in ipairs(bestanden) do
        if bestand:match("%.png$") then
            local naam = bestand:gsub("%.png$", "")
            local waarde, kleur = naam:match("^(.-)_of_(.-)$")

            if waarde and kleur then
                local afbeelding = love.graphics.newImage(kaartmap .. "/" .. bestand)

                table.insert(basis, {
                    kleur = kleur,
                    waarde = waarde,
                    afbeelding = afbeelding,
                    naam = naam
                })
            end
        end
    end

    for _ = 1, count do
        for _, card in ipairs(basis) do
            table.insert(drawPile.cards, card)
        end
    end

    -- Schudden
    math.randomseed(os.time())
    for i = #drawPile.cards, 2, -1 do
        local j = math.random(i)
        drawPile.cards[i], drawPile.cards[j] = drawPile.cards[j], drawPile.cards[i]
    end
end

function drawPile.draw()
    local c = table.remove(drawPile.cards)
    if not c then return nil end
    -- maak een kopie zodat geselecteerde staat per kaart uniek is
    return {
        kleur = c.kleur,
        waarde = c.waarde,
        afbeelding = c.afbeelding,
        naam = c.naam,
        selected = false
    }
end

function drawPile.count()
    return #drawPile.cards
end

return drawPile
