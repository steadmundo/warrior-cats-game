# AGENTS.md — Warrior Cats: Path of the Apprentice

This file is for coding agents (Claude Code, OpenCode, Codex, Cursor, …) working in this repo.
Read `CLAUDE.md` first for the project-wide rules: kid-friendly content only, no personal
information in this public repo, Godot 4 + GDScript only, keep the HTML5 build working, big
readable text, and always test with `python3 tools/check_game.py`.

`history.md` is the kid-facing changelog. Add a session entry there after every change.

## What the game is

A Godot 4 game based on the *Warriors* books. The player makes a cat, joins ThunderClan, and
plays the first book's story, then keeps living in the Clan. There is also a local two-player
mode ("ThunderClan Together") on one keyboard, and a new **online mode** (proof of concept).

## Online mode — current status (2026-10-26)

Local end-to-end play is working: two Godot clients can create/join a room, see each other's
cats, walk, pounce, and send preset emotes. This is a small proof of concept for the kids, not
a production service.

**Design decision:** online mode is a *separate, simpler shared world* (`online_world.gd`). Do
not insert online branches into the big two-player `territory.gd`. An earlier attempt did that
and broke the story mode because `territory.gd` assumes two local save slots everywhere. Keep
single-player, two-player, and online code paths apart.

### How it fits together

```
Godot client                         Cloudflare Worker (online/)
┌──────────────────────┐   HTTPS     ┌─────────────────────────────┐
│ online_lobby.tscn     │ ─────────▶ │ POST /api/room/create       │
│  (choose save slot)   │             │ POST /api/room/join         │
│        │              │             │ GET  /health                │
│        ▼              │   WSS       │                             │
│ online_world.tscn     │ ◀────────▶ │ GET /ws?room=CODE           │
│  local player         │             │      │                      │
│  RemotePlayer cats    │             │      ▼                      │
│  Net autoload         │             │ Durable Object "Room"       │
└──────────────────────┘             │  one per room code          │
                                     │  8 players max              │
                                     └─────────────────────────────┘
```

- **`game/scripts/net.gd`** — autoload `Net`. Creates/joins rooms over `HTTPRequest`, opens a
  `WebSocketPeer`, sends local state at most every 60 ms, parses server messages, and emits
  signals used by the scenes. It also turns a save-slot cat into JSON (`cat_payload`).
- **`game/scenes/online_lobby.tscn` / `game/scripts/online_lobby.gd`** — save-slot picker,
  "Create a Room", room-code box, server URL field, status text.
- **`game/scenes/online_world.tscn` / `game/scripts/online_world.gd`** — shared camp/forest.
  Reuses `Territory.WorldFloor`, camp props, Clan NPCs and terrain art, but only spawns the
  local `TopDownPlayer` plus `RemotePlayer` nodes. One camera follows the local cat.
- **`game/scripts/remote_player.gd`** — draws another player's cat from the joined cat data,
  smooths between network updates, and shows their name and speech bubbles.
- **`online/src/index.js`** — Worker routes and the `Room` Durable Object. One DO per room code.
  Player names/cats/positions live in each WebSocket's **attachment**, so the DO can hibernate
  between messages. The DO only relays messages; it is not authoritative.
- **`online/wrangler.jsonc`** — Worker name `warrior-cats-online`, SQLite-backed DO migration.
- **`online/test_room.mjs`** — Node WebSocket test for the worker by itself.

### Room protocol (JSON over WebSocket)

Client → server:

| type | fields | purpose |
|---|---|---|
| `hello` | `name`, `catData`, optional `pos` | join as a visible cat |
| `input` | `pos {x,y}`, `facing`, `walking`, `pouncing` | movement state |
| `action` | `action {type, data}` | emotes (currently `emote` + `{text}`) |
| `chat` | `text` | relayed text (no chat UI yet) |
| `ping` | — | auto-answered `pong` by the DO (not JSON; ignored by the client) |

Server → client:

| type | fields | purpose |
|---|---|---|
| `welcome` | `playerId`, `players`, `world` | sent right after the socket opens |
| `player_joined` | `player` | someone said hello |
| `player_update` | `player {id, pos, facing, walking, pouncing}` | movement |
| `player_left` | `playerId` | socket closed |
| `event` | `event {kind, from, name, data}` | emote/action relay |
| `chat` | `from`, `name`, `text` | chat relay |

Join/create HTTP responses: `{ "roomCode": "ABCD", "wsUrl": "ws(s)://…/ws?room=ABCD" }`.
`/api/room/join` returns 404 for an unknown code.

### Running it locally

Terminal 1 — room server:

