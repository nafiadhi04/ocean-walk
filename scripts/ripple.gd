extends Node3D

# ============================================================
# ripple.gd
# Animasi cincin riak air mengembang dan fade out
# Di-spawn oleh player setiap langkah kaki
# ============================================================

@export var duration: float = 1.2
@export var max_scale: float = 2.2
@export var start_alpha: float = 0.95

@onready var mesh: MeshInstance3D = $MeshInstance3D

var _time: float = 0.0
var _mat: StandardMaterial3D = null


func _ready() -> void:
	# Buat material sendiri agar tidak shared antar instance
	_mat = StandardMaterial3D.new()
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.albedo_color = Color(0.75, 0.90, 1.0, start_alpha)
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.no_depth_test = false
	if mesh:
		mesh.material_override = _mat

	# Mulai kecil
	scale = Vector3(0.05, 1.0, 0.05)


func _process(delta: float) -> void:
	_time += delta
	var progress: float = clampf(_time / duration, 0.0, 1.0)

	# Scale mengembang - easing out agar cepat di awal lalu melambat
	var s: float = ease(progress, -2.0) * max_scale
	scale = Vector3(s, 1.0, s)

	# Alpha fade out linear
	var alpha: float = start_alpha * (1.0 - progress)
	if _mat:
		_mat.albedo_color = Color(0.75, 0.90, 1.0, alpha)

	# Hapus node saat selesai
	if progress >= 1.0:
		queue_free()
