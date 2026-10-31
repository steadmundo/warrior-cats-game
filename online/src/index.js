/**
 * Warrior Cats online rooms — a tiny Cloudflare Worker + Durable Object.
 *
 * Each room is one Durable Object. It relays players' positions, cats and emotes.
 * It keeps no game state of its own, so a room costs almost nothing while it is empty.
 *
 * HTTP API
 *   POST /api/room/create  -> { roomCode, wsUrl }
 *   POST /api/room/join    -> { roomCode, wsUrl }   (404 if the room was never created)
 *   GET  /health           -> { ok: true }
 *   GET  /ws?room=CODE     -> WebSocket upgrade
 *
 * WebSocket messages (JSON)
 *   client -> server: hello, input, action, chat, ping
 *   server -> client: welcome, player_joined, player_update, player_left, event, chat
 *
 * Local development:  cd online && npx wrangler dev
 */

const ROOM_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // no I, O, 0 or 1
const ROOM_LENGTH = 4;
const MAX_PLAYERS = 8;
const MAX_NAME = 24;
const MAX_CHAT = 120;
const MAP_W = 3200;
const MAP_H = 2400;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, X-Create-Key",
  "Access-Control-Max-Age": "86400",
};

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", ...CORS },
  });
}

function textResponse(text, status = 200) {
  return new Response(text, {
    status,
    headers: { "content-type": "text/plain; charset=utf-8", ...CORS },
  });
}

function newRoomCode() {
  const bytes = crypto.getRandomValues(new Uint8Array(ROOM_LENGTH));
  let code = "";
  for (const byte of bytes) code += ROOM_ALPHABET[byte % ROOM_ALPHABET.length];
  return code;
}

function cleanCode(value) {
  return String(value ?? "")
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, "")
    .slice(0, 8);
}

function cleanText(value, maxLength) {
  return String(value ?? "")
    .replace(/[\u0000-\u001f\u007f]/g, "")
    .trim()
    .slice(0, maxLength);
}

