extends Control

# ============================================================
# battle_scene.gd
# Controller utama BattleScene.tscn

# Mirror enum dari BattleManager agar bisa dipakai tanpa class_name
const STATE_INACTIVE      := 0
const STATE_INTRO         := 1
const STATE_ATB_RUNNING   := 2
const STATE_PLAYER_ACTION := 3
const STATE_ENEMY_ACTION  := 4
const STATE_RESOLVING     := 5
const STATE_BATTLE_WON    := 6
const STATE_BATTLE_LOST   := 7
const STATE_OUTRO         := 8
# Menampilkan 5 lane, party player, tombol serangan,
# preview pola lane, dan log battle.
# ============================================================

## --- Node References (di-setup via _setup_ui) ---
var _lane_container: HBoxContainer      = null  ## 5 kolom lane musuh
var _party_container: HBoxContainer     = null  ## Slot party player
var _skill_container: GridContainer     = null  ## Tombol serangan
var _log_label: RichTextLabel           = null  ## Log battle
var _turn_label: Label                  = null  ## "Giliran: NamaUnit"
var _confirm_btn: Button                = null  ## Konfirmasi serangan
var _cancel_btn: Button                 = null  ## Batal pilih serangan
var _end_battle_btn: Button             = null  ## Kembali (setelah menang/kalah)

## Lane highlight overlays (ColorRect per lane, index 0-4)
var _lane_highlights: Array[ColorRect]  = []
## Node visual per lane (lane index -> Array of BattleUnitNode)
var _enemy_nodes: Dictionary            = {}
## Node visual party player (party index -> BattleUnitNode)
var _party_nodes: Dictionary            = {}

## Referensi BattleManager
@onready var _bm: Node = get_node("/root/BattleManager")

## Warna highlight lane saat preview
const COLOR_LANE_ACTIVE   := Color(1.0, 0.9, 0.2, 0.18)
const COLOR_LANE_INACTIVE := Color(0.0, 0.0, 0.0, 0.0)
const COLOR_LANE_HIT      := Color(1.0, 0.2, 0.2, 0.22)


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_setup_ui()
	_connect_signals()
	_build_unit_nodes()
	_bm.begin_atb()
	_log("Battle dimulai!")


# ============================================================
# Build UI secara programatik
# ============================================================

func _setup_ui() -> void:
	# Root layout: VBoxContainer
	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 6)
	add_child(root_vbox)

	# -- Background gelap
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.12, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -1
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# -- Header bar
	var header := _make_panel(Color(0.08, 0.10, 0.18, 1.0))
	header.custom_minimum_size.y = 36
	root_vbox.add_child(header)

	_turn_label = Label.new()
	_turn_label.text = "Menunggu..."
	_turn_label.add_theme_font_size_override("font_size", 16)
	_turn_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	_turn_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	header.add_child(_turn_label)

	# -- Area lane musuh (atas)
	var lane_area := VBoxContainer.new()
	lane_area.custom_minimum_size.y = 160
	lane_area.add_theme_constant_override("separation", 0)
	root_vbox.add_child(lane_area)

	var lane_title := Label.new()
	lane_title.text = "— MUSUH —"
	lane_title.add_theme_font_size_override("font_size", 11)
	lane_title.add_theme_color_override("font_color", Color(0.7, 0.4, 0.4))
	lane_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lane_area.add_child(lane_title)

	_lane_container = HBoxContainer.new()
	_lane_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_lane_container.add_theme_constant_override("separation", 8)
	_lane_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lane_area.add_child(_lane_container)

	# Buat 5 slot lane
	for i in 5:
		var slot := _build_lane_slot(i)
		_lane_container.add_child(slot)

	# -- Divider
	var div := ColorRect.new()
	div.color = Color(0.2, 0.25, 0.35)
	div.custom_minimum_size.y = 2
	root_vbox.add_child(div)

	# -- Area party player (tengah)
	var party_area := VBoxContainer.new()
	party_area.custom_minimum_size.y = 140
	party_area.add_theme_constant_override("separation", 0)
	root_vbox.add_child(party_area)

	var party_title := Label.new()
	party_title.text = "— PARTY —"
	party_title.add_theme_font_size_override("font_size", 11)
	party_title.add_theme_color_override("font_color", Color(0.4, 0.7, 0.4))
	party_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	party_area.add_child(party_title)

	_party_container = HBoxContainer.new()
	_party_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_party_container.add_theme_constant_override("separation", 12)
	_party_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	party_area.add_child(_party_container)

	# -- Panel bawah: skill + log
	var bottom_hbox := HBoxContainer.new()
	bottom_hbox.custom_minimum_size.y = 200
	bottom_hbox.add_theme_constant_override("separation", 8)
	root_vbox.add_child(bottom_hbox)

	# Panel skill
	var skill_panel := _make_panel(Color(0.07, 0.09, 0.15, 1.0))
	skill_panel.custom_minimum_size.x = 300
	skill_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bottom_hbox.add_child(skill_panel)

	var skill_vbox := VBoxContainer.new()
	skill_vbox.add_theme_constant_override("separation", 4)
	skill_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skill_panel.add_child(skill_vbox)

	var skill_title := Label.new()
	skill_title.text = "SERANGAN"
	skill_title.add_theme_font_size_override("font_size", 12)
	skill_title.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	skill_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_vbox.add_child(skill_title)

	_skill_container = GridContainer.new()
	_skill_container.columns = 2
	_skill_container.add_theme_constant_override("h_separation", 6)
	_skill_container.add_theme_constant_override("v_separation", 6)
	skill_vbox.add_child(_skill_container)

	# Tombol konfirmasi / batal
	var action_hbox := HBoxContainer.new()
	action_hbox.add_theme_constant_override("separation", 6)
	skill_vbox.add_child(action_hbox)

	_cancel_btn = Button.new()
	_cancel_btn.text = "Batal"
	_cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cancel_btn.visible = false
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	action_hbox.add_child(_cancel_btn)

	_confirm_btn = Button.new()
	_confirm_btn.text = "Serang!"
	_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_btn.visible = false
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	action_hbox.add_child(_confirm_btn)

	# Panel log
	var log_panel := _make_panel(Color(0.04, 0.06, 0.10, 1.0))
	log_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_hbox.add_child(log_panel)

	_log_label = RichTextLabel.new()
	_log_label.bbcode_enabled = true
	_log_label.scroll_following = true
	_log_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_log_label.add_theme_font_size_override("normal_font_size", 11)
	log_panel.add_child(_log_label)

	# Tombol akhir battle (tersembunyi sampai battle selesai)
	_end_battle_btn = Button.new()
	_end_battle_btn.text = "Kembali ke Dunia"
	_end_battle_btn.visible = false
	_end_battle_btn.pressed.connect(_on_end_battle_pressed)
	root_vbox.add_child(_end_battle_btn)


