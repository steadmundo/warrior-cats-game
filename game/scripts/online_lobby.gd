extends Node2D
## Online Play: choose one of your saved cats, then make a room or join a friend's.
## This is the front door to the shared camp in `online_world.gd`.
##
## The room server is the Cloudflare Worker in `online/`. A grown-up can run it on this
## computer at http://127.0.0.1:8787, or deploy it to Cloudflare; the server box at the
## bottom of the screen can point somewhere else. See Net.default_server_url().

const SERVER_HINT := "Server (press Apply after changing)"
const PARENT_HINT := "Parent key (only needed if room creation is locked)"

var _status: Label
var _slot_buttons: Array[Button] = []
var _create_button: Button
var _join_button: Button
var _first_cat_button: Button
var _step2_label: Label
var _join_hint: Label
var _room_input: LineEdit
var _server_input: LineEdit
var _parent_input: LineEdit
var _parent_toggle: Button
var _parent_panel: Panel
var _parent_open := false
var _selected_slot := -1
var _busy := false
var _launching := false
var _time := 0.0


func _ready() -> void:
	GameState.return_to_online = false  # only set while we are off making a first cat
	var ui := CanvasLayer.new()
	add_child(ui)

	ui.add_child(Fx.centered_label("Play Together Online", 52, Color("ffd966"), 24))
	ui.add_child(Fx.centered_label("Two devices, one camp — play with a friend far away!", 24,
			Color("fff6ec"), 88))
	var sound := SoundButton.new()
	sound.position = SoundButton.CORNER
	ui.add_child(sound)

	var panel := Panel.new()
	panel.position = Vector2(110, 130)
	panel.size = Vector2(1060, 490)
	panel.add_theme_stylebox_override("panel", Fx.cute_panel(30))
	ui.add_child(panel)

	var choose := Fx.ink_label("1. Choose your cat", 30, Fx.PINK_DARK)
	choose.position = Vector2(30, 20)
	panel.add_child(choose)

	for i in GameState.SAVE_SLOTS:
		var button := _make_button("", Color("f3e6ea"), Vector2(30 + i * 336, 66), Vector2(316, 82))
		button.pressed.connect(_select_slot.bind(i))
		panel.add_child(button)
		_slot_buttons.append(button)

	var make := Fx.ink_label("2. Make a room, or join one", 30, Fx.PINK_DARK)
	_step2_label = make
	make.position = Vector2(30, 174)
	panel.add_child(make)

	_create_button = _make_button("Create a Room", Color("7ad67a"), Vector2(30, 218), Vector2(316, 72))
	_create_button.add_theme_font_size_override("font_size", 30)
	_create_button.pressed.connect(_create_room)
	panel.add_child(_create_button)

	var join_hint := Fx.ink_label("Room code:", 24, Fx.INK)
	_join_hint = join_hint
	join_hint.position = Vector2(392, 238)
	join_hint.size = Vector2(140, 40)
	panel.add_child(join_hint)

	_room_input = LineEdit.new()
	_room_input.position = Vector2(530, 226)
	_room_input.size = Vector2(200, 58)
	_room_input.placeholder_text = "ABCD"
	_room_input.max_length = 8
	_room_input.add_theme_font_size_override("font_size", 28)
	_room_input.add_theme_color_override("font_color", Fx.INK)
	_room_input.add_theme_color_override("caret_color", Fx.INK)
	panel.add_child(_room_input)

	_join_button = _make_button("Join", Color("8fd8ff"), Vector2(750, 226), Vector2(180, 58))
	_join_button.add_theme_font_size_override("font_size", 28)
	_join_button.pressed.connect(_join_room)
	panel.add_child(_join_button)

	# Shown instead of the room buttons when there is no saved cat yet
	_first_cat_button = _make_button("Make your first cat!", Color("7ad67a"), Vector2(30, 218), Vector2(740, 72))
	_first_cat_button.add_theme_font_size_override("font_size", 34)
	_first_cat_button.pressed.connect(_make_first_cat)
	panel.add_child(_first_cat_button)

	_status = Fx.ink_label("", 22, Fx.INK)
	_status.position = Vector2(30, 322)
	_status.size = Vector2(1000, 70)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_status)

	var server_hint := Fx.ink_label(SERVER_HINT, 18, Fx.INK)
	server_hint.position = Vector2(30, 408)
	server_hint.size = Vector2(320, 26)
	panel.add_child(server_hint)

	_server_input = LineEdit.new()
	_server_input.position = Vector2(30, 434)
	_server_input.size = Vector2(440, 44)
	_server_input.text = Net.server_url
	_server_input.add_theme_font_size_override("font_size", 18)
	_server_input.add_theme_color_override("font_color", Fx.INK)
	_server_input.add_theme_color_override("caret_color", Fx.INK)
	panel.add_child(_server_input)

	var apply := _make_button("Apply", Color("e7c6ff"), Vector2(482, 432), Vector2(110, 46))
	apply.add_theme_font_size_override("font_size", 20)
	apply.pressed.connect(_apply_server)
	panel.add_child(apply)

	_parent_toggle = _make_button("Parent", Color("e7c6ff"), Vector2(610, 432), Vector2(130, 46))
	_parent_toggle.add_theme_font_size_override("font_size", 20)
	_parent_toggle.pressed.connect(_toggle_parent)
	panel.add_child(_parent_toggle)

	_parent_panel = Panel.new()
	_parent_panel.position = Vector2(610, 340)
	_parent_panel.size = Vector2(420, 80)
	_parent_panel.visible = false
	_parent_panel.add_theme_stylebox_override("panel", Fx.cute_panel(20))
	panel.add_child(_parent_panel)

	var parent_hint := Fx.ink_label(PARENT_HINT, 16, Fx.INK)
	parent_hint.position = Vector2(12, 10)
	parent_hint.size = Vector2(396, 22)
	_parent_panel.add_child(parent_hint)

	_parent_input = LineEdit.new()
	_parent_input.position = Vector2(12, 34)
	_parent_input.size = Vector2(296, 38)
	_parent_input.placeholder_text = "Key"
	_parent_input.secret = true
	_parent_input.add_theme_font_size_override("font_size", 16)
	_parent_input.add_theme_color_override("font_color", Fx.INK)
	_parent_input.add_theme_color_override("caret_color", Fx.INK)
	if Net.has_method("get") and "create_key" in Net:
		_parent_input.text = Net.create_key
	_parent_panel.add_child(_parent_input)

	var parent_apply := _make_button("Save", Color("7ad67a"), Vector2(318, 34), Vector2(90, 38))
	parent_apply.add_theme_font_size_override("font_size", 18)
	parent_apply.pressed.connect(_apply_parent_key)
	_parent_panel.add_child(parent_apply)

	ui.add_child(Fx.centered_label("ESC = back to the title screen", 22, Color("fff6ec"), 656))

	Net.room_created.connect(_on_room_created)
	Net.room_error.connect(_on_room_error)
	Net.connected_to_room.connect(_on_connected)
	Net.disconnected_from_room.connect(_on_disconnected)

	if GameState.slot >= 0 and GameState.slot < GameState.SAVE_SLOTS \
			and not GameState.describe_slot(GameState.slot).is_empty():
		_select_slot(GameState.slot)
	else:
		for i in GameState.SAVE_SLOTS:
			if not GameState.describe_slot(i).is_empty():
				_select_slot(i)
				break
	if _selected_slot < 0:
		_set_status("You need a cat before you can play online — it only takes a minute!")
	_refresh_slots()
	_refresh_buttons()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if Input.is_action_just_pressed("menu") and not Transition.is_busy():
		_go_back()


