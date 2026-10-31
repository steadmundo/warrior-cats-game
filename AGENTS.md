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
  local `TopDownPlayer` plus `RemotePlayer` nodes. One camera follows the local cat. The HUD has
  one **room info** box in the top-right that is **hidden until TAB is held**: room code, cat
  count, and a row per cat (name tag colour, fur swatch, name, title) — see `_who_entries()`,
  `_build_info_body()` and `_set_info_open()`; `_info_sig` keeps it from rebuilding on every
  position update.
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
| `action` | `action {type, data}` | emotes (currently `emote` + `{text}`, text cut to 40 chars) |
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
**hold TAB** to open the room info box, **ESC** menu. **M** mutes all sound in any scene, and the
menu screens also have a small "Sound: On/Off" button in the top-right corner
(`game/scripts/sound_button.gd`); `Sfx` remembers the choice in `user://settings.cfg`. (The local
two-player mode also uses E for Player 2, hence the separate `online` / `online_emote` /
`online_players` input actions.)

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

The room server is already deployed for this project:

```
https://warrior-cats-online.maast85.workers.dev      # worker: warrior-cats-online
```

Redeploy after changing `online/src/index.js`:

```bash
cd online
wrangler login          # once
wrangler deploy
```

`Net.default_server_url()` gives native builds `http://127.0.0.1:8787` and web builds the
deployed worker (`PUBLIC_SERVER_URL` in `game/scripts/net.gd` — update that constant if the
worker is ever deployed somewhere else). The lobby's **Server** box still overrides it and is
remembered in `user://online.cfg`; applying an empty box goes back to the built-in default.
The Worker returns a `wss://` URL when it is reached over HTTPS, so no client change is needed
for deployment.

Web build note: a page served over HTTPS cannot connect to `ws://127.0.0.1`, and a player's
browser cannot reach the developer's local worker. That is why the hosted build defaults to the
deployed worker. Single-player still works without any server.

### Known POC limits (do not assume these work)

- No shared story, saves, items, patrols, ceremonies, or NPC state. Each client builds its own
  camp; Clan cats wander independently on each screen.
- No server authority, prediction, reconciliation, interpolation beyond simple smoothing, or
  anti-cheat. Positions are clamped to the 3200×2400 territory.
- **Saves and profiles are per device.** Each client reads its own three local slots
  (`user://save_N.json`); the room only ever learns a cat's name, title and looks, and only for
  as long as that socket is open. Nothing about a save is stored in the DO.
- A new player with no saved cat gets a **"Make your first cat!"** button in the lobby. It sets
  `GameState.return_to_online`, sends them through the normal story cat maker (`slots.tscn` →
  `creator.tscn` → `paint.tscn`), and `GameState.back_to_online_if_asked()` brings them back to
  the lobby afterwards. Do not duplicate the cat maker inside online mode.
- No chat input UI; `chat` messages are relayed but only emotes are exposed.
- No reconnection, spectator mode, passwords, or moderation. Four-letter room codes are public
  and guessable, and knowing a code is all a player needs. Rooms hold at most 8 sockets.
