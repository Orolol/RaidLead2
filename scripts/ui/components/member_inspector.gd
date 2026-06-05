extends PanelContainer
class_name MemberInspector

signal action_requested(action: String, player)

var _selected_member: SimulatedPlayer = null
var _context: String = ""
var _title_label: Label
var _subtitle_label: Label
var _status_label: Label
var _metrics_box: VBoxContainer
var _tags_box: HFlowContainer
var _schedule_label: Label
var _equipment_label: Label

func _ready() -> void:
	custom_minimum_size = Vector2(300, 310)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _panel_style())
	_build_ui()
	_connect_signals()
	_on_member_selected(GuildManager.get_selected_member() if GuildManager and GuildManager.has_method("get_selected_member") else null, "restore")

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)

	_title_label = Label.new()
	_title_label.text = "Inspecteur membre"
	_title_label.add_theme_color_override("font_color", UITheme.ACCENT)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(28, 26)
	close_button.tooltip_text = "Fermer l'inspecteur"
	close_button.pressed.connect(func() -> void:
		if GuildManager and GuildManager.has_method("clear_selected_member"):
			GuildManager.clear_selected_member()
		else:
			_on_member_selected(null, "")
	)
	header.add_child(close_button)

	_subtitle_label = Label.new()
	_subtitle_label.add_theme_color_override("font_color", UITheme.TEXT)
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_subtitle_label)

	_status_label = Label.new()
	_status_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status_label)

	_metrics_box = VBoxContainer.new()
	_metrics_box.add_theme_constant_override("separation", 5)
	root.add_child(_metrics_box)

	var detail_grid := GridContainer.new()
	detail_grid.columns = 2
	detail_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_grid.add_theme_constant_override("h_separation", 12)
	detail_grid.add_theme_constant_override("v_separation", 4)
	root.add_child(detail_grid)

	_add_static_row(detail_grid, "Equipement", true)
	_equipment_label = _add_static_row(detail_grid, "", false)
	_add_static_row(detail_grid, "Planning", true)
	_schedule_label = _add_static_row(detail_grid, "", false)

	_tags_box = HFlowContainer.new()
	_tags_box.add_theme_constant_override("h_separation", 4)
	_tags_box.add_theme_constant_override("v_separation", 4)
	root.add_child(_tags_box)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	root.add_child(actions)
	_add_action_button(actions, "Roster", "roster")
	_add_action_button(actions, "Cohesion", "cohesion")
	_add_action_button(actions, "Equip", "equipment")
	_add_action_button(actions, "PvE", "pve")

func _connect_signals() -> void:
	if GuildManager:
		if GuildManager.has_signal("member_selected") and not GuildManager.member_selected.is_connected(_on_member_selected):
			GuildManager.member_selected.connect(_on_member_selected)
		if not GuildManager.member_activity_changed.is_connected(_on_member_activity_changed):
			GuildManager.member_activity_changed.connect(_on_member_activity_changed)
		if not GuildManager.member_connected.is_connected(_on_member_changed):
			GuildManager.member_connected.connect(_on_member_changed)
		if not GuildManager.member_disconnected.is_connected(_on_member_changed):
			GuildManager.member_disconnected.connect(_on_member_changed)
		if not GuildManager.member_leveled_up.is_connected(_on_member_leveled_up):
			GuildManager.member_leveled_up.connect(_on_member_leveled_up)
		if GuildManager.has_signal("member_left") and not GuildManager.member_left.is_connected(_on_member_left):
			GuildManager.member_left.connect(_on_member_left)
	if SaveManager and not SaveManager.load_completed.is_connected(_on_save_loaded):
		SaveManager.load_completed.connect(_on_save_loaded)

func _on_member_selected(player, context: String) -> void:
	_selected_member = player as SimulatedPlayer
	_context = context
	visible = _selected_member != null
	_refresh()

func inspect_member(player: SimulatedPlayer, context: String = "manual") -> void:
	if GuildManager and GuildManager.has_method("select_member"):
		GuildManager.select_member(player, context)
	else:
		_on_member_selected(player, context)

func _refresh() -> void:
	if _selected_member == null:
		hide()
		return
	show()
	var activity: String = _format_activity(_selected_member)
	_title_label.text = _selected_member.nom
	_subtitle_label.text = "%s %s - Niv.%d | skill %d | iLvl %d" % [
		_selected_member.get_role(),
		_selected_member.personnage_classe,
		int(_selected_member.personnage_niveau),
		int(_selected_member.skill),
		int(_selected_member.get_total_ilvl()),
	]
	_status_label.text = "%s%s" % [
		"En ligne" if _selected_member.is_online else "Hors ligne",
		" - " + activity if activity != "" else "",
	]
	_equipment_label.text = _selected_member.get_equipment_stats_summary() if _selected_member.has_method("get_equipment_stats_summary") else _selected_member.get_equipment_summary()
	_schedule_label.text = _selected_member.get_schedule_summary() if _selected_member.has_method("get_schedule_summary") else "Planning inconnu"
	_rebuild_metrics()
	_rebuild_tags()

