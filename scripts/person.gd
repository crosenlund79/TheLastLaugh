extends CharacterBody3D
## Any human in the carnival: clowns, civilians, maintenance workers, security guards.
## Only purple fog can turn a person hostile (see add_fog / _begin_transform).
## Staff (workers/guards) do duties, radio a warning when one of them is infected,
## and the rest physically navigate (navmesh) to their profession's safe house.

enum { PERFORM, FLEE, HIDE, FOLLOW, TRANSFORM, HOSTILE, DEAD, DUTY, RETREAT, SAFE, RESCUED }

const BODIES := {
	"tall":   {"leg": 1.25, "arm": 1.2, "torso": 0.8, "tw": 0.2, "head": 0.24, "shoe": 0.34, "belly": 0.0, "speed": 2.1, "freq": 0.85, "stride": 0.6, "armswing": 1.0, "sway": 0.14, "bob": 0.14, "k": 22.0, "hp": 70.0, "limb": 0.065, "squash": 0.05},
	"squat":  {"leg": 0.32, "arm": 0.4, "torso": 0.42, "tw": 0.32, "head": 0.32, "shoe": 0.6, "belly": 0.18, "speed": 1.8, "freq": 2.6, "stride": 0.85, "armswing": 0.9, "sway": 0.38, "bob": 0.07, "k": 40.0, "hp": 55.0, "limb": 0.1, "squash": 0.12},
	"round":  {"leg": 0.55, "arm": 0.5, "torso": 0.6, "tw": 0.58, "head": 0.28, "shoe": 0.42, "belly": 0.0, "speed": 1.6, "freq": 1.5, "stride": 0.6, "armswing": 0.55, "sway": 0.26, "bob": 0.09, "k": 30.0, "hp": 115.0, "limb": 0.12, "squash": 0.1},
	"belly":  {"leg": 0.82, "arm": 0.66, "torso": 0.62, "tw": 0.25, "head": 0.25, "shoe": 0.4, "belly": 0.4, "speed": 2.0, "freq": 1.55, "stride": 0.6, "armswing": 0.75, "sway": 0.16, "bob": 0.09, "k": 34.0, "hp": 80.0, "limb": 0.085, "squash": 0.07},
	"skinny": {"leg": 1.0, "arm": 0.95, "torso": 0.75, "tw": 0.15, "head": 0.22, "shoe": 0.3, "belly": 0.0, "speed": 2.2, "freq": 1.2, "stride": 0.65, "armswing": 1.1, "sway": 0.2, "bob": 0.1, "k": 20.0, "hp": 55.0, "limb": 0.055, "squash": 0.06},
	"normal": {"leg": 0.86, "arm": 0.66, "torso": 0.62, "tw": 0.24, "head": 0.21, "shoe": 0.15, "belly": 0.0, "speed": 2.0, "freq": 1.7, "stride": 0.5, "armswing": 0.5, "sway": 0.05, "bob": 0.05, "k": 60.0, "hp": 60.0, "limb": 0.075, "squash": 0.0},
}
const CLOWN_COLORS := [Color(0.95, 0.15, 0.2), Color(0.2, 0.5, 1.0), Color(1.0, 0.85, 0.1), Color(0.3, 0.85, 0.35), Color(1.0, 0.45, 0.8), Color(0.6, 0.3, 0.95), Color(1.0, 0.55, 0.1), Color(0.1, 0.8, 0.8)]
const HAIR_COLORS := [Color(1.0, 0.3, 0.1), Color(0.1, 0.6, 1.0), Color(0.9, 0.2, 0.7), Color(0.3, 1.0, 0.3), Color(1.0, 0.95, 0.3), Color(0.95, 0.95, 0.95)]
const CORRUPT := Color(0.32, 0.08, 0.42)
const CLOWN_LINES := ["Honk honk!", "Wanna see a trick?", "Hee hee!", "Smile, friend!", "Balloon? No? Okay!"]
const SCARED_LINES := ["Oh god, oh god!", "Stay away from me!", "What happened to him?!", "RUN!", "Help!"]
const WORKER_RADIO := [
	"Maintenance, it's %s— the fog— it's IN me— everybody get to the shed! Lock the—",
	"%s here... can't see... so purple... GET TO THE SHED... hee... hee hee...",
	"Mayday, it's %s! Walked right into it— shed, go to the shed, don't wait for m—",
]
const GUARD_RADIO := [
	"Security, %s! The fog's got me— fall back to the office! FALL BACK! It's... so funny...",
	"%s to all units— I'm compromised— back to the office, lock the do— hehehe",
	"This is %s— can't hold it— everyone back to security, NOW— haaa ha ha",
]
const SAFE_LINES := {
	"worker": ["Is it still out there?", "Shut the door! SHUT IT!", "I heard them on the radio... the laughing...", "We fix rides. We're not supposed to... this.", "If the gate's open, I'll make a run for it with you."],
	"guard": ["We hold here until help comes.", "Don't let them in. Not even the funny ones.", "Radio's just static and giggling now.", "Open the main gate and I'll walk out with you. Not before."],
}

# identity
var role := "clown"
var body := "normal"
var P: Dictionary
var hp := 60.0
var staff_name := ""
var staff_index := 0
var keyholder := false
var duty_points: Array = []
var duty_area := ""

# tracked state
var state := PERFORM
var fog_exposure := 0.0
var fog_affected := false
var hostile := false
var dead := false
var rescued := false
var home := Vector3.ZERO
var fear := 0.0
var threat := Vector3.ZERO
var follow_target = null

# behaviour timers
var perform := "wander"
var perform_t := 0.0
var _act := 0.0
var _scan_t := 0.0
var _say_cd := 0.0
var _scream_cd := 0.0
var _state_t := 0.0
var _dt := 0.016
var move_target := Vector3.ZERO
var face_point = null
var want_vel := Vector3.ZERO
var _stuck_t := 0.0
var _unstick_t := 0.0
var _unstick_dir := Vector3.ZERO
var _last_pos := Vector3.ZERO
var guard_angry := false
var guard_greeted := false
var worker_unlocking := -1.0
var flower_given := false
var _duty_i := 0
var _duty_work := 0.0
var _hinted := false

# navigation
var _path := PackedVector3Array()
var _path_i := 0
var _path_target := Vector3(INF, INF, INF)
var _path_t := 0.0

# hostile
var alert_t := 0.0
var last_known := Vector3.ZERO
var shoot_cd := 2.0
var aim_t := 0.0
var melee := ""
var melee_t := 0.0
var burst_left := 0
var stagger_t := 0.0
var giggle_cd := 5.0
var _spotted_once := false
var _glitch_t := 0.0
var _burst_t := 0.0

# rig
var rig: Node3D
var pelvis: Node3D
var torso: Node3D
var head: Node3D
var belly_node: Node3D
var nose: Node3D
var mouth: Node3D
var brows: Array = []
var eyes: Array = []
var hand_r: Node3D
var hand_l: Node3D
var joints := {}
var pelvis_y := 1.0
var _head_base_y := 0.0
var costume_mats: Array = []
var costume_orig: Array = []
var skin_mat: StandardMaterial3D
var eye_mat: StandardMaterial3D
var mouth_mat: StandardMaterial3D
var juggle_balls: Array = []
var flower: Node3D
var gun: Node3D
var hammer: Node3D
var tool: Node3D
var flashlight: SpotLight3D
var speech_label: Label3D
var _speech_t := 0.0
var phase := 0.0
var _last_step_sign := 1.0
var facing := 0.0
var belly_s := 0.0
var belly_v := 0.0
var _prev_pelvis := 0.0
var twitch := Vector3.ZERO
var _twitch_t := 0.0
var fall := 0.0
var fall_v := 0.0
var spin_v := 0.0
var _trip := 0.0
var _height := 1.8
var _honk_t := 0.0
var _rescue_t := 0.0
var _blink_t := 2.0
var _corrupt := 0.0


# ================================================================ setup
func setup(p_role: String, p_body: String, pos: Vector3) -> void:
	role = p_role
	body = p_body
	P = BODIES[body]
	hp = P.hp
	home = pos
	position = pos
	_last_pos = pos
	facing = randf() * TAU
	collision_layer = 4
	collision_mask = 1 | 2 | 16
	_build_rig()
	match role:
		"guard", "worker":
			state = DUTY
		_:
			state = PERFORM
			_pick_perform()
	GameState.register_person(self)


func setup_staff(p_name: String, idx: int, points: Array, area: String, has_key: bool) -> void:
	staff_name = p_name
	staff_index = idx
	duty_points = points
	duty_area = area
	keyholder = has_key
	_duty_i = randi() % maxi(1, points.size())
	if keyholder:
		var ring := Build.torus(pelvis, 0.05, 0.08, Vector3(P.tw * 0.8, -0.05, -0.1), Build.mat(Color(1, 0.85, 0.2), 2.0), Vector3(0, 0, PI / 2))
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for k in 2:
			Build.box(pelvis, Vector3(0.02, 0.12, 0.04), Vector3(P.tw * 0.8 + 0.02, -0.15 - k * 0.03, -0.12 + k * 0.05), Color(1, 0.85, 0.2), false, 2.0)


