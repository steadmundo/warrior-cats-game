# Warrior Cats: Path of the Apprentice

A fan game based on the *Warriors* books by Erin Hunter, made by two kids who love them,
by describing their ideas to [Claude Code](https://claude.com/claude-code).

Design your own cat, leave your Twoleg garden to join ThunderClan, and live the first book's
story as the main character: hunting, border patrols, play-fights and your warrior ceremony,
or train as a medicine cat and visit the Moonstone. Then keep living in the Clan, play
**ThunderClan Together** with a friend on the same keyboard, or visit a shared camp in
**Online Play**.

**Controls:** arrow keys to walk and choose, SPACE to jump, pounce, talk and OK, ESC for the
menu. Player 2 uses WASD and E. Press **O** on the title screen for Online Play.

## Play it

- **In your browser:** <https://warrior-cats-game.maast85.workers.dev/> (works best on a
  computer with a keyboard). Saves are kept in your browser.
- **Download:** Windows, macOS and Linux versions are on the
  [Releases](../../releases/latest) page. Unzip and run, nothing else to install.
  - macOS: the app isn't notarized by Apple, so the first time, right-click it → Open
    (or System Settings → Privacy & Security → Open Anyway).
  - Windows: if SmartScreen warns about an unknown publisher, click More info → Run anyway.

*This is an unofficial fan project, not affiliated with Erin Hunter or the Warriors
publishers.*

## Playing online (proof of concept)

Online Play puts you and a friend in a shared camp on two different computers. It is new and
deliberately simple: you can see each other's cats, walk around, pounce, and say hello. Story
progress, saves, patrols and Clan ceremonies stay single-player for now.

It needs the little Cloudflare room server in `online/`. To try it on your own network:

```bash
# Terminal 1 — the room server
cd online
wrangler dev --port 8787 --ip 0.0.0.0

# Terminal 2 — the game
godot --path game
```

Press **O** on the title screen, choose a saved cat, and press **Create a Room**. Tell your
friend the four-letter code; they press **O**, choose their cat, type the code and press
**Join**. The online lobby's **Server** box points at `http://127.0.0.1:8787` by default —
change it to `http://<your-computer's-LAN-IP>:8787` so the second computer can reach it.

To run the whole thing automatically (starts a worker, plays a room end to end, stops it):

```bash
python3 tools/check_online.py
```

For a hosted version, deploy the worker with `cd online && wrangler deploy`, then put its
`https://…workers.dev` address in the lobby's **Server** box. A web build served over HTTPS
must use that HTTPS address — it cannot reach a server on your own computer. See `AGENTS.md`
for the full architecture and current limits.

## Working on the game

You need [Godot 4.6](https://godotengine.org/download) (the `godot` command on your PATH, or
set `GODOT` to it), Python 3.9+ and Claude Code. Open `game/project.godot` in Godot and press
Play to run it.

**Kid mode:** `./kids-vibe-code` (on Windows, `kids-vibe-code.cmd`) opens the game in Godot and
starts Claude as a friendly game-making buddy for kids aged 7–12. It:

- talks in simple words, makes all the technical decisions, and asks only fun questions
- keeps everything kid-friendly and stays in character
- tests the game after every change, writes what's new in `history.md`, and makes a git save
  point so "undo that!" always works
- runs in Claude's safe mode with web access blocked, so a grown-up's own Claude setup on the
  computer (personal instructions, plugins, tools) isn't part of the kid's session
- edits files without asking, but anything beyond the game's own tools and git save points
  still needs approval, so stay nearby

The persona and permissions are in `tools/kids/`.

**Grown-up mode:** just run `claude` in this folder. `CLAUDE.md` tells it how the game works
and how to check changes.

**Tools:**

| Command | What it does |
|---|---|
| `python3 tools/check_game.py` | Runs the game for a few seconds and reports any errors (`--screenshot` to see it) |
| `python3 tools/check_online.py` | Starts the room server and checks online play end to end |
| `python3 tools/export_game.py` | Builds the packages below (`web --serve` to play the web build locally) |
| `python3 tools/make_sounds.py` | Regenerates the sound effects in `game/assets/sounds/` |

## Packaging and publishing

`tools/export_game.py` builds a self-contained zip per platform into `dist/`. The first run
downloads the Godot export templates it needs (only those files, not the whole 1.2 GB set).

| Package | What's inside |
|---|---|
| `warrior-cats-web.zip` | HTML5 version for any static web host (itch.io, Cloudflare, GitHub Pages) |
| `warrior-cats-windows.zip` | A single 64-bit `.exe` |
| `warrior-cats-macos.zip` | `Warrior Cats.app` for Intel and Apple Silicon Macs (ad-hoc signed) |
| `warrior-cats-linux.zip` | A single x86_64 program |

The web build has to be served over http; opening `index.html` from disk won't work. It's
exported without threads, so no special server headers are needed.

## Publishing the website

The website is a Cloudflare Worker with static assets (`web/`). Cloudflare builds it itself:
Workers Builds pulls this repo on every push, runs `tools/cf_build.sh` (which downloads Godot,
exports the browser build) and then runs `wrangler deploy`.

Godot's `index.wasm` is about 36 MiB and Cloudflare refuses to store any single asset over
25 MiB, so the build cuts the engine into parts and `web/src/index.js` streams them back to the
browser as one ordinary download. That file also records the two approaches that do *not* work,
so nobody has to rediscover them.

To publish by hand from this computer:

```bash
python3 tools/deploy_web.py           # build and deploy
python3 tools/deploy_web.py --local   # build, then play it at http://localhost:8790
python3 tools/deploy_web.py --build    # build only
```

`.github/workflows/release.yml` builds every desktop package when a tag like `v1.0` is pushed
and attaches them to a GitHub Release. The file names never change, so
`releases/latest/download/warrior-cats-windows.zip` always gets the newest version. It pins
`GODOT_VERSION`; bump it when you update Godot. The website no longer uses GitHub Pages.
