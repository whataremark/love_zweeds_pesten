local drawPile = {}

--codex-- Load and shuffle a deck with the configured amount of sets
function drawPile.init(count)
    count = count or 1
    drawPile.cards = drawPile.cards or {}        -- ← voorkomt nil

    local kaartmap = "png"
    local bestanden = love.filesystem.getDirectoryItems(kaartmap)
    local basis = {}

    for _, bestand in ipairs(bestanden) do
        if bestand:match("%.png$") then
            local naam = bestand:gsub("%.png$", "")
            local waarde, kleur = naam:match("^(.-)_of_(.-)$")

            ------------------------------------------------------------
            -- 1. Gewone kaarten “X_of_<suit>.png”
            ------------------------------------------------------------
            if waarde and kleur then
                local afbeelding = love.graphics.newImage(kaartmap .. "/" .. bestand)

                table.insert(basis, {
                    kleur      = kleur,
                    waarde     = waarde,
                    afbeelding = afbeelding,
                    naam       = naam
                })

            ------------------------------------------------------------
            -- 2. Jokers: black_joker.png / red_joker.png
            --    (geen "_of_", dus vang ze in een extra elseif)
            ------------------------------------------------------------
            elseif naam == "black_joker" or naam == "red_joker" then
                local afbeelding = love.graphics.newImage(kaartmap .. "/" .. bestand)

                table.insert(basis, {
                    kleur      = (naam == "black_joker") and "black" or "red",
                    waarde     = "joker",        -- speciale waarde-string
                    afbeelding = afbeelding,
                    naam       = naam
                })
            end
        end
    end
    
for _ = 1, count do
    for _, card in ipairs(basis) do
        -- kopieer velden → elke positie krijgt een unieke tabel
        table.insert(drawPile.cards, {
            kleur      = card.kleur,
            waarde     = card.waarde,
            afbeelding = card.afbeelding,
            naam       = card.naam
        })
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
    c.selected = false       -- reset vlag per trek
    return c
end

function drawPile.count()   return #(drawPile.cards or {}) end

return drawPile
