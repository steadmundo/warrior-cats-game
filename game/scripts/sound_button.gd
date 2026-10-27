class_name SoundButton
extends Button
## A small "Sound: On / Off" button for the menu screens, so the game can be hushed before
## it starts. The M key does the same thing anywhere, and so does the button in the pause menu.

const SIZE := Vector2(150, 46)
const CORNER := Vector2(1114, 6)  # the top-right corner of the 1280x720 screen


func _init() -> void:
	focus_mode = Control.FOCUS_NONE  # the menus are arrow-key driven; this is for the mouse
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	size = SIZE
	add_theme_font_size_override("font_size", 22)
	add_theme_color_override("font_color", Fx.INK)
	add_theme_color_override("font_hover_color", Fx.INK)
	add_theme_color_override("font_pressed_color", Fx.INK)
	pressed.connect(_toggle)
	Sfx.mute_changed.connect(refresh)
	refresh()


func refresh(_muted := false) -> void:
	text = "Sound: Off" if Sfx.muted else "Sound: On"
	var colour := Color("ffc9c9") if Sfx.muted else Color("e7c6ff")
	for state in ["normal", "hover", "pressed"]:
		add_theme_stylebox_override(state, Fx.panel_style(
				colour.lightened(0.12) if state == "hover" else colour, Color.WHITE, 18, 4))


func _exit_tree() -> void:
	if Sfx.mute_changed.is_connected(refresh):
		Sfx.mute_changed.disconnect(refresh)


func _toggle() -> void:
	Sfx.toggle_muted()
	if not Sfx.muted:
		Sfx.play("select")  # a little chirp, so it is clear the sound is back
