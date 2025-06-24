local config = {}

--codex-- Default card display settings
config.cardHeight = 160
config.cardPadding = 15
config.scale = config.cardHeight / 500
config.cardWidth = 300 * config.scale

--codex-- Toggle verbose debug output in helper modules
config.debug = false

return config
