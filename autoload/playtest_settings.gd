extends Node
signal changed
const PATH := "user://playtest_settings.cfg"
var sensitivity := 0.1
var master := 1.0
var music := 1.0
var sfx := 1.0
var fullscreen := false
var focus_mode := "toggle"

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		sensitivity = clampf(float(config.get_value("settings", "sensitivity", 0.1)), 0.01, 0.5)
		master = clampf(float(config.get_value("settings", "master", 1.0)), 0, 1)
		music = clampf(float(config.get_value("settings", "music", 1.0)), 0, 1)
		sfx = clampf(float(config.get_value("settings", "sfx", 1.0)), 0, 1)
		fullscreen = bool(config.get_value("settings", "fullscreen", false))
		focus_mode = "hold" if config.get_value("settings", "focus_mode", "toggle") == "hold" else "toggle"
	apply()

func update(key: String, value: Variant) -> void:
	set(key, value)
	apply()
	var config := ConfigFile.new()
	for setting in ["sensitivity", "master", "music", "sfx", "fullscreen", "focus_mode"]:
		config.set_value("settings", setting, get(setting))
	var error := config.save(PATH)
	if error != OK: push_warning("Could not save playtest settings: %s" % error)
	changed.emit()

func apply() -> void:
	for pair in [["Master", master], ["Music", music], ["SFX", sfx]]:
		var index := AudioServer.get_bus_index(pair[0])
		if index >= 0:
			AudioServer.set_bus_volume_db(index, linear_to_db(maxf(pair[1], 0.0001)))
			AudioServer.set_bus_mute(index, pair[1] <= 0.0)
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode: DisplayServer.window_set_mode(mode)
