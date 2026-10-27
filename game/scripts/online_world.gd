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
const INFO_X := 930.0
const INFO_Y := 10.0
const INFO_W := 334.0
const INFO_TOP := 74.0
const INFO_ROW_H := 56.0

var world: Node2D
var player: TopDownPlayer
var camera: Camera2D
var remotes: Dictionary = {}
var playing := false

var _hud: CanvasLayer
var _room_label: Label
var _count_label: Label
var _info_panel: Panel
var _info_body: Control
var _info_open := false
var _info_sig := ""
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

	# Room info stays out of the way until TAB is held: then this box drops down with the
	# room code, how many cats are here, and a row for each of them.
	_info_panel = Panel.new()
	_info_panel.position = Vector2(INFO_X, INFO_Y)
	_info_panel.size = Vector2(INFO_W, 150)
	_info_panel.add_theme_stylebox_override("panel", Fx.cute_panel(20))
	_info_panel.visible = false
	_hud.add_child(_info_panel)
	_room_label = Fx.ink_label("Room " + Net.room_code, 30, Fx.PINK_DARK)
	_room_label.position = Vector2(16, 8)
	_room_label.size = Vector2(302, 36)
	_room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_panel.add_child(_room_label)
	_count_label = Fx.ink_label("", 20, Fx.INK)
	_count_label.position = Vector2(16, 46)
	_count_label.size = Vector2(302, 24)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_panel.add_child(_count_label)
	_info_body = Control.new()
	_info_body.position = Vector2(0, INFO_TOP)
	_info_body.size = Vector2(INFO_W, 24)
	_info_panel.add_child(_info_body)

	var keys := Fx.make_label("Arrows = walk    SPACE = pounce    E = say hello    TAB = room info    ESC = menu",
			22, Color("fff6ec"), 6)
	keys.position = Vector2(16, 684)
	keys.size = Vector2(1150, 30)
	_hud.add_child(keys)
	_refresh_room_hud()


func _refresh_room_hud() -> void:
	if _info_panel == null:
		return
	var entries := _who_entries()
	_count_label.text = "%d cat%s together" % [entries.size(), "" if entries.size() == 1 else "s"]
	var names: Array[String] = []
	for entry in entries:
		names.append(str(entry.get("name", "")))
	var signature := ",".join(names)
	if not _info_open or signature == _info_sig:
		return  # hidden, or nothing changed: leave the rows alone
	_info_sig = signature
	_build_info_body(entries)


## One row per cat: name tag colour, fur, name and Clan title.
func _build_info_body(entries: Array) -> void:
	for child in _info_body.get_children():
		_info_body.remove_child(child)
		child.queue_free()
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var y := i * INFO_ROW_H
		var tag := ColorRect.new()  # matches the colour of their name tag in the world
		tag.color = entry.tag
		tag.position = Vector2(16, y + 10)
		tag.size = Vector2(6, 30)
		_info_body.add_child(tag)
		var fur := Panel.new()  # a little fur-colour swatch, like their cat
		fur.position = Vector2(30, y + 9)
		fur.size = Vector2(30, 30)
		fur.add_theme_stylebox_override("panel", Fx.panel_style(entry.fur, Color.WHITE, 9, 2))
		_info_body.add_child(fur)
		var row_name := Fx.ink_label(str(entry.name) + ("  (you)" if entry.you else ""), 22, Fx.INK)
		row_name.position = Vector2(70, y - 2)
		row_name.size = Vector2(250, 28)
		row_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_info_body.add_child(row_name)
		var row_title := str(entry.title)
		var title_text := row_title if row_title != "" else "ThunderClan cat"
		var row_sub := Fx.ink_label(title_text, 16, Fx.PINK_DARK)
		row_sub.position = Vector2(70, y + 24)
		row_sub.size = Vector2(250, 22)
		row_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_info_body.add_child(row_sub)
	var body_height := entries.size() * INFO_ROW_H
	if entries.size() < 2:
		var alone := Fx.ink_label("Just you — invite a friend!", 17, Fx.PINK_DARK)
		alone.position = Vector2(16, body_height + 2)
		alone.size = Vector2(302, 24)
		alone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_info_body.add_child(alone)
		body_height += 26
	_info_panel.size = Vector2(INFO_W, INFO_TOP + body_height + 12)


## Room info is on screen only while TAB is held.
func _set_info_open(open: bool) -> void:
	if _info_open == open:
		return
	_info_open = open
	_info_panel.visible = open
	if open:
		_info_sig = ""  # build fresh every time, so it always names who is here right now
		_refresh_room_hud()
		Sfx.play("click")


## You first, then everybody else in the room by name.
func _who_entries() -> Array:
	var entries := []
	var mine := GameState.describe_slot(GameState.slot)
	if not mine.is_empty():
		var look: Dictionary = mine.get("look", {})
		entries.append({
			"name": str(mine.get("name", "You")),
			"title": str(mine.get("title", "")),
			"fur": _fur_color(look),
			"tag": LOCAL_COLOR,
			"you": true,
		})
	var friends := []
	for pid in Net.players:
		if str(pid) == Net.player_id:
			continue
		var data = Net.players[pid]
		if not data is Dictionary:
			continue
		var friend_name := str(data.get("name", ""))
		if friend_name == "":
			continue
		var cat_data := {}
		if data.get("catData") is Dictionary:
			cat_data = data.catData
		var tag := Color("ff9ec0")
		if remotes.has(str(pid)):
			tag = (remotes[str(pid)] as RemotePlayer).name_color
		friends.append({
			"name": friend_name,
			"title": str(cat_data.get("title", "")),
			"fur": _fur_color(cat_data),
			"tag": tag,
			"you": false,
		})
	friends.sort_custom(func(a, b): return str(a.name).nocasecmp_to(str(b.name)) < 0)
	entries.append_array(friends)
	return entries


## A cat's fur colour, whether it comes from a save (Color) or over the wire (hex string)
static func _fur_color(cat: Dictionary) -> Color:
	var fur = cat.get("fur", null)
	if fur is Color:
		return fur
	if fur is String and str(fur) != "":
		return Color.from_string(str(fur), Color("e8862a"))
	return Color("e8862a")


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
	if Input.is_action_pressed("online_players") != _info_open:
		_set_info_open(not _info_open)


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
