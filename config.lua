local config = {}

--codex-- Default card display settings
config.cardHeight = 160
config.cardPadding = 15
config.scale = config.cardHeight / 500
config.cardWidth = 300 * config.scale
config.HAND_SIZE = 6

config.SETUP_OPEN  = 3     -- open kaarten bovenop de blinde
config.BLIND_SIZE  = 3     -- totaal blinde kaarten




return config
