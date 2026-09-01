extends Node3D

# ============================================================
# sky_manager.gd
# Mengelola animasi sky shader - update time uniform
# Pause saat window tidak fokus untuk mencegah freeze Alt+Tab
# ============================================================

@onready var world_env: WorldEnvironment = $"../WorldEnvironment"

var _sky_material: ShaderMaterial = null
var _time: float = 0.0
var _focused: bool = true


func _ready() -> void:
	_find_sky_material()
	get_tree().get_root().focus_entered.connect(_on_focus_entered)
	get_tree().get_root().focus_exited.connect(_on_focus_exited)


func _find_sky_material() -> void:
	if world_env == null:
		push_error("sky_manager.gd: WorldEnvironment tidak ditemukan")
		return

	var env := world_env.environment
	if env == null:
		return

	var sky := env.sky
	if sky == null:
		return

	if sky.sky_material is ShaderMaterial:
		_sky_material = sky.sky_material as ShaderMaterial


func _on_focus_entered() -> void:
	_focused = true


func _on_focus_exited() -> void:
	_focused = false


func _process(delta: float) -> void:
	if not _focused:
		return
	_time += delta
	if _sky_material:
		_sky_material.set_shader_parameter("time", _time)