func _build_rig() -> void:
	var is_clown := role == "clown"
	var shoe_h: float = 0.1 + P.shoe * 0.18
	pelvis_y = P.leg + shoe_h
	var torso_h: float = P.torso
	if body == "round":
		torso_h = P.tw * 1.8
	var head_r: float = P.head
	_height = pelvis_y + torso_h + head_r * 2.2

	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = clampf(P.tw + 0.05, 0.3, 0.6)
	cap.height = maxf(_height, cap.radius * 2.0 + 0.1)
	cs.shape = cap
	cs.position.y = cap.height / 2.0
	add_child(cs)

	# ---- palette
	var c1: Color
	var c2: Color
	var shoe_c: Color
	var skin: Color = Color(0.97, 0.95, 0.92) if is_clown else [Color(0.93, 0.76, 0.62), Color(0.62, 0.43, 0.3), Color(0.8, 0.6, 0.45), Color(0.42, 0.28, 0.2)].pick_random()
	var pat1 := 4
	var pat2 := 4
	var acc1 := Color.WHITE
	var acc2 := Color.WHITE
	match role:
		"clown":
			c1 = CLOWN_COLORS.pick_random()
			c2 = CLOWN_COLORS.pick_random()
			acc1 = CLOWN_COLORS.pick_random().lightened(0.3)
			acc2 = CLOWN_COLORS.pick_random()
			pat1 = randi() % 5
			pat2 = randi() % 5
			shoe_c = [Color(0.9, 0.1, 0.1), Color(0.95, 0.85, 0.1), Color(0.15, 0.6, 1.0), Color(0.1, 0.9, 0.3)].pick_random()
		"worker":
			c1 = Color(0.95, 0.5, 0.1)
			c2 = Color(0.2, 0.25, 0.4)
			shoe_c = Color(0.25, 0.18, 0.1)
		"guard":
			c1 = Color(0.14, 0.2, 0.38)
			c2 = Color(0.08, 0.08, 0.12)
			shoe_c = Color(0.05, 0.05, 0.05)
		_:
			c1 = Color.from_hsv(randf(), randf_range(0.3, 0.7), randf_range(0.4, 0.85))
			c2 = Color.from_hsv(randf_range(0.55, 0.65), 0.4, randf_range(0.2, 0.45))
			acc1 = c1.lightened(0.4)
			pat1 = [4, 4, 0, 2].pick_random()
			shoe_c = Color(0.15, 0.12, 0.1)
	var m1 := _cmat(c1, acc1, pat1)
	var m2 := _cmat(c2, acc2, pat2)
	var ms := _cmat(shoe_c)
	ms.roughness = 0.25
	skin_mat = Build.unique_mat(skin)
	var glove := _cmat(Color(1, 1, 1)) if is_clown else skin_mat
	eye_mat = Build.unique_mat(Color(0.05, 0.05, 0.08))
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(0.75, 0.15, 1.0)
	eye_mat.emission_energy_multiplier = 0.0
	mouth_mat = Build.unique_mat(Color(0.85, 0.05, 0.12) if is_clown else Color(0.45, 0.18, 0.18))
	mouth_mat.emission_enabled = true
	mouth_mat.emission = Color(0.5, 0.0, 0.7)
	mouth_mat.emission_energy_multiplier = 0.0

	rig = Node3D.new()
	add_child(rig)
	pelvis = Node3D.new()
	pelvis.position.y = pelvis_y
	rig.add_child(pelvis)
	var limb_r: float = P.limb

	# ---- legs
	for side in [-1, 1]:
		var hip := _pivot(pelvis, Vector3(side * P.tw * 0.55, 0, 0))
		_capsule(hip, P.leg * 0.5, limb_r * 1.15, m2)
		var knee := _pivot(hip, Vector3(0, -P.leg * 0.5, 0))
		_capsule(knee, P.leg * 0.5, limb_r, m2)
		var foot := _pivot(knee, Vector3(0, -P.leg * 0.5, 0))
		var shoe_len: float = 0.25 + P.shoe * 1.3
		var shoe := Build.sphere(foot, 0.5, Vector3(0, -shoe_h * 0.45, -shoe_len * 0.3), ms, 10)
		shoe.scale = Vector3(0.12 + P.shoe * 0.45, shoe_h * 1.1, shoe_len)
		if is_clown:
			_detail(Build.torus(foot, limb_r * 0.9, limb_r * 1.9, Vector3(0, 0.02, 0), _cmat(acc1)))
		var nm := "L" if side < 0 else "R"
		_joint("hip" + nm, hip, P.k * 1.6, 12.0)
		_joint("knee" + nm, knee, P.k * 1.6, 12.0)
		joints["foot" + nm] = [foot]

	# ---- torso
	torso = _pivot(pelvis, Vector3.ZERO)
	_joint("torso", torso, P.k, 8.0)
	if body == "round":
		belly_node = Build.sphere(torso, P.tw, Vector3(0, P.tw * 0.9, 0), m1, 16)
	else:
		var tm := CapsuleMesh.new()
		tm.radius = P.tw
		tm.height = maxf(P.torso, P.tw * 2.0 + 0.01)
		tm.radial_segments = 12
		tm.rings = 4
		Build.mesh(torso, tm, Vector3(0, P.torso * 0.5, 0), m1)
		if P.belly > 0.0:
			belly_node = Build.sphere(torso, P.belly, Vector3(0, P.torso * 0.32, -P.tw * 0.55), m1, 14)
	var front_r := _front_r()
	match role:
		"clown":
			for k in 3:
				var y := torso_h * (0.3 + k * 0.22)
				_detail(Build.sphere(torso, 0.065, Vector3(0, y, -front_r - 0.03), Build.mat(CLOWN_COLORS.pick_random(), 0.2), 8))
			for k in 2:
				_detail(Build.torus(torso, P.tw + 0.02, P.tw + 0.16 - k * 0.04, Vector3(0, torso_h + 0.02 + k * 0.05, 0), _cmat(acc2 if k == 0 else acc1)))
			if randf() < 0.5:
				# bow tie
				var bt := _cmat(CLOWN_COLORS.pick_random())
				for sx in [-1, 1]:
					var b := Build.mesh(torso, _prism(Vector3(0.14, 0.14, 0.05)), Vector3(sx * 0.08, torso_h - 0.06, -P.tw - 0.04), bt, Vector3(0, 0, sx * PI / 2))
					_detail(b)
			if P.belly > 0.0 or body == "round":
				for sx in [-1, 1]:
					_detail(Build.box(torso, Vector3(0.05, torso_h * 0.9, 0.02), Vector3(sx * P.tw * 0.45, torso_h * 0.55, -front_r - 0.01), acc2, false))
		"worker":
			for yy in [0.35, 0.6]:
				_detail(Build.cyl(torso, P.tw + 0.012, P.tw + 0.012, 0.06, Vector3(0, torso_h * yy, 0), Color(0.85, 0.9, 0.9), false, 12, 0.6))
			Build.torus(pelvis, P.tw * 0.85, P.tw * 1.05, Vector3(0, 0.0, 0), Build.mat(Color(0.35, 0.22, 0.1)))
			_detail(Build.box(pelvis, Vector3(0.1, 0.14, 0.08), Vector3(-P.tw * 0.8, -0.05, -0.08), Color(0.5, 0.3, 0.15), false))
			_radio_prop(torso_h, front_r)
		"guard":
			_detail(Build.box(torso, Vector3(0.08, 0.09, 0.02), Vector3(-P.tw * 0.45, torso_h * 0.72, -front_r - 0.01), Color(1, 0.85, 0.3), false, 1.2))
			Build.torus(pelvis, P.tw * 0.85, P.tw * 1.05, Vector3(0, 0.0, 0), Build.mat(Color(0.05, 0.05, 0.05)))
			_radio_prop(torso_h, front_r)
		_:
			pass

	# ---- head & face
	head = _pivot(torso, Vector3(0, torso_h + 0.02, 0))
	_head_base_y = head.position.y
	_joint("head", head, P.k * 0.8, 6.0)
	Build.sphere(head, head_r, Vector3(0, head_r, 0), skin_mat, 16)
	for sx in [-1, 1]:
		_detail(Build.sphere(head, head_r * 0.22, Vector3(sx * head_r * 0.97, head_r * 1.0, 0.0), skin_mat, 6))
	var ey := head_r * 1.2
	var ez := -head_r * 0.82
	for sx in [-1, 1]:
		var eye := Node3D.new()
		eye.position = Vector3(sx * head_r * 0.36, ey, ez)
		head.add_child(eye)
		var white := Build.sphere(eye, head_r * 0.2, Vector3.ZERO, Build.mat(Color(0.98, 0.98, 0.98)), 8)
		white.scale = Vector3(1, 1.15, 0.6)
		_detail(white)
		_detail(Build.sphere(eye, head_r * 0.1, Vector3(0, 0, -head_r * 0.1), eye_mat, 6))
		eyes.append(eye)
		var brow := Node3D.new()
		brow.position = Vector3(sx * head_r * 0.36, ey + head_r * 0.3, ez + head_r * 0.04)
		head.add_child(brow)
		_detail(Build.box(brow, Vector3(head_r * 0.42, head_r * 0.07, head_r * 0.07), Vector3.ZERO, Color(0.1, 0.06, 0.06) if not is_clown else Color(0.15, 0.1, 0.3), false))
		brows.append(brow)
		if is_clown:
			var blush := Build.sphere(head, head_r * 0.2, Vector3(sx * head_r * 0.58, head_r * 0.82, -head_r * 0.72), Build.mat(Color(1, 0.45, 0.55)), 6)
			blush.scale = Vector3(1, 0.7, 0.3)
			_detail(blush)
	if is_clown and randf() < 0.5:
		var paint := Build.mat(CLOWN_COLORS.pick_random())
		for sx in [-1, 1]:
			for sy in [-1, 1]:
				_detail(Build.box(head, Vector3(head_r * 0.12, head_r * 0.12, 0.02), Vector3(sx * head_r * 0.36, ey + sy * head_r * 0.36, ez + head_r * 0.06), paint.albedo_color, false, 0.0, Vector3(0, 0, PI / 4)))
	if is_clown:
		var nm := StandardMaterial3D.new()
		nm.albedo_color = Color(1, 0.05, 0.05)
		nm.roughness = 0.12
		nm.emission_enabled = true
		nm.emission = Color(1, 0.05, 0.05)
		nm.emission_energy_multiplier = 0.25
		nose = Build.sphere(head, head_r * 0.32, Vector3(0, head_r * 0.95, -head_r * 0.98), nm, 12)
	else:
		nose = Build.sphere(head, head_r * 0.14, Vector3(0, head_r * 0.95, -head_r * 0.98), skin_mat, 6)
	# painted smile: an arc of beads that stretches into a grin when infected
	mouth = Node3D.new()
	mouth.position = Vector3(0, head_r * 0.55, -head_r * 0.86)
	head.add_child(mouth)
	var beads := 7 if is_clown else 4
	var mw := head_r * (0.65 if is_clown else 0.35)
	for k in beads:
		var u := (float(k) / (beads - 1)) * 2.0 - 1.0
		_detail(Build.sphere(mouth, head_r * (0.09 if is_clown else 0.05), Vector3(u * mw, u * u * head_r * 0.22, absf(u) * head_r * 0.25), mouth_mat, 5))
	_hair_and_hat(head, head_r, is_clown)

	# ---- arms
	var torso_top: float = torso_h - 0.06
	var sh_x: float = P.tw + limb_r * 0.6
	if body == "round":
		torso_top = P.tw * 1.2
		sh_x = P.tw * 0.95
	for side in [-1, 1]:
		var sh := _pivot(torso, Vector3(side * sh_x, torso_top, 0))
		Build.sphere(sh, limb_r * 1.3, Vector3.ZERO, m1, 8)
		_capsule(sh, P.arm * 0.5, limb_r, m1)
		var el := _pivot(sh, Vector3(0, -P.arm * 0.5, 0))
		_capsule(el, P.arm * 0.5, limb_r * 0.9, m1 if is_clown or role != "civilian" else skin_mat)
		var hand := _pivot(el, Vector3(0, -P.arm * 0.5, 0))
		Build.sphere(hand, limb_r * (1.9 if is_clown else 1.3), Vector3.ZERO, glove, 8)
		if is_clown:
			_detail(Build.torus(hand, limb_r * 1.0, limb_r * 2.1, Vector3(0, limb_r * 1.4, 0), _cmat(acc1)))
		var nm := "L" if side < 0 else "R"
		_joint("sh" + nm, sh, P.k, 5.0)
		_joint("el" + nm, el, P.k, 5.0)
		if side > 0:
			hand_r = hand
		else:
			hand_l = hand

	# ---- props
	for k in 3:
		var b := Build.sphere(rig, 0.09, Vector3.ZERO, Build.mat(CLOWN_COLORS[k * 2], 0.8), 8)
		b.visible = false
		juggle_balls.append(b)
	flower = Node3D.new()
	hand_r.add_child(flower)
	Build.cyl(flower, 0.015, 0.015, 0.4, Vector3(0, -0.15, 0), Color(0.2, 0.7, 0.2), false, 4)
	for k in 5:
		var a := TAU * k / 5.0
		Build.sphere(flower, 0.06, Vector3(cos(a) * 0.07, -0.36, sin(a) * 0.07), Build.mat(Color(1, 0.3, 0.6), 0.4), 5)
	Build.sphere(flower, 0.05, Vector3(0, -0.36, 0), Build.mat(Color(1, 0.9, 0.2)), 5)
	flower.visible = false

	gun = Node3D.new()
	hand_r.add_child(gun)
	if role == "guard":
		Build.box(gun, Vector3(0.09, 0.5, 0.14), Vector3(0, -0.2, -0.04), Color(0.08, 0.08, 0.1), false)
		Build.box(gun, Vector3(0.06, 0.08, 0.25), Vector3(0, -0.15, 0.1), Color(0.12, 0.12, 0.14), false)
	else:
		Build.cyl(gun, 0.07, 0.035, 0.55, Vector3(0, -0.28, -0.03), Color(0.35, 0.3, 0.3), false, 8)
		Build.box(gun, Vector3(0.07, 0.12, 0.22), Vector3(0, 0.0, 0.08), Color(0.45, 0.25, 0.1), false)
	gun.visible = role == "guard"

	hammer = Node3D.new()
	hand_r.add_child(hammer)
	Build.cyl(hammer, 0.04, 0.04, 1.2, Vector3(0, -0.5, 0), Color(1, 0.5, 0.8), false, 6)
	var hhead := CylinderMesh.new()
	hhead.top_radius = 0.33
	hhead.bottom_radius = 0.33
	hhead.height = 0.8
	hhead.radial_segments = 12
	Build.mesh(hammer, hhead, Vector3(0, -1.15, 0), Build.mat(Color(1, 0.15, 0.2), 0.3), Vector3(PI / 2, 0, 0))
	Build.cyl(hammer, 0.34, 0.34, 0.12, Vector3(0, -1.15, -0.4), Color(1, 0.9, 0.2), false, 12, 0.3, Vector3(PI / 2, 0, 0))
	Build.cyl(hammer, 0.34, 0.34, 0.12, Vector3(0, -1.15, 0.4), Color(1, 0.9, 0.2), false, 12, 0.3, Vector3(PI / 2, 0, 0))
	hammer.visible = false

	if role == "worker":
		tool = Node3D.new()
		hand_l.add_child(tool)
		Build.box(tool, Vector3(0.05, 0.38, 0.03), Vector3(0, -0.12, 0), Color(0.6, 0.62, 0.66), false)
		Build.torus(tool, 0.03, 0.06, Vector3(0, -0.33, 0), Build.mat(Color(0.6, 0.62, 0.66)), Vector3(PI / 2, 0, 0))
	elif role == "guard":
		tool = Node3D.new()
		hand_l.add_child(tool)
		Build.cyl(tool, 0.04, 0.05, 0.25, Vector3(0, -0.08, 0), Color(0.1, 0.1, 0.1), false, 6)
		Build.sphere(tool, 0.04, Vector3(0, -0.21, 0), Build.mat(Color(1, 0.95, 0.8), 4.0), 6)
		flashlight = SpotLight3D.new()
		flashlight.light_color = Color(1, 0.95, 0.8)
		flashlight.light_energy = 3.5
		flashlight.spot_range = 16.0
		flashlight.spot_angle = 24.0
		flashlight.shadow_enabled = false
		flashlight.position = Vector3(-0.1, pelvis_y + torso_h * 0.75, -0.3)
		flashlight.rotation.x = -0.18
		rig.add_child(flashlight)

	speech_label = Build.label(self, "", Vector3(0, _height + 0.4, 0), Color(1, 1, 0.9), 44, 0.0, true)
	speech_label.pixel_size = 0.005
	speech_label.width = 600.0
	speech_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech_label.visible = false


