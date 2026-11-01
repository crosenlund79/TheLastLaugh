extends Node
## Global run state, population tracking, settings and input map.

signal thought(text: String)
signal speech(text: String)
signal radio(speaker: String, text: String)

const SETTINGS_PATH := "user://settings.cfg"

# --- settings ---
var master_volume := 0.8
var music_volume := 0.6
var sfx_volume := 0.9
var mouse_sensitivity := 1.0

# --- run state ---
var people: Array = []        # every Person in the carnival
var players: Array = []       # player nodes (single player for now, co-op later)
var fog_banks: Array = []
var light_points: Array = []  # Vector3 positions of bright lights (stealth)
var safehouses := {}          # profession -> {door, slots, inside_center}
var dread := 0.0              # 0 = cheerful carnival, 1 = full nightmare
var radio_log: Array = []
var corruptibles: Array = []      # corruptible.gd components placed on attractions/props
var corrupted_cells := {}         # Vector2i -> true: ground the fog has permanently tainted
var run_time := 0.0
var running := false
var flags := {}
var innocents_killed := 0
var escaped := false
var smg_acquired := false
var worker_rescued := false
var _thought_ids := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	load_settings()


func _process(delta: float) -> void:
	if running and not get_tree().paused:
		run_time += delta


func reset_run() -> void:
	people.clear()
	players.clear()
	fog_banks.clear()
	light_points.clear()
	safehouses = {}
	dread = 0.0
	radio_log.clear()
	corruptibles.clear()
	corrupted_cells = {}
	run_time = 0.0
	running = true
	flags = {}
	innocents_killed = 0
	escaped = false
	smg_acquired = false
	worker_rescued = false
	_thought_ids = {}


# ---------------------------------------------------------------- population
func register_person(p) -> void:
	people.append(p)


## Every person is in exactly one bucket: rescued + affected + inside (alive, unaffected)
## + casualties (unaffected and dead) == total. Fog-affected does not mean dead.
func get_stats() -> Dictionary:
	var total := 0
	var affected := 0
	var rescued := 0
	var casualties := 0
	var inside := 0
	var workers_rescued := 0
	for p in people:
		if not is_instance_valid(p):
			continue
		total += 1
		if p.rescued:
			rescued += 1
			if p.role == "worker":
				workers_rescued += 1
		elif p.fog_affected:
			affected += 1
		elif p.dead:
			casualties += 1
		else:
			inside += 1
	return {
		"total": total, "affected": affected, "rescued": rescued,
		"casualties": casualties, "trapped": inside, "remaining": inside,
		"innocents_killed": innocents_killed, "workers_rescued": workers_rescued,
	}


func nearest_player(pos: Vector3):
	var best = null
	var bd := INF
	for pl in players:
		if is_instance_valid(pl) and not pl.dead:
			var d: float = pl.global_position.distance_squared_to(pos)
			if d < bd:
				bd = d
				best = pl
	return best


## A loud event (gunshot etc). Frightens humans, alerts hostiles. Never transforms.
func noise_event(pos: Vector3, radius: float, source = null) -> void:
	for p in people:
		if is_instance_valid(p) and not p.dead:
			if p.global_position.distance_to(pos) < radius:
				p.hear_noise(pos, source)


## Staff radio chatter, heard everywhere (HUD + static).
func radio_call(speaker: String, text: String) -> void:
	radio_log.append([speaker, text])
	radio.emit(speaker, text)


## Every staff member of a profession who is still human heads for their safe house.
func order_retreat(profession: String) -> void:
	for p in people:
		if is_instance_valid(p) and p.role == profession:
			p.start_retreat()


func think(text: String, id: String = "") -> void:
	if id != "":
		if _thought_ids.has(id):
			return
		_thought_ids[id] = true
	thought.emit(text)


func compute_score() -> Dictionary:
	var s := get_stats()
	var t := run_time
	var lines := []
	var total := 0
	if escaped:
		lines.append(["Escaped the carnival", 1000]); total += 1000
		var tb := int(clampf(600.0 - t * 0.75, 0.0, 600.0))
		lines.append(["Time bonus", tb]); total += tb
	else:
		lines.append(["Did not escape", 0])
	var rescue_pts: int = s.rescued * 400
	lines.append(["People rescued (%d x 400)" % s.rescued, rescue_pts]); total += rescue_pts
	if s.workers_rescued > 0:
		lines.append(["Maintenance workers rescued (%d x 300)" % s.workers_rescued, s.workers_rescued * 300]); total += s.workers_rescued * 300
	if escaped and not smg_acquired:
		lines.append(["Escaped without taking an SMG", 300]); total += 300
	elif smg_acquired:
		lines.append(["Took a guard's SMG", 0])
	if innocents_killed > 0:
		var pen := -500 * innocents_killed
		lines.append(["Innocent people killed (%d x -500)" % innocents_killed, pen]); total += pen
	return {"lines": lines, "total": total, "stats": s, "time": t}


# ---------------------------------------------------------------- settings
func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		master_volume = cfg.get_value("audio", "master", master_volume)
		music_volume = cfg.get_value("audio", "music", music_volume)
		sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
		mouse_sensitivity = cfg.get_value("input", "sensitivity", mouse_sensitivity)
	apply_audio()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("input", "sensitivity", mouse_sensitivity)
	cfg.save(SETTINGS_PATH)
	apply_audio()


func apply_audio() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(music_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(sfx_volume, 0.0001)))


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")


# ---------------------------------------------------------------- input
func _setup_input() -> void:
	_key("move_forward", [KEY_W, KEY_UP])
	_key("move_back", [KEY_S, KEY_DOWN])
	_key("move_left", [KEY_A, KEY_LEFT])
	_key("move_right", [KEY_D, KEY_RIGHT])
	_key("jump", [KEY_SPACE])
	_key("sprint", [KEY_SHIFT])
	_key("crouch", [KEY_CTRL, KEY_C])
	_key("interact", [KEY_E])
	_key("reload", [KEY_R])
	_key("weapon_1", [KEY_1])
	_key("weapon_2", [KEY_2])
	_key("weapon_3", [KEY_3])
	_key("pause", [KEY_ESCAPE, KEY_P])
	_mouse("fire", MOUSE_BUTTON_LEFT)
	_mouse("weapon_next", MOUSE_BUTTON_WHEEL_UP)
	_mouse("weapon_prev", MOUSE_BUTTON_WHEEL_DOWN)


func _key(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _mouse(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
