extends StaticBody3D
## Generic interactable: pickups, safe-house doors, exit gate. Behaviour chosen by `kind`.
## Doors and the gate live on physics layer 16 so the navmesh bake ignores them
## (paths go through doorways; the closed door still blocks bodies physically).

var kind := "pickup"          # pickup, safe_door, gate
var item := ""                # for pickups
var label_text := ""
var opened := false
var _visual: Node3D
var _t := 0.0
var door_pivots: Array = []
var _closed_rot: Array = []

# safe-house doors
var profession := ""          # "worker" (maintenance shed) or "guard" (security office)
var inside_dir := Vector3.RIGHT
var unlock_flag := ""
var _close_t := 0.0
var _player_hold := false
var _let_in_t := -1.0


func setup_pickup(item_kind: String) -> void:
	kind = "pickup"
	item = item_kind
	collision_layer = 8
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.5
	cs.shape = sh
	add_child(cs)
	_visual = Node3D.new()
	add_child(_visual)
	match item:
		"pistol":
			label_text = "Carnival Revolver"
			Build.box(_visual, Vector3(0.08, 0.14, 0.32), Vector3(0, 0, 0), Color(0.75, 0.6, 0.2), false)
			Build.box(_visual, Vector3(0.07, 0.2, 0.09), Vector3(0, -0.12, 0.12), Color(0.45, 0.2, 0.1), false)
		"shotgun":
			label_text = "Pump Shotgun"
			Build.box(_visual, Vector3(0.09, 0.1, 0.9), Vector3.ZERO, Color(0.25, 0.25, 0.28), false)
			Build.box(_visual, Vector3(0.1, 0.16, 0.35), Vector3(0, -0.04, 0.5), Color(0.5, 0.3, 0.15), false)
		"smg":
			label_text = "Security SMG"
			Build.box(_visual, Vector3(0.09, 0.14, 0.5), Vector3.ZERO, Color(0.1, 0.1, 0.12), false)
			Build.box(_visual, Vector3(0.06, 0.25, 0.08), Vector3(0, -0.17, -0.05), Color(0.15, 0.15, 0.18), false)
		"gate_key", "shed_key":
			label_text = "Main Gate Key" if item == "gate_key" else "Maintenance Shed Key"
			var c := Color(1.0, 0.85, 0.2) if item == "gate_key" else Color(0.7, 0.8, 0.9)
			Build.box(_visual, Vector3(0.05, 0.05, 0.3), Vector3.ZERO, c, false, 1.5)
			Build.cyl(_visual, 0.1, 0.1, 0.04, Vector3(0, 0, -0.18), c, false, 8, 1.5, Vector3(PI / 2, 0, 0))
			# tall beacon so a dropped key is never lost in the dark
			var beam := Build.cyl(_visual, 0.03, 0.03, 3.0, Vector3(0, 1.5, 0), Color(c.r, c.g, c.b, 0.25), false, 6)
			beam.set_meta("beacon", true)
		_:
			label_text = {"ammo_pistol": "Revolver Rounds", "ammo_shells": "Shotgun Shells", "ammo_smg": "SMG Magazine", "ammo": "Ammo"}.get(item, "Ammo")
			Build.box(_visual, Vector3(0.3, 0.18, 0.2), Vector3.ZERO, Color(0.3, 0.45, 0.2), false)
			Build.box(_visual, Vector3(0.31, 0.06, 0.21), Vector3(0, 0.03, 0), Color(0.9, 0.8, 0.2), false, 0.8)
	var glow := Build.omni(self, Vector3(0, 0.4, 0), Color(1, 0.9, 0.5), 0.6, 2.5)
	glow.shadow_enabled = false


func setup_safe_door(p_profession: String, p_inside_dir: Vector3) -> void:
	kind = "safe_door"
	profession = p_profession
	inside_dir = p_inside_dir.normalized()
	unlock_flag = "shed_unlocked" if profession == "worker" else "office_unlocked"
	collision_layer = 16
	collision_mask = 0


func _ensure_rot() -> void:
	if _closed_rot.size() != door_pivots.size():
		_closed_rot.clear()
		for p in door_pivots:
			_closed_rot.append(p.rotation.y)


func _process(delta: float) -> void:
	_t += delta
	if kind == "pickup" and _visual:
		_visual.rotation.y += delta * 1.5
		_visual.position.y = sin(_t * 2.0) * 0.06
	elif kind == "safe_door":
		_safe_tick(delta)


# ------------------------------------------------------------- safe-house door
func _staff_wants_through() -> bool:
	for p in GameState.people:
		if not is_instance_valid(p) or p.role != profession or p.hostile or p.dead or p.rescued or p.fog_affected:
			continue
		if p.global_position.distance_to(global_position) < 3.4 and p.wants_door():
			return true
	return false


func _anyone_in_doorway() -> bool:
	for p in GameState.people:
		if is_instance_valid(p) and not p.dead and p.visible and _flat_dist(p.global_position) < 1.1:
			return true
	for pl in GameState.players:
		if is_instance_valid(pl) and _flat_dist(pl.global_position) < 1.0:
			return true
	return false