func _rebuild_metrics() -> void:
	for child in _metrics_box.get_children():
		child.queue_free()
	_metrics_box.add_child(_make_metric_bar("Energie", float(_selected_member.energy), 100.0, UIConstants.COLOR_SUCCESS))
	_metrics_box.add_child(_make_metric_bar("Humeur", float(_selected_member.mood), 100.0, UIConstants.COLOR_INFO))
	_metrics_box.add_child(_make_metric_bar("Integration", float(_selected_member.integration), 100.0, UITheme.ACCENT))
	_metrics_box.add_child(_make_metric_bar("Stress", float(_selected_member.stress_level), 100.0, UIConstants.COLOR_WARNING))
	var burnout_value: float = _selected_member.get_burnout_risk() * 100.0 if _selected_member.has_method("get_burnout_risk") else float(_selected_member.burnout_level) * 33.0
	_metrics_box.add_child(_make_metric_bar("Burnout", burnout_value, 100.0, UIConstants.COLOR_ERROR))

func _rebuild_tags() -> void:
	for child in _tags_box.get_children():
		child.queue_free()
	var tags: Array = _selected_member.get_visible_tags()
	if tags.is_empty():
		var empty := Label.new()
		empty.text = "Aucun trait revele"
		empty.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		_tags_box.add_child(empty)
		return
	for i in range(mini(tags.size(), 6)):
		var tag := Button.new()
		tag.text = str(tags[i])
		tag.flat = true
		tag.disabled = true
		tag.add_theme_font_size_override("font_size", UITheme.FONT_SMALL)
		_tags_box.add_child(tag)

func _make_metric_bar(label_text: String, value: float, max_value: float, color: Color) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var row := HBoxContainer.new()
	box.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", UITheme.FONT_SMALL)
	row.add_child(label)
	var value_label := Label.new()
	value_label.text = "%d" % int(round(value))
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(38, 0)
	value_label.add_theme_font_size_override("font_size", UITheme.FONT_SMALL)
	row.add_child(value_label)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = max_value
	bar.value = clampf(value, 0.0, max_value)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", fill)
	box.add_child(bar)
	return box

func _add_static_row(parent: GridContainer, text: String, is_label: bool) -> Label:
	var label := Label.new()
	label.text = text
	if is_label:
		label.custom_minimum_size = Vector2(86, 0)
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	else:
		label.custom_minimum_size = Vector2(176, 0)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", UITheme.FONT_SMALL)
	label.add_theme_color_override("font_color", UITheme.TEXT_DIM if is_label else UITheme.TEXT)
	parent.add_child(label)
	return label

func _add_action_button(parent: HBoxContainer, text: String, action: String) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(62, 30)
	button.pressed.connect(func() -> void:
		if _selected_member != null:
			action_requested.emit(action, _selected_member)
	)
	parent.add_child(button)

func _format_activity(player: SimulatedPlayer) -> String:
	if player.current_activity == null:
		return ""
	var text: String = player.current_activity.get_type_string()
	if player.current_activity.location != "":
		text += " a " + player.current_activity.location
	return text

func _on_member_activity_changed(player, _activity) -> void:
	if player == _selected_member:
		_refresh()

func _on_member_changed(player) -> void:
	if player == _selected_member:
		_refresh()

func _on_member_leveled_up(player, _new_level: int) -> void:
	if player == _selected_member:
		_refresh()

func _on_member_left(player) -> void:
	if player == _selected_member:
		_on_member_selected(null, "")

func _on_save_loaded(_success: bool) -> void:
	if not (GuildManager and GuildManager.has_method("get_selected_member")):
		_on_member_selected(null, "save")
		return
	var selected: SimulatedPlayer = GuildManager.get_selected_member()
	if selected != null and selected not in GuildManager.guild_members:
		GuildManager.clear_selected_member()
		return
	_on_member_selected(selected, "save")

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UITheme.BG_PANEL
	style.bg_color.a = 0.95
	style.set_corner_radius_all(UITheme.RADIUS)
	style.set_border_width_all(1)
	style.border_color = UITheme.BORDER
	return style