function cleanHex(value, fallback = "ffffff") {
  const text = String(value ?? "").replace(/^#/, "");
  return /^[0-9a-fA-F]{6}$/.test(text) ? text.toLowerCase() : fallback;
}

function number(value, fallback = 0) {
  const n = Number(value);
  return Number.isFinite(n) ? n : fallback;
}

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

function cleanPosition(pos) {
  if (!pos || typeof pos !== "object") return null;
  return {
    x: clamp(number(pos.x, MAP_W / 2), 0, MAP_W),
    y: clamp(number(pos.y, MAP_H / 2), 0, MAP_H),
  };
}

/** The cat's appearance is sent once when the player joins. */
function cleanCat(cat) {
  if (!cat || typeof cat !== "object") return {};
  const paint = [];
  if (Array.isArray(cat.paint)) {
    for (const dab of cat.paint.slice(0, 120)) {
      if (!Array.isArray(dab) || dab.length < 3) continue;
      paint.push([
        clamp(number(dab[0]), -200, 200),
        clamp(number(dab[1]), -200, 200),
        cleanHex(dab[2], "ff5d73"),
        clamp(number(dab[3], 8), 1, 30),
      ]);
    }
  }
  return {
    name: cleanText(cat.name, MAX_NAME),
    title: cleanText(cat.title, 32),
    size: clamp(number(cat.size, 1), 0.5, 2),
    collar: Boolean(cat.collar),
    fur: cleanHex(cat.fur, "e8862a"),
    markings: cleanHex(cat.markings, "4a2c18"),
    pattern: cleanText(cat.pattern, 24) || "Solid",
    eyes: cleanHex(cat.eyes, "5fd14a"),
    fluffy: Boolean(cat.fluffy),
    mood: cat.mood === "grumpy" ? "grumpy" : "happy",
    paint,
  };
}

function websocketUrl(request, roomCode) {
  const url = new URL(request.url);
  url.protocol = url.protocol === "https:" ? "wss:" : "ws:";
  url.pathname = "/ws";
  url.search = `?room=${encodeURIComponent(roomCode)}`;
  return url.toString();
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS });
    }

    if (url.pathname === "/health") {
      return jsonResponse({ ok: true, service: "warrior-cats-online" });
    }

    if (url.pathname === "/" && request.method === "GET") {
      return textResponse(
        [
          "Warrior Cats online rooms",
          "",
          "POST /api/room/create   make a room",
          "POST /api/room/join     join a room  ({\"roomCode\":\"ABCD\"})",
          "GET  /ws?room=ABCD      WebSocket for a room",
          "",
          "The Godot game starts a room from its Online Play screen.",
        ].join("\n"),
      );
    }

    try {
      if (url.pathname === "/api/room/create" && request.method === "POST") {
        const requiredKey = env.CREATE_ROOM_KEY;
        if (requiredKey) {
          const body = await request.json().catch(() => ({}));
          const providedKey = request.headers.get("X-Create-Key") || body?.key || "";
          if (providedKey !== requiredKey) {
            return jsonResponse({ error: "Room creation is locked. Ask a grown-up for the key." }, 403);
          }
          const roomCode = cleanCode(body?.roomCode) || newRoomCode();
          const stub = env.ROOMS.get(env.ROOMS.idFromName(roomCode));
          const created = await stub.fetch("https://room.internal/create", { method: "POST" });
          if (!created.ok) return jsonResponse({ error: "Could not create the room." }, 500);
          return jsonResponse({ roomCode, wsUrl: websocketUrl(request, roomCode) });
        } else {
          const body = await request.json().catch(() => ({}));
          const roomCode = cleanCode(body?.roomCode) || newRoomCode();
          const stub = env.ROOMS.get(env.ROOMS.idFromName(roomCode));
          const created = await stub.fetch("https://room.internal/create", { method: "POST" });
          if (!created.ok) return jsonResponse({ error: "Could not create the room." }, 500);
          return jsonResponse({ roomCode, wsUrl: websocketUrl(request, roomCode) });
        }
      }

      if (url.pathname === "/api/room/join" && request.method === "POST") {
        const body = await request.json().catch(() => ({}));
        const roomCode = cleanCode(body?.roomCode);
        if (roomCode.length < ROOM_LENGTH) {
          return jsonResponse({ error: "That room code is too short." }, 400);
        }
        const stub = env.ROOMS.get(env.ROOMS.idFromName(roomCode));
        const found = await stub.fetch("https://room.internal/exists");
        if (!found.ok) {
          return jsonResponse({ error: "No room with that code. Check the letters!" }, 404);
        }
        return jsonResponse({ roomCode, wsUrl: websocketUrl(request, roomCode) });
      }

      if (url.pathname === "/ws") {
        const roomCode = cleanCode(url.searchParams.get("room"));
        if (roomCode.length < ROOM_LENGTH) {
          return textResponse("Missing room code.", 400);
        }
        const stub = env.ROOMS.get(env.ROOMS.idFromName(roomCode));
        return stub.fetch(request);
      }

      return jsonResponse({ error: "Not found." }, 404);
    } catch (error) {
      console.error("online worker error", error);
      return jsonResponse({ error: "The room server had a problem." }, 500);
    }
  },
};

/**
 * One room. Players live in their WebSocket attachment, so the room can hibernate
 * between messages and costs almost nothing when nobody is moving.
 */
export class Room {
  constructor(ctx, env) {
    this.ctx = ctx;
    this.env = env;
    this.ctx.setWebSocketAutoResponse(
      new WebSocketRequestResponsePair("ping", "pong"),
    );
  }

