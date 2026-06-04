extends PanelContainer
class_name ObjectiveTracker

signal open_requested()

var _collapsed: bool = false
var _title_label: Label
var _detail_label: Label
var _progress_label: Label
var _progress_bar: ProgressBar
var _toggle_button: Button
var _open_button: Button

func _ready() -> void:
	custom_minimum_size = Vector2(560, 76)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _panel_style())
	_build_ui()
	_connect_signals()
	refresh()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)

	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", UITheme.FONT_NORMAL)
	_title_label.add_theme_color_override("font_color", UITheme.ACCENT)
	_title_label.clip_text = true
	_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(_title_label)

	_progress_label = Label.new()
	_progress_label.custom_minimum_size = Vector2(74, 0)
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_progress_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	header.add_child(_progress_label)

	_toggle_button = Button.new()
	_toggle_button.text = "-"
	_toggle_button.custom_minimum_size = Vector2(34, 28)
	_toggle_button.tooltip_text = "Replier l'objectif"
	_toggle_button.pressed.connect(_toggle_collapsed)
	header.add_child(_toggle_button)

	_open_button = Button.new()
	_open_button.text = "Voir"
	_open_button.custom_minimum_size = Vector2(62, 28)
	_open_button.tooltip_text = "Ouvrir la progression detaillee"
	_open_button.pressed.connect(func() -> void:
		open_requested.emit()
	)
	header.add_child(_open_button)

	_detail_label = Label.new()
	_detail_label.add_theme_color_override("font_color", UITheme.TEXT)
	_detail_label.clip_text = true
	_detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	root.add_child(_detail_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size = Vector2(0, 12)
	root.add_child(_progress_bar)

func _connect_signals() -> void:
	if PhaseManager:
		if not PhaseManager.progression_updated.is_connected(_on_progression_updated):
			PhaseManager.progression_updated.connect(_on_progression_updated)
		if not PhaseManager.phase_changed.is_connected(_on_phase_changed):
			PhaseManager.phase_changed.connect(_on_phase_changed)
	if GuildManager:
		if not GuildManager.member_recruited.is_connected(_on_member_changed):
			GuildManager.member_recruited.connect(_on_member_changed)
		if not GuildManager.member_left.is_connected(_on_member_changed):
			GuildManager.member_left.connect(_on_member_changed)
		if not GuildManager.member_connected.is_connected(_on_member_changed):
			GuildManager.member_connected.connect(_on_member_changed)
		if not GuildManager.member_disconnected.is_connected(_on_member_changed):
			GuildManager.member_disconnected.connect(_on_member_changed)
	if GuildRanking:
		if not GuildRanking.ranking_updated.is_connected(_on_ranking_updated):
			GuildRanking.ranking_updated.connect(_on_ranking_updated)
		if not GuildRanking.guild_position_changed.is_connected(_on_position_changed):
			GuildRanking.guild_position_changed.connect(_on_position_changed)
		if not GuildRanking.new_server_first.is_connected(_on_server_first):
			GuildRanking.new_server_first.connect(_on_server_first)
	if DramaManager:
		if not DramaManager.drama_occurred.is_connected(_on_drama_changed):
			DramaManager.drama_occurred.connect(_on_drama_changed)
		if not DramaManager.drama_resolved.is_connected(_on_drama_changed):
			DramaManager.drama_resolved.connect(_on_drama_changed)
	if SponsorshipManager:
		if not SponsorshipManager.sponsor_acquired.is_connected(_on_sponsor_changed):
			SponsorshipManager.sponsor_acquired.connect(_on_sponsor_changed)
		if not SponsorshipManager.sponsor_lost.is_connected(_on_sponsor_lost):
			SponsorshipManager.sponsor_lost.connect(_on_sponsor_lost)
	if StaffManager:
		if not StaffManager.staff_hired.is_connected(_on_staff_changed):
			StaffManager.staff_hired.connect(_on_staff_changed)
		if not StaffManager.staff_fired.is_connected(_on_staff_changed):
			StaffManager.staff_fired.connect(_on_staff_changed)
	if TournamentManager:
		if not TournamentManager.tournament_completed.is_connected(_on_tournament_completed):
			TournamentManager.tournament_completed.connect(_on_tournament_completed)
	if GameTime:
		if not GameTime.day_changed.is_connected(_on_day_changed):
			GameTime.day_changed.connect(_on_day_changed)
		if not GameTime.week_changed.is_connected(_on_week_changed):
			GameTime.week_changed.connect(_on_week_changed)
	if SaveManager:
		if not SaveManager.load_completed.is_connected(_on_save_loaded):
			SaveManager.load_completed.connect(_on_save_loaded)

func refresh() -> void:
	if not PhaseManager:
		_title_label.text = "Objectif indisponible"
		_detail_label.text = "PhaseManager non charge"
		_progress_label.text = "--"
		_progress_bar.value = 0.0
		return

	var phase: Variant = PhaseManager.get_current_phase()
	var progress: Dictionary = PhaseManager.get_requirements_progress(phase)
	var overall: float = _overall_progress(progress)
	var primary_req: String = _primary_requirement(progress)

	_title_label.text = "%s - Objectif de phase" % [PhaseManager.get_phase_name(phase)]
	_progress_label.text = "%d%%" % [int(round(overall))]
	_progress_bar.value = overall

	if primary_req == "":
		_detail_label.text = "Tous les objectifs de phase sont remplis."
	else:
		var data: Dictionary = progress.get(primary_req, {})
		_detail_label.text = "%s : %s" % [_requirement_label(primary_req), _format_requirement_progress(primary_req, data)]

	_apply_collapsed_state()

func _overall_progress(progress: Dictionary) -> float:
	if progress.is_empty():
		return 100.0
	var total: float = 0.0
	for req_name in progress:
		var data: Dictionary = progress[req_name]
		total += float(data.get("progress_percent", 0.0))
	return clampf(total / float(progress.size()), 0.0, 100.0)

func _primary_requirement(progress: Dictionary) -> String:
	for req_name in progress:
		var data: Dictionary = progress[req_name]
		if not bool(data.get("met", false)):
			return str(req_name)
	return ""

func _format_requirement_progress(req_name: String, data: Dictionary) -> String:
	var current_value: Variant = data.get("current", 0)
	var required_value: Variant = data.get("required", 0)
	match req_name:
		"server_rank_position", "national_rank_position":
			var current_rank: int = int(current_value)
			if current_rank > 0:
				return "rang #%d / objectif #%d" % [current_rank, int(required_value)]
			return "non classe / objectif #%d" % [int(required_value)]
		"max_dramas_per_year":
			return "%d / max %d" % [int(current_value), int(required_value)]
		"integration_threshold", "content_cleared_percent", "media_reputation", "international_reputation", "team_stability":
			return "%.0f / %.0f%%" % [float(current_value), float(required_value)]
		_:
			return "%d / %d" % [int(current_value), int(required_value)]

func _requirement_label(req_name: String) -> String:
	match req_name:
		"heroic_dungeons_completed":
			return "Donjons heroiques"
		"server_rank_position":
			return "Rang serveur"
		"server_rank_duration":
			return "Jours rang 1 serveur"
		"active_members_min":
			return "Membres actifs"
		"integration_threshold":
			return "Integration moyenne"
		"content_cleared_percent":
			return "Contenu PvE clear"
		"national_rank_position":
			return "Rang national"
		"national_rank_duration":
			return "Jours rang 1 national"
		"max_dramas_per_year":
			return "Dramas majeurs"
		"active_sponsors":
			return "Sponsors actifs"
		"world_first_count":
			return "World firsts"
		"media_reputation":
			return "Reputation media"
		"world_championship_wins":
			return "Titres mondiaux"
		"professional_staff_count":
			return "Staff pro"
		"international_reputation":
			return "Reputation internationale"
		"team_stability":
			return "Stabilite equipe"
		_:
			return req_name.capitalize()

func _toggle_collapsed() -> void:
	_collapsed = not _collapsed
	_apply_collapsed_state()

func _apply_collapsed_state() -> void:
	_detail_label.visible = not _collapsed
	_progress_bar.visible = not _collapsed
	_toggle_button.text = "+" if _collapsed else "-"
	_toggle_button.tooltip_text = "Deplier l'objectif" if _collapsed else "Replier l'objectif"
	custom_minimum_size = Vector2(custom_minimum_size.x, 42 if _collapsed else 76)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UITheme.BG_PANEL
	style.bg_color.a = 0.94
	style.set_corner_radius_all(UITheme.RADIUS)
	style.set_border_width_all(1)
	style.border_color = UITheme.ACCENT_DIM
	return style

func _on_progression_updated(_phase: Variant, _progress: Dictionary) -> void:
	refresh()

func _on_phase_changed(_new_phase: Variant, _old_phase: Variant) -> void:
	refresh()

func _on_member_changed(_player: Variant = null) -> void:
	refresh()

func _on_ranking_updated(_rankings: Array) -> void:
	refresh()

func _on_position_changed(_guild_name: String, _old_position: int, _new_position: int) -> void:
	refresh()

func _on_server_first(_guild_name: String, _achievement_name: String) -> void:
	refresh()

func _on_drama_changed(_drama: Variant) -> void:
	refresh()

func _on_sponsor_changed(_sponsor: Variant) -> void:
	refresh()

func _on_sponsor_lost(_sponsor: Variant, _reason: String) -> void:
	refresh()

func _on_staff_changed(_staff: Variant) -> void:
	refresh()

func _on_tournament_completed(_tournament: Variant, _stage_reached: Variant, _is_champion: bool, _results: Variant) -> void:
	refresh()

func _on_day_changed(_day: int, _week: int, _year: int) -> void:
	refresh()

func _on_week_changed(_week: int, _year: int) -> void:
	refresh()

func _on_save_loaded(_success: bool) -> void:
	refresh()
