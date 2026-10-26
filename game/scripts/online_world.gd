extends Node2D
## The shared online camp and forest. It uses the same territory artwork as ThunderClan
## Together, but it is deliberately simple: you, your friends, and the Clan cats who live
## in camp. There is no story progress or saving here — the room just lets everybody
## see each other walking around.
##
## Online play is a proof of concept for now: positions and little emotes are synced,
## and everything else stays on each player's own computer.

const MAP := Territory.MAP
const WALK := Territory.WALK
const CAMP := Territory.CAMP
const CAMP_RADII := Territory.CAMP_RADII

const LOCAL_COLOR := Color("ffd966")
const REMOTE_COLORS := [Color("ff9ec0"), Color("9be3ff"), Color("c9f7a8"), Color("e7c6ff"),
		Color("ffb38a"), Color("b8d4ff"), Color("ffe08a")]
const EMOTES := ["Mew!", "Hello!", "Let's play!", "Follow me!", "Race you!", "Nice catch!", "Purr..."]

var world: Node2D
var player: TopDownPlayer
var camera: Camera2D
var remotes: Dictionary = {}
var playing := false

var _hud: CanvasLayer
var _room_label: Label
var _count_label: Label
var _names_label: Label
var _card: InfoCard
var _leaving := false
var _emote_index := 0


func _ready() -> void:
	if not Net.in_room:
		Transition.go.call_deferred("res://scenes/online_lobby.tscn")
		return
	var info := GameState.describe_slot(GameState.slot)
	if info.is_empty():
		Net.leave_room()
		Transition.go.call_deferred("res://scenes/online_lobby.tscn")
		return

	var blockers := _build_world()
	player = TopDownPlayer.new()
	player.custom = info
	player.controls = "p1"
	player.bounds = WALK
	player.speed = 270.0
	player.can_pounce = true
	player.frozen = true
	player.blockers = blockers
	player.position = CAMP + Vector2(0, 200)
	world.add_child(player)
	player.name_label.add_theme_color_override("font_color", LOCAL_COLOR)

	camera = Camera2D.new()
	camera.limit_left = int(MAP.position.x)
	camera.limit_top = int(MAP.position.y)
	camera.limit_right = int(MAP.end.x)
	camera.limit_bottom = int(MAP.end.y)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.position = player.position + Vector2(0, -60)
	add_child(camera)
	camera.make_current()

	Net.player_joined.connect(_on_player_joined)
	Net.player_left.connect(_on_player_left)
	Net.players_updated.connect(_on_players_updated)
	Net.event_received.connect(_on_event)
	Net.chat_received.connect(_on_chat)
	Net.disconnected_from_room.connect(_on_disconnected)
	for pid in Net.players:
		if str(pid) != Net.player_id:
			_spawn_remote(str(pid))
	_refresh_room_hud()

	Net.send_hello(player.position)
	_make_hud()
	_card = InfoCard.new()
	add_child(_card)
	var friend_line := "You are %s." % info.name
	if remotes.size() > 0:
		friend_line += "  %d friend%s is already here!" % [remotes.size(), "" if remotes.size() == 1 else "s"]
	_card.show_card("ThunderClan Online!",
			"Room %s\n%s\n\nExplore the camp and the forest together.\nPress E to say hello to your friend!" % [
				Net.room_code, friend_line],
			"Press SPACE to start!")
	await _card.closed
	if _leaving or not Net.in_room:
		return
	playing = true
	player.frozen = false
	Net.send_state(player.position, player.cat.facing, false, false, true)


# --- Building the shared world ---------------------------------------------------------------