func _draw() -> void:
	Scenery.sky(self, Color("263a63"), Color("f2b3b5"))
	draw_circle(Vector2(1070, 120), 54, Color(1, 0.97, 0.8, 0.9))
	for i in 9:
		Scenery.pine(self, Vector2(i * 170 - 40, 560), 1.5 + (i % 3) * 0.2, Color("315844"))
	draw_colored_polygon(Fx.ellipse_points(Vector2(640, 760), Vector2(900, 220)), Color("4f8a5a"))
	for x in [90, 1190]:
		Scenery.bush(self, Vector2(x, 700), 1.8, Color("62a554"), true)


# --- Choosing a cat --------------------------------------------------------------------------

func _select_slot(i: int) -> void:
	if _busy:
		return
	var info := GameState.describe_slot(i)
	if info.is_empty():
		_set_status("Slot %d is empty. Press 'Make your first cat!' and come back!" % (i + 1))
		return
	if not GameState.load_game(i):
		_set_status("That save could not be opened. Try another slot.")
		return
	_selected_slot = i
	_set_status("Playing as %s. Make a room, or type a friend's room code." % info.name)
	_refresh_slots()
	_refresh_buttons()


func _refresh_slots() -> void:
	for i in _slot_buttons.size():
		var info := GameState.describe_slot(i)
		var picked := i == _selected_slot
		if info.is_empty():
			_slot_buttons[i].text = "Slot %d\nEmpty" % (i + 1)
		else:
			_slot_buttons[i].text = "Slot %d\n%s" % [i + 1, info.name]
		_slot_buttons[i].add_theme_stylebox_override("normal", Fx.panel_style(
				Color("fff0f5") if picked else Color("f3e6ea"),
				Fx.PINK_DARK if picked else Color.WHITE, 18, 6 if picked else 3))
		_slot_buttons[i].add_theme_color_override("font_color", Fx.INK)
	_refresh_flow()


