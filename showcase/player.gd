extends CharacterBody3D
## Minimal explorer: WASD, mouse look, Shift to stroll faster, Space to hop, Esc frees the mouse.

const WALK := 3.2
const RUN := 6.0
var yaw := 0.0
var pitch := 0.0
var cam: Camera3D
var _bob := 0.0


func _ready() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.875
	add_child(cs)
	cam = Camera3D.new()
	cam.position.y = 1.62
	cam.fov = 68.0
	cam.near = 0.05
	cam.far = 4000.0
	add_child(cam)
	cam.current = true
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Place the eye at `eye` looking at `target` (used by photo-mode viewpoints).
func set_view(eye: Vector3, target: Vector3) -> void:
	global_position = eye - Vector3(0, 1.62, 0)
	velocity = Vector3.ZERO
	var d := target - eye
	yaw = atan2(-d.x, -d.z)
	pitch = atan2(d.y, Vector2(d.x, d.z).length())
	_apply_look()


func _apply_look() -> void:
	rotation = Vector3(0, yaw, 0)
	cam.rotation = Vector3(pitch, 0, 0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.0022
		pitch = clampf(pitch - event.relative.y * 0.0022, -1.45, 1.45)
		_apply_look()
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(dt: float) -> void:
	var input := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var speed := RUN if Input.is_physical_key_pressed(KEY_SHIFT) else WALK
	var dir := (Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)).normalized()
	velocity.x = lerpf(velocity.x, dir.x * speed, minf(1.0, dt * 10.0))
	velocity.z = lerpf(velocity.z, dir.z * speed, minf(1.0, dt * 10.0))
	if is_on_floor():
		if Input.is_physical_key_pressed(KEY_SPACE):
			velocity.y = 4.0
	else:
		velocity.y -= 14.0 * dt
	move_and_slide()
	# very gentle head bob while walking
	var hv := Vector2(velocity.x, velocity.z).length()
	_bob += dt * hv * 2.2
	cam.position.y = 1.62 + sin(_bob) * 0.025 * clampf(hv / WALK, 0.0, 1.0)