  async fetch(request) {
    const path = new URL(request.url).pathname;

    if (path.endsWith("/create")) {
      await this.ctx.storage.put("created", Date.now());
      return jsonResponse({ ok: true });
    }

    if (path.endsWith("/exists")) {
      const created = await this.ctx.storage.get("created");
      return created ? jsonResponse({ ok: true }) : jsonResponse({ error: "no room" }, 404);
    }

    if (path.endsWith("/ws")) {
      if (request.headers.get("Upgrade") !== "websocket") {
        return textResponse("Expected a WebSocket upgrade.", 426);
      }
      if (this.ctx.getWebSockets().length >= MAX_PLAYERS) {
        return textResponse("This room is full.", 409);
      }

      const pair = new WebSocketPair();
      const [client, server] = Object.values(pair);
      this.ctx.acceptWebSocket(server);

      const me = {
        id: crypto.randomUUID(),
        name: "",
        catData: {},
        pos: null,
        facing: 1,
        walking: false,
        pouncing: false,
        joined: false,
      };
      server.serializeAttachment(me);
      server.send(
        JSON.stringify({
          type: "welcome",
          playerId: me.id,
          players: this.players(),
          world: { map: "territory" },
        }),
      );

      return new Response(null, { status: 101, webSocket: client });
    }

    return textResponse("Not found.", 404);
  }

  /** Everybody who has said hello, as { id: player }. */
  players() {
    const found = {};
    for (const ws of this.ctx.getWebSockets()) {
      const player = this.attachment(ws);
      if (player?.joined) found[player.id] = publicPlayer(player);
    }
    return found;
  }

  attachment(ws) {
    try {
      return ws.deserializeAttachment();
    } catch {
      return null;
    }
  }

  broadcast(payload, except = null) {
    const text = JSON.stringify(payload);
    for (const ws of this.ctx.getWebSockets()) {
      if (ws === except) continue;
      const player = this.attachment(ws);
      if (!player?.joined) continue;
      try {
        ws.send(text);
      } catch {
        // A socket that has just gone away; webSocketClose will clean it up.
      }
    }
  }

  async webSocketMessage(ws, message) {
    if (typeof message !== "string") return;
    if (message.length > 16_000) return;

    let data;
    try {
      data = JSON.parse(message);
    } catch {
      return;
    }
    if (!data || typeof data !== "object") return;

    const player = this.attachment(ws);
    if (!player) return;

    if (data.type === "hello") {
      player.name = cleanText(data.name, MAX_NAME) || "Cat";
      player.catData = cleanCat(data.catData);
      player.pos = cleanPosition(data.pos) ?? player.pos;
      player.joined = true;
      ws.serializeAttachment(player);
      // Sending this to everyone makes a repeated hello harmless.
      this.broadcast({ type: "player_joined", player: publicPlayer(player) }, ws);
      return;
    }

    if (!player.joined) return;

    if (data.type === "input") {
      const pos = cleanPosition(data.pos);
      if (pos) player.pos = pos;
      player.facing = number(data.facing, 1) < 0 ? -1 : 1;
      player.walking = Boolean(data.walking);
      player.pouncing = Boolean(data.pouncing);
      ws.serializeAttachment(player);
      this.broadcast(
        {
          type: "player_update",
          player: {
            id: player.id,
            pos: player.pos,
            facing: player.facing,
            walking: player.walking,
            pouncing: player.pouncing,
          },
        },
        ws,
      );
      return;
    }

    if (data.type === "action") {
      const action = data.action;
      if (!action || typeof action !== "object") return;
      this.broadcast(
        {
          type: "event",
          event: {
            kind: cleanText(action.type, 24),
            from: player.id,
            name: player.name,
            data: action.data && typeof action.data === "object" ? action.data : {},
          },
        },
        ws,
      );
      return;
    }

    if (data.type === "chat") {
      const text = cleanText(data.text, MAX_CHAT);
      if (!text) return;
      this.broadcast({ type: "chat", from: player.id, name: player.name, text }, ws);
    }
  }

  async webSocketClose(ws) {
    this.leave(ws);
  }

  async webSocketError(ws) {
    this.leave(ws);
  }

  leave(ws) {
    const player = this.attachment(ws);
    if (player?.joined) {
      this.broadcast({ type: "player_left", playerId: player.id }, ws);
    }
  }
}

function publicPlayer(player) {
  return {
    id: player.id,
    name: player.name,
    catData: player.catData,
    pos: player.pos,
    facing: player.facing,
    walking: player.walking,
    pouncing: player.pouncing,
  };
}