func _radio_prop(torso_h: float, front_r: float) -> void:
	_detail(Build.box(torso, Vector3(0.08, 0.13, 0.05), Vector3(P.tw * 0.45, torso_h * 0.8, -front_r - 0.02), Color(0.08, 0.08, 0.08), false))
	_detail(Build.cyl(torso, 0.008, 0.008, 0.16, Vector3(P.tw * 0.45 + 0.025, torso_h * 0.8 + 0.14, -front_r - 0.02), Color(0.08, 0.08, 0.08), false, 4))


func _detail(mi: GeometryInstance3D) -> void:
	# small decorative parts: no shadows, culled at distance (keeps 25+ characters cheap)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 30.0


func _prism(s: Vector3) -> PrismMesh:
	var p := PrismMesh.new()
	p.size = s
	return p


func _front_r() -> float:
	if body == "round":
		return P.tw * 0.95
	if P.belly > 0.0:
		return P.tw + P.belly * 0.5
	return P.tw


func _hair_and_hat(h: Node3D, r: float, is_clown: bool) -> void:
	if role == "worker":
		var hat := Build.sphere(h, r * 1.08, Vector3(0, r * 1.35, 0), Build.mat(Color(1, 0.82, 0.1)), 12)
		hat.scale = Vector3(1, 0.75, 1.05)
		Build.cyl(h, r * 1.3, r * 1.3, 0.03, Vector3(0, r * 1.3, -r * 0.1), Color(1, 0.82, 0.1), false, 12)
		return
	if role == "guard":
		Build.cyl(h, r * 1.1, r * 1.0, r * 0.45, Vector3(0, r * 1.7, 0), Color(0.08, 0.1, 0.2), false, 10)
		Build.mesh(h, _boxm(Vector3(r * 1.3, 0.03, r * 0.7)), Vector3(0, r * 1.5, -r * 0.9), Build.mat(Color(0.05, 0.05, 0.05)))
		_detail(Build.box(h, Vector3(r * 0.3, r * 0.3, 0.02), Vector3(0, r * 1.75, -r * 1.07), Color(1, 0.85, 0.3), false, 1.0))
		return
	if not is_clown:
		var hc: Color = [Color(0.2, 0.12, 0.05), Color(0.05, 0.04, 0.03), Color(0.7, 0.55, 0.2), Color(0.5, 0.2, 0.1)].pick_random()
		var hair := Build.sphere(h, r * 1.04, Vector3(0, r * 1.18, r * 0.12), Build.mat(hc), 10)
		hair.scale = Vector3(1, 0.9, 1)
		if randf() < 0.4:
			Build.sphere(h, r * 0.4, Vector3(0, r * 1.3, r * 1.0), Build.mat(hc), 8)  # ponytail/bun
		return
	var hm := Build.unique_mat(HAIR_COLORS.pick_random())
	costume_mats.append(hm)
	costume_orig.append(hm.albedo_color)
	match randi() % 4:
		0:
			for side in [-1, 1]:
				for k in 3:
					Build.sphere(h, r * (0.35 + k * 0.05), Vector3(side * r * (0.85 + k * 0.12), r * (1.4 - k * 0.25), r * 0.1 + k * r * 0.1), hm, 8)
		1:
			Build.sphere(h, r * 1.25, Vector3(0, r * 1.45, r * 0.15), hm, 12)
		2:
			Build.sphere(h, r * 0.25, Vector3(0, r * 2.0, 0), hm, 8)
		3:
			for k in 5:
				var a := -0.9 + k * 0.45
				var spike := Build.mesh(h, _cone(r * 0.2, r * 0.7), Vector3(sin(a) * r * 0.7, r * 1.75 + cos(a) * r * 0.2, r * 0.1), hm, Vector3(0, 0, -a))
				spike.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var hat_c := _cmat(CLOWN_COLORS.pick_random(), CLOWN_COLORS.pick_random(), [0, 1, 4].pick_random())
	match randi() % 5:
		0:
			Build.mesh(h, _cone(r * 0.55, r * 1.6), Vector3(r * 0.2, r * 2.4, 0), hat_c, Vector3(0, 0, -0.3))
			Build.sphere(h, r * 0.15, Vector3(r * 0.55, r * 3.15, 0), Build.mat(Color(1, 1, 1)), 6)
		1:
			Build.cyl(h, r * 0.35, r * 0.35, r * 0.7, Vector3(0, r * 2.25, 0), Color(0.08, 0.08, 0.1), false, 10)
			Build.cyl(h, r * 0.36, r * 0.36, r * 0.12, Vector3(0, r * 2.0, 0), Color(0.9, 0.15, 0.2), false, 10)
			Build.cyl(h, r * 0.6, r * 0.6, 0.03, Vector3(0, r * 1.9, 0), Color(0.08, 0.08, 0.1), false, 10)
		2:
			Build.sphere(h, r * 0.75, Vector3(0, r * 1.8, 0), hat_c, 10)
			Build.cyl(h, r * 1.05, r * 1.05, 0.03, Vector3(0, r * 1.62, 0), Color(0.1, 0.1, 0.1), false, 12)
		3:
			# tiny propeller beanie
			var beanie := Build.sphere(h, r * 0.7, Vector3(0, r * 1.75, 0), hat_c, 8)
			beanie.scale = Vector3(1, 0.6, 1)
			Build.box(h, Vector3(r * 1.2, 0.02, 0.06), Vector3(0, r * 2.25, 0), Color(1, 0.9, 0.2), false)
		_:
			pass


func _cone(rb: float, hgt: float) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = rb
	cm.height = hgt
	cm.radial_segments = 10
	return cm


func _cmat(c: Color, accent: Color = Color.WHITE, pattern: int = 4) -> StandardMaterial3D:
	var m := Build.unique_mat(c if pattern == 4 else Color.WHITE)
	if pattern != 4:
		m.albedo_texture = Build.pattern_tex(c, accent, pattern)
		m.uv1_scale = Vector3(3, 2, 1)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	costume_mats.append(m)
	costume_orig.append(m.albedo_color)
	return m


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _capsule(parent: Node3D, length: float, radius: float, m: Material) -> void:
	var cm := CapsuleMesh.new()
	cm.radius = radius
	cm.height = maxf(length + radius, radius * 2.01)
	cm.radial_segments = 8
	cm.rings = 2
	Build.mesh(parent, cm, Vector3(0, -length * 0.5, 0), m)


func _boxm(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


func _joint(nm: String, node: Node3D, k: float, damp: float) -> void:
	joints[nm] = [node, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, k, damp]


func _tgt(nm: String, t: Vector3) -> void:
	joints[nm][3] = t


func is_staff() -> bool:
	return role == "worker" or role == "guard"


# ================================================================ main loop
func _physics_process(dt: float) -> void:
	_dt = dt
	if state == RESCUED:
		_rescue_t += dt
		want_vel = Vector3(0, 0, 3.0)
		_apply_motion(dt)
		_animate(dt)
		if _rescue_t > 5.0:
			visible = false
			set_physics_process(false)
		return
	_state_t += dt
	_say_cd -= dt
	_scream_cd -= dt
	stagger_t -= dt
	_speech_tick(dt)
	if keyholder and Engine.get_physics_frames() % 30 == 0:
		GameState.flags["gate_key_last_pos"] = global_position
	if not dead and not hostile and state != TRANSFORM:
		_scan_t -= dt
		if _scan_t <= 0.0:
			_scan_t = 0.4 + randf() * 0.1
			_scan_threats()
	match state:
		PERFORM: _do_perform(dt)
		FLEE: _do_flee(dt)
		HIDE: _do_hide(dt)
		FOLLOW: _do_follow(dt)
		TRANSFORM: _do_transform(dt)
		HOSTILE: _do_hostile(dt)
		DEAD: _do_dead(dt)
		DUTY: _do_duty(dt)
		RETREAT: _do_retreat(dt)
		SAFE: _do_safe(dt)
	_apply_motion(dt)
	_animate(dt)


func _apply_motion(dt: float) -> void:
	var accel := 10.0 if not dead else 1.5
	if stagger_t > 0.0:
		accel = 1.0
	var wv := want_vel
	if _unstick_t > 0.0 and wv.length() > 0.1:
		_unstick_t -= dt
		wv = _unstick_dir * wv.length()
	velocity.x = lerpf(velocity.x, wv.x, minf(1.0, accel * dt))
	velocity.z = lerpf(velocity.z, wv.z, minf(1.0, accel * dt))
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = -0.5
		if dead:
			velocity.x *= 0.9
			velocity.z *= 0.9
	else:
		velocity.y -= 18.0 * dt
	move_and_slide()
	if want_vel.length() > 0.5 and not dead:
		var moved := (global_position - _last_pos).length()
		if moved < want_vel.length() * dt * 0.25:
			_stuck_t += dt
		else:
			_stuck_t = maxf(0.0, _stuck_t - dt)
		if _stuck_t > 0.7:
			_stuck_t = 0.0
			_unstick_t = randf_range(0.4, 0.9)
			_unstick_dir = want_vel.normalized().rotated(Vector3.UP, PI / 2 * (1 if randf() < 0.5 else -1))
			_path_t = 0.0  # force a re-path
	_last_pos = global_position
	if global_position.y < -10.0:
		global_position = home + Vector3(0, 1, 0)


## Direct steering (open ground, short range).
func _go(target: Vector3, speed: float, stop_dist: float = 0.6) -> bool:
	var d := target - global_position
	d.y = 0
	if d.length() < stop_dist:
		want_vel = Vector3.ZERO
		return true
	want_vel = d.normalized() * speed
	return false


## Navmesh steering around buildings and rides. Falls back to direct steering.
func _nav_go(target: Vector3, speed: float, stop_dist: float = 0.6) -> bool:
	var flat := target - global_position
	flat.y = 0
	if flat.length() < stop_dist:
		want_vel = Vector3.ZERO
		return true
	_path_t -= _dt
	if _path_t <= 0.0 or _path_target.distance_to(target) > 1.5:
		_path_t = randf_range(0.8, 1.4)
		_path_target = target
		var map := get_world_3d().navigation_map
		if NavigationServer3D.map_get_iteration_id(map) > 0:
			_path = NavigationServer3D.map_get_path(map, global_position, target, true)
			_path_i = 0
		else:
			_path = PackedVector3Array()
	while _path_i < _path.size():
		var wp := _path[_path_i] - global_position
		wp.y = 0
		if wp.length() < 0.6:
			_path_i += 1
		else:
			break
	var aim := target if _path_i >= _path.size() else _path[_path_i]
	var dir := aim - global_position
	dir.y = 0
	want_vel = dir.normalized() * speed if dir.length() > 0.05 else Vector3.ZERO
	return false


# ================================================================ speech
func say(text: String, dur: float = 2.8) -> void:
	speech_label.text = text
	speech_label.visible = true
	_speech_t = dur
	_say_cd = dur + 2.0


func _speech_tick(dt: float) -> void:
	if _speech_t > 0.0:
		_speech_t -= dt
		if _speech_t <= 0.0:
			speech_label.visible = false


func _near_player(r: float) -> bool:
	var pl = GameState.nearest_player(global_position)
	return pl != null and pl.global_position.distance_to(global_position) < r


# ================================================================ perception
func _scan_threats() -> void:
	for p in GameState.people:
		if p == self or not is_instance_valid(p) or p.dead:
			continue
		if not (p.hostile or p.state == TRANSFORM):
			continue
		var d: float = p.global_position.distance_to(global_position)
		var r := 13.0 if p.hostile else 8.0
		if d < r and (d < 5.0 or _los(global_position + Vector3.UP * 1.5, p.global_position + Vector3.UP * 1.2)):
			threat = p.global_position
			fear = 1.0
			if is_staff():
				if state == DUTY and role == "worker":
					start_retreat()
				return
			if state == PERFORM or (state == HIDE and d < 6.0):
				_start_flee()
			return


func hear_noise(pos: Vector3, source) -> void:
	if dead or rescued:
		return
	if hostile:
		if source != null and source.is_in_group("player"):
			alert_t = 10.0
			last_known = source.global_position
		return
	if is_staff() or state == TRANSFORM:
		return
	fear = maxf(fear, 0.7)
	threat = pos
	if state == PERFORM:
		_start_flee()


func _start_flee() -> void:
	state = FLEE
	_state_t = 0.0
	_drop_props()
	if _scream_cd <= 0.0:
		_scream_cd = randf_range(4.0, 8.0)
		Sfx.play("scream", global_position + Vector3.UP * 1.5, -6.0, randf_range(0.8, 1.3))
	if _say_cd <= 0.0:
		say(SCARED_LINES.pick_random())


func _los(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1 | 16)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


# ================================================================ civilians & clowns
func _pick_perform() -> void:
	var opts: Array
	if role == "clown":
		opts = ["juggle", "honk", "wave", "flower", "trip", "wander", "wander", "juggle"]
	else:
		opts = ["wander", "wander", "idle", "wave"]
	perform = opts.pick_random()
	perform_t = randf_range(6.0, 11.0)
	_act = 0.0
	_trip = 0.0
	flower_given = false
	_drop_props()
	move_target = home + Vector3(randf_range(-7, 7), 0, randf_range(-7, 7))
	if perform == "juggle":
		for b in juggle_balls:
			b.visible = true
	elif perform == "flower":
		flower.visible = true


func _drop_props() -> void:
	for b in juggle_balls:
		b.visible = false
	flower.visible = false


func _do_perform(dt: float) -> void:
	perform_t -= dt
	_act += dt
	face_point = null
	if perform_t <= 0.0:
		_pick_perform()
	match perform:
		"wander", "trip":
			if _trip > 0.0:
				want_vel = Vector3.ZERO
			elif _nav_go(move_target, P.speed * 0.7):
				move_target = home + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))
			if perform == "trip" and _act > 2.0 and _trip == 0.0:
				_trip = 0.001
				Sfx.play("squeak", global_position, -4.0, 0.7)
		"flower":
			var pl = GameState.nearest_player(global_position)
			if pl and pl.global_position.distance_to(global_position) < 12.0:
				face_point = pl.global_position
				if _go(pl.global_position, P.speed * 0.6, 2.2) and not flower_given:
					flower_given = true
					say("For you!")
			else:
				want_vel = Vector3.ZERO
		"wave":
			want_vel = Vector3.ZERO
			var pl2 = GameState.nearest_player(global_position)
			if pl2 and pl2.global_position.distance_to(global_position) < 16.0:
				face_point = pl2.global_position
		_:
			want_vel = Vector3.ZERO
	if perform == "honk":
		_honk_t -= dt
		if _honk_t <= 0.0:
			_honk_t = randf_range(1.4, 2.4)
			if _near_player(32.0):
				Sfx.play("honk", global_position + Vector3.UP * _height, -2.0, 1.4 - P.head * 1.5)
			if randf() < 0.25 and _say_cd <= 0.0 and _near_player(14.0):
				say(CLOWN_LINES.pick_random())


