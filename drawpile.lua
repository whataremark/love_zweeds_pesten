local drawPile = {}

-- Load and shuffle a deck with the configured amount of sets
function drawPile.init(count)
    count = count or 1
    drawPile.cards = {}  -- vers deck

    local kaartmap  = "png"
    local bestanden = love.filesystem.getDirectoryItems(kaartmap)
    local basis     = {}

    -- map korte ranks naar lange naam
    local function norm_rank(v)
        if not v then return v end
        v = v:lower()
        if v == "a" then return "ace" end
        if v == "k" then return "king" end
        if v == "q" then return "queen" end
        if v == "j" then return "jack" end
        return v -- "2".."10" blijven zo
    end

    for _, bestand in ipairs(bestanden) do
        if bestand:match("%.png$") then
            local naam = bestand:gsub("%.png$", "")
            local lower = naam:lower()

            -- match "<value>_of_<suit>"
            local waarde, kleur = lower:match("^(.-)_of_(.-)$")

            if waarde and kleur then
                -- sla alleen echte speelkaarten op (geen back, etc.)
                if naam ~= "back" then
                    local afbeelding = love.graphics.newImage(kaartmap .. "/" .. bestand)
                    table.insert(basis, {
                        kleur      = kleur,               -- spades/hearts/diamonds/clubs
                        waarde     = norm_rank(waarde),   -- ace/king/queen/jack/2..10
                        afbeelding = afbeelding,
                        naam       = naam                 -- bestandsnaam zonder .png
                    })
                end
            end
            -- (geen jokers/extra gevallen nodig als je die niet gebruikt)
        end
    end

    -- vermenigvuldig met aantal decks + shuffle
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

    -- Fisher–Yates met love.math.random (interne seed van LÖVE is ok)
    for i = #full, 2, -1 do
        local j = love.math.random(i)
        full[i], full[j] = full[j], full[i]
    end

    drawPile.cards = full
end

function drawPile.draw()
    local c = table.remove(drawPile.cards)
    if not c then return nil end
    c.selected = false
    return c
end

function drawPile.count()
    return #(drawPile.cards or {})
end

return drawPile
