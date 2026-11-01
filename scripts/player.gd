extends CharacterBody3D
## First-person survivor. Kept self-contained so more players can be spawned later.

const WEAPONS := {
	"pistol": {"name": "Carnival Revolver", "damage": 34.0, "mag": 6, "start": 12, "fire": 0.32, "spread": 0.012, "pellets": 1, "reload": 1.5, "auto": false, "snd": "pistol", "kick": 0.045, "noise": 35.0},
	"shotgun": {"name": "Pump Shotgun", "damage": 13.0, "mag": 4, "start": 8, "fire": 0.85, "spread": 0.075, "pellets": 9, "reload": 2.2, "auto": false, "snd": "shotgun", "kick": 0.12, "noise": 45.0},
	"smg": {"name": "Security SMG", "damage": 13.0, "mag": 30, "start": 60, "fire": 0.085, "spread": 0.035, "pellets": 1, "reload": 1.9, "auto": true, "snd": "smg", "kick": 0.018, "noise": 40.0},
}
const ORDER := ["pistol", "shotgun", "smg"]
const AMMO_ITEMS := {"ammo_pistol": ["pistol", 12], "ammo_shells": ["shotgun", 6], "ammo_smg": ["smg", 30]}

var health := 100.0
var max_health := 100.0
var dead := false
var noise_level := 0.4
var weapons: Array = []
var mag := {"pistol": 0, "shotgun": 0, "smg": 0}
var reserve := {"pistol": 0, "shotgun": 0, "smg": 0}
var current := ""
var items := {}
var hud = null

var head: Node3D
var cam: Camera3D
var viewmodel: Node3D
var vm_models := {}
var muzzle: OmniLight3D
var flash_mesh: MeshInstance3D
var shape: CollisionShape3D
var capsule: CapsuleShape3D

var yaw := 0.0
var pitch := 0.0
var fire_cd := 0.0
var reload_t := 0.0
var disorient := 0.0
var shake := 0.0
var knock := Vector3.ZERO
var crouching := false
var _noise_spike := 0.0
var _step_acc := 0.0
var _t := 0.0
var _vm_kick := 0.0
var _flash_t := 0.0
var _hurt_cd := 0.0
var focus = null


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4
	shape = CollisionShape3D.new()
	capsule = CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	head = Node3D.new()
	head.position.y = 1.62
	add_child(head)
	cam = Camera3D.new()
	cam.fov = 78.0
	cam.near = 0.05
	cam.far = 300.0
	head.add_child(cam)
	cam.current = true
	viewmodel = Node3D.new()
	viewmodel.position = Vector3(0.26, -0.24, -0.45)
	cam.add_child(viewmodel)
	_build_viewmodels()
	muzzle = OmniLight3D.new()
	muzzle.light_color = Color(1, 0.75, 0.4)
	muzzle.omni_range = 7.0
	muzzle.light_energy = 0.0
	muzzle.position = Vector3(0.26, -0.15, -1.0)
	cam.add_child(muzzle)
	var fq := QuadMesh.new()
	fq.size = Vector2(0.25, 0.25)
	flash_mesh = Build.mesh(cam, fq, Vector3(0.26, -0.17, -0.95), Build.mat(Color(1, 0.8, 0.3), 6.0, true))
	flash_mesh.visible = false
	GameState.players.append(self)


func _build_viewmodels() -> void:
	var p := Node3D.new()
	Build.box(p, Vector3(0.06, 0.09, 0.32), Vector3(0, 0, -0.08), Color(0.75, 0.6, 0.2), false, 0.15)
	Build.cyl(p, 0.035, 0.035, 0.08, Vector3(0, 0.0, 0.0), Color(0.6, 0.45, 0.15), false, 6, 0.0, Vector3(0, 0, PI / 2))
	Build.box(p, Vector3(0.05, 0.16, 0.07), Vector3(0, -0.1, 0.07), Color(0.45, 0.2, 0.1), false, 0.0, Vector3(-0.3, 0, 0))
	Build.box(p, Vector3(0.015, 0.03, 0.02), Vector3(0, 0.06, -0.22), Color(1, 0.3, 0.3), false, 2.0)
	vm_models["pistol"] = p
	var s := Node3D.new()
	Build.box(s, Vector3(0.07, 0.07, 0.8), Vector3(0, 0.02, -0.25), Color(0.25, 0.25, 0.28), false)
	Build.box(s, Vector3(0.08, 0.08, 0.3), Vector3(0, -0.05, -0.35), Color(0.45, 0.28, 0.12), false)
	Build.box(s, Vector3(0.07, 0.13, 0.3), Vector3(0, -0.06, 0.2), Color(0.45, 0.28, 0.12), false)
	vm_models["shotgun"] = s
	var m := Node3D.new()
	Build.box(m, Vector3(0.07, 0.1, 0.45), Vector3(0, 0, -0.12), Color(0.1, 0.1, 0.12), false)
	Build.box(m, Vector3(0.04, 0.2, 0.06), Vector3(0, -0.13, -0.1), Color(0.15, 0.15, 0.18), false)
	Build.box(m, Vector3(0.03, 0.03, 0.2), Vector3(0, 0.0, -0.42), Color(0.2, 0.2, 0.22), false)
	Build.box(m, Vector3(0.012, 0.025, 0.02), Vector3(0, 0.065, -0.3), Color(0.3, 1, 0.4), false, 2.0)
	vm_models["smg"] = m
	for k in vm_models:
		viewmodel.add_child(vm_models[k])
		vm_models[k].visible = false


func _unhandled_input(event: InputEvent) -> void:
	if dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := 0.0022 * GameState.mouse_sensitivity
		if disorient > 0.0:
			sens *= 1.0 + disorient * 0.6
		yaw -= event.relative.x * sens
		pitch = clampf(pitch - event.relative.y * sens, -1.5, 1.5)
	elif event.is_action_pressed("weapon_1"):
		_switch("pistol")
	elif event.is_action_pressed("weapon_2"):
		_switch("shotgun")
	elif event.is_action_pressed("weapon_3"):
		_switch("smg")
	elif event.is_action_pressed("weapon_next"):
		_cycle(1)
	elif event.is_action_pressed("weapon_prev"):
		_cycle(-1)
	elif event.is_action_pressed("reload"):
		_start_reload()
	elif event.is_action_pressed("interact"):
		if focus and is_instance_valid(focus):
			focus.interact(self)


func _physics_process(dt: float) -> void:
	_t += dt
	fire_cd -= dt
	_hurt_cd -= dt
	if dead:
		velocity.x = lerpf(velocity.x, 0.0, dt * 4.0)
		velocity.z = lerpf(velocity.z, 0.0, dt * 4.0)
		velocity.y -= 18.0 * dt
		move_and_slide()
		return
	# movement
	crouching = Input.is_action_pressed("crouch")
	var sprint := Input.is_action_pressed("sprint") and not crouching
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		input = Vector2.ZERO
		sprint = false
	var dir := (Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y))
	if disorient > 0.0:
		dir = dir.rotated(Vector3.UP, sin(_t * 2.3) * 0.7 * disorient)
	var speed := 2.2 if crouching else (7.0 if sprint else 4.3)
	if reload_t > 0.0:
		speed *= 0.85
	var accel := 12.0 if is_on_floor() else 3.0
	velocity.x = lerpf(velocity.x, dir.x * speed, minf(1.0, accel * dt))
	velocity.z = lerpf(velocity.z, dir.z * speed, minf(1.0, accel * dt))
	if is_on_floor() and Input.is_action_just_pressed("jump") and not crouching and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		velocity.y = 5.2
	velocity.y -= 16.0 * dt
	var saved := velocity
	velocity += knock
	move_and_slide()
	velocity = Vector3(saved.x, velocity.y, saved.z)
	knock = knock.lerp(Vector3.ZERO, minf(1.0, dt * 3.5))

	# crouch
	var target_h := 1.0 if crouching else 1.8
	capsule.height = lerpf(capsule.height, target_h, dt * 10.0)
	shape.position.y = capsule.height * 0.5
	head.position.y = capsule.height - 0.18

	# footsteps
	var hv := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hv > 0.5:
		_step_acc += hv * dt
		var stride := 2.4 if sprint else 1.8
		if _step_acc > stride:
			_step_acc = 0.0
			if not crouching:
				Sfx.play("step", global_position, -6.0 if sprint else -12.0, randf_range(0.85, 1.1), 25.0)

	# stealth: movement + light + noise spikes
	var n := 0.08
	if hv > 0.5:
		n = 0.18 if crouching else (0.95 if sprint else 0.45)
	elif crouching:
		n = 0.03
	if not crouching:
		for lp in GameState.light_points:
			if global_position.distance_to(lp) < 6.0:
				n += 0.15
				break
	_noise_spike = maxf(0.0, _noise_spike - dt * 0.6)
	noise_level = clampf(maxf(n, _noise_spike), 0.0, 1.0)

	# camera
	disorient = maxf(0.0, disorient - dt * 0.45)
	shake = maxf(0.0, shake - dt * 2.5)
	rotation.y = 0.0
	head.rotation = Vector3(pitch, yaw, 0)
	var roll := sin(_t * 3.1) * 0.22 * disorient + randf_range(-1, 1) * shake * 0.03
	cam.rotation = Vector3(randf_range(-1, 1) * shake * 0.02, 0, roll)
	cam.fov = 78.0 + sin(_t * 2.0) * 8.0 * disorient
	# viewmodel bob
	var bob := sin(_t * (12.0 if sprint else 8.0)) * 0.012 * minf(hv / 4.0, 1.5)
	_vm_kick = lerpf(_vm_kick, 0.0, dt * 12.0)
	viewmodel.position = Vector3(0.26, -0.24 + bob - (0.15 if reload_t > 0.0 else 0.0), -0.45 + _vm_kick)
	viewmodel.rotation.x = _vm_kick * 2.0 + (0.5 if reload_t > 0.0 else 0.0)
	_flash_t -= dt
	if _flash_t <= 0.0:
		flash_mesh.visible = false
		muzzle.light_energy = 0.0

	# reload
	if reload_t > 0.0:
		reload_t -= dt
		if reload_t <= 0.0:
			var need: int = WEAPONS[current].mag - mag[current]
			var take: int = mini(need, reserve[current])
			mag[current] += take
			reserve[current] -= take

	# fire
	if current != "" and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var w: Dictionary = WEAPONS[current]
		var want: bool = Input.is_action_pressed("fire") if w.auto else Input.is_action_just_pressed("fire")
		if want and fire_cd <= 0.0 and reload_t <= 0.0:
			_fire(w)

	_update_focus()


func _fire(w: Dictionary) -> void:
	fire_cd = w.fire
	if mag[current] <= 0:
		Sfx.play("click", global_position)
		_start_reload()
		return
	mag[current] -= 1
	var origin := cam.global_position
	var space := get_world_3d().direct_space_state
	for i in int(w.pellets):
		var fwd := -cam.global_basis.z
		var spread: float = w.spread * (1.6 if not is_on_floor() else (0.6 if crouching else 1.0))
		var d := (fwd + cam.global_basis.x * randf_range(-spread, spread) + cam.global_basis.y * randf_range(-spread, spread)).normalized()
		var q := PhysicsRayQueryParameters3D.create(origin, origin + d * 90.0, 1 | 4)
		q.exclude = [get_rid()]
		var hit := space.intersect_ray(q)
		var end_p: Vector3 = hit.position if hit else origin + d * 90.0
		var scene := get_tree().current_scene
		if scene.has_method("spawn_tracer") and i < 3:
			scene.spawn_tracer(muzzle.global_position, end_p)
		if hit:
			if hit.collider.has_method("take_damage"):
				hit.collider.take_damage(w.damage, origin, self)
			elif scene.has_method("spawn_impact"):
				scene.spawn_impact(hit.position, Color(1, 0.9, 0.5))
	Sfx.play(w.snd, global_position + Vector3.UP * 1.5, 0.0)
	GameState.noise_event(global_position, w.noise, self)
	_noise_spike = 1.0
	pitch = clampf(pitch + w.kick, -1.5, 1.5)
	yaw += randf_range(-0.3, 0.3) * w.kick
	_vm_kick = 0.08 + w.kick
	_flash_t = 0.05
	flash_mesh.visible = true
	flash_mesh.rotation.z = randf() * TAU
	muzzle.light_energy = 4.0
	if mag[current] <= 0 and reserve[current] > 0:
		_start_reload()


func _start_reload() -> void:
	if current == "" or reload_t > 0.0:
		return
	if mag[current] >= WEAPONS[current].mag or reserve[current] <= 0:
		return
	reload_t = WEAPONS[current].reload
	Sfx.play("reload", global_position + Vector3.UP)


func _switch(w: String) -> void:
	if not weapons.has(w) or current == w:
		return
	current = w
	reload_t = 0.0
	fire_cd = 0.3
	for k in vm_models:
		vm_models[k].visible = k == w
	_vm_kick = 0.3
	Sfx.play("click", global_position, -6.0)


func _cycle(step: int) -> void:
	if weapons.size() < 2:
		return
	var owned: Array = ORDER.filter(func(x): return weapons.has(x))
	var i := owned.find(current)
	_switch(owned[(i + step + owned.size()) % owned.size()])


func _update_focus() -> void:
	var origin := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(origin, origin - cam.global_basis.z * 3.2, 1 | 4 | 8)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	focus = null
	var prompt := ""
	if hit and hit.collider.has_method("get_prompt"):
		prompt = hit.collider.get_prompt(self)
		if prompt != "":
			focus = hit.collider
	if hud:
		hud.set_prompt(prompt)


# ------------------------------------------------------------- items
func has_item(item: String) -> bool:
	return items.get(item, false)


func give(item: String) -> void:
	if WEAPONS.has(item):
		if not weapons.has(item):
			weapons.append(item)
			mag[item] = WEAPONS[item].mag
			reserve[item] += WEAPONS[item].start
			_switch(item)
		else:
			reserve[item] += WEAPONS[item].start
		match item:
			"pistol":
				GameState.think("A carnival revolver. Six shots. Better than nothing.", "got_pistol")
			"shotgun":
				GameState.think("Now THAT'S a prize.", "got_shotgun")
			"smg":
				GameState.smg_acquired = true
				GameState.think("Sorry, pal. I need this more than you do.", "got_smg")
	elif AMMO_ITEMS.has(item):
		var a: Array = AMMO_ITEMS[item]
		reserve[a[0]] += a[1]
	elif item == "ammo":
		reserve["pistol"] += 6
		if weapons.has("shotgun"):
			reserve["shotgun"] += 3
		if weapons.has("smg"):
			reserve["smg"] += 15
	else:
		items[item] = true
		if item == "gate_key":
			GameState.think("The gate key. I could leave right now... but what about everyone else?", "got_gate_key")
		elif item == "shed_key":
			GameState.think("His key. I'm sorry...", "got_shed_key")
	if hud:
		hud.toast("Picked up: %s" % item.replace("_", " ").capitalize())


# ------------------------------------------------------------- damage
func take_hit(dmg: float, from_pos: Vector3, knockback: float, disor: float, _attacker = null) -> void:
	if dead:
		return
	health -= dmg
	var dir := global_position - from_pos
	dir.y = 0
	dir = dir.normalized()
	knock += dir * knockback
	if knockback > 4.0:
		velocity.y = knockback * 0.45
		GameState.think("OW— that is NOT a toy hammer!", "first_hammer")
	disorient = maxf(disorient, disor)
	shake = maxf(shake, 0.4 + dmg * 0.02)
	if hud:
		hud.flash_damage(clampf(dmg / 50.0, 0.25, 1.0))
	if _hurt_cd <= 0.0:
		_hurt_cd = 0.3
		Sfx.play("hurt", global_position + Vector3.UP, 2.0)
	if health <= 0.0:
		_die()


func on_spotted(_by) -> void:
	if weapons.is_empty():
		GameState.think("It saw me! I need a weapon... the shooting gallery!", "spotted_unarmed")


func _die() -> void:
	health = 0.0
	dead = true
	focus = null
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(head, "position:y", 0.35, 0.8).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(cam, "rotation:z", 1.3, 0.8)
	viewmodel.visible = false
	if hud:
		hud.set_prompt("")
		hud.show_death()