func _do_flee(_dt2: float) -> void:
	var away := global_position - threat
	away.y = 0
	if away.length() < 0.1:
		away = Vector3(randf() - 0.5, 0, randf() - 0.5)
	want_vel = away.normalized() * P.speed * 2.3
	if _state_t > randf_range(4.0, 6.0):
		state = HIDE
		_state_t = 0.0


func _do_hide(dt: float) -> void:
	want_vel = Vector3.ZERO
	fear -= dt * 0.08
	if fear < 0.2:
		if is_staff():
			state = DUTY
			return
		state = PERFORM
		home = global_position
		_pick_perform()


func _do_follow(dt: float) -> void:
	if follow_target == null or not is_instance_valid(follow_target) or follow_target.dead:
		if is_staff():
			start_retreat(true)
		else:
			state = HIDE
		return
	var tp: Vector3 = follow_target.global_position
	var d := global_position.distance_to(tp)
	face_point = null
	var spd: float = P.speed * (2.4 if d > 7.0 else 1.3)
	if role == "worker" and not GameState.flags.get("shed_unlocked", false):
		var door_pos: Vector3 = GameState.flags.get("shed_door_pos", Vector3.ZERO)
		if global_position.distance_to(door_pos) < 5.0 and d < 10.0:
			if worker_unlocking < 0.0:
				worker_unlocking = 1.8
				say("Hold on... got it. Shotgun's in there!")
			_go(door_pos, P.speed, 0.8)
			face_point = door_pos
			worker_unlocking -= dt
			if worker_unlocking <= 0.0:
				var door = GameState.flags.get("shed_door")
				if door and is_instance_valid(door):
					door.open_door()
			return
	if d > 2.6:
		if d < 6.0 and _los(global_position + Vector3.UP * 1.4, tp + Vector3.UP * 1.4):
			_go(tp, spd, 2.6)
		else:
			_nav_go(tp, spd, 2.6)
	else:
		want_vel = Vector3.ZERO
	if role == "guard":
		_guard_engage(dt)
	if GameState.flags.get("gate_open", false) and global_position.z > 43.5:
		_get_rescued()


func _get_rescued() -> void:
	if rescued:
		return
	rescued = true
	state = RESCUED
	collision_layer = 0
	collision_mask = 1
	if flashlight:
		flashlight.visible = false
	if role == "worker":
		GameState.worker_rescued = true
	say("Thank you!")
	Sfx.play("pickup", global_position, -4.0, 0.8)


# ================================================================ staff: duty, retreat, safe house
func _do_duty(dt: float) -> void:
	if duty_points.is_empty():
		want_vel = Vector3.ZERO
		return
	var target: Vector3 = duty_points[_duty_i]
	if role == "guard":
		var firing := _guard_engage(dt)
		if firing:
			want_vel = Vector3.ZERO
			return
		var pl = GameState.nearest_player(global_position)
		if pl and not guard_greeted and pl.global_position.distance_to(global_position) < 9.0:
			guard_greeted = true
			say("Evening. Stay close to the lights tonight.")
			GameState.think("Security's armed. They won't hand those guns over easily.", "guard_seen")
		if _duty_work > 0.0:
			_duty_work -= dt
			want_vel = Vector3.ZERO
			if pl and pl.global_position.distance_to(global_position) < 7.0:
				face_point = pl.global_position
			return
		face_point = null
		if _nav_go(target, P.speed * 0.75, 0.9):
			_duty_work = randf_range(1.5, 3.5)
			_duty_i = (_duty_i + 1) % duty_points.size()
		return
	# workers: walk to a job, fix it, move on
	if _duty_work > 0.0:
		_duty_work -= dt
		want_vel = Vector3.ZERO
		_act += dt
		if fmod(_act, 0.55) < dt and _near_player(25.0):
			Sfx.play("click", hand_l.global_position, -10.0, 1.6)
			var scene := get_tree().current_scene
			if scene.has_method("spawn_impact") and randf() < 0.4:
				scene.spawn_impact(hand_l.global_position, Color(1, 0.7, 0.3))
		if _duty_work <= 0.0:
			_duty_i = (_duty_i + 1) % duty_points.size()
		return
	face_point = null
	if _nav_go(target, P.speed * 0.8, 0.9):
		_duty_work = randf_range(6.0, 10.0)
		_act = 0.0
		face_point = target + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))


## Called by GameState.order_retreat (radio) or when a worker sees the infected.
func start_retreat(force: bool = false) -> void:
	if not is_staff() or dead or hostile or fog_affected or rescued:
		return
	if state == SAFE or state == RETREAT:
		return
	if state == FOLLOW and GameState.flags.get("gate_open", false) and not force:
		return  # being escorted out of an open gate is the better escape
	state = RETREAT
	_state_t = 0.0
	follow_target = null
	_duty_work = 0.0
	_path_t = 0.0
	_drop_props()
	say("Falling back to the shed!" if role == "worker" else "Copy! Falling back to the office!", 2.5)


func _safe_slot() -> Vector3:
	var sh: Dictionary = GameState.safehouses.get(role, {})
	if sh.is_empty():
		return home
	var slots: Array = sh.slots
	return slots[staff_index % slots.size()]


func _do_retreat(dt: float) -> void:
	var slot := _safe_slot()
	var spd: float = P.speed * 2.2
	if role == "guard" and _guard_engage(dt):
		spd *= 0.4  # shoot-and-scoot
	if _nav_go(slot, spd, 0.6):
		state = SAFE
		_state_t = 0.0
		if flashlight:
			flashlight.visible = false
		say("Made it... lock it, LOCK IT!" if role == "worker" else "Office secure.", 2.5)
		if role == "worker":
			# the crew is inside now and will let a living person in when they knock
			GameState.flags["workers_sheltering"] = true
	elif _state_t > 90.0:
		_state_t = 0.0
		_path_t = 0.0


func _do_safe(dt: float) -> void:
	var slot := _safe_slot()
	if global_position.distance_to(slot) > 1.4:
		_nav_go(slot, P.speed, 0.5)
	else:
		want_vel = Vector3.ZERO
	var sh: Dictionary = GameState.safehouses.get(role, {})
	if sh.has("door") and is_instance_valid(sh.door):
		face_point = sh.door.global_position
	if role == "guard":
		_guard_engage(dt)
	var pl = GameState.nearest_player(global_position)
	if pl and _say_cd <= 0.0 and pl.global_position.distance_to(global_position) < 6.0 and randf() < 0.02:
		if sh.has("door") and is_instance_valid(sh.door) and sh.door.opened and sh.door._hostile_near(14.0):
			say("Close the door! They're RIGHT THERE!")
		else:
			say(SAFE_LINES[role].pick_random(), 3.5)
		_say_cd = 9.0


func is_safe_inside() -> bool:
	return state == SAFE and not dead and not hostile and not fog_affected and not rescued


func wants_door() -> bool:
	return state == RETREAT or state == FOLLOW


func _keyholder_hint() -> String:
	for p in GameState.people:
		if is_instance_valid(p) and p.keyholder and not p.dead and not p.fog_affected:
			if p == self:
				return ""
			return "%s has the gate key — usually working near %s." % [p.staff_name, p.duty_area]
	return ""


# ================================================================ interaction
func get_prompt(player) -> String:
	if dead or hostile or rescued or state == TRANSFORM:
		return ""
	var gate_open: bool = GameState.flags.get("gate_open", false)
	if role == "worker" and keyholder and not player.has_item("gate_key"):
		return "[E] Ask %s for the gate key" % staff_name
	if is_staff():
		match state:
			RETREAT:
				return "[E] Talk to %s" % staff_name
			SAFE:
				return "[E] \"The gate's open — follow me!\"" if gate_open else "[E] Talk to %s" % staff_name
			FOLLOW:
				return "[E] \"Wait here.\""
		if role == "guard":
			return "[E] \"Gate's open, come on!\"" if gate_open else "[E] Talk to %s" % staff_name
		return "[E] \"Come with me, %s.\"" % staff_name
	if state == FOLLOW:
		return "[E] \"Wait here.\""
	return "[E] \"Come with me, I'll get you out!\""


func interact(player) -> void:
	if dead or hostile or rescued or state == TRANSFORM:
		return
	var gate_open: bool = GameState.flags.get("gate_open", false)
	if role == "worker" and keyholder and not player.has_item("gate_key"):
		keyholder = false
		player.give("gate_key")
		say("The gate key... here. Get as many people out as you can.", 3.5)
		return
	if is_staff():
		match state:
			RETREAT:
				say("No time! Get somewhere safe!")
				return
			SAFE:
				if gate_open and not guard_angry:
					_follow(player, "Okay... okay. Right behind you.")
				else:
					var hint := _keyholder_hint() if role == "worker" else ""
					say(hint if hint != "" and not player.has_item("gate_key") else SAFE_LINES[role].pick_random(), 3.5)
				return
			FOLLOW:
				state = DUTY
				follow_target = null
				if GameState.flags.get("staff_alarm_" + role, false):
					start_retreat(true)
				else:
					say("I'll get back to it, then.")
				return
		if role == "guard":
			if gate_open and not guard_angry:
				_follow(player, "Gate's open? ...Fine. Lead the way. Gun stays with me.")
			elif guard_angry:
				say("You stay the hell away from me!")
			else:
				say(["Move along. This SMG stays with me.", "Weird fog tonight. Keep your distance from it.", "You want my weapon? Over my dead body, pal.", "Clowns are acting funny. Funnier than usual."].pick_random(), 3.2)
			return
		var hint2 := _keyholder_hint()
		_follow(player, (hint2 + " I'll tag along.") if hint2 != "" and not _hinted else "Sure, I'll come. Safer in numbers.")
		_hinted = true
		return
	if state == FOLLOW:
		state = HIDE
		fear = 0.5
		follow_target = null
		say("Okay... I'll wait here.")
	else:
		_follow(player, ["Really? Okay, okay!", "Please don't leave me!", "Right behind you!", "Is it safe out there?"].pick_random())


