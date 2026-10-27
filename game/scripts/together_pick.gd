extends Node2D
## Two players, one keyboard: each player picks a cat from the save slots.
## Player 1: LEFT/RIGHT to choose, SPACE = ready.  Player 2: A/D to choose, E = ready.
## UP/DOWN (or W/S) picks which game to play.

const SIDES := [
	{"keys": "p1", "title": "Player 1", "help": "LEFT / RIGHT = choose\nSPACE = I'm ready!", "x": 60.0},
	{"keys": "p2", "title": "Player 2", "help": "A / D = choose\nE = I'm ready!", "x": 680.0},
]

## The games two players can play: [name, scene]
const GAMES := [["Explore ThunderClan Together", "res://scenes/territory.tscn"],
		["Hunting Race", "res://scenes/together.tscn"]]

var _cats: Array = []
var _game := 0
var _game_label: Label
var _choice := [0, 1]
var _is_ready := [false, false]
var _cards: Array[Panel] = []
var _previews: Array[Cat] = []
var _names: Array[Label] = []
var _states: Array[Label] = []
var _time := 0.0
var _starting := false


func _ready() -> void:
	_cats = GameState.all_saved_cats()
	var ui := CanvasLayer.new()
	add_child(ui)
	ui.add_child(Fx.centered_label("Play Together!", 52, Color("ffd966"), 16))
	var sound := SoundButton.new()
	sound.position = SoundButton.CORNER
	ui.add_child(sound)
	if _cats.size() < 2:
		var sorry := Fx.centered_label("To play together you need TWO cats!\n\nMake another cat in an empty save slot first,\nthen come back and press E on the title screen.",
				32, Color("fff6ec"), 220)
		ui.add_child(sorry)
		ui.add_child(Fx.centered_label("Press SPACE to go back", 30, Color("9be37a"), 560))
		return
	for i in 2:
		var side: Dictionary = SIDES[i]
		var card := Panel.new()
		card.position = Vector2(side.x, 100)
		card.size = Vector2(540, 500)
		ui.add_child(card)
		_cards.append(card)
		var title := Fx.centered_label(side.title, 36, Fx.PINK_DARK, 14, 540)
		title.add_theme_constant_override("outline_size", 0)
		card.add_child(title)
		var holder := Node2D.new()
		holder.position = Vector2(270, 290)
		card.add_child(holder)
		var cat := Cat.new()
		cat.size = 2.0
		holder.add_child(cat)
		_previews.append(cat)
		var name_label := Fx.centered_label("", 38, Fx.INK, 302, 540)
		name_label.add_theme_constant_override("outline_size", 0)
		card.add_child(name_label)
		_names.append(name_label)
		var help := Fx.ink_label(side.help, 24)
		help.position = Vector2(0, 360)
		help.size = Vector2(540, 70)
		help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(help)
		var state := Fx.centered_label("", 34, Color("3f9e4a"), 438, 540)
		state.add_theme_constant_override("outline_size", 0)
		card.add_child(state)
		_states.append(state)
	_game_label = Fx.centered_label("", 34, Color("ffd966"), 612)
	ui.add_child(_game_label)
	ui.add_child(Fx.centered_label("UP/DOWN or W/S = pick a game.  Then BOTH press your ready key!", 24, Color("fff6ec"), 670))
	_refresh()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if Transition.is_busy() or _starting:
		return
	if _cats.size() < 2:
		if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("action"):
			Transition.go("res://scenes/title.tscn")
		return
	for i in 2:
		var keys: String = SIDES[i].keys
		if Input.is_action_just_pressed(keys + "_up") or Input.is_action_just_pressed(keys + "_down"):
			_game = wrapi(_game + 1, 0, GAMES.size())
			Sfx.play("select")
			_refresh()
		elif Input.is_action_just_pressed(keys + "_left"):
			_move(i, -1)
		elif Input.is_action_just_pressed(keys + "_right"):
			_move(i, 1)
		elif Input.is_action_just_pressed(keys + "_pounce"):
			_is_ready[i] = not _is_ready[i]
			Sfx.play("powerup" if _is_ready[i] else "click")
			_previews[i].bounce(0.4)
			if _is_ready[i]:
				Fx.hearts(self, _cards[i].position + Vector2(270, 240), 10)
			_refresh()
	if _is_ready[0] and _is_ready[1]:
		_start()


## Choose the next cat, skipping the one the other player has
func _move(i: int, dir: int) -> void:
	if _is_ready[i]:
		return
	var other: int = _choice[1 - i]
	var next: int = _choice[i]
	for tries in _cats.size():
		next = wrapi(next + dir, 0, _cats.size())
		if next != other:
			break
	_choice[i] = next
	Sfx.play("click")
	_previews[i].bounce(0.25)
	_refresh()


func _refresh() -> void:
	_game_label.text = "<  Game: %s  >" % GAMES[_game][0]
	for i in 2:
		var info: Dictionary = _cats[_choice[i]]
		_previews[i].set_look(info.look)
		_previews[i].paint = info.paint
		_previews[i].collar = info.kittypet
		_names[i].text = info.name
		_states[i].text = "READY!" if _is_ready[i] else ""
		_cards[i].add_theme_stylebox_override("panel", Fx.panel_style(Color("fff0f5") if _is_ready[i] else Fx.CREAM,
				Color("3f9e4a") if _is_ready[i] else Fx.PINK_DARK, 26, 8 if _is_ready[i] else 4))


func _start() -> void:
	_starting = true
	Sfx.play("win")
	GameState.together = [_cats[_choice[0]].slot, _cats[_choice[1]].slot]
	await get_tree().create_timer(0.6).timeout
	Transition.go(GAMES[_game][1])


func _draw() -> void:
	Scenery.sky(self, Color("2a2160"), Color("c47aa8"))
	for k in 40:
		var p := Vector2(fmod(k * 137.0, 1280.0), fmod(k * 71.0, 400.0))
		draw_circle(p, 1.5 + sin(_time * 2.0 + k) * 0.8, Color(1, 1, 0.9, 0.8))
	draw_rect(Rect2(0, 640, 1280, 80), Color("4f8a5a"))
