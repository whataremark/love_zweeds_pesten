--- Basisconfiguratie voor kaarten en spelopzet ----------------------
local cfg = {
    cardWidth       = 140,  -- design size (px)
    cardHeight      = 200,
    cardPadding     = 16,
    phoneBreakpoint = 800,

    safePad         = 16,
    minTap          = 40,
    minScale        = 0.75,
    maxScale        = 1.20,

    HAND_SIZE       = 6,
    CARDS_INHAND    = 3,
    SETUP_OPEN      = 3,
    BLIND_SIZE      = 3,
}

-- Backwards compatibility for older modules -------------------------
cfg.cardBaseW = cfg.cardWidth
cfg.cardBaseH = cfg.cardHeight
cfg.cardPad   = cfg.cardPadding
cfg.phoneBP   = cfg.phoneBreakpoint

return cfg

