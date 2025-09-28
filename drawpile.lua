local drawPile = {}
-- Load and shuffle a deck with the configured amount of sets
function drawPile.init(count)
    count = count or 1
    drawPile.cards = drawPile.cards or {}  -- voorkom nil

    local kaartmap  = "png"
    local bestanden = love.filesystem.getDirectoryItems(kaartmap)
    local basis     = {}

    -- korte ranks mappen naar lange namen (A/K/Q/J → ace/king/queen/jack)
    local function norm_rank(v)
        if not v then return v end
        if v == "A" or v == "a" then return "ace"   end
        if v == "K" or v == "k" then return "king"  end
        if v == "Q" or v == "q" then return "queen" end
        if v == "J" or v == "j" then return "jack"  end
        return v -- 2..10 blijven hetzelfde
    end

    for _, bestand in ipairs(bestanden) do
        if bestand:match("%.png$") then
            local naam = bestand:gsub("%.png$", "")
            local waarde, kleur = naam:match("^(.-)_of_(.-)$")

            ------------------------------------------------------------
            -- 1. Gewone kaarten “X_of_<suit>.png”  (A/K/Q/J of 2..10)
            ------------------------------------------------------------
            if waarde and kleur then
                local afbeelding = love.graphics.newImage(kaartmap .. "/" .. bestand)

                table.insert(basis, {
                    kleur      = kleur,
                    waarde     = norm_rank(waarde),  -- ← hier de mapping
                    afbeelding = afbeelding,
                    naam       = naam                -- bestandsnaam zonder .png
                })

            ------------------------------------------------------------
            -- 2. Jokers: black_joker.png / red_joker.png
            ------------------------------------------------------------
            elseif naam == "black_joker" or naam == "red_joker" then
                local afbeelding = love.graphics.newImage(kaartmap .. "/" .. bestand)

                table.insert(basis, {
                    kleur      = (naam == "black_joker") and "black" or "red",
                    waarde     = "joker",
                    afbeelding = afbeelding,
                    naam       = naam
                })
            end
        end
    end

    -- vermenigvuldig met aantal decks + shuffle (zoals je al had)
    local full = {}
    for d = 1, count do
        for i = 1, #basis do
            local c = basis[i]
            full[#full+1] = {
                kleur      = c.kleur,
                waarde     = c.waarde,
                afbeelding = c.afbeelding,
                naam       = c.naam
            }
        end
    end

    for i = #full, 2, -1 do
        local j = love.math.random(i)
        full[i], full[j] = full[j], full[i]
    end

    drawPile.cards = full
end


function drawPile.draw()
    local c = table.remove(drawPile.cards)
    if not c then return nil end
    c.selected = false       -- reset vlag per trek
    return c
end

function drawPile.count()   return #(drawPile.cards or {}) end

return drawPile
