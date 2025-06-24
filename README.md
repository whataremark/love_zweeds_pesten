# Zweeds Pesten

Een kleine LÖVE implementatie van het kaartspel "Zweeds Pesten". 
De code bestaat uit losse modules voor spelregels, spelerslogica, 
AI en de gebruikersinterface.

## Spelen
Installeer [LÖVE](https://love2d.org/) en start de game vanuit deze map. In het hoofdmenu kun je kiezen of je met één of twee kaartdecks speelt:

```bash
love .
```

## Structuur
De bronbestanden staan in de map `src/`:
- `game.lua` bevat alleen het kale spelmodel.
- `rules.lua` verwerkt de spelregels en kaarteffecten.
- `ai.lua` regelt de zetten van de tegenstander.
- `utils.lua` bevat herbruikbare hulpfuncties.
- `ui.lua` tekent de kaarten en menu's.

Veel plezier!


### Nieuw
- Kaarten worden nu geselecteerd met muiskliks in plaats van slepen.
- Het spel toont een eindscreen zodra iemand geen kaarten meer heeft.


### BUGS
Geen bekende bugs op dit moment. Het probleem waarbij een gespeelde "3" de
"7"-regel ongedaan maakte, is opgelost.