- **A room is forgotten two hours after its last player leaves** (`ROOM_TTL_MS` in
  `online/src/index.js`, handled by the DO's `alarm()`), so codes do not pile up. Until then the
  code works for anyone who knows it.
- **Creating and joining rooms is rate limited per visitor IP** with Cloudflare's
  `ratelimits` bindings (10 creates and 40 joins a minute). `wrangler dev` has no
  `CF-Connecting-IP`, so local tests are never limited.
- Reusing an existing code merges into that room (collision chance is tiny for this scale).
- Emotes are a fixed list (`EMOTES` in `online_world.gd`); names/cats are cleaned/truncated.
  The room only forwards `data.text` (≤40 chars) for an `action`, and drops any other fields a
  client invents.
- Optional `CREATE_ROOM_KEY` secret: when set, `/api/room/create` needs an `X-Create-Key`
  header. The lobby's **Parent** box saves one. It is a speed bump, not real auth — a key typed
  into the web build lives in that browser only, but anyone reading the screen can see it.

## The website — Cloudflare Worker (2026-11-01)

The browser version is hosted on Cloudflare, not GitHub Pages:

```
https://warrior-cats-game.maast85.workers.dev      # worker: warrior-cats-game
```

`web/` is a Worker with static assets, configured by `wrangler.jsonc` in the **repo root** —
Cloudflare reads that file for the Worker name and assets directory, and it has to sit at the top
level for the dashboard to find it. Build output goes to `web/public`, which is **not committed**
(see `.gitignore`).

**Where the build command lives:** in the Cloudflare dashboard, not in `wrangler.jsonc`.
Workers Builds does not honour "custom builds" from the Wrangler config, so a `build.command`
there would be ignored — and might build twice. The dashboard setting is
`bash tools/cf_build.sh` (download Godot, then `tools/deploy_web.py --build`), deploy command
`npx wrangler deploy`, root directory left at the repo root. `tools/deploy_web.py` runs the same
build itself, so a manual deploy and a push-built deploy do the same work once.

`build.command`, when one is used, runs from the repo root, never from `web/`. Keep its paths
repo-relative — a path that assumes `web/` as the working directory breaks the build.

**Why the engine file is split — read this before "simplifying" it.** Godot's `index.wasm` is
about 36 MiB and Cloudflare refuses to store or serve any single static asset over 25 MiB.
`tools/deploy_web.py` cuts it into 20 MiB parts (`index.wasm.0`, `index.wasm.1`, ...) plus
`index.wasm.json`, and `web/src/index.js` streams the parts back as one `/index.wasm` download.
Two tidier-looking alternatives were tried and both fail:

- `_headers` with `Content-Encoding: gzip` — Cloudflare strips `Content-Encoding`.
- Setting the same header from a Worker — Cloudflare re-compresses the body, so the browser
  gets gzip-of-gzip and the engine never starts.

Leaving the bytes uncompressed and letting Cloudflare compress the streamed response is the
only version that works. Verify any change by fetching `/index.wasm` and comparing the decoded
bytes with `game/export/web/index.wasm`:

```bash
curl -s -H 'Accept-Encoding: gzip' -o /tmp/a.wasm https://warrior-cats-game.maast85.workers.dev/index.wasm
gzip -dc /tmp/a.wasm | cmp - game/export/web/index.wasm && echo same
```

Publishing by hand (no CI) works too:

```bash
python3 tools/deploy_web.py           # build + deploy
python3 tools/deploy_web.py --local   # build, then http://localhost:8790
```

`.github/workflows/pages.yml` was deleted — neither GitHub Pages nor that workflow is used any
more. `.github/workflows/release.yml` stays: desktop packages need macOS, which Cloudflare
cannot build.

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

wrangler.jsonc                     # the game website: worker name and assets directory
web/                              # the game website (Cloudflare Worker with static assets)
├── src/index.js                  # streams the split engine file as /index.wasm
└── public/                       # build output, gitignored (tools/deploy_web.py)

tools/
├── check_online.py               # starts worker + runs the Godot smoke test
├── deploy_web.py                 # build the browser version and deploy/preview it
└── cf_build.sh                   # build step Cloudflare Workers Builds runs
```

## Style and safety reminders

- Keep the online lobby and world text big and simple; the players are children.
- Never log or send real names, locations, or other personal information. The worker already
  trims names to 24 characters and strips control characters.
- Keep the Worker dependency-free (Web APIs only) so `wrangler deploy` stays simple.
- If you add a new message type, update both `online/src/index.js` and `game/scripts/net.gd`,
  then extend `online/test_room.mjs` and `game/tests/online_smoke.gd`.
- Do not commit `online/node_modules/` or `online/.wrangler/`.
