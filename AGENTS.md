# Zweeds Pesten – Agent Guide  
*(Love2D / Lua — July 2025 multiplayer refactor)*

Deze gids is geschreven voor **OpenAI Codex** (en alle menselijke
ontwikkelaars) om snel de architectuur, de spelregels en de
multiplayer‑flow te begrijpen – ‑én om straks zonder pijn naar 3+ spelers
te kunnen schalen.

---

## 📦 Project­structuur (snapshot)

| File | Rol |
|------|-----|
| `main.lua` | Love2D‐entry; routed callbacks → `state.*`, `net.update` |
| `state.lua` |  Mini‑router naar actieve scene (menu, lobby, game) |
| `net.lua` |  TCP/UDP‑laag, lobby‑beacons, snapshot‑sync |
| `host_lobby.lua` / `client_lobby.lua` | Wachtkamers vóór het spel |
| `game.lua` | Kern‑state & beurt‑logica (géén AI meer in MP) |
| `player.lua` | Structuur & helpers voor `player.players[id]` |
| `rules.lua` | Regels + kaart‑effecten |
| `ui.lua` | Alle rendering (kaarten, pot, knoppen, seats) |
| `ai.lua` | Simple AI, **alleen** actief in single‑player |

*(afgekort; zie repo voor rest)*

---

## 🌐 Multiplayer‑architectuur

| Variabele | Betekenis |
|-----------|-----------|
| `net.mode` | `"host"` / `"client"` / `"ai"` |
| `net.localId` | Mijn eigen speler‑id (1 = host, 2‑n = clients) |
| `net.conns` | `[id] = socket` — alleen gevuld bij host |
| `game.maxPlayers` | Aantal echte mensen in deze match |
| `player.players[id]` | Hand, faceUp, faceDown, scrollOffset, … |

### ▸ Berichtformaat (JSON + newline)

```jsonc
{ "cmd":"HELLO", "seed":169211, "deckCount":2 }
{ "cmd":"JOIN" , "id":3, "name":"Bob" }
{ "cmd":"PLAY" , "id":2, "cards":[{"kleur":"♣","waarde":"K"}] }
{ "cmd":"STATE", "game": { … platte snapshot … } }


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

- moet alleen in Singleplayer (ai mode)
-De AI analyseert zijn hand en kiest de **legaal speelbare kaart** met de hoogste voorkeur.
- Bij het kiezen houdt de AI ook rekening met of de vorige kaart een `7` was (dan moet hij ≤ 7 spelen).
- De AI gebruikt `utils.effective_top_card` om te kijken wat écht de laatste relevante kaart is.
- Als geen legale kaart beschikbaar is:
  - Bij normale beurt → AI pakt de hele pot op.
  - Bij extra beurt → AI past.

---

📈 Roadmap naar >2 spelers
Geen hard‑coded 2 meer – loop over game.maxPlayers. ✅

net.send_all broadcast naar ieder socket. ✅

Lobby toont #player.players / game.maxPlayers.

Extra sockets ➔ plus‑één id ➔ automatisch nieuwe seat.

Optioneel: ready‑status per speler in JOIN‑pakket.


## known bugs:

-
## THINGS TO ADD
- 
### PROJECT CONTEXT
Love2D / Lua card game “Zweeds Pesten”.
Repo contains: main.lua, state.lua, game.lua, net.lua, player.lua,
ui.lua, rules.lua, ai.lua, host_lobby.lua, client_lobby.lua, menu.lua.

### CURRENT PROBLEMS
1. In multiplayer host & client share the same hand; turns don't alternate.
2. AI logic still runs during multiplayer.
3. Game always starts with one random card already on the pot.

### DESIRED STATE  (keep code style / file layout)
––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
**A. Real PvP multiplayer**
• `net.localId`    – 1 = host, 2 = client  
• `player.players[id]` – separate hands / faceUp / faceDown  
• All input checks (`mousepressed`, `keypressed`, …) use  
  `if game.currentPlayer == net.localId then … end`

**B. AI completely OFF when `game.mode == "multiplayer"`**

**C. Setup / first turn**
1. Players first choose their face‑up cards as before.
2. Pot is initially **empty**.
3. The first player who can legally play **a 4** starts.  
   If neither has a 4, check 5, then 6, … up to A.  
   (Use rules.is_speelbaar per value loop.)
4. Print in console:  
   `[INIT] P1 starts with 4` (etc.) or `[INIT] no 4/5/… found`.

**D. Turn alternation**
`game.next_turn()` must use:  
`game.currentPlayer = (game.currentPlayer % game.maxPlayers) + 1`

**E. Console debug prints (only in dev)**
• When a packet is sent: `[NET] SEND  cmd=STATE len=xyz`  
• When a packet is received: `[NET] RECV  cmd=PLAY from id=2`  
• When rule logic fires: `[RULE] 10 clears pot`, `[RULE] 7 – next ≤7`  
• When next turn happens: `[TURN] now player id=…`  

Prints go to `love.errhand` or simply `print`.

### MINIMAL CHANGES REQUIRED
* DO NOT redesign the whole net layer.
* Just ensure each side keeps its own state table and AI.update is skipped.
* Leave future multi‑player scalability **possible** (variable maxPlayers),
  but you do NOT have to implement >2 players now.

### DELIVERABLE
Modify only the necessary files.  
Keep functions / names unless explicitly changed.  
No extra text – just the patched code files.