extends StaticBody3D
## Generic interactable: pickups, shed door, exit gate. Behaviour chosen by `kind`.

var kind := "pickup"          # pickup, shed_door, gate
var item := ""                # for pickups
var label_text := ""
var opened := false
var _visual: Node3D
var _t := 0.0
var door_pivots: Array = []


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
		_:
			label_text = {"ammo_pistol": "Revolver Rounds", "ammo_shells": "Shotgun Shells", "ammo_smg": "SMG Magazine", "ammo": "Ammo"}.get(item, "Ammo")
			Build.box(_visual, Vector3(0.3, 0.18, 0.2), Vector3.ZERO, Color(0.3, 0.45, 0.2), false)
			Build.box(_visual, Vector3(0.31, 0.06, 0.21), Vector3(0, 0.03, 0), Color(0.9, 0.8, 0.2), false, 0.8)
	var glow := Build.omni(self, Vector3(0, 0.4, 0), Color(1, 0.9, 0.5), 0.6, 2.5)
	glow.shadow_enabled = false


func _process(delta: float) -> void:
	if kind == "pickup" and _visual:
		_t += delta
		_visual.rotation.y += delta * 1.5
		_visual.position.y = sin(_t * 2.0) * 0.06


func get_prompt(player) -> String:
	match kind:
		"pickup":
			return "[E] Take %s" % label_text
		"shed_door":
			if opened:
				return ""
			if GameState.flags.get("shed_unlocked", false) or player.has_item("shed_key"):
				return "[E] Unlock maintenance shed"
			return "Locked — the maintenance worker has the key"
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
		"shed_door":
			if opened:
				return
			if GameState.flags.get("shed_unlocked", false) or player.has_item("shed_key"):
				open_door()
			else:
				Sfx.play("clunk", global_position, -4.0, 1.4)
				GameState.think("Locked. The maintenance guy must have the key... if he's still around.", "shed_locked")
		"gate":
			if opened:
				return
			if player.has_item("gate_key"):
				open_door()
				GameState.flags["gate_open"] = true
				GameState.think("It's open. I could just walk out... or bring a few more people with me.", "gate_open")
			else:
				Sfx.play("clunk", global_position, -2.0, 0.8)
				GameState.think("Locked. There has to be a key somewhere in here.", "gate_locked")


func open_door() -> void:
	if opened:
		return
	opened = true
	if kind == "shed_door":
		GameState.flags["shed_unlocked"] = true
		GameState.flags["shed_open"] = true
	Sfx.play("creak", global_position)
	Sfx.play("clunk", global_position)
	for c in get_children():
		if c is CollisionShape3D:
			c.set_deferred("disabled", true)
	for i in door_pivots.size():
		var p: Node3D = door_pivots[i]
		var tw := create_tween()
		var dir := -1.0 if i % 2 == 0 else 1.0
		tw.tween_property(p, "rotation:y", p.rotation.y + dir * 1.7, 1.6).set_trans(Tween.TRANS_SINE)