func _build_lane_slot(lane_index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(110, 130)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_END
	panel.add_child(vbox)

	# Label nomor lane
	var lbl := Label.new()
	lbl.text = "Lane %d" % (lane_index + 1)
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)

	# Highlight overlay
	var hl := ColorRect.new()
	hl.color = COLOR_LANE_INACTIVE
	hl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hl)
	_lane_highlights.append(hl)

	_enemy_nodes[lane_index] = []
	return panel


# ============================================================
# Build unit nodes dari BattleManager
# ============================================================

func _build_unit_nodes() -> void:
	if not _bm:
		return

	# Musuh
	for unit in _bm.enemy_units:
		_create_enemy_node(unit)

	# Party player
	for unit in _bm.player_party:
		_create_party_node(unit)

	# Build skill buttons untuk party member pertama yang hidup
	_refresh_skill_buttons()


func _create_enemy_node(unit: BattleUnit) -> void:
	var node := BattleUnitNode.new()
	node.bind_unit(unit)
	unit.visual_node = node

	# Tempatkan di lane pertama yang ia tempati
	if unit.occupied_lanes.size() > 0:
		var first_lane := unit.occupied_lanes[0] - 1
		var slot_vbox := _lane_container.get_child(first_lane).get_child(0) as VBoxContainer
		if slot_vbox:
			slot_vbox.add_child(node)
			# Tambah referensi ke semua lane yang ditempati
			for lane in unit.occupied_lanes:
				var idx := lane - 1
				if not _enemy_nodes[idx].has(node):
					_enemy_nodes[idx].append(node)


func _create_party_node(unit: BattleUnit) -> void:
	var node := BattleUnitNode.new()
	node.bind_unit(unit)
	unit.visual_node = node
	_party_container.add_child(node)
	_party_nodes[unit.party_index] = node


func _refresh_skill_buttons() -> void:
	# Hapus tombol lama secara langsung
	for child in _skill_container.get_children():
		child.free()

	if not _bm.active_player_unit:
		return

	var attacks: Array = _bm.active_player_unit.stats.attacks
	for i in attacks.size():
		var atk := attacks[i] as AttackData
		if not atk:
			continue

		var btn := Button.new()
		btn.text = "%s\n[%s]" % [atk.attack_name, atk.pattern_label]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size.y = 40
		btn.add_theme_font_size_override("font_size", 10)
		btn.disabled = not _bm.active_player_unit.is_attack_available(i)
		btn.tooltip_text = atk.description

		var idx := i
		btn.pressed.connect(func(): _on_skill_pressed(idx))
		_skill_container.add_child(btn)


# ============================================================
# Koneksi sinyal BattleManager
# ============================================================

func _connect_signals() -> void:
	if not _bm:
		return
	_bm.state_changed.connect(_on_state_changed)
	_bm.turn_started.connect(_on_turn_started)
	_bm.action_executed.connect(_on_action_executed)
	_bm.unit_hp_changed.connect(_on_unit_hp_changed)
	_bm.unit_died.connect(_on_unit_died_visual)
	_bm.battle_ended.connect(_on_battle_ended)
	_bm.atb_updated.connect(_on_atb_updated)


