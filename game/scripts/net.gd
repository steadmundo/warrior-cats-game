extends Node
## The online room connection. It lives for the whole game (an autoload), so the
## connection survives going from the lobby into the shared camp.
##
## The room server is the little Cloudflare Worker in `online/`. Run it locally with
##   cd online && npx wrangler dev
## and the game talks to http://127.0.0.1:8787 by default. The browser build talks to
## the deployed worker instead (see PUBLIC_SERVER_URL), because a page on the web cannot
## reach your computer at 127.0.0.1.
##
## A room only carries player positions, their cats and little emotes. Everything else
## (the story, saves, Clan cats) stays on each player's own computer.

signal room_created(code: String)
signal room_error(message: String)
signal connected_to_room(code: String)
signal disconnected_from_room
signal player_joined(player: Dictionary)
signal player_left(player_id: String)
signal players_updated(players: Dictionary)
signal event_received(event: Dictionary)
signal chat_received(message: Dictionary)

## The room server running on this computer, for playing with somebody nearby.
const DEFAULT_SERVER_URL := "http://127.0.0.1:8787"
## The public room server the browser build uses. A page served over HTTPS cannot reach
## http://127.0.0.1, and cannot use ws:// at all, so the hosted game needs a real one.
## Deploy it with:  cd online && npx wrangler deploy
const PUBLIC_SERVER_URL := "https://warrior-cats-online.maast85.workers.dev"
const CONFIG_PATH := "user://online.cfg"
const CONNECT_TIMEOUT := 10.0
const PING_EVERY := 20.0

var server_url := ""
var in_room := false
var connecting := false
var room_code := ""
var player_id := ""
var players: Dictionary = {}

var _ws: WebSocketPeer = null
var _pending_cat: Dictionary = {}
var _pending_name := ""
var _connect_left := 0.0
var _ping_left := PING_EVERY
var _last_state_sent := 0


func _ready() -> void:
	_load_server_url()


func _process(delta: float) -> void:
	if _ws == null:
		return
	_ws.poll()
	var state := _ws.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		if connecting:
			connecting = false
			in_room = true
			_connect_left = 0.0
			_ping_left = PING_EVERY
			_send_hello_now()
			connected_to_room.emit(room_code)
		while _ws.get_available_packet_count() > 0:
			_handle_packet(_ws.get_packet())
		_ping_left -= delta
		if _ping_left <= 0.0:
			_ping_left = PING_EVERY
			_ws.send_text("ping")  # the room's Durable Object answers this by itself
	elif state == WebSocketPeer.STATE_CONNECTING:
		_connect_left -= delta
		if _connect_left <= 0.0:
			_close_socket()
			_emit_error("Could not reach the room server. Is it running?")
	elif state == WebSocketPeer.STATE_CLOSED:
		_ws = null
		if in_room:
			_cleanup()
			disconnected_from_room.emit()
		elif connecting:
			_cleanup()
			_emit_error("The room server closed the connection.")


# --- Making and joining rooms ----------------------------------------------------------------

## Makes a new room and connects to it. `cat_data` comes from Net.cat_payload(info).
func create_room(cat_data: Dictionary, display_name: String) -> void:
	if in_room or connecting:
		return
	_pending_cat = cat_data
	_pending_name = display_name
	var answer: Dictionary = await _post("/api/room/create", {})
	if answer.is_empty():
		return
	room_code = str(answer.get("roomCode", "")).to_upper()
	if room_code == "" or not answer.has("wsUrl"):
		_emit_error("The room server sent an unexpected answer.")
		return
	room_created.emit(room_code)
	_start_socket(str(answer["wsUrl"]))


## Joins a room that somebody else made.
func join_room(code: String, cat_data: Dictionary, display_name: String) -> void:
	if in_room or connecting:
		return
	_pending_cat = cat_data
	_pending_name = display_name
	var wanted := code.strip_edges().to_upper()
	var answer: Dictionary = await _post("/api/room/join", {"roomCode": wanted})
	if answer.is_empty():
		return
	room_code = str(answer.get("roomCode", wanted)).to_upper()
	if not answer.has("wsUrl"):
		_emit_error("The room server sent an unexpected answer.")
		return
	room_created.emit(room_code)
	_start_socket(str(answer["wsUrl"]))


func leave_room() -> void:
	if _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.close(1000, "bye")
	_ws = null
	_cleanup()


func is_room_open() -> bool:
	return in_room and _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN


func _start_socket(url: String) -> void:
	_close_socket()
	_ws = WebSocketPeer.new()
	var error := _ws.connect_to_url(url)
	if error != OK:
		_ws = null
		_emit_error("Could not open the room connection (error %d)." % error)
		return
	connecting = true
	_connect_left = CONNECT_TIMEOUT
	_ping_left = PING_EVERY


func _close_socket() -> void:
	if _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.close(1000, "bye")
	_ws = null


func _cleanup() -> void:
	connecting = false
	in_room = false
	room_code = ""
	player_id = ""
	players.clear()


func _emit_error(message: String) -> void:
	room_error.emit(message)


# --- Server URL ------------------------------------------------------------------------------

## Where this build looks for rooms when nobody has said otherwise.
func default_server_url() -> String:
	return PUBLIC_SERVER_URL if OS.has_feature("web") else DEFAULT_SERVER_URL


## The lobby's Apply button: an empty box, or the built-in address, means "use the default".
func set_server_url(value: String) -> void:
	var cleaned := value.strip_edges()
	while cleaned.ends_with("/"):
		cleaned = cleaned.left(-1)
	server_url = cleaned if cleaned != "" else default_server_url()
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)  # a missing file is fine: we are about to write it
	if server_url == default_server_url():
		config.erase_section_key("online", "server_url")  # no stale address to remember
	else:
		config.set_value("online", "server_url", server_url)
	config.save(CONFIG_PATH)