func _refresh_buttons() -> void:
	var ready := _selected_slot >= 0 and not _busy
	_create_button.disabled = not ready
	_join_button.disabled = not ready
	_first_cat_button.disabled = _busy


## With no saved cat at all, the room buttons cannot work: offer the story's cat maker instead.
func _refresh_flow() -> void:
	var has_cat := _has_any_cat()
	_first_cat_button.visible = not has_cat
	_create_button.visible = has_cat
	_join_button.visible = has_cat
	_room_input.visible = has_cat
	_join_hint.visible = has_cat
	_step2_label.text = "2. Make a room, or join one" if has_cat else "2. Make your first cat!"


func _has_any_cat() -> bool:
	for i in GameState.SAVE_SLOTS:
		if not GameState.describe_slot(i).is_empty():
			return true
	return false


## The story's usual cat maker (name, looks, paint) is the only way to make a cat.
## We go there, and `GameState.return_to_online` brings us back here when it is done.
func _make_first_cat() -> void:
	if _busy:
		return
	GameState.return_to_online = true
	Sfx.play("select")
	Transition.go("res://scenes/slots.tscn")


# --- Making and joining rooms ----------------------------------------------------------------

func _create_room() -> void:
	if _busy or _selected_slot < 0:
		return
	_busy = true
	_refresh_buttons()
	_set_status("Making a room...")
	var info := GameState.describe_slot(_selected_slot)
	GameState.load_game(_selected_slot)
	await Net.create_room(Net.cat_payload(info), str(info.get("name", "Cat")))


func _join_room() -> void:
	if _busy or _selected_slot < 0:
		return
	var code := _room_input.text.strip_edges().to_upper()
	if code.length() < 4:
		_set_status("Type the room code your friend gave you (4 letters).")
		return
	_busy = true
	_refresh_buttons()
	_set_status("Finding room %s..." % code)
	var info := GameState.describe_slot(_selected_slot)
	GameState.load_game(_selected_slot)
	await Net.join_room(code, Net.cat_payload(info), str(info.get("name", "Cat")))


func _on_room_created(code: String) -> void:
	_set_status("Room %s! Connecting..." % code)


func _on_connected(code: String) -> void:
	_set_status("Connected to room %s! Starting..." % code)
	_launching = true
	await get_tree().create_timer(0.7).timeout
	if Net.in_room:
		Transition.go("res://scenes/online_world.tscn")


func _on_room_error(message: String) -> void:
	_busy = false
	_launching = false
	_set_status(message)
	_refresh_buttons()


func _on_disconnected() -> void:
	if _launching:
		return
	_busy = false
	_set_status("The room connection ended. Try again!")
	_refresh_buttons()


func _go_back() -> void:
	if Net.in_room or Net.connecting:
		Net.leave_room()
	Transition.go("res://scenes/title.tscn")


func _exit_tree() -> void:
	if not _launching:
		Net.leave_room()


func _apply_server() -> void:
	Net.set_server_url(_server_input.text)
	_server_input.text = Net.server_url
	_set_status("Server set to %s" % Net.server_url)


func _toggle_parent() -> void:
	_parent_open = not _parent_open
	if _parent_panel != null:
		_parent_panel.visible = _parent_open


func _apply_parent_key() -> void:
	if Net.has_method("set_create_key"):
		Net.set_create_key(_parent_input.text)
	_set_status("Parent key saved." if _parent_input.text.strip_edges() != "" else "Parent key cleared.")


func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text


# --- Little UI helpers -----------------------------------------------------------------------

func _make_button(text: String, color: Color, pos: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = button_size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 26)
	button.add_theme_color_override("font_color", Fx.INK)
	button.add_theme_color_override("font_hover_color", Fx.INK)
	button.add_theme_color_override("font_pressed_color", Fx.INK)
	for state in ["normal", "hover", "pressed"]:
		var shade := color.lightened(0.15) if state == "hover" else color
		button.add_theme_stylebox_override(state, Fx.panel_style(shade, Color.WHITE, 18, 4))
	return button
