import { getDatabase, ref, set, get, update, push, onValue, onDisconnect, remove, serverTimestamp } from 'https://www.gstatic.com/firebasejs/9.23.0/firebase-database.js';

const db = getDatabase(window.FIREBASE_APP);
let currentRoom = null;

function genRoomId() {
  return Math.random().toString(36).substring(2,8).toUpperCase();
}

function playerRef(roomId, uid) {
  return ref(db, `rooms/${roomId}/players/${uid}`);
}

export async function createRoom() {
  const id = genRoomId();
  await set(ref(db, `rooms/${id}`), { created: serverTimestamp() });
  await joinRoom(id);
  return id;
}

export async function joinRoom(id) {
  const uid = window.AUTH?.uid;
  if (!uid) return;
  currentRoom = id;
  const pRef = playerRef(id, uid);
  await set(pRef, { ts: serverTimestamp() });
  onDisconnect(pRef).remove();
  return id;
}

export async function leaveRoom() {
  const uid = window.AUTH?.uid;
  if (currentRoom && uid) {
    await remove(playerRef(currentRoom, uid));
    currentRoom = null;
  }
}

export async function playMove(payload) {
  if (!currentRoom) return;
  const uid = window.AUTH?.uid;
  const mRef = push(ref(db, `rooms/${currentRoom}/moves`));
  await set(mRef, { uid, payload, ts: serverTimestamp() });
}

export function onRoomState(roomId, cb) {
  const sRef = ref(db, `rooms/${roomId}/state`);
  onValue(sRef, snap => {
    const state = snap.val();
    if (cb) cb(state);
    if (window.LOVE_onState) window.LOVE_onState(state);
  });
}

export function onPlayers(roomId, cb) {
  const pRef = ref(db, `rooms/${roomId}/players`);
  onValue(pRef, snap => {
    const players = snap.val() || {};
    if (cb) cb(players);
    if (window.LOVE_onPlayers) window.LOVE_onPlayers(players);
  });
}

export function onMoves(roomId, cb) {
  const mRef = ref(db, `rooms/${roomId}/moves`);
  onValue(mRef, snap => {
    const moves = snap.val() || {};
    if (cb) cb(moves);
    const arr = Object.values(moves);
    if (arr.length && window.LOVE_onMove) {
      window.LOVE_onMove(arr[arr.length - 1]);
    }
  });
}

window.NET = { createRoom, joinRoom, leaveRoom, playMove, onRoomState, onPlayers, onMoves };