func _build_world() -> Array[Rect2]:
	world = Territory.WorldFloor.new()
	world.name = "Territory"
	world.y_sort_enabled = true
	add_child(world)

	_add_prop("high_rock", Territory.camp_pos(Territory.ROCK), "Highrock")
	for key in Territory.DENS:
		var den: Array = Territory.DENS[key]
		_add_prop("medicine" if key == "medicine" else "den", Territory.camp_pos(den[0]), str(den[1]))
	_add_prop("fresh_kill", Territory.camp_pos(Vector2(840, 470)), "Fresh-kill Pile")

	var blockers: Array[Rect2] = _gorse_wall()
	for prop in world.get_children():
		if prop is CampProp:
			blockers.append((prop as CampProp).footprint())

	for clan_cat in Territory.CLAN:
		var npc := Npc.make(str(clan_cat[0]), [-1.0, 1.0].pick_random())
		var at: Vector2 = clan_cat[1]
		npc.position = Territory.camp_pos(at)
		var area: Rect2 = clan_cat[2]
		if area.has_area():
			npc.set_wander(Territory.camp_area(area))
		world.add_child(npc)
	return blockers


func _add_prop(kind: String, pos: Vector2, label: String) -> CampProp:
	var prop := CampProp.new().setup(kind, label)
	prop.position = pos
	world.add_child(prop)
	return prop


## The prickly gorse wall around camp, with the tunnel at the bottom left open.
func _gorse_wall() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for k in 100:
		var angle := TAU * k / 100.0
		if absf(angle - PI / 2.0) < 0.1:
			continue
		var p := CAMP + Vector2(cos(angle) * CAMP_RADII.x, sin(angle) * CAMP_RADII.y)
		rects.append(Rect2(p - Vector2(45, 45), Vector2(90, 90)))
	return rects


# --- The HUD ---------------------------------------------------------------------------------

func _make_hud() -> void:
	_hud = CanvasLayer.new()
	add_child(_hud)

	var info := GameState.describe_slot(GameState.slot)
	var name_label := Fx.make_label(str(info.get("name", "Cat")), 28, LOCAL_COLOR, 8)
	name_label.position = Vector2(16, 10)
	name_label.size = Vector2(520, 40)
	_hud.add_child(name_label)
	var title_label := Fx.make_label(str(info.get("title", "")), 20, Color("fff6ec"), 6)
	title_label.position = Vector2(16, 46)
	title_label.size = Vector2(520, 30)
	_hud.add_child(title_label)

	var panel := Panel.new()
	panel.position = Vector2(930, 10)
	panel.size = Vector2(334, 150)
	panel.add_theme_stylebox_override("panel", Fx.cute_panel(20))
	_hud.add_child(panel)
	_room_label = Fx.ink_label("Room " + Net.room_code, 30, Fx.PINK_DARK)
	_room_label.position = Vector2(16, 10)
	_room_label.size = Vector2(302, 36)
	_room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_room_label)
	_count_label = Fx.ink_label("", 20, Fx.INK)
	_count_label.position = Vector2(16, 50)
	_count_label.size = Vector2(302, 24)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_count_label)
	_names_label = Fx.ink_label("", 19, Fx.INK)
	_names_label.position = Vector2(16, 78)
	_names_label.size = Vector2(302, 64)
	_names_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_names_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_names_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_names_label)

	var keys := Fx.make_label("Arrows = walk    SPACE = pounce    E = say hello    ESC = menu",
			22, Color("fff6ec"), 6)
	keys.position = Vector2(16, 684)
	keys.size = Vector2(1000, 30)
	_hud.add_child(keys)
	_refresh_room_hud()


func _refresh_room_hud() -> void:
	if _hud == null:
		return
	var names: Array[String] = []
	var local := str(GameState.describe_slot(GameState.slot).get("name", "You"))
	names.append(local + " (you)")
	for pid in Net.players:
		var player_data = Net.players[pid]
		if str(pid) == Net.player_id or not player_data is Dictionary:
			continue
		var friend_name := str(player_data.get("name", ""))
		if friend_name != "":
			names.append(friend_name)
	_count_label.text = "%d cat%s together" % [names.size(), "" if names.size() == 1 else "s"]
	_names_label.text = "\n".join(names)