func _follow(player, line: String) -> void:
	state = FOLLOW
	follow_target = player
	_drop_props()
	_path_t = 0.0
	say(line, 3.5)
	if role == "worker":
		GameState.flags["worker_following"] = true


# ================================================================ guard combat
## Shoots the nearest visible hostile (or the player, if provoked). Returns true while engaging.
func _guard_engage(dt: float) -> bool:
	shoot_cd -= dt
	aim_t -= dt
	var pl = GameState.nearest_player(global_position)
	var target = null
	if guard_angry and pl and not pl.dead and pl.global_position.distance_to(global_position) < 25.0 and _los(global_position + Vector3.UP * 1.6, pl.global_position + Vector3.UP * 1.4):
		target = pl
	else:
		var best := 16.0
		for p in GameState.people:
			if is_instance_valid(p) and p.hostile and not p.dead:
				var d: float = p.global_position.distance_to(global_position)
				if d < best and _los(global_position + Vector3.UP * 1.6, p.global_position + Vector3.UP * 1.2):
					best = d
					target = p
	if target == null:
		return false
	face_point = target.global_position
	aim_t = 0.4
	if shoot_cd <= 0.0:
		shoot_cd = 0.11 if burst_left > 0 else randf_range(0.7, 1.2)
		if burst_left <= 0:
			burst_left = 4
		burst_left -= 1
		var spread := 0.1 if target == pl else 0.06
		_fire_at(target.global_position + Vector3.UP * 1.2, spread, 6.0 if target == pl else 12.0, "smg")
	return true


# ================================================================ fog & transformation
func add_fog(dt: float) -> void:
	if fog_affected or dead or rescued or state == SAFE:
		return  # sealed safe houses keep the fog out
	fog_exposure += dt
	if fog_exposure > 0.8:
		_begin_transform()


func _begin_transform() -> void:
	fog_affected = true
	var was_staff := is_staff()
	state = TRANSFORM
	_state_t = 0.0
	follow_target = null
	_drop_props()
	if flashlight:
		flashlight.visible = false
	Sfx.play("transform", global_position + Vector3.UP, 0.0)
	if keyholder:
		_drop_key("gate_key")
	if was_staff:
		# one last desperate radio call, then everyone of the same trade runs for it
		var lines: Array = WORKER_RADIO if role == "worker" else GUARD_RADIO
		var who := "%s (%s)" % [staff_name, "Maintenance" if role == "worker" else "Security"]
		GameState.radio_call(who, (lines.pick_random() as String) % staff_name)
		say("—get to the " + ("shed!" if role == "worker" else "office!"), 2.0)
		GameState.flags["staff_alarm_" + role] = true
		GameState.order_retreat(role)
		if role == "worker":
			_drop_shed_key_if_needed()
	else:
		speech_label.visible = false
	var pl = GameState.nearest_player(global_position)
	if pl and pl.global_position.distance_to(global_position) < 35.0:
		match role:
			"clown":
				GameState.think("Something's wrong with that clown.", "first_transform")
			"worker":
				GameState.think("The maintenance guy... the fog got him.", "worker_turn")
			"guard":
				GameState.think("The guard... the fog's got him. And his gun.", "guard_turn")
			_:
				GameState.think("That fog is doing something to them...", "civ_turn")


func _drop_key(kind: String) -> void:
	if kind == "gate_key":
		keyholder = false
	var p := global_position
	p.x = clampf(p.x, -40.0, 40.0)
	p.z = clampf(p.z, -40.0, 40.0)
	p.y = 0.7
	var scene := get_tree().current_scene
	if scene.has_method("spawn_pickup"):
		scene.spawn_pickup(kind, p)
	if kind == "gate_key":
		var pl = GameState.nearest_player(global_position)
		if pl and pl.global_position.distance_to(global_position) < 40.0:
			GameState.think("Something golden just hit the ground over there... the gate key?", "key_dropped")


func _drop_shed_key_if_needed() -> void:
	if GameState.flags.get("shed_unlocked", false) or GameState.flags.get("shed_key_dropped", false):
		return
	GameState.flags["shed_key_dropped"] = true
	_drop_key("shed_key")


func _do_transform(dt: float) -> void:
	want_vel = Vector3.ZERO
	var u := clampf(_state_t / 3.0, 0.0, 1.0)
	_twitch_t -= dt
	if _twitch_t <= 0.0:
		_twitch_t = randf_range(0.05, 0.18)
		twitch = Vector3(randf_range(-0.5, 0.5), randf_range(-0.8, 0.8), randf_range(-0.5, 0.5)) * (0.4 + u)
	_set_corruption(u)
	if _state_t > 3.0:
		hostile = true
		state = HOSTILE
		_state_t = 0.0
		gun.visible = role != "worker"
		if tool:
			tool.visible = false
		shoot_cd = randf_range(1.0, 2.5)
		Sfx.play("giggle", global_position + Vector3.UP * _height, 0.0, 0.8)
		if is_staff():
			say("...hee.")


func _set_corruption(u: float) -> void:
	_corrupt = u
	for i in costume_mats.size():
		var orig: Color = costume_orig[i]
		var m: StandardMaterial3D = costume_mats[i]
		m.albedo_color = orig.lerp(orig.darkened(0.6).lerp(CORRUPT, 0.45), u)
		if u > 0.0 and not m.emission_enabled:
			m.emission_enabled = true
			m.emission = Color(0.35, 0.05, 0.55)
		m.emission_energy_multiplier = u * 0.18
		m.rim_tint = 1.0
	skin_mat.albedo_color = skin_mat.albedo_color.lerp(Color(0.6, 0.55, 0.68), u * 0.1)
	eye_mat.emission_energy_multiplier = u * 7.0
	mouth_mat.albedo_color = Color(0.85, 0.05, 0.12).lerp(Color(0.05, 0.0, 0.05), u)
	mouth_mat.emission_energy_multiplier = u * 1.5
	mouth.scale = Vector3(1.0 + u * 0.8, 1.0 + u * 1.4, 1.0)


# ================================================================ hostile
func _do_hostile(dt: float) -> void:
	shoot_cd -= dt
	giggle_cd -= dt
	aim_t -= dt
	_burst_t -= dt
	var pl = GameState.nearest_player(global_position)
	var d := 999.0
	var to_pl := Vector3.ZERO
	if pl:
		to_pl = pl.global_position - global_position
		to_pl.y = 0
		d = to_pl.length()
	_scan_t -= dt
	if _scan_t <= 0.0 and pl:
		_scan_t = 0.2
		var seen := _los(global_position + Vector3.UP * (_height - 0.2), pl.global_position + Vector3.UP * 1.3)
		var detect_r: float = 4.0 + 26.0 * pl.noise_level
		var fwd := Vector3(-sin(facing), 0, -cos(facing))
		var in_fov := fwd.dot(to_pl.normalized()) > 0.1
		if (seen and d < detect_r and (in_fov or d < detect_r * 0.5)) or d < 2.2:
			if alert_t <= 0.0 and not _spotted_once:
				_spotted_once = true
				Sfx.play("giggle", global_position + Vector3.UP * _height, 2.0)
				if pl.has_method("on_spotted"):
					pl.on_spotted(self)
			alert_t = 10.0
			last_known = pl.global_position
		elif seen and alert_t > 0.0:
			last_known = pl.global_position
			alert_t = 10.0
		else:
			alert_t -= 0.2
	if giggle_cd <= 0.0:
		giggle_cd = randf_range(7.0, 14.0)
		if d < 25.0:
			Sfx.play("giggle" if randf() < 0.7 else "honk", global_position + Vector3.UP * _height, -3.0, randf_range(0.6, 0.9))

	# unpredictable: twitch, freeze-frame glitches, sudden lunges
	_twitch_t -= dt
	if _twitch_t <= 0.0:
		_twitch_t = randf_range(0.25, 1.2)
		twitch = Vector3(randf_range(-0.4, 0.4), randf_range(-0.8, 0.8), randf_range(-0.5, 0.5))
		if randf() < 0.18:
			_glitch_t = randf_range(0.15, 0.45)
		if randf() < 0.12 and alert_t > 0.0:
			_burst_t = randf_range(0.6, 1.1)
	else:
		twitch = twitch.lerp(Vector3.ZERO, dt * 3.0)
	_glitch_t -= dt

	var fast: float = P.speed * 1.65 * (1.8 if _burst_t > 0.0 else 1.0)
	if melee != "":
		_do_melee(dt, pl, d, to_pl)
		return
	if alert_t > 0.0 and pl and not pl.dead:
		face_point = pl.global_position if d < 25.0 else null
		if d < 2.6:
			melee = "windup"
			melee_t = 0.0
			gun.visible = false
			hammer.visible = true
			Sfx.play("squeak", global_position + Vector3.UP * 2.0, 2.0)
			return
		var wobble := Vector3(-to_pl.z, 0, to_pl.x).normalized() * sin(_state_t * 3.0) * 0.4
		if aim_t > 0.0 or _glitch_t > 0.0:
			want_vel = want_vel.lerp(Vector3.ZERO, dt * 8.0)
		else:
			if d < 8.0 and _los(global_position + Vector3.UP * 1.2, pl.global_position + Vector3.UP * 1.2):
				_go(last_known, fast, 1.0)
			else:
				_nav_go(last_known, fast, 1.0)
			want_vel += wobble * fast * 0.3
		var ranged := role != "worker"
		if ranged and d > 4.0 and d < 24.0 and shoot_cd <= 0.0 and aim_t <= 0.0:
			if _los(global_position + Vector3.UP * 1.5, pl.global_position + Vector3.UP * 1.3):
				aim_t = 0.45
				burst_left = 3 if role == "guard" else 1
		if aim_t > 0.0 and aim_t < 0.15 and burst_left > 0:
			burst_left -= 1
			var spread := clampf(0.08 + d * 0.012, 0.1, 0.32)
			if role == "guard":
				_fire_at(pl.global_position + Vector3.UP * 1.2, spread, 6.0, "smg")
				aim_t = 0.3 if burst_left > 0 else 0.0
			else:
				_fire_at(pl.global_position + Vector3.UP * 1.2, spread, 10.0, "clown_gun")
			shoot_cd = randf_range(1.8, 3.2)
		if not hammer.visible and ranged:
			gun.visible = true
	else:
		face_point = null
		aim_t = 0.0
		if _glitch_t > 0.0:
			want_vel = Vector3.ZERO
		elif _nav_go(move_target, P.speed * 0.5, 1.0) or _state_t > 9.0:
			_state_t = 0.0
			move_target = global_position + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
			move_target.x = clampf(move_target.x, -38, 38)
			move_target.z = clampf(move_target.z, -38, 38)


