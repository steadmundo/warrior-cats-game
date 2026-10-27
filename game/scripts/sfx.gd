extends Node
## Plays sound effects from the sound library: Sfx.play("collect")
## Press M (or the pause menu button) to mute everything; the choice is remembered.

const NAMES := ["jump", "land", "collect", "hurt", "enemy_bonk", "win", "lose", "click", "select", "powerup"]
const SETTINGS_PATH := "user://settings.cfg"

signal mute_changed(muted: bool)

var muted := false

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	for n in NAMES:
		var path := "res://assets/sounds/%s.wav" % n
		if ResourceLoader.exists(path):
			_sounds[n] = load(path)
	for i in 8:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_load_muted()


## Turns all sound on or off, and remembers the choice for next time.
func set_muted(value: bool) -> void:
	muted = value
	if muted:
		for player in _players:
			player.stop()
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)  # a missing file is fine: defaults are used
	config.set_value("audio", "muted", muted)
	config.save(SETTINGS_PATH)
	mute_changed.emit(muted)


func toggle_muted() -> bool:
	set_muted(not muted)
	return muted


func _load_muted() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	muted = bool(config.get_value("audio", "muted", false))


func play(sound: String, pitch := 1.0, volume_db := 0.0) -> void:
	if muted or not _sounds.has(sound):
		return
	for player in _players:
		if not player.playing:
			player.stream = _sounds[sound]
			player.pitch_scale = pitch
			player.volume_db = volume_db
			player.play()
			return
