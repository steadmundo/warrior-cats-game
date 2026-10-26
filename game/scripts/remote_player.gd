class_name RemotePlayer
extends Node2D
## Another player's cat in the shared online camp. It follows the positions the room
## server relays, smoothing between updates so it still walks nicely at 15 updates a second.

const POUNCE_TIME := 0.34
const NAME_COLORS := [Color("ff9ec0"), Color("9be3ff"), Color("c9f7a8"), Color("e7c6ff")]

var cat: Cat
var info: Dictionary = {}
var target_pos := Vector2.ZERO
var target_facing := 1.0
var name_color := Color("ff9ec0")

var _pounce_left := 0.0
var _name_label: Label


func setup(player: Dictionary, color := Color("ff9ec0")) -> RemotePlayer:
	info = player
	name_color = color
	target_pos = position
	return self


func _ready() -> void:
	var cat_data: Dictionary = info.get("catData", {})
	cat = Cat.new()
	cat.set_look({
		"fur": _color(cat_data.get("fur"), Color("e8862a")),
		"markings": _color(cat_data.get("markings"), Color("4a2c18")),
		"pattern": str(cat_data.get("pattern", "Solid")),
		"eyes": _color(cat_data.get("eyes"), Color("5fd14a")),
		"fluffy": bool(cat_data.get("fluffy", false)),
		"mood": str(cat_data.get("mood", "happy")),
	})
	cat.size = float(cat_data.get("size", 1.0))
	cat.collar = bool(cat_data.get("collar", false))
	cat.paint = _paint(cat_data.get("paint", []))
	cat.facing = target_facing
	add_child(cat)

	_name_label = Fx.make_label(str(info.get("name", cat_data.get("name", "Cat"))), 20, name_color, 6)
	_name_label.size = Vector2(300, 34)
	_name_label.position = Vector2(-150, -112 * cat.size - 32)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_name_label)


## New position/facing from the room server. Keeps the cat's look from when they joined.
func set_state(player: Dictionary) -> void:
	for key in player:
		info[key] = player[key]
	var cat_data: Dictionary = info.get("catData", {})
	if _name_label != null:
		_name_label.text = str(info.get("name", cat_data.get("name", "Cat")))
	if player.has("pos") and player.pos is Dictionary:
		target_pos = Vector2(float(player.pos.get("x", target_pos.x)), float(player.pos.get("y", target_pos.y)))
	if player.has("facing"):
		target_facing = -1.0 if float(player.facing) < 0.0 else 1.0
	if bool(player.get("pouncing", false)) and _pounce_left <= 0.0:
		_pounce_left = POUNCE_TIME


func say(text: String) -> void:
	for child in get_children():
		if child is PanelContainer:
			child.queue_free()
	Fx.speech(self, text, 112 * (cat.size if cat != null else 1.0) + 30, 3.0)


func _process(delta: float) -> void:
	if cat == null:
		return

	var distance := position.distance_to(target_pos)
	if distance > 500.0:
		position = target_pos  # after a lag spike, don't glide across the whole map
	else:
		position = position.lerp(target_pos, minf(1.0, delta * 11.0))

	var moving := distance > 3.0
	cat.walk_amount = move_toward(cat.walk_amount, 1.0 if moving else 0.0, delta * 6.0)
	if absf(target_facing) > 0.1:
		cat.facing = target_facing

	if _pounce_left > 0.0:
		_pounce_left -= delta
		cat.lift = sin((1.0 - _pounce_left / POUNCE_TIME) * PI) * 55.0
		if _pounce_left <= 0.0:
			cat.lift = 0.0
	else:
		cat.lift = move_toward(cat.lift, 0.0, delta * 200.0)


static func _color(value, fallback: Color) -> Color:
	if value is Color:
		return value
	if value is String:
		return Color.from_string(value, fallback)
	return fallback


static func _paint(value) -> Array:
	var dabs := []
	if not value is Array:
		return dabs
	for dab in value:
		if not dab is Array or dab.size() < 4:
			continue
		dabs.append([
			Vector2(float(dab[0]), float(dab[1])),
			_color(dab[2], Color("ff5d73")),
			float(dab[3]),
		])
	return dabs
