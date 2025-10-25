# Zweeds Pesten – Web Build

Static hosting setup for the LÖVE (Love2D) game exported with [love.js](https://github.com/love2d/love.js) and Firebase Hosting. Includes optional client‑side multiplayer sync using Firebase Realtime Database.

## Getting Started

1. **Install Firebase tools**
   ```bash
   npm i -g firebase-tools
   firebase login
   ```
2. **Link your Firebase project**
   ```bash
   firebase use --add <your-project-id>
   ```
   or run `firebase init` (enable *Hosting* and *Realtime Database*).
3. **Add web config**
   - Copy `public/app.config.sample.js` to `public/app.config.js`.
   - Paste your Firebase web config in the object.
4. **Build love.js & copy files**
   - Export your game with love.js.
   - Drop the generated `index.html`, `.js`, `.wasm`, `.data` files into `public/love/`.
5. **Deploy**
   ```bash
   firebase deploy
   ```
   Uses free Spark tier; deploys Hosting and database rules.

## Realtime Multiplayer (optional)
- Anonymous auth is used automatically.
- Presence stored under `rooms/{roomId}/players/{uid}`.
- Moves pushed to `rooms/{roomId}/moves/`.
- `public/js/realtime.js` exposes `window.NET` with helpers:
  - `createRoom()` / `joinRoom(roomId)` / `leaveRoom()`
  - `playMove(payload)`
  - listeners: `onRoomState`, `onPlayers`, `onMoves`
- Game‑side hooks can call `window.NET.playMove` and receive callbacks via `window.LOVE_onState`, `window.LOVE_onPlayers`, `window.LOVE_onMove`.

## Firebase Database Rules
Rules are in `database.rules.json` and restrict access to authenticated users, ensuring players only write their own presence and moves. Tweak as needed for production.

## Development Notes
- The `/public` folder is the hosting root.
- Static assets (`.wasm`, `.data`, images) are cached long‑term; HTML is not.
- If `public/app.config.js` is missing the page will warn you.
- When no love.js build is found, the page shows a reminder to drop your build into `public/love/`.

Enjoy! After `firebase deploy` you can open the provided URL and play.
