# Codex

Deze repository bevat een eenvoudige Love2D implementatie van het kaartspel "Zweeds Pesten". De code is opgedeeld in losse modules.

## Belangrijkste modules
- `main.lua` start het spel en regelt de input
- `game.lua` beheert de huidige speltoestand
- `rules.lua` controleert of zetten legaal zijn en verwerkt kaarteffecten
- `ui.lua` tekent de kaarten en menu's
- `ai.lua` bevat eenvoudige tegenstanderlogica

## Laatste wijzigingen
- Verholpen bug waardoor een gespeelde "3" de 7-regel onterecht ophief
- Overbodige zipbestanden en `todo.md` verwijderd om de codebase op te ruimen
- Drag&drop vervangen door kaartselectie met klikken
- Eindscreen toegevoegd wanneer een speler geen kaarten meer heeft