func _load_server_url() -> void:
	var from_command_line := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--server="):
			from_command_line = argument.trim_prefix("--server=")
	var config := ConfigFile.new()
	var from_file := ""
	if config.load(CONFIG_PATH) == OK:
		from_file = str(config.get_value("online", "server_url", ""))
	server_url = (from_command_line if from_command_line != ""
			else (from_file if from_file != "" else default_server_url()))


# --- Sending ---------------------------------------------------------------------------------

func send_state(pos: Vector2, facing: float, walking: bool, pouncing: bool, force := false) -> void:
	if not is_room_open():
		return
	var now := Time.get_ticks_msec()
	if not force and now - _last_state_sent < 60:
		return
	_last_state_sent = now
	_send_json({
		"type": "input",
		"pos": {"x": roundi(pos.x), "y": roundi(pos.y)},
		"facing": 1 if facing >= 0.0 else -1,
		"walking": walking,
		"pouncing": pouncing,
	})


func send_hello(pos := Vector2.INF) -> void:
	if not is_room_open():
		return
	var message := {
		"type": "hello",
		"name": _pending_name,
		"catData": _pending_cat,
	}
	if pos != Vector2.INF:
		message["pos"] = {"x": roundi(pos.x), "y": roundi(pos.y)}
	_send_json(message)


func send_emote(text: String) -> void:
	send_action("emote", {"text": text.left(80)})


func send_action(action_type: String, data: Dictionary = {}) -> void:
	if not is_room_open():
		return
	_send_json({"type": "action", "action": {"type": action_type, "data": data}})


func send_chat(text: String) -> void:
	if not is_room_open():
		return
	var clean := text.strip_edges().left(120)
	if clean != "":
		_send_json({"type": "chat", "text": clean})


func _send_hello_now() -> void:
	send_hello()


func _send_json(message: Dictionary) -> void:
	if _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify(message))


# --- Receiving -------------------------------------------------------------------------------

func _handle_packet(packet: PackedByteArray) -> void:
	var data = JSON.parse_string(packet.get_string_from_utf8())
	if not data is Dictionary:
		return
	match str(data.get("type", "")):
		"welcome":
			player_id = str(data.get("playerId", ""))
			var room_players = data.get("players", {})
			players = room_players if room_players is Dictionary else {}
			players_updated.emit(players)
		"player_joined":
			var joined = data.get("player", {})
			if joined is Dictionary and joined.has("id"):
				players[str(joined.id)] = joined
				player_joined.emit(joined)
				players_updated.emit(players)
		"player_update":
			var update = data.get("player", {})
			if update is Dictionary and update.has("id"):
				var pid := str(update.id)
				var player: Dictionary = players.get(pid, {"id": pid})
				for key in update:
					player[key] = update[key]
				players[pid] = player
				players_updated.emit(players)
		"player_left":
			var pid := str(data.get("playerId", ""))
			if players.has(pid):
				players.erase(pid)
			player_left.emit(pid)
			players_updated.emit(players)
		"event":
			var event = data.get("event", {})
			if event is Dictionary:
				event_received.emit(event)
		"chat":
			chat_received.emit(data)


# --- Talking to the room server --------------------------------------------------------------

func _post(path: String, payload: Dictionary) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = CONNECT_TIMEOUT
	add_child(http)
	var error := http.request(
		server_url + path,
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if error != OK:
		http.queue_free()
		_emit_error("Could not ask the room server (error %d)." % error)
		return {}
	var result: Array = await http.request_completed
	http.queue_free()
	if result[0] != HTTPRequest.RESULT_SUCCESS:
		_emit_error("Could not reach the room server. Is it running?")
		return {}
	var bytes: PackedByteArray = result[3]
	var body = JSON.parse_string(bytes.get_string_from_utf8())
	var status: int = result[1]
	if status >= 200 and status < 300 and body is Dictionary:
		return body
	if body is Dictionary and body.has("error"):
		_emit_error(str(body["error"]))
	else:
		_emit_error("The room server said no (%d)." % status)
	return {}


# --- Cat data for the other player -----------------------------------------------------------

## Turns a cat from GameState.describe_slot() into plain JSON the room server can pass on.
## Colours and paint dabs are sent as hex strings so nothing is lost in JSON.
static func cat_payload(info: Dictionary) -> Dictionary:
	var look: Dictionary = info.get("look", {})
	var dabs := []
	for dab in info.get("paint", []):
		if not dab is Array or dab.size() < 3:
			continue
		var x := 0.0
		var y := 0.0
		if dab[0] is Vector2:
			x = dab[0].x
			y = dab[0].y
		var color := "ff5d73"
		var dab_color = dab[1]
		if dab_color is Color:
			color = dab_color.to_html(false)
		dabs.append([x, y, color, float(dab[2])])
	return {
		"name": str(info.get("name", "Cat")),
		"title": str(info.get("title", "")),
		"size": float(info.get("size", 1.0)),
		"collar": bool(info.get("kittypet", false)),
		"fur": _hex(look.get("fur"), Color("e8862a")),
		"markings": _hex(look.get("markings"), Color("4a2c18")),
		"pattern": str(look.get("pattern", "Solid")),
		"eyes": _hex(look.get("eyes"), Color("5fd14a")),
		"fluffy": bool(look.get("fluffy", false)),
		"mood": str(look.get("mood", "happy")),
		"paint": dabs,
	}


static func _hex(value, fallback: Color) -> String:
	if value is Color:
		return value.to_html(false)
	return fallback.to_html(false)