func _do_melee(dt: float, pl, d: float, to_pl: Vector3) -> void:
	melee_t += dt
	match melee:
		"windup":
			if pl:
				face_point = pl.global_position
			want_vel = to_pl.normalized() * 1.0 if d > 1.8 else Vector3.ZERO
			if melee_t > 0.85:
				melee = "swing"
				melee_t = 0.0
				Sfx.play("whoosh", global_position + Vector3.UP * 2.0)
		"swing":
			want_vel = Vector3.ZERO
			if melee_t > 0.16:
				melee = "recover"
				melee_t = 0.0
				var fwd := Vector3(-sin(facing), 0, -cos(facing))
				if pl and not pl.dead and d < 3.1 and fwd.dot(to_pl.normalized()) > 0.25:
					pl.take_hit(52.0, global_position, 11.0, 2.0, self)
					Sfx.play("hammer_hit", pl.global_position + Vector3.UP, 4.0)
					Sfx.play("boing", pl.global_position + Vector3.UP, 0.0)
				else:
					Sfx.play("hammer_hit", global_position + fwd * 2.0, -4.0, 1.3)
		"recover":
			want_vel = Vector3.ZERO
			if melee_t > 0.9:
				melee = ""
				if d > 4.0 and role != "worker":
					hammer.visible = false
					gun.visible = true


func _fire_at(target: Vector3, spread: float, dmg: float, snd: String) -> void:
	var from: Vector3 = global_position + Vector3.UP * (pelvis_y + P.torso * 0.8)
	var dir: Vector3 = (target - from).normalized()
	dir = dir.rotated(Vector3.UP, randf_range(-spread, spread))
	dir = dir.rotated(dir.cross(Vector3.UP).normalized(), randf_range(-spread, spread) * 0.6)
	Sfx.play(snd, from, 0.0 if snd != "smg" else -3.0)
	GameState.noise_event(from, 22.0, self)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 45.0, 1 | 2 | 4 | 16)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var scene := get_tree().current_scene
	if scene.has_method("spawn_tracer"):
		scene.spawn_tracer(from, hit.position if hit else from + dir * 45.0)
	if hit:
		var col = hit.collider
		if col and col.is_in_group("player"):
			col.take_hit(dmg, from, 1.5, 0.0, self)
		elif col and col.has_method("take_damage"):
			col.take_damage(dmg, from, self)
		elif scene.has_method("spawn_impact"):
			scene.spawn_impact(hit.position, Color(1, 0.8, 0.4))
			if randf() < 0.4:
				Sfx.play("ricochet", hit.position, -4.0)


# ================================================================ damage & death
func take_damage(amount: float, from_pos: Vector3, attacker) -> void:
	if dead or rescued:
		return
	hp -= amount
	var dir := global_position - from_pos
	dir.y = 0
	dir = dir.normalized()
	velocity += dir * (2.0 + amount * 0.06)
	stagger_t = 0.25
	Sfx.play("flesh", global_position + Vector3.UP * 1.2)
	var scene := get_tree().current_scene
	if scene.has_method("spawn_impact"):
		scene.spawn_impact(global_position + Vector3.UP * pelvis_y * 1.3, Color(0.9, 0.1, 0.4) if not hostile else Color(0.6, 0.1, 0.9))
	var by_player: bool = attacker != null and is_instance_valid(attacker) and attacker.is_in_group("player")
	if hostile:
		alert_t = 10.0
		if attacker and is_instance_valid(attacker):
			last_known = attacker.global_position
	elif by_player and state != TRANSFORM:
		if role == "guard":
			guard_angry = true
			if state == FOLLOW:
				state = DUTY
				follow_target = null
			say("That's it, you're dead!")
		else:
			fear = 1.0
			threat = from_pos
			follow_target = null
			say("Ow! What are you DOING?!")
			if is_staff():
				start_retreat(true)
			else:
				_start_flee()
	if hp <= 0.0:
		_die(dir * (3.0 + amount * 0.15), by_player)


func _die(impulse: Vector3, by_player: bool) -> void:
	dead = true
	state = DEAD
	if by_player and not fog_affected:
		GameState.innocents_killed += 1
		GameState.think("...They were just scared. What am I doing?", "killed_innocent")
	collision_layer = 0
	collision_mask = 1
	velocity = impulse + Vector3(0, 4.0 + randf() * 3.0, 0)
	fall_v = randf_range(5.0, 8.0)
	spin_v = randf_range(-8.0, 8.0)
	speech_label.visible = false
	_drop_props()
	gun.visible = false
	hammer.visible = false
	if flashlight:
		flashlight.visible = false
	eye_mat.emission_energy_multiplier = 0.0
	for nm in joints:
		var j: Array = joints[nm]
		if j.size() > 4:
			j[4] = j[4] * 0.3
			j[2] = Vector3(randf_range(-12, 12), randf_range(-8, 8), randf_range(-12, 12))
	if role == "clown":
		Sfx.play("boing", global_position + Vector3.UP, 0.0)
		Sfx.play("honk", global_position + Vector3.UP, -2.0, 0.5)
	else:
		Sfx.play("hurt", global_position + Vector3.UP, 0.0)
	# staff deaths go out over the radio too, if they were still human
	if is_staff() and not fog_affected:
		GameState.radio_call("%s (%s)" % [staff_name, "Maintenance" if role == "worker" else "Security"], "—AAGH— man down, man d—")
	var scene := get_tree().current_scene
	if scene.has_method("spawn_pickup"):
		var dp := global_position + Vector3.UP * 0.6
		if keyholder:
			_drop_key("gate_key")
		if role == "worker":
			_drop_shed_key_if_needed()
		elif role == "guard":
			scene.spawn_pickup("smg", dp)
			scene.spawn_pickup("ammo_smg", dp + Vector3(0.6, 0, 0.3))
		elif hostile and randf() < 0.45:
			scene.spawn_pickup(["ammo_pistol", "ammo_pistol", "ammo_shells", "ammo"].pick_random(), dp)


func _do_dead(dt: float) -> void:
	want_vel = Vector3.ZERO
	fall += fall_v * dt
	fall_v += 9.0 * dt
	if fall > 1.5:
		fall = 1.5
		fall_v = -absf(fall_v) * 0.35
		if absf(fall_v) < 0.4:
			fall_v = 0.0
	if not is_on_floor():
		facing += spin_v * dt
	spin_v *= 0.97


