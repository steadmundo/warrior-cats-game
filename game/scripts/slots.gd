extends Node2D
## Pick a save slot: keep playing a saved cat, or start a new one.
## LEFT/RIGHT = pick a slot, UP/DOWN = Play or Erase, SPACE = do it. Mouse works too.

var _selected := 0
var _on_erase := false  # is the Erase button picked (instead of Play)?
var _confirm_erase := -1  # slot that asked "are you sure?"
var _cards: Array[Panel] = []
var _play_buttons: Array[Button] = []
var _erase_buttons: Array[Button] = []
var _infos: Array[Dictionary] = []
var _ui: CanvasLayer
var _time := 0.0


func _ready() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	_ui.add_child(Fx.centered_label("Choose a Save Slot", 52, Color("ffd966"), 20))
	_ui.add_child(Fx.centered_label("LEFT/RIGHT = pick    UP/DOWN = Play or Erase    SPACE = go!", 22,
			Color("fff6ec"), 660))
	_ui.add_child(Fx.centered_label("ESC = back to title", 22, Color("fff6ec"), 696))
	var sound := SoundButton.new()
	sound.position = SoundButton.CORNER
	_ui.add_child(sound)
	_build()


func _build() -> void:
	for card in _cards:
		card.queue_free()
	_cards.clear()
	_play_buttons.clear()
	_erase_buttons.clear()
	_infos.clear()
	for i in GameState.SAVE_SLOTS:
		var info := GameState.describe_slot(i)
		_infos.append(info)
		var card := Panel.new()
		card.position = Vector2(60 + i * 400, 110)
		card.size = Vector2(360, 550)
		_ui.add_child(card)
		_cards.append(card)
		var title := Fx.centered_label("Slot %d" % (i + 1), 30, Fx.PINK_DARK, 14, 360)
		title.add_theme_constant_override("outline_size", 0)
		card.add_child(title)
		if info.is_empty():
			var plus := Fx.centered_label("+", 140, Fx.PINK, 90, 360)
			plus.add_theme_constant_override("outline_size", 0)
			card.add_child(plus)
			var empty := Fx.centered_label("Empty", 30, Fx.INK, 300, 360)
			empty.add_theme_constant_override("outline_size", 0)
			card.add_child(empty)
		else:
			var holder := Node2D.new()
			holder.position = Vector2(180, 290)
			card.add_child(holder)
			var cat := Cat.new()
			cat.set_look(info.look)
			cat.paint = info.paint
			cat.collar = info.kittypet
			cat.size = 1.8
			holder.add_child(cat)
			var name_label := Fx.centered_label(info.name, 34, Fx.INK, 300, 360)
			name_label.add_theme_constant_override("outline_size", 0)
			card.add_child(name_label)
			var progress := Fx.ink_label(info.progress, 22)
			progress.position = Vector2(20, 350)
			progress.size = Vector2(320, 60)
			progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			progress.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			card.add_child(progress)
		var play := _make_button("New Cat!" if info.is_empty() else "Play", Color("7ad67a"), Vector2(30, 420))
		play.pressed.connect(func():
			_selected = i
			_on_erase = false
			_go())
		card.add_child(play)
		_play_buttons.append(play)
		var erase := _make_button("Erase", Color("ffb3a7"), Vector2(30, 484))
		erase.visible = not info.is_empty()
		erase.size.y = 48
		erase.pressed.connect(func():
			_selected = i
			_on_erase = true
			_go())
		card.add_child(erase)
		_erase_buttons.append(erase)
	_show_friends()
	_refresh()


## Under each slot's title: the cats from other slots it is friends with
func _show_friends() -> void:
	for i in _cards.size():
		if _infos[i].is_empty():
			continue
		var names := []
		for f in GameState.friends_of(i):
			if f < _infos.size() and not _infos[f].is_empty():
				names.append(_infos[f].name)
		if names.is_empty():
			continue
		var label := Fx.ink_label("Friends: " + ", ".join(names), 20, Fx.PINK_DARK)
		label.position = Vector2(14, 56)
		label.size = Vector2(332, 30)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_cards[i].add_child(label)


func _make_button(text: String, color: Color, pos: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(300, 56)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_color_override("font_color", Fx.INK)
	b.add_theme_color_override("font_hover_color", Fx.INK)
	for state in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(state, Fx.panel_style(color.lightened(0.15) if state == "hover" else color,
				Color.WHITE, 18, 4))
	return b


func _refresh() -> void:
	for i in _cards.size():
		var picked := i == _selected
		_cards[i].add_theme_stylebox_override("panel", Fx.panel_style(Color("fff0f5") if picked else Fx.CREAM,
				Fx.PINK_DARK if picked else Fx.PINK, 26, 8 if picked else 4))
		var erase_picked := picked and _on_erase
		_erase_buttons[i].text = "Sure? Press again!" if _confirm_erase == i else "Erase"
		_play_buttons[i].add_theme_stylebox_override("normal", Fx.panel_style(Color("7ad67a"),
				Fx.PINK_DARK if picked and not _on_erase else Color.WHITE, 18, 6 if picked and not _on_erase else 4))
		_erase_buttons[i].add_theme_stylebox_override("normal", Fx.panel_style(Color("ffb3a7"),
				Fx.PINK_DARK if erase_picked else Color.WHITE, 18, 6 if erase_picked else 4))


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if Transition.is_busy():
		return
	if Input.is_action_just_pressed("menu"):
		Sfx.play("click")
		Transition.go("res://scenes/title.tscn")
		return
	var has_save := not _infos[_selected].is_empty()
	if Input.is_action_just_pressed("move_right") or Input.is_action_just_pressed("move_left"):
		var dir := 1 if Input.is_action_just_pressed("move_right") else -1
		_selected = wrapi(_selected + dir, 0, GameState.SAVE_SLOTS)
		_on_erase = false
		_confirm_erase = -1
		Sfx.play("click")
		_refresh()
	elif Input.is_action_just_pressed("move_down") or Input.is_action_just_pressed("move_up"):
		_on_erase = has_save and Input.is_action_just_pressed("move_down")
		_confirm_erase = -1
		Sfx.play("click")
		_refresh()
	elif Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("action"):
		_go()


func _go() -> void:
	if _on_erase:
		if _confirm_erase == _selected:
			GameState.erase_slot(_selected)
			Sfx.play("hurt")
			_confirm_erase = -1
			_on_erase = false
			_build()
		else:
			_confirm_erase = _selected
			Sfx.play("click", 0.7)
			_refresh()
		return
	Sfx.play("win")
	if GameState.load_game(_selected):
		GameState.continue_game()
	else:
		GameState.forget_friends(_selected)  # a brand new cat starts with no friends yet
		GameState.new_game(_selected)
		Transition.go("res://scenes/creator.tscn")


func _draw() -> void:
	Scenery.sky(self, Color("2a2160"), Color("c47aa8"))
	for k in 40:
		var p := Vector2(fmod(k * 137.0, 1280.0), fmod(k * 71.0, 400.0))
		draw_circle(p, 1.5 + sin(_time * 2.0 + k) * 0.8, Color(1, 1, 0.9, 0.8))
	draw_rect(Rect2(0, 640, 1280, 80), Color("4f8a5a"))