func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func _hostile_near(r: float) -> bool:
	for p in GameState.people:
		if is_instance_valid(p) and p.hostile and not p.dead and _flat_dist(p.global_position) < r:
			return true
	return false


func _safe_tick(dt: float) -> void:
	if _let_in_t > 0.0:
		_let_in_t -= dt
		if _let_in_t <= 0.0:
			GameState.flags[unlock_flag] = true
			_open()
			_player_hold = true
	var pl = GameState.nearest_player(global_position)
	if _player_hold and (pl == null or _flat_dist(pl.global_position) > 4.5):
		_player_hold = false
	if _staff_wants_through() or _player_hold:
		if not opened:
			_open()
		_close_t = 1.5
	elif opened:
		_close_t -= dt * (3.0 if _hostile_near(7.0) else 1.0)
		if _close_t <= 0.0 and not _anyone_in_doorway():
			_close()


func _player_inside(player) -> bool:
	var d: Vector3 = player.global_position - global_position
	d.y = 0
	return d.dot(inside_dir) > 0.2


func _human_staff_inside() -> Array:
	var out := []
	for p in GameState.people:
		if is_instance_valid(p) and p.role == profession and p.is_safe_inside():
			out.append(p)
	return out


func _player_can_open(player) -> bool:
	if _player_inside(player) or GameState.flags.get(unlock_flag, false):
		return true
	return profession == "worker" and player.has_item("shed_key")


# ------------------------------------------------------------- prompts
func get_prompt(player) -> String:
	match kind:
		"pickup":
			return "[E] Take %s" % label_text
		"safe_door":
			var place := "maintenance shed" if profession == "worker" else "security office"
			if opened:
				return "[E] Close the door"
			if _player_can_open(player):
				return "[E] Open the %s" % place
			return "[E] Knock on the %s door" % place
		"gate":
			if opened:
				return ""
			if player.has_item("gate_key"):
				return "[E] Unlock the main gate"
			return "Main gate — locked tight"
	return ""


func interact(player) -> void:
	match kind:
		"pickup":
			player.give(item)
			Sfx.play("pickup", global_position)
			queue_free()
		"safe_door":
			_door_interact(player)
		"gate":
			if opened:
				return
			if player.has_item("gate_key"):
				_open()
				GameState.flags["gate_open"] = true
				GameState.think("It's open. I could just walk out... or bring a few more people with me.", "gate_open")
			else:
				Sfx.play("clunk", global_position, -2.0, 0.8)
				GameState.think("Locked. One of the maintenance crew should have the gate key.", "gate_locked")


func _door_interact(player) -> void:
	if opened:
		if not _anyone_in_doorway():
			_player_hold = false
			_close()
		return
	if _player_can_open(player):
		if profession == "worker" and player.has_item("shed_key"):
			GameState.flags[unlock_flag] = true
		_open()
		_player_hold = true
		return
	Sfx.play("knock", global_position + Vector3.UP * 1.4)
	var inside := _human_staff_inside()
	var friendly := inside.filter(func(p): return not p.guard_angry)
	if friendly.is_empty():
		if inside.is_empty():
			if profession == "worker":
				GameState.think("Nobody's answering. A maintenance worker could let me in... or his key could.", "shed_knock_empty")
			else:
				GameState.think("Locked, and nobody's home. Probably nothing I need in there anyway.", "office_knock_empty")
		else:
			inside[0].say("Get lost! I know what you did!")
		return
	var who = friendly[0]
	who.say("Who's there?! ...It's a person! Quick, get in!" if profession == "worker" else "Identify yourself! ...Human. Fine, get in, FAST.", 3.0)
	_let_in_t = 1.2


func open_door() -> void:
	# kept for the escorted-worker unlock path
	if kind == "safe_door":
		GameState.flags[unlock_flag] = true
	_open()


func _open() -> void:
	if opened:
		return
	_ensure_rot()
	opened = true
	if kind == "safe_door" and profession == "worker":
		GameState.flags["shed_open"] = true
	Sfx.play("creak" if kind == "gate" else "door", global_position + Vector3.UP)
	if kind == "gate":
		Sfx.play("clunk", global_position)
	for c in get_children():
		if c is CollisionShape3D:
			c.set_deferred("disabled", true)
	for i in door_pivots.size():
		var p: Node3D = door_pivots[i]
		var tw := create_tween()
		var dir := -1.0 if i % 2 == 0 else 1.0
		tw.tween_property(p, "rotation:y", _closed_rot[i] + dir * 1.7, 0.9 if kind == "safe_door" else 1.6).set_trans(Tween.TRANS_SINE)


func _close() -> void:
	if not opened or kind == "gate":
		return
	_ensure_rot()
	opened = false
	Sfx.play("door", global_position + Vector3.UP, 0.0, 0.8)
	for c in get_children():
		if c is CollisionShape3D:
			c.set_deferred("disabled", false)
	for i in door_pivots.size():
		var p: Node3D = door_pivots[i]
		var tw := create_tween()
		tw.tween_property(p, "rotation:y", _closed_rot[i], 0.7).set_trans(Tween.TRANS_SINE)
