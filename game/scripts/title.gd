extends Node2D
## Title screen: a starry forest night, the game's name, and the controls.

var _start_label: Label
var _stars: Array = []
var _time := 0.0


func _ready() -> void:
	seed(7)
	for i in 70:
		_stars.append(Vector3(randf() * 1280, randf() * 380, randf() * TAU))
	randomize()

	var cats := [["Graypaw", Vector2(400, 655), 1.0, 1.6], ["Bluestar", Vector2(880, 655), -1.0, 1.6]]
	for data in cats:
		var cat := Cat.new()
		cat.set_look(GameState.CATS[data[0]])
		cat.position = data[1]
		cat.facing = data[2]
		cat.size = data[3]
		add_child(cat)
	var kittypet := Cat.new()
	kittypet.set_look({"fur": Color("f29a45"), "markings": Color("c8642a"), "pattern": "Tabby Stripes",
			"eyes": Color("5fd14a")})
	kittypet.collar = true
	kittypet.size = 1.1
	kittypet.position = Vector2(630, 450)
	add_child(kittypet)

	Scenery.fireflies(self, Rect2(0, 250, 1280, 400))

	var ui := CanvasLayer.new()
	add_child(ui)
	ui.add_child(Fx.centered_label("WARRIOR CATS", 96, Color("ffd966"), 46))
	ui.add_child(Fx.centered_label("Into the Wild", 44, Color("fff6ec"), 164))
	
	var panel := Panel.new()
	panel.position = Vector2(260, 250)
	panel.size = Vector2(760, 350)
	var style := Fx.cute_panel(30)
	style.bg_color = Color(1.0, 0.96, 0.93, 0.72)
	style.shadow_color = Color(0.3, 0.1, 0.2, 0.16)
	panel.add_theme_stylebox_override("panel", style)
	ui.add_child(panel)
	
	panel.add_child(Fx.centered_label("Choose how to play!", 44, Color("ffd966"), 28, 760))
	
	var paw1 := Label.new()
	paw1.text = "🐾"
	paw1.position = Vector2(90, 118)
	paw1.add_theme_font_size_override("font_size", 48)
	panel.add_child(paw1)
	var solo := Fx.centered_label("SPACE = Play Solo", 46, Color("9be37a"), 118, 580)
	solo.position.x = 170
	panel.add_child(solo)
	
	var paw2 := Label.new()
	paw2.text = "🐾"
	paw2.position = Vector2(90, 198)
	paw2.add_theme_font_size_override("font_size", 48)
	panel.add_child(paw2)
	var local := Fx.centered_label("E = Play Together on this computer", 44, Color("ffb3c8"), 198, 580)
	local.position.x = 170
	panel.add_child(local)
	
	var paw3 := Label.new()
	paw3.text = "🐾"
	paw3.position = Vector2(90, 278)
	paw3.add_theme_font_size_override("font_size", 48)
	panel.add_child(paw3)
	var online := Fx.centered_label("O = Play Together Online", 44, Color("9be3ff"), 278, 580)
	online.position.x = 170
	panel.add_child(online)
	
	var sound := SoundButton.new()
	sound.position = SoundButton.CORNER
	ui.add_child(sound)
	var controls := Fx.centered_label("Arrows = walk and choose    SPACE = jump, pounce, talk, OK    ESC = menu", 26,
			Color("f6e8c8"), 660)
	ui.add_child(controls)


func _process(delta: float) -> void:
	_time += delta
	if _start_label != null:
		_start_label.modulate.a = 0.55 + 0.45 * sin(_time * 4.0)
	queue_redraw()
	if Transition.is_busy():
		return
	if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("action"):
		Sfx.play("select")
		Transition.go("res://scenes/slots.tscn")
	elif Input.is_action_just_pressed("p2_pounce"):
		# Player 2 joins in! Both players pick their cats next.
		Sfx.play("powerup")
		Transition.go("res://scenes/together_pick.tscn")
	elif Input.is_action_just_pressed("online"):
		Sfx.play("select")
		Transition.go("res://scenes/online_lobby.tscn")


func _draw() -> void:
	Scenery.sky(self, Color("2a2160"), Color("c47aa8"))
	for s in _stars:
		var twinkle := 0.5 + 0.5 * sin(_time * 2.0 + s.z)
		draw_circle(Vector2(s.x, s.y), 1.5 + twinkle, Color(1, 1, 0.9, 0.4 + 0.6 * twinkle))
	draw_circle(Vector2(1090, 110), 58, Color(1, 0.97, 0.8, 0.15))
	draw_circle(Vector2(1090, 110), 46, Color("fff6d5"))
	for i in 12:
		Scenery.pine(self, Vector2(i * 120 - 20, 520), 1.4 + (i % 3) * 0.2, Color("3a3470"))
	draw_colored_polygon(Fx.ellipse_points(Vector2(640, 760), Vector2(900, 230)), Color("4f8a5a"))
	Scenery.rock(self, Vector2(640, 610), 3.6, Color("a7a3b5"))
	for x in [120, 240, 1040, 1180]:
		Scenery.bush(self, Vector2(x, 720), 1.4, Color("62a554"), true)
