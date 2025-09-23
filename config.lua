local config = {}

-- Kaart-UI
config.cardHeight  = 160
config.cardPadding = 15
config.scale       = config.cardHeight / 500
config.cardWidth   = 300 * config.scale

-- Deelfases
config.HAND_SIZE   = 6
config.CARDS_INHAND = 3
config.SETUP_OPEN   = 3
config.BLIND_SIZE   = 3

-- NIEUW: maximale seats (AI of mens)
config.MAX_SEATS = 4

return config
