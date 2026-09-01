extends MeshInstance3D

# ============================================================
# ocean.gd - OPTIMIZED
# - _time di-wrap setiap 1000 detik agar tidak float overflow
# - Pause update saat window tidak fokus (cegah freeze Alt+Tab)
# ============================================================

@export_group("Wave Settings")
@export var wave_amplitude: float = 0.055

# Internal
var _player_ref: Node3D = null
var _time: float = 0.0
var _ocean_mat: ShaderMaterial = null
var _focused: bool = true

# Wrap time setiap N detik agar presisi float tetap terjaga
const TIME_WRAP: float = 1000.0


func _ready() -> void:
	_setup_material()
	_find_player()
	get_tree().get_root().focus_entered.connect(_on_focus_entered)
	get_tree().get_root().focus_exited.connect(_on_focus_exited)


func _on_focus_entered() -> void:
	_focused = true


func _on_focus_exited() -> void:
	_focused = false


func _setup_material() -> void:
	var shader := load("res://shaders/ocean_shader.gdshader") as Shader
	if shader == null:
		push_error("ocean.gd: Tidak dapat memuat ocean_shader.gdshader")
		return

	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("wave_amplitude", wave_amplitude)
	mat.set_shader_parameter("water_color_shallow", Color(0.04, 0.18, 0.38, 0.95))
	mat.set_shader_parameter("water_color_deep",    Color(0.01, 0.05, 0.15, 0.99))
	mat.set_shader_parameter("water_color_scatter", Color(0.03, 0.12, 0.28, 1.0))
	mat.set_shader_parameter("fresnel_power",       4.5)
	mat.set_shader_parameter("roughness_min",       0.02)
	mat.set_shader_parameter("roughness_max",       0.14)
	mat.set_shader_parameter("specular_strength",   0.8)
	mat.set_shader_parameter("sky_color_horizon",   Color(0.18, 0.32, 0.55, 1.0))
	mat.set_shader_parameter("sky_color_zenith",    Color(0.05, 0.12, 0.28, 1.0))
	mat.set_shader_parameter("time", 0.0)

	_ocean_mat = mat
	material_override = mat


func _find_player() -> void:
	var scene := get_tree().current_scene
	if scene:
		_player_ref = scene.get_node_or_null("Player") as Node3D


func _process(delta: float) -> void:
	if not _focused:
		return

	_time = fmod(_time + delta, TIME_WRAP)

	if _ocean_mat:
		_ocean_mat.set_shader_parameter("time", _time)

	_follow_player()


func _follow_player() -> void:
	if _player_ref == null:
		_find_player()
		return
	var player_pos := _player_ref.global_position
	global_position = Vector3(player_pos.x, 0.0, player_pos.z)


func get_wave_height(world_pos: Vector3) -> float:
	var t  := _time
	var px := world_pos.x
	var pz := world_pos.z

	var h: float = sin(px * 0.22 + t * 0.30) * cos(pz * 0.18 + t * 0.25)
	h += sin(px * 0.35 + pz * 0.28 + t * 0.20) * 0.45
	h += cos(px * 0.12 + t * 0.18) * sin(pz * 0.14 + t * 0.22) * 0.22
	h += sin(px * 0.55 + pz * 0.48 + t * 0.38) * 0.12

	return h * wave_amplitude
