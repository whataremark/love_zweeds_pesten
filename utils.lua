
--helper functie om de bovenste kaart in de pot te vinden
local function get_effective_top_card(pot)
    for i = #pot, 1, -1 do
        if pot[i].waarde ~= "3" then
            return pot[i]
        end
    end
    return nil
end

local function get_numeric_value(waarde)
    local map = {
        ace = 14,
        king = 13,
        queen = 12,
        jack = 11
    }
    return tonumber(waarde) or map[waarde] or -1
end
-- ...existing code...

local utils = {}

utils.get_effective_top_card = get_effective_top_card
utils.get_numeric_value = get_numeric_value
utils.handle_card_effects = handle_card_effects

return utils