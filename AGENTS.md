# Agents.md – Zweeds Pesten (Love2D Card Game)

Deze gids is bedoeld om OpenAI Codex en andere AI-agents te helpen bij het begrijpen en correct aanpassen van het spel "Zweeds Pesten", inclusief de belangrijkste regels, speciale kaarten en game-logica.

---

## ♠️ Spelregels

### Basisregels

- Spelers spelen om beurten een kaart op de aflegstapel (`pot`).
- Een kaart mag alleen gespeeld worden als deze aan de regels voldoet ten opzichte van de huidige bovenste kaart op de stapel.
- De bovenste kaart wordt bepaald via `utils.effective_top_card`, waarbij **"3" wordt genegeerd**.
- Doel: Als eerste speler geen kaarten meer over hebben.

---

## 🎴 Speciale Kaarten en Hun Effecten

| Kaartwaarde | Effect                                                             |
|-------------|--------------------------------------------------------------------|
| `2`         | Mag altijd gespeeld worden, ongeacht de vorige kaart              |
| `3`         | Mag altijd gespeeld worden; Maar is doorzichtig dus bij regels wordt gekeken naar kaart hiervoor   |
| `7`         | Dwingt volgende speler om een kaart ≤ 7 te spelen                 |
| `8`         | Speler krijgt een extra beurt                                     |
| `10`        | Leegt de aflegstapel (`pot`) en geeft een extra beurt            |

---

## 🔄 Spelverloop en Beurtlogica

- Kaarten worden gedeeld uit het deck bij `startGame`.
- De speler speelt een kaart als deze **legaal** is volgens `rules.is_speelbaar`.
- Speciale effecten worden afgehandeld via `rules.handle_card_effects`.

---

## 📥 Trekstapel / Draw Pile

- Kaarten die overblijven na het uitdelen worden in een trekstapel gestopt (bijv. `drawPile` of `deck`).
- Als een speler minder dan **5 kaarten** heeft na een beurt, worden kaarten bijgetrokken totdat hij weer 5 heeft.
- Als de stapel leeg is, wordt **niet** meer bijgevuld.
- De trekstapel wordt **visueel weergegeven** als een stapel achterkanten, met een teller erbij.

---

## 👀 Visuele Afhandeling

- Speelstapel (`pot`) wordt zichtbaar als kaarten op elkaar gestapeld.
- Trekstapel wordt weergegeven met meerdere overlappende kaarten (verschillende rotaties & opaciteit).
- UI toont knoppen, handen, en kaartselectie.

---

## 🧠 AI Logica

- De AI analyseert zijn hand en kiest de **legaal speelbare kaart** met de hoogste voorkeur.
- Bij het kiezen houdt de AI ook rekening met of de vorige kaart een `7` was (dan moet hij ≤ 7 spelen).
- De AI gebruikt `utils.effective_top_card` om te kijken wat écht de laatste relevante kaart is.
- Als geen legale kaart beschikbaar is:
  - Bij normale beurt → AI pakt de hele pot op.
  - Bij extra beurt → AI past.

---


## known bugs:

- the card selection process is not working as intended. it is working but if you pak pot it keeps the cards selected, so after you pak pot it should deslectect all the cards in your hand
- the cards the player (and the ai for that matter) you can only see a certain amount and you have to scroll trough them, make it so that you can see a lot more, but it has to stay centerd in the screen, make it so it almost fills the whole container it is in
- when selecting cards if you scrolll trough them it is sometimes not fully accurate fix this.
- the BRUNZYN functainlyt is working, only thing to changes is that if the the top card (not the effictive top carrd but the real topcard) is a certain card, and the player or the ai has 3 of the same cards this is also a brunzyn so that means that you dontt have to have all 4 same cards, if you have 3 jacks for example and the top card is a jack, you can play these 3 and you will get the brunzyn, also add print statements for when brunzyn happens
- organize the print statements better, so player plays ... Ai plays..., ai picks up pot, etc etc
 
## THINGS TO ADD
- Check the file structrue and all the files and organize everything better, make sure it stilll works correctly.
- if you add coments make sure to add --codex to it
- 