# ================================================================ procedural animation
func _animate(dt: float) -> void:
	var hv := Vector2(velocity.x, velocity.z).length()
	var sf := clampf(hv / P.speed, 0.0, 2.2)
	if dead:
		sf = 0.0
	if sf > 0.05:
		phase += dt * P.freq * TAU * (0.35 + sf * 0.65)
		var sg := signf(sin(phase))
		if sg != _last_step_sign:
			_last_step_sign = sg
			if sf > 0.3 and _near_player(20.0) and is_on_floor():
				if P.shoe > 0.3:
					Sfx.play("flop", global_position, -8.0 + P.shoe * 6.0, 1.2 - P.shoe * 0.6, 25.0)
				else:
					Sfx.play("step", global_position, -12.0, 1.0, 20.0)
	else:
		phase = lerpf(phase, roundf(phase / PI) * PI, dt * 4.0)

	# facing
	if not dead:
		var look_dir := Vector3.ZERO
		if face_point != null:
			look_dir = face_point - global_position
		elif hv > 0.3:
			look_dir = Vector3(velocity.x, 0, velocity.z)
		if look_dir.length() > 0.1:
			facing = lerp_angle(facing, atan2(-look_dir.x, -look_dir.z), minf(1.0, dt * 6.0))
	rig.rotation = Vector3(0, facing + twitch.y * 0.3, 0)

	var amp := minf(sf, 1.6)
	var s := sin(phase)
	var c := cos(phase)
	var hostile_hunch := 0.45 if hostile else 0.0
	var scared := state == FLEE or (state == HIDE and fear > 0.2) or state == RETREAT or state == SAFE

	# legs
	_tgt("hipL", Vector3(s * P.stride * amp, 0, -0.05))
	_tgt("hipR", Vector3(-s * P.stride * amp, 0, 0.05))
	_tgt("kneeL", Vector3(-(0.1 + maxf(0.0, -c) * 0.9) * amp, 0, 0))
	_tgt("kneeR", Vector3(-(0.1 + maxf(0.0, c) * 0.9) * amp, 0, 0))
	var aw: float = P.armswing * amp
	_tgt("shL", Vector3(-s * aw + 0.1, 0, -0.15 - absf(s) * 0.1 * amp))
	_tgt("shR", Vector3(s * aw + 0.1, 0, 0.15 + absf(s) * 0.1 * amp))
	_tgt("elL", Vector3(0.25 + amp * 0.35, 0, 0))
	_tgt("elR", Vector3(0.25 + amp * 0.35, 0, 0))
	_tgt("torso", Vector3(-amp * 0.12 - hostile_hunch, s * 0.15 * amp, s * P.sway * amp) + twitch * 0.5)
	var head_t := Vector3(c * 0.1 * amp, 0, -s * P.sway * 0.7 * amp) + twitch
	# curious head-turn toward a nearby player (normal people only)
	if not hostile and not dead and state != TRANSFORM:
		var pl = GameState.nearest_player(global_position)
		if pl and pl.global_position.distance_to(global_position) < 8.0:
			var to: Vector3 = pl.global_position - global_position
			var rel := wrapf(atan2(-to.x, -to.z) - facing, -PI, PI)
			head_t.y = clampf(rel, -1.0, 1.0)
	_tgt("head", head_t)
	var py: float = pelvis_y + (absf(c) - 0.6) * P.bob * amp

	# --- state-specific poses
	var t := _state_t
	var brow_z := 0.0
	var brow_y := 0.0
	if state == PERFORM:
		brow_y = 0.02
		match perform:
			"juggle":
				var jt := _act * 5.0
				_tgt("shL", Vector3(1.0 + sin(jt) * 0.35, 0, -0.25))
				_tgt("shR", Vector3(1.0 + sin(jt + PI) * 0.35, 0, 0.25))
				_tgt("elL", Vector3(0.9, 0, 0))
				_tgt("elR", Vector3(0.9, 0, 0))
				var center := Vector3(0, pelvis_y + P.torso * 0.9 + 0.35, -0.45 - P.tw)
				for i in 3:
					var a := jt * 1.4 + i * TAU / 3.0
					juggle_balls[i].position = center + Vector3(cos(a) * 0.35, absf(sin(a)) * 0.6, 0)
			"honk":
				if _honk_t > 1.0:
					_tgt("shR", Vector3(2.3, 0, 0.3))
					_tgt("elR", Vector3(1.9, 0, 0))
					nose.scale = Vector3.ONE * (1.0 + maxf(0.0, _honk_t - 1.0) * 1.2)
				else:
					nose.scale = Vector3.ONE
			"wave":
				_tgt("shR", Vector3(0.2, 0, 2.6))
				_tgt("elR", Vector3(0.0, 0, sin(_act * 9.0) * 0.6))
				_tgt("shL", Vector3(0, 0, -0.2))
			"flower":
				_tgt("shR", Vector3(1.45, 0, 0.1))
				_tgt("elR", Vector3(0.1, 0, 0))
		if _trip > 0.0:
			_trip += dt
			if _trip < 0.35:
				fall = -_trip / 0.35 * 1.35
			elif _trip < 1.8:
				fall = -1.35
				_tgt("shL", Vector3(2.8, 0, -0.6))
				_tgt("shR", Vector3(2.8, 0, 0.6))
			elif _trip < 2.6:
				fall = lerpf(-1.35, 0.0, (_trip - 1.8) / 0.8)
			else:
				fall = 0.0
				_trip = 0.0
				_act = 0.0
				perform = "wander"
	elif state == DUTY and role == "worker" and _duty_work > 0.0:
		# kneel and wrench away at a ride
		py = pelvis_y * 0.72
		_tgt("hipL", Vector3(1.0, 0, -0.15))
		_tgt("hipR", Vector3(0.3, 0, 0.15))
		_tgt("kneeL", Vector3(-1.6, 0, 0))
		_tgt("kneeR", Vector3(-1.2, 0, 0))
		_tgt("torso", Vector3(-0.45, 0, 0))
		_tgt("shL", Vector3(1.3 + sin(_act * 11.0) * 0.4, 0, -0.1))
		_tgt("elL", Vector3(0.6, 0, 0))
		_tgt("shR", Vector3(0.9, 0, 0.2))
	elif state == DUTY and role == "guard":
		_tgt("shL", Vector3(1.2, 0, -0.1))  # flashlight forward
		_tgt("elL", Vector3(0.3, 0, 0))
		_tgt("shR", Vector3(0.7, 0, 0.1))
		_tgt("elR", Vector3(0.6, 0, 0))
	elif scared:
		brow_z = 0.35
		brow_y = 0.03
		if state == FLEE or (state == RETREAT and role == "worker"):
			_tgt("shL", Vector3(2.6 + sin(t * 14.0) * 0.4, 0, -0.5))
			_tgt("shR", Vector3(2.6 + sin(t * 14.0 + 1.0) * 0.4, 0, 0.5))
			_tgt("elL", Vector3(0.6, 0, 0))
			_tgt("elR", Vector3(0.6, 0, 0))
		elif state == SAFE and want_vel.length() < 0.1:
			# arms wrapped around themselves, trembling
			_tgt("shL", Vector3(0.9, 0, 0.5))
			_tgt("shR", Vector3(0.9, 0, -0.5))
			_tgt("elL", Vector3(1.6, 0, 0))
			_tgt("elR", Vector3(1.6, 0, 0))
			_tgt("torso", Vector3(-0.15 + sin(t * 30.0) * 0.02, 0, sin(t * 23.0) * 0.02))
			if role == "guard" and aim_t > 0.0:
				_tgt("shR", Vector3(1.55, 0, 0.05))
				_tgt("elR", Vector3(0, 0, 0))
		elif state == HIDE:
			py = pelvis_y * 0.62
			_tgt("hipL", Vector3(1.2, 0, -0.2))
			_tgt("hipR", Vector3(1.2, 0, 0.2))
			_tgt("kneeL", Vector3(-2.0, 0, 0))
			_tgt("kneeR", Vector3(-2.0, 0, 0))
			_tgt("torso", Vector3(-0.5 + sin(t * 30.0) * 0.03, 0, sin(t * 25.0) * 0.03))
			_tgt("shL", Vector3(2.7, 0, -0.4))
			_tgt("shR", Vector3(2.7, 0, 0.4))
			_tgt("elL", Vector3(1.8, 0, 0))
			_tgt("elR", Vector3(1.8, 0, 0))
	elif state == TRANSFORM:
		var u := clampf(t / 3.0, 0.0, 1.0)
		_tgt("head", Vector3(0.3, 0, 1.0 * u) + twitch * 1.5)
		_tgt("shL", twitch * 3.0 + Vector3(u * 0.5, 0, -0.3))
		_tgt("shR", -twitch * 3.0 + Vector3(u * 0.5, 0, 0.3))
		_tgt("torso", Vector3(-0.6 * u, 0, 0) + twitch)
		py = pelvis_y + sin(t * 40.0) * 0.03 + u * 0.15
		brow_z = -0.5 * u
	elif state == HOSTILE:
		brow_z = -0.55
		var cur: Vector3 = joints["head"][3]
		_tgt("head", cur + Vector3(0, 0, 0.55))
		_tgt("shL", Vector3(-s * aw * 1.4 + 0.2, 0, -0.35))
		_tgt("elL", Vector3(0.1, 0, 0))
		if melee == "windup":
			_tgt("shR", Vector3(3.1, 0, 0.2))
			_tgt("elR", Vector3(0.5, 0, 0))
			_tgt("torso", Vector3(0.35, 0, 0) + twitch)
		elif melee == "swing":
			joints["shR"][1] = Vector3(0.6, 0, 0.1)
			_tgt("shR", Vector3(0.6, 0, 0.1))
			_tgt("torso", Vector3(-0.8, 0, 0))
		elif melee == "recover":
			_tgt("shR", Vector3(0.4, 0, 0.2))
			_tgt("torso", Vector3(-0.7, 0, 0))
		elif aim_t > 0.0:
			_tgt("shR", Vector3(1.55 + hostile_hunch, 0, 0.05))
			_tgt("elR", Vector3(0.0, 0, 0))
		elif alert_t <= 0.0:
			# stalking creep: low, swaying, arms dangling
			py = pelvis_y * 0.85
			_tgt("shR", Vector3(-0.1 + twitch.x, 0, 0.1))
			_tgt("elR", Vector3(0.05, 0, 0))
	elif (state == FOLLOW or state == RETREAT) and role == "guard" and aim_t > 0.0:
		_tgt("shR", Vector3(1.55, 0, 0.05))
		_tgt("elR", Vector3(0.0, 0, 0))
	elif state == FOLLOW and role == "worker" and worker_unlocking > 0.0:
		_tgt("shR", Vector3(1.4, 0, 0.1))
		_tgt("elR", Vector3(sin(t * 20.0) * 0.3, 0, 0))

	if dead:
		py = pelvis_y
		_tgt("hipL", Vector3(0.4, 0, -0.5))
		_tgt("hipR", Vector3(0.2, 0, 0.5))
		_tgt("shL", Vector3(-0.4, 0, -1.5))
		_tgt("shR", Vector3(-0.4, 0, 1.5))
		_tgt("torso", Vector3.ZERO)
	rig.rotation.x = fall
	pelvis.position.y = lerpf(pelvis.position.y, py, minf(1.0, dt * 12.0))

	# face: brows, blinking, infected neck stretch
	for i in brows.size():
		var side := -1.0 if i == 0 else 1.0
		var b: Node3D = brows[i]
		b.rotation.z = lerpf(b.rotation.z, brow_z * side, dt * 8.0)
		b.position.y = lerpf(b.position.y, P.head * 1.5 + brow_y, dt * 8.0)
	_blink_t -= dt
	var closed := _blink_t < 0.12 and not hostile
	if _blink_t <= 0.0:
		_blink_t = randf_range(2.0, 5.0)
	for e in eyes:
		e.scale.y = 0.1 if closed or dead else (1.0 + _corrupt * 0.3)
	head.position.y = _head_base_y + _corrupt * 0.12 + (sin(_state_t * 17.0) * 0.02 if hostile else 0.0)

	# squash & stretch on footfalls (clowns are made of rubber)
	if role == "clown" and not dead:
		var sq: float = (absf(c) - 0.5) * P.squash * amp
		rig.scale = Vector3(1.0 - sq * 0.5, 1.0 + sq, 1.0 - sq * 0.5)

	# springs (floppy limbs). Infected "freeze-frame" glitches skip a few updates.
	if _glitch_t > 0.0 and hostile:
		return
	for nm in joints:
		var j: Array = joints[nm]
		if j.size() < 6:
			continue
		var ang: Vector3 = j[1]
		var vel: Vector3 = j[2]
		var target: Vector3 = j[3]
		vel += (target - ang) * j[4] * dt
		vel *= exp(-j[5] * dt)
		ang += vel * dt
		j[1] = ang
		j[2] = vel
		j[0].rotation = ang
	for side2 in ["L", "R"]:
		var foot: Node3D = joints["foot" + side2][0]
		foot.rotation.x = -(joints["hip" + side2][1].x + joints["knee" + side2][1].x) * 0.8

	if belly_node:
		var pv := (pelvis.position.y - _prev_pelvis) / maxf(dt, 0.001)
		_prev_pelvis = pelvis.position.y
		belly_v += (-belly_s * 140.0 - belly_v * 5.0 - pv * 4.0) * dt
		belly_s += belly_v * dt
		belly_s = clampf(belly_s, -0.5, 0.5)
		belly_node.scale = Vector3(1.0 + belly_s * 0.35, 1.0 - belly_s * 0.45, 1.0 + belly_s * 0.35)
