class_name BattleUnitNode
extends Control

# ============================================================
# BattleUnitNode.gd
# Node visual untuk menampilkan satu unit (player atau musuh)
# di dalam BattleScene. Di-instantiate secara dinamis oleh
# battle_scene.gd dan ditempatkan di slot lane / party slot.
# ============================================================

## Sinyal saat node ini diklik (untuk target manual jika diperlukan)
signal unit_clicked(unit: BattleUnit)

## Referensi ke data unit runtime
var battle_unit: BattleUnit = null

## Warna HP bar sehat
const COLOR_HP_HIGH  := Color(0.2, 0.85, 0.3)
## Warna HP bar sedang
const COLOR_HP_MID   := Color(0.95, 0.80, 0.1)
## Warna HP bar kritis
const COLOR_HP_LOW   := Color(0.9, 0.15, 0.15)
## Warna background HP bar
const COLOR_HP_BG    := Color(0.15, 0.15, 0.15, 0.9)
## Warna tint saat unit mati
const COLOR_DEAD     := Color(0.3, 0.3, 0.3, 0.5)

# Child nodes (dibuat di _setup_nodes)
var _sprite: TextureRect      = null
var _name_label: Label        = null
var _hp_bar_bg: ColorRect     = null
var _hp_bar_fill: ColorRect   = null
var _hp_label: Label          = null
var _atb_bar_bg: ColorRect    = null
var _atb_bar_fill: ColorRect  = null
var _hit_overlay: ColorRect   = null


func _init() -> void:
	_setup_nodes()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)


func _setup_nodes() -> void:
	custom_minimum_size = Vector2(100, 110)

	# Background kartu
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.1, 0.14, 0.85)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Sprite karakter
	_sprite = TextureRect.new()
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_sprite.position = Vector2(0, 4)
	_sprite.size = Vector2(100, 60)
	_sprite.offset_left = -50
	add_child(_sprite)

	# Nama
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 10)
	_name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_name_label.position = Vector2(-50, 66)
	_name_label.size = Vector2(100, 14)
	add_child(_name_label)

	# HP bar background
	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.color = COLOR_HP_BG
	_hp_bar_bg.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hp_bar_bg.position = Vector2(-44, 82)
	_hp_bar_bg.size = Vector2(88, 8)
	add_child(_hp_bar_bg)

	# HP bar fill
	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.color = COLOR_HP_HIGH
	_hp_bar_fill.position = _hp_bar_bg.position + Vector2(1, 1)
	_hp_bar_fill.size = Vector2(86, 6)
	add_child(_hp_bar_fill)

	# HP label
	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 8)
	_hp_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hp_label.position = Vector2(-44, 91)
	_hp_label.size = Vector2(88, 11)
	add_child(_hp_label)

	# ATB bar background
	_atb_bar_bg = ColorRect.new()
	_atb_bar_bg.color = Color(0.08, 0.08, 0.2, 0.9)
	_atb_bar_bg.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_atb_bar_bg.position = Vector2(-44, 103)
	_atb_bar_bg.size = Vector2(88, 5)
	add_child(_atb_bar_bg)

	# ATB bar fill
	_atb_bar_fill = ColorRect.new()
	_atb_bar_fill.color = Color(0.3, 0.6, 1.0)
	_atb_bar_fill.position = _atb_bar_bg.position + Vector2(1, 1)
	_atb_bar_fill.size = Vector2(0, 3)
	add_child(_atb_bar_fill)

	# Hit flash overlay
	_hit_overlay = ColorRect.new()
	_hit_overlay.color = Color(1, 0.2, 0.2, 0.0)
	_hit_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hit_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hit_overlay)


## Hubungkan node ini ke sebuah BattleUnit
func bind_unit(unit: BattleUnit) -> void:
	battle_unit = unit
	if not unit or not unit.stats:
		return

	_name_label.text = unit.stats.character_name
	if unit.stats.character_sprite:
		_sprite.texture = unit.stats.character_sprite

	unit.hp_changed.connect(_on_hp_changed)
	unit.unit_died.connect(_on_unit_died)
	refresh()


## Refresh tampilan berdasarkan state unit saat ini
func refresh() -> void:
	if not battle_unit or not battle_unit.stats:
		return
	_update_hp_bar()
	_update_atb_bar()


func _update_hp_bar() -> void:
	var pct := battle_unit.get_hp_percent()
	var max_w := 86.0
	_hp_bar_fill.size.x = max_w * pct

	# Warna berdasarkan persentase HP
	if pct > 0.5:
		_hp_bar_fill.color = COLOR_HP_HIGH
	elif pct > 0.25:
		_hp_bar_fill.color = COLOR_HP_MID
	else:
		_hp_bar_fill.color = COLOR_HP_LOW

	_hp_label.text = "%d/%d" % [battle_unit.current_hp, battle_unit.stats.max_hp]


func _update_atb_bar() -> void:
	if not battle_unit:
		return
	var max_w := 86.0
	_atb_bar_fill.size.x = max_w * battle_unit.atb_gauge

	# ATB penuh = warna kuning
	if battle_unit.is_turn_ready:
		_atb_bar_fill.color = Color(1.0, 0.9, 0.2)
	else:
		_atb_bar_fill.color = Color(0.3, 0.6, 1.0)


## Flash merah saat terkena damage
func play_hit_flash() -> void:
	_hit_overlay.color = Color(1, 0.2, 0.2, 0.7)
	var tween := create_tween()
	tween.tween_property(_hit_overlay, "color:a", 0.0, 0.3)


## Tint abu-abu saat mati
func _on_unit_died() -> void:
	modulate = COLOR_DEAD
	if _atb_bar_fill:
		_atb_bar_fill.visible = false
	if _atb_bar_bg:
		_atb_bar_bg.visible = false


func _on_hp_changed(_old: int, _new: int) -> void:
	_update_hp_bar()
	play_hit_flash()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if battle_unit:
				unit_clicked.emit(battle_unit)
