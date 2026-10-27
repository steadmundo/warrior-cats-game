extends CanvasLayer
## Press ESC any time to pause: keep playing, mute the sound, or go back to the title screen.
## M mutes the sound in any scene, even without opening this menu.
## The game saves by itself after every chapter, so going back is safe.

const NO_MENU_SCENES := ["res://scenes/title.tscn", "res://scenes/slots.tscn"]

var _panel: Panel
var _buttons: Array[Button] = []
var _choice := 0


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	Sfx.process_mode = Node.PROCESS_MODE_ALWAYS  # so the menu can still go "click"
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.size = Vector2(1280, 720)
	add_child(dim)
	_panel = Panel.new()
	_panel.position = Vector2(390, 160)
	_panel.size = Vector2(500, 400)
	_panel.add_theme_stylebox_override("panel", Fx.cute_panel(30))
	dim.add_child(_panel)
	var title := Fx.centered_label("Paused", 50, Fx.PINK_DARK, 24, 500)
	title.add_theme_constant_override("outline_size", 0)
	_panel.add_child(title)
	for i in 2:
		var b := Button.new()
		b.text = ["Keep playing", "Back to title screen"][i]
		b.focus_mode = Control.FOCUS_NONE
		b.position = Vector2(70, 100 + i * 86)
		b.size = Vector2(360, 66)
		b.add_theme_font_size_override("font_size", 30)
		b.add_theme_color_override("font_color", Fx.INK)
		b.add_theme_color_override("font_hover_color", Fx.INK)
		b.pressed.connect(func():
			_choice = i
			_pick())
		_panel.add_child(b)
		_buttons.append(b)
	# Sound sits apart, below the two choices, so it never gets picked by accident
	var sound := SoundButton.new()
	sound.position = Vector2(70, 276)
	sound.size = Vector2(360, 56)
	sound.add_theme_font_size_override("font_size", 26)
	_panel.add_child(sound)
	var hint := Fx.centered_label("Press M any time to mute the sound", 20, Fx.INK, 342, 500)
	hint.add_theme_constant_override("outline_size", 0)
	_panel.add_child(hint)
	visible = false


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("mute"):
		# Works in every scene, even on the title screen, so a grown-up can hush it fast
		Sfx.toggle_muted()
		if not Sfx.muted:
			Sfx.play("select")
		return
	if Input.is_action_just_pressed("menu"):
		if visible:
			_close()
		elif _can_open():
			_open()
		return
	if not visible:
		return
	if Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("move_down"):
		var dir := -1 if Input.is_action_just_pressed("move_up") else 1
		_choice = wrapi(_choice + dir, 0, _buttons.size())
		Sfx.play("click")
		_refresh()
	elif Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("action"):
		_pick()


func _can_open() -> bool:
	for box in get_tree().get_nodes_in_group("typing"):
		if box.is_open():
			return false
	var scene := get_tree().current_scene
	return scene != null and not Transition.is_busy() and not scene.scene_file_path in NO_MENU_SCENES


func _open() -> void:
	_choice = 0
	_refresh()
	visible = true
	get_tree().paused = true
	Sfx.play("select")


func _close(to_title := false) -> void:
	visible = false
	# Unpause after this frame, so the key that closed the menu doesn't also do something in the game
	_unpause.call_deferred(to_title)


func _unpause(to_title: bool) -> void:
	get_tree().paused = false
	if to_title:
		Transition.go("res://scenes/title.tscn")


func _pick() -> void:
	Sfx.play("select")
	_close(_choice == 1)


func _refresh() -> void:
	for i in _buttons.size():
		var picked := i == _choice
		for state in ["normal", "hover", "pressed"]:
			_buttons[i].add_theme_stylebox_override(state, Fx.panel_style(Fx.PINK if picked else Color("f3e6ea"),
					Fx.PINK_DARK if picked else Color.WHITE, 18, 5 if picked else 3))
