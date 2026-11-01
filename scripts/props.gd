extends Node3D
## Small animated prop behaviours: spinners, gallery ducks, flickering lights.

@export var kind := "spin"  # spin, duck, flicker, bob
@export var axis := Vector3.UP
@export var speed := 0.3
@export var amp := 1.0
var _t := 0.0
var _base := Vector3.ZERO
var _light: Light3D
var _base_energy := 1.0


func _ready() -> void:
	_base = position
	_t = randf() * 10.0
	if kind == "flicker":
		for c in get_children():
			if c is Light3D:
				_light = c
				_base_energy = c.light_energy


func _process(delta: float) -> void:
	_t += delta
	match kind:
		"spin":
			rotate(axis.normalized(), speed * delta * (1.0 - Music.distortion * 0.6))
		"duck":
			position.x = _base.x + sin(_t * speed) * amp
		"bob":
			position.y = _base.y + sin(_t * speed) * amp
		"flicker":
			if _light:
				var f := 1.0
				if randf() < 0.03 + Music.distortion * 0.15:
					f = randf_range(0.1, 0.6)
				_light.light_energy = lerpf(_light.light_energy, _base_energy * f, 0.4)
