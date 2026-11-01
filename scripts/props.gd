extends Node3D
## Small animated prop behaviours: spinners, gallery ducks, bobbing, flickering lights, blinkers.
## corrupt() (called by corruptible.gd) makes each behaviour permanently erratic.

@export var kind := "spin"  # spin, duck, flicker, bob, blink
@export var axis := Vector3.UP
@export var speed := 0.3
@export var amp := 1.0
var corrupted := false
var _t := 0.0
var _base := Vector3.ZERO
var _light: Light3D
var _base_energy := 1.0
var _dead_light := false
var _lurch := 0.0


func _ready() -> void:
	_base = position
	_t = randf() * 10.0
	if kind == "flicker":
		for c in get_children():
			if c is Light3D:
				_light = c
				_base_energy = c.light_energy


func corrupt() -> void:
	corrupted = true
	_dead_light = randf() < 0.3
	if kind == "duck":
		rotation.z = PI  # targets hang upside down
	if kind == "bob":
		scale = Vector3(1.0, 0.55, 1.0)  # deflated


func _process(delta: float) -> void:
	_t += delta
	match kind:
		"spin":
			if corrupted:
				# lurching, reversing, stalling
				_lurch -= delta
				if _lurch <= 0.0:
					_lurch = randf_range(0.6, 2.5)
				var surge := pow(maxf(0.0, sin(_t * 1.7)), 6.0) * 6.0
				rotate(axis.normalized(), -speed * delta * (0.3 + surge) * (1.0 if _lurch > 0.4 else -2.0))
			else:
				rotate(axis.normalized(), speed * delta)
		"duck":
			if corrupted:
				position.x = _base.x + sin(_t * speed * 3.0) * amp * 0.5 + randf_range(-0.05, 0.05)
			else:
				position.x = _base.x + sin(_t * speed) * amp
		"bob":
			if corrupted:
				position.y = _base.y + sin(_t * speed * 4.0) * amp * 2.0 - 0.4
			else:
				position.y = _base.y + sin(_t * speed) * amp
		"blink":
			visible = fmod(_t, 0.5 if corrupted else 1.2) < 0.25
		"flicker":
			if _light:
				var target := _base_energy
				if corrupted:
					if _dead_light:
						target = _base_energy * (0.5 if randf() < 0.03 else 0.02)
					elif randf() < 0.15:
						target *= randf_range(0.0, 0.5)
				elif randf() < 0.01 + Music.distortion * 0.05:
					target *= randf_range(0.5, 0.9)
				_light.light_energy = lerpf(_light.light_energy, target, 0.35)
