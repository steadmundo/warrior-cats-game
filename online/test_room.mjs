/**
 * Smoke test for the online room worker.
 *
 * Start the worker first:   cd online && npx wrangler dev
 * Then run:                 node online/test_room.mjs [server-url]
 *
 * It creates a room, connects two WebSocket players, and checks that joins,
 * movement and leaves are relayed.
 */

const base = (process.argv[2] || process.env.SERVER || "http://127.0.0.1:8787").replace(/\/$/, "");

function fail(message) {
  console.error("FAIL:", message);
  process.exit(1);
}

async function api(path, body) {
  const response = await fetch(base + path, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body ?? {}),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) fail(`${path} returned ${response.status}: ${JSON.stringify(data)}`);
  return data;
}

function nextMessage(socket, predicate, label, timeoutMs = 4000) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      socket.removeEventListener("message", onMessage);
      reject(new Error(`timed out waiting for ${label}`));
    }, timeoutMs);
    function onMessage(event) {
      let data;
      try {
        data = JSON.parse(event.data);
      } catch {
        return;
      }
      if (!predicate(data)) return;
      clearTimeout(timer);
      socket.removeEventListener("message", onMessage);
      resolve(data);
    }
    socket.addEventListener("message", onMessage);
  });
}

function connect(url) {
  return new Promise((resolve, reject) => {
    const socket = new WebSocket(url);
    const timer = setTimeout(() => reject(new Error(`could not connect to ${url}`)), 5000);
    socket.addEventListener("open", () => {
      clearTimeout(timer);
      resolve(socket);
    });
    socket.addEventListener("error", () => {
      clearTimeout(timer);
      reject(new Error(`WebSocket error connecting to ${url}`));
    });
  });
}

const cat = (name, fur) => ({
  name,
  title: "Warrior",
  size: 1,
  collar: false,
  fur,
  markings: "4a2c18",
  pattern: "Tabby Stripes",
  eyes: "5fd14a",
  fluffy: false,
  mood: "happy",
  paint: [[0, -40, "ff5d73", 8]],
});

const health = await fetch(base + "/health").then((r) => r.json());
if (!health.ok) fail("health check failed");

const room = await api("/api/room/create");
if (!/^[A-Z0-9]{4,8}$/.test(room.roomCode)) fail(`bad room code: ${room.roomCode}`);
console.log("created room", room.roomCode);

const alice = await connect(room.wsUrl);
const welcomeA = await nextMessage(alice, (m) => m.type === "welcome", "Alice's welcome");
if (!welcomeA.playerId) fail("welcome did not include a player id");
alice.send(JSON.stringify({ type: "hello", name: "Firepaw", catData: cat("Firepaw", "f29a45"), pos: { x: 1600, y: 1350 } }));

const bob = await connect(room.wsUrl);
const welcomeB = await nextMessage(bob, (m) => m.type === "welcome", "Bob's welcome");
const joinedPromise = nextMessage(alice, (m) => m.type === "player_joined" && m.player.name === "Sandpaw", "Bob joining");
bob.send(JSON.stringify({ type: "hello", name: "Sandpaw", catData: cat("Sandpaw", "f3c98e"), pos: { x: 1700, y: 1360 } }));
const joined = await joinedPromise;
if (!joined.player.pos) fail("joined player had no position");
console.log("player_joined works");

const updatePromise = nextMessage(alice, (m) => m.type === "player_update" && m.player.name === undefined, "Bob's move");
bob.send(JSON.stringify({ type: "input", pos: { x: 1720, y: 1400 }, facing: -1, walking: true, pouncing: false }));
const update = await updatePromise;
if (update.player.pos.x !== 1720 || update.player.facing !== -1) fail("movement was not relayed correctly");
console.log("player_update works");

const emotePromise = nextMessage(alice, (m) => m.type === "event", "Bob's emote");
bob.send(JSON.stringify({ type: "action", action: { type: "emote", data: { text: "Mew!" } } }));
const emote = await emotePromise;
if (emote.event.kind !== "emote" || emote.event.data.text !== "Mew!") fail("emote was not relayed");
console.log("event works");

const leftPromise = nextMessage(alice, (m) => m.type === "player_left", "Bob leaving");
bob.close();
const left = await leftPromise;
if (left.playerId !== welcomeB.playerId) fail("player_left had the wrong id");
console.log("player_left works");

alice.close();

const missing = await fetch(base + "/api/room/join", {
  method: "POST",
  headers: { "content-type": "application/json" },
  body: JSON.stringify({ roomCode: "ZZZZ" }),
});
if (missing.status !== 404) fail(`joining a missing room returned ${missing.status}, not 404`);
console.log("missing room is rejected");

console.log("\nOK: online room server works.");