```bash
cd online
wrangler dev --port 8787 --ip 127.0.0.1     # or: npm run dev
```

Terminal 2 — the game:

```bash
godot --path game
```

On the title screen press **O** to open Online Play. Pick a saved cat, then:

- **Create a Room** → note the four-letter code.
- On the other computer (or another Godot window), press **O**, pick a cat, type the code,
  and press **Join**.

The default server is `http://127.0.0.1:8787`. The lobby's **Server** box changes it and saves
to `user://online.cfg`. A `--server=` command-line argument overrides both:

```bash
godot --path game -- --server=http://192.168.1.20:8787
```

For two windows on one computer, give each its own save folder so they can have different cats:

```bash
XDG_DATA_HOME=/tmp/cat-a godot --path game
XDG_DATA_HOME=/tmp/cat-b godot --path game
```

Controls in the shared world: **arrows** walk, **SPACE** pounce, **E** say a preset hello,
**ESC** menu. (The local two-player mode also uses E for Player 2, hence the separate
`online` / `online_emote` input actions.)

### Testing and checking changes

Always run the normal check after touching game scripts:

```bash
python3 tools/check_game.py
python3 tools/check_game.py --scene res://scenes/online_lobby.tscn --seconds 2
python3 tools/check_game.py --scene res://scenes/online_world.tscn --seconds 2
```

The online end-to-end check starts its own Wrangler on a free port, gives Godot a throwaway
save folder, runs `game/tests/online_smoke.tscn`, and stops the worker:

```bash
python3 tools/check_online.py
```

It should print `OK: online rooms, joining and movement all work.` This is the check that
proves the client, WebSocket relay, remote-cat spawn and movement all work together. Use
`--keep` to leave the worker running and `--server http://127.0.0.1:8787` to test an already
running one.

Worker-only test (needs a running worker):

```bash
cd online && node test_room.mjs
```

Godot note: `godot --headless --path game --script something.gd` does **not** load autoloads
(`Net`, `GameState`, …), so online tests must run a real scene, not a bare script.

### Deploying the room server

```bash
cd online
wrangler login          # once
wrangler deploy
```

Then open Online Play, put the deployed `https://<worker>.workers.dev` URL in the **Server**
box, press **Apply**, and create a room. The Worker returns a `wss://` URL when it is reached
over HTTPS, so no client change is needed for deployment.

Web build note: a page served over HTTPS cannot connect to `ws://127.0.0.1`, and a player's
browser cannot reach the developer's local worker. A hosted build therefore needs the deployed
HTTPS worker URL. Single-player still works without any server.

### Known POC limits (do not assume these work)

- No shared story, saves, items, patrols, ceremonies, or NPC state. Each client builds its own
  camp; Clan cats wander independently on each screen.
- No server authority, prediction, reconciliation, interpolation beyond simple smoothing, or
  anti-cheat. Positions are clamped to the 3200×2400 territory.
- No chat input UI; `chat` messages are relayed but only emotes are exposed.
- No room expiry, reconnection, spectator mode, passwords, or moderation. Four-letter room
  codes are public and guessable. Rooms hold at most 8 sockets.
- Reusing an existing code merges into that room (collision chance is tiny for this scale).
- Emotes are a fixed list (`EMOTES` in `online_world.gd`); names/cats are cleaned/truncated.

## File map for online work

```
game/
├── project.godot                 # Net autoload + online / online_emote input actions
├── scenes/
│   ├── online_lobby.tscn
│   └── online_world.tscn
├── scripts/
│   ├── net.gd                    # client networking autoload
│   ├── online_lobby.gd
│   ├── online_world.gd
│   ├── remote_player.gd
│   └── title.gd                  # O opens Online Play
└── tests/
    ├── online_smoke.gd           # headless end-to-end test
    └── online_smoke.tscn

online/
├── src/index.js                  # Worker + Room Durable Object
├── wrangler.jsonc
├── package.json
├── test_room.mjs                 # worker-only WebSocket test
└── .gitignore                    # node_modules/, .wrangler/

tools/
└── check_online.py               # starts worker + runs the Godot smoke test
```

## Style and safety reminders

- Keep the online lobby and world text big and simple; the players are children.
- Never log or send real names, locations, or other personal information. The worker already
  trims names to 24 characters and strips control characters.
- Keep the Worker dependency-free (Web APIs only) so `wrangler deploy` stays simple.
- If you add a new message type, update both `online/src/index.js` and `game/scripts/net.gd`,
  then extend `online/test_room.mjs` and `game/tests/online_smoke.gd`.
- Do not commit `online/node_modules/` or `online/.wrangler/`.
