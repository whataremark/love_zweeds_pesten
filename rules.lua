local rules = {}

local function waarde_naar_getal(waarde)
    local map = {
        ["2"] = 2, ["3"] = 3, ["4"] = 4, ["5"] = 5,
        ["6"] = 6, ["7"] = 7, ["8"] = 8, ["9"] = 9,
        ["10"] = 10, ["jack"] = 11, ["queen"] = 12,
        ["king"] = 13, ["ace"] = 14
    }
    return map[waarde] or 0
end

function rules.is_speelbaar(kaart, pot, onderZevenGedwongen)
    if not kaart then return false end

    local bovenste = pot[#pot]
    if not bovenste then return true end -- lege pot → altijd toegestaan

    local waarde = waarde_naar_getal(kaart.waarde)
    local bovensteWaarde = waarde_naar_getal(bovenste.waarde)

    -- Speciale kaarten mogen altijd
    if kaart.waarde == "2" or kaart.waarde == "3" or kaart.waarde == "10" then
        return true
    end

    -- 7 mag alleen als bovenste kaart 7 of lager is
    if kaart.waarde == "7" then
        return bovensteWaarde and bovensteWaarde <= 7
    end

    -- Als vorige kaart een 7 was: dan moet <= 7
    if onderZevenGedwongen then
        return waarde and waarde <= 7
    end

    -- Normale regel: >= vorige kaart
    return waarde and bovensteWaarde and waarde >= bovensteWaarde
    
end
return rules