# ============================================================
# Handler sinyal
# ============================================================

func _on_state_changed(new_state: int) -> void:
	match new_state:
		STATE_PLAYER_ACTION:
			_turn_label.text = "Giliran: %s — Pilih Serangan" % \
				(_bm.active_player_unit.stats.character_name if _bm.active_player_unit else "?")
			_refresh_skill_buttons()
			_clear_lane_highlights()
		STATE_ENEMY_ACTION:
			_turn_label.text = "Musuh bertindak..."
			_set_skills_enabled(false)
			_confirm_btn.visible = false
			_cancel_btn.visible = false
		STATE_ATB_RUNNING:
			_turn_label.text = "Menunggu giliran..."
			_set_skills_enabled(false)
			_confirm_btn.visible = false
			_cancel_btn.visible = false
			_clear_lane_highlights()
		STATE_RESOLVING:
			_set_skills_enabled(false)


func _on_turn_started(unit: BattleUnit) -> void:
	_log("[color=yellow]▶ Giliran: %s[/color]" % unit.stats.character_name)


func _on_action_executed(attacker: BattleUnit, attack: AttackData, hit_units: Array) -> void:
	var type_str := "Fisik" if attack.attack_type == AttackData.AttackType.PHYSICAL else "Sihir"
	_log("[b]%s[/b] menggunakan [color=cyan]%s[/color] (%s) → %s lane" % [
		attacker.stats.character_name,
		attack.attack_name,
		type_str,
		attack.get_pattern_string()
	])
	for target in hit_units:
		var bu := target as BattleUnit
		if bu and bu.visual_node:
			(bu.visual_node as BattleUnitNode).play_hit_flash()

	# Highlight lane yang terkena
	_highlight_hit_lanes(attack.target_lanes)


func _on_unit_hp_changed(unit: BattleUnit) -> void:
	if unit.visual_node:
		(unit.visual_node as BattleUnitNode).refresh()


func _on_unit_died_visual(unit: BattleUnit) -> void:
	_log("[color=red]✖ %s telah dikalahkan![/color]" % unit.stats.character_name)


func _on_battle_ended(player_won: bool) -> void:
	if player_won:
		_log("[color=lime][b]MENANG! Semua musuh dikalahkan.[/b][/color]")
		_turn_label.text = "Kemenangan!"
	else:
		_log("[color=red][b]KALAH. Party dikalahkan...[/b][/color]")
		_turn_label.text = "Kekalahan..."
	_end_battle_btn.visible = true
	_set_skills_enabled(false)
	_confirm_btn.visible = false
	_cancel_btn.visible = false


func _on_atb_updated() -> void:
	for unit in _bm.player_party:
		if unit.visual_node:
			(unit.visual_node as BattleUnitNode)._update_atb_bar()
	for unit in _bm.enemy_units:
		if unit.visual_node:
			(unit.visual_node as BattleUnitNode)._update_atb_bar()


# ============================================================
# Handler tombol
# ============================================================

func _on_skill_pressed(index: int) -> void:
	_bm.player_select_attack(index)
	var attack: AttackData = _bm.get_pending_attack()
	if attack:
		_preview_lane_pattern(attack)
		_confirm_btn.visible = true
		_cancel_btn.visible = true
		_log("Preview: [color=cyan]%s[/color] — %s" % [attack.attack_name, attack.get_pattern_string()])


func _on_confirm_pressed() -> void:
	_clear_lane_highlights()
	_bm.player_confirm_action()
	_confirm_btn.visible = false
	_cancel_btn.visible = false


func _on_cancel_pressed() -> void:
	_bm.player_cancel_action()
	_clear_lane_highlights()
	_confirm_btn.visible = false
	_cancel_btn.visible = false


func _on_end_battle_pressed() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_bm.end_battle()


# ============================================================
# Lane highlight
# ============================================================

func _preview_lane_pattern(attack: AttackData) -> void:
	_clear_lane_highlights()
	for lane in attack.target_lanes:
		var idx := lane - 1
		if idx >= 0 and idx < _lane_highlights.size():
			_lane_highlights[idx].color = attack.lane_highlight_color


func _highlight_hit_lanes(target_lanes: Array[int]) -> void:
	_clear_lane_highlights()
	for lane in target_lanes:
		var idx := lane - 1
		if idx >= 0 and idx < _lane_highlights.size():
			_lane_highlights[idx].color = COLOR_LANE_HIT
	# Fade out setelah 0.5 detik
	await get_tree().create_timer(0.5).timeout
	_clear_lane_highlights()


func _clear_lane_highlights() -> void:
	for hl in _lane_highlights:
		hl.color = COLOR_LANE_INACTIVE


# ============================================================
# Utilitas
# ============================================================

func _make_panel(bg_color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _set_skills_enabled(enabled: bool) -> void:
	for child in _skill_container.get_children():
		if child is Button:
			(child as Button).disabled = not enabled


func _log(text: String) -> void:
	if _log_label:
		_log_label.append_text(text + "\n")
