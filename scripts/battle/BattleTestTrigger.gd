extends Node

# ============================================================
# BattleTestTrigger.gd
# Tambahkan node ini ke Main.tscn untuk testing battle.
# Tekan F5 saat di ocean scene untuk memulai test battle.
# ============================================================

## Path ke resource stats player default
const PLAYER_STATS := preload("res://scenes/battle/player_default.tres")
## Path ke resource attacks player
const ATK_WAVE_SLASH := preload("res://scenes/battle/atk_wave_slash.tres")
const ATK_TIDE_CROSS := preload("res://scenes/battle/atk_tide_cross.tres")
const ATK_RIPTIDE    := preload("res://scenes/battle/atk_riptide.tres")
const ATK_DEEP_SURGE := preload("res://scenes/battle/atk_deep_surge.tres")
## Path ke resource musuh
const ENEMY_CRAB    := preload("res://scenes/battle/enemy_sea_crab.tres")
const ENEMY_SPRITE  := preload("res://scenes/battle/enemy_tide_sprite.tres")

## Label hint di layar
var _hint: Label = null


func _ready() -> void:
	_create_hint()


func _create_hint() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)

	_hint = Label.new()
	_hint.text = "F5 — Mulai Battle Test"
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 0.75))
	_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_hint.add_theme_constant_override("shadow_offset_x", 1)
	_hint.add_theme_constant_override("shadow_offset_y", 1)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.position = Vector2(20, -40)
	canvas.add_child(_hint)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and key.physical_keycode == KEY_F5:
			_start_test_battle()


func _start_test_battle() -> void:
	if BattleManager.current_state != BattleManager.BattleState.INACTIVE:
		return

	# Buat instance player stats dengan attacks yang terisi
	var player_stats: CharacterStats = PLAYER_STATS.duplicate()
	player_stats.attacks = [ATK_WAVE_SLASH, ATK_TIDE_CROSS, ATK_RIPTIDE, ATK_DEEP_SURGE]

	# Buat dua musuh dengan lane berbeda
	# Sea Crab menempati lane 2 dan 3 (multi-lane)
	var crab: CharacterStats = ENEMY_CRAB.duplicate()
	# Tide Sprite menempati lane 4 saja
	var sprite: CharacterStats = ENEMY_SPRITE.duplicate()

	var party: Array = [player_stats]
	var enemies: Array = [crab, sprite]

	var current_scene_path: String = get_tree().current_scene.scene_file_path
	BattleManager.start_battle(party, enemies, current_scene_path)