func _show_banner(text: String) -> void:
	var banner := Fx.centered_label(text, 34, Color("ffd966"), 132)
	banner.add_theme_constant_override("outline_size", 12)
	_hud.add_child(banner)
	var tween := create_tween()
	tween.tween_interval(2.2)
	tween.tween_property(banner, "modulate:a", 0.0, 0.4)
	tween.tween_callback(banner.queue_free)


# --- Playing ---------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if player == null:
		return
	camera.position = player.position + Vector2(0, -60)
	if not playing:
		return
	Net.send_state(player.position, player.cat.facing, player.cat.walk_amount > 0.2,
			player.is_pouncing())
	if Input.is_action_just_pressed("online_emote"):
		_say_emote()


func _say_emote() -> void:
	var text: String = EMOTES[_emote_index % EMOTES.size()]
	_emote_index += 1
	for child in player.get_children():
		if child is PanelContainer:
			child.queue_free()
	Fx.speech(player, text, 112 * player.cat.size + 30, 3.0)
	Net.send_emote(text)


# --- Other players ---------------------------------------------------------------------------

func _spawn_remote(pid: String) -> void:
	if remotes.has(pid) or pid == Net.player_id:
		return
	var player_data = Net.players.get(pid, {})
	if not player_data is Dictionary or str(player_data.get("name", "")) == "":
		return
	var at := CAMP + Vector2(randf_range(-50, 50), 200 + randf_range(-20, 40))
	if player_data.get("pos") is Dictionary:
		var pos: Dictionary = player_data.pos
		at = Vector2(float(pos.get("x", at.x)), float(pos.get("y", at.y)))
	var remote := RemotePlayer.new()
	remote.position = at
	remote.target_pos = at
	remote.setup(player_data, REMOTE_COLORS[remotes.size() % REMOTE_COLORS.size()])
	world.add_child(remote)
	remotes[pid] = remote
	_refresh_room_hud()


func _on_player_joined(player_data: Dictionary) -> void:
	var pid := str(player_data.get("id", ""))
	if pid != "" and pid != Net.player_id:
		if remotes.has(pid):
			(remotes[pid] as RemotePlayer).set_state(player_data)
		else:
			_spawn_remote(pid)
			var name := str(player_data.get("name", "A friend"))
			_show_banner("%s joined!" % name)
	_refresh_room_hud()


func _on_players_updated(players: Dictionary) -> void:
	for pid in players:
		if str(pid) == Net.player_id:
			continue
		if remotes.has(pid):
			(remotes[pid] as RemotePlayer).set_state(players[pid])
		else:
			_spawn_remote(str(pid))
	_refresh_room_hud()


func _on_player_left(pid: String) -> void:
	if not remotes.has(pid):
		return
	var remote: RemotePlayer = remotes[pid]
	var name := str(remote.info.get("name", "A friend"))
	remote.queue_free()
	remotes.erase(pid)
	_show_banner("%s went home." % name)
	_refresh_room_hud()


func _on_event(event: Dictionary) -> void:
	if str(event.get("kind", "")) != "emote":
		return
	var from := str(event.get("from", ""))
	var text := str(event.get("data", {}).get("text", ""))
	if remotes.has(from) and text != "":
		(remotes[from] as RemotePlayer).say(text)


func _on_chat(message: Dictionary) -> void:
	var from := str(message.get("from", ""))
	var text := str(message.get("text", ""))
	if text == "":
		return
	if remotes.has(from):
		(remotes[from] as RemotePlayer).say(text)


func _on_disconnected() -> void:
	if _leaving:
		return
	_leaving = true
	playing = false
	if player != null:
		player.frozen = true
	_show_banner("The room connection ended. Back to Online Play...")
	await get_tree().create_timer(2.0).timeout
	Transition.go("res://scenes/online_lobby.tscn")


func _exit_tree() -> void:
	Net.leave_room()
