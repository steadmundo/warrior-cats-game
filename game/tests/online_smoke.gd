extends Node
## A headless end-to-end check for online play. It:
##   1. makes a throwaway save in slot 1 (run it with a temporary XDG_DATA_HOME!)
##   2. makes a room through Net (the real game client code)
##   3. opens the real online world scene
##   4. connects a second, raw WebSocket player and sends a hello + movement
##   5. checks that the world spawned that player's cat in the right place
##
## Run it with:  python3 tools/check_online.py
## (or: XDG_DATA_HOME=/tmp/warrior-online godot --headless --path game tests/online_smoke.tscn)
##
## The room server address comes from Net (the same setting the game uses), so the runner
## can pass --server=http://127.0.0.1:PORT after a `--` on the command line.

const TIMEOUT := 20.0

var _friend: Friend
var _world: Node
var _room := ""
var _elapsed := 0.0
var _waiting := 0.0
var _sent_move := false
var _failed := false


class Friend extends Node:
	var ws := WebSocketPeer.new()
	var room_code := ""
	var sent_hello := false
	var sent_move := false

	func start(code: String) -> void:
		room_code = code
		ws.connect_to_url(_ws_url(Net.server_url) + "?room=" + code)

	static func _ws_url(server_url: String) -> String:
		var url := server_url
		if url.begins_with("https://"):
			url = "wss://" + url.trim_prefix("https://")
		elif url.begins_with("http://"):
			url = "ws://" + url.trim_prefix("http://")
		while url.ends_with("/"):
			url = url.left(-1)
		return url + "/ws"

	func _process(_delta: float) -> void:
		ws.poll()
		if ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
			return
		if not sent_hello:
			sent_hello = true
			ws.send_text(JSON.stringify({
				"type": "hello",
				"name": "Sandpaw",
				"catData": {
					"name": "Sandpaw", "title": "Apprentice", "size": 0.9, "collar": false,
					"fur": "f3c98e", "markings": "e0a530", "pattern": "Solid", "eyes": "5fd14a",
					"fluffy": false, "mood": "happy", "paint": [],
				},
				"pos": {"x": 1900, "y": 1350},
			}))
		if sent_hello and not sent_move:
			sent_move = true
			ws.send_text(JSON.stringify({
				"type": "input", "pos": {"x": 2050, "y": 1400}, "facing": -1,
				"walking": true, "pouncing": false,
			}))
		while ws.get_available_packet_count() > 0:
			ws.get_packet()


func _ready() -> void:
	# A throwaway cat in slot 1. The runner points XDG_DATA_HOME at a temp folder,
	# so this never touches a real player's save.
	GameState.new_game(1)
	GameState.met_clan = true
	GameState.step = GameState.STORY.size()
	GameState.prefix_index = 0
	GameState.name_ending = "heart"
	GameState.save_game()
	GameState.load_game(1)

	# Net already read --server=... from the command line (see tools/check_online.py).
	await Net.create_room(Net.cat_payload(GameState.describe_slot(1)), "Fireheart")
	_room = Net.room_code
	if _room == "":
		_finish(false, "could not create a room")
		return

	var waited := 0.0
	while not Net.in_room and waited < 8.0:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	if not Net.in_room:
		_finish(false, "never connected to the room")
		return

	_world = load("res://scenes/online_world.tscn").instantiate()
	add_child(_world)
	_friend = Friend.new()
	add_child(_friend)
	_friend.start(_room)


func _process(delta: float) -> void:
	_elapsed += delta
	if _failed or _world == null:
		if _elapsed > TIMEOUT:
			_finish(false, "timed out")
		return

	var remotes: Dictionary = _world.remotes
	if remotes.size() == 0:
		if _elapsed > TIMEOUT:
			_finish(false, "the friend's cat was never spawned")
		return

	var remote = remotes.values()[0]
	if remote.target_pos.distance_to(Vector2(2050, 1400)) > 5.0:
		if _elapsed > TIMEOUT:
			_finish(false, "the friend's movement never arrived (target %s)" % remote.target_pos)
		return

	_finish(true, "room %s, friend spawned at %s" % [_room, remote.target_pos])


func _finish(ok: bool, message: String) -> void:
	if _failed:
		return
	_failed = true
	Net.leave_room()
	if ok:
		print("ONLINE SMOKE OK: ", message)
		get_tree().quit(0)
	else:
		printerr("ONLINE SMOKE FAILED: ", message)
		get_tree().quit(1)
