# Codex

Deze repository bevat een eenvoudige Love2D implementatie van het kaartspel "Zweeds Pesten". De code is opgedeeld in losse modules.

## Belangrijkste modules
- `main.lua` start het spel en regelt de input
- `game.lua` beheert de huidige speltoestand
- `rules.lua` controleert of zetten legaal zijn en verwerkt kaarteffecten
- `ui.lua` tekent de kaarten en menu's
- `ai.lua` bevat eenvoudige tegenstanderlogica

## Laatste wijzigingen



## Bugs:
Als speler zijn laatse kaart speelt, (anderre speler heeft nog kaarrten idk of relevant)
dan loopt het spel vast, console zegt dat speler 2 aan de beurt is maar spelers kunnen beide niks doen, als player 1 (die dus leeg is)
 op speel drukt dan staat er geen kaarten geselcteerd....

 
[SEL] phase=open  idx=2  target=ace clubs  al_geselecteerd=0
 ÔåÆ select (open eerste)      ace clubs
[CLICK] PLAY(open) seat=2 cur=2 selectedOpen=1
[UTILS] effective_top_card: 9
[PLAY_OPEN] result =    true