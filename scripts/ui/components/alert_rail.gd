extends PanelContainer
class_name AlertRail

signal alert_action_requested(action: String, context: Dictionary)

const MAX_VISIBLE_ALERTS: int = 4
const ALERT_SEVERITY: int = 0
const WARNING_SEVERITY: int = 1
const TIP_SEVERITY: int = 2

var _collapsed: bool = false
var _count_label: Label
var _list: VBoxContainer
var _empty_label: Label
var _toggle_button: Button
var _open_all_button: Button

func _ready() -> void:
	custom_minimum_size = Vector2(300, 360)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _panel_style())
	_build_ui()
	_connect_signals()
	refresh()

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

	var title := Label.new()
	title.text = "Alertes"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", UITheme.ACCENT)
	header.add_child(title)

	_count_label = Label.new()
	_count_label.custom_minimum_size = Vector2(34, 0)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	header.add_child(_count_label)

	_toggle_button = Button.new()
	_toggle_button.text = "-"
	_toggle_button.custom_minimum_size = Vector2(32, 28)
	_toggle_button.tooltip_text = "Replier les alertes"
	_toggle_button.pressed.connect(_toggle_collapsed)
	header.add_child(_toggle_button)

	_open_all_button = Button.new()
	_open_all_button.text = "Voir"
	_open_all_button.custom_minimum_size = Vector2(58, 28)
	_open_all_button.tooltip_text = "Ouvrir les conseils"
	_open_all_button.pressed.connect(func() -> void:
		alert_action_requested.emit("advice", {"hub": "hub_advice", "section": "weekly"})
	)
	header.add_child(_open_all_button)

	_empty_label = Label.new()
	_empty_label.text = "Rien d'urgent."
	_empty_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	root.add_child(_empty_label)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	root.add_child(_list)

func _connect_signals() -> void:
	if AdvisorManager:
		if not AdvisorManager.advice_pushed.is_connected(_on_advice_pushed):
			AdvisorManager.advice_pushed.connect(_on_advice_pushed)
	if DramaManager:
		if not DramaManager.drama_occurred.is_connected(_on_drama_changed):
			DramaManager.drama_occurred.connect(_on_drama_changed)
		if not DramaManager.drama_resolved.is_connected(_on_drama_changed):
			DramaManager.drama_resolved.connect(_on_drama_changed)
		if not DramaManager.drama_response_needed.is_connected(_on_drama_changed):
			DramaManager.drama_response_needed.connect(_on_drama_changed)
	if RecruitmentPool:
		if not RecruitmentPool.pool_refreshed.is_connected(_on_recruitment_changed):
			RecruitmentPool.pool_refreshed.connect(_on_recruitment_changed)
		if not RecruitmentPool.player_lost_to_competition.is_connected(_on_candidate_lost):
			RecruitmentPool.player_lost_to_competition.connect(_on_candidate_lost)
	if GuildManager:
		if not GuildManager.member_recruited.is_connected(_on_member_changed):
			GuildManager.member_recruited.connect(_on_member_changed)
		if not GuildManager.member_left.is_connected(_on_member_changed):
			GuildManager.member_left.connect(_on_member_changed)
		if not GuildManager.member_activity_changed.is_connected(_on_member_activity_changed):
			GuildManager.member_activity_changed.connect(_on_member_activity_changed)
		if GuildManager.guild:
			_connect_guild_signals()
	if GuildCultureManager:
		if not GuildCultureManager.morale_changed.is_connected(_on_morale_changed):
			GuildCultureManager.morale_changed.connect(_on_morale_changed)
		if GuildCultureManager.has_signal("tension_detected") and not GuildCultureManager.tension_detected.is_connected(_on_tension_detected):
			GuildCultureManager.tension_detected.connect(_on_tension_detected)
		if GuildCultureManager.has_signal("tension_resolved") and not GuildCultureManager.tension_resolved.is_connected(_on_tension_resolved):
			GuildCultureManager.tension_resolved.connect(_on_tension_resolved)
	if GameTime:
		if not GameTime.day_changed.is_connected(_on_day_changed):
			GameTime.day_changed.connect(_on_day_changed)
		if not GameTime.week_changed.is_connected(_on_week_changed):
			GameTime.week_changed.connect(_on_week_changed)
	if SaveManager:
		if not SaveManager.load_completed.is_connected(_on_save_loaded):
			SaveManager.load_completed.connect(_on_save_loaded)

func _connect_guild_signals() -> void:
	var guild: Guild = GuildManager.guild
	if not guild.gold_changed.is_connected(_on_gold_changed):
		guild.gold_changed.connect(_on_gold_changed)
	if not guild.reputation_changed.is_connected(_on_reputation_changed):
		guild.reputation_changed.connect(_on_reputation_changed)

func refresh() -> void:
	_connect_guild_signals()
	var alerts: Array[Dictionary] = _collect_alerts()
	_count_label.text = str(alerts.size())
	_open_all_button.visible = alerts.size() > 0
	_empty_label.visible = alerts.is_empty() and not _collapsed
	_list.visible = not _collapsed and not alerts.is_empty()

	for child in _list.get_children():
		child.free()

	if not _collapsed:
		for i in range(mini(alerts.size(), MAX_VISIBLE_ALERTS)):
			_list.add_child(_make_alert_card(alerts[i]))

	_apply_collapsed_state()

func _collect_alerts() -> Array[Dictionary]:
	var alerts: Array[Dictionary] = []
	_add_drama_alerts(alerts)
	_add_recruitment_alerts(alerts)
	_add_member_risk_alerts(alerts)
	_add_advisor_alerts(alerts)
	var deduped: Array[Dictionary] = _dedupe_alerts(alerts)
	deduped.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("priority", 999)) < int(b.get("priority", 999))
	)
	return deduped

func _add_drama_alerts(alerts: Array[Dictionary]) -> void:
	if not DramaManager:
		return
	for drama in DramaManager.active_dramas:
		if drama == null or not bool(drama.active):
			continue
		var severity: int = ALERT_SEVERITY if int(drama.severity) >= 2 else WARNING_SEVERITY
		alerts.append({
			"id": "drama:%s:%s" % [str(drama.source_member), str(drama.drama_type)],
			"priority": 5 + (3 - int(drama.severity)),
			"severity": severity,
			"title": "%s: %s" % [drama.get_type_name(), str(drama.source_member)],
			"text": str(drama.description),
			"action": "drama",
			"action_label": "Traiter",
			"hub": "hub_business" if _is_phase_unlocked(PhaseManager.GamePhase.NATIONAL) else "hub_guild",
			"section": "national" if _is_phase_unlocked(PhaseManager.GamePhase.NATIONAL) else "cohesion",
		})

func _add_recruitment_alerts(alerts: Array[Dictionary]) -> void:
	if not RecruitmentPool:
		return
	var candidates: Array[Dictionary] = []
	for player in RecruitmentPool.available_players:
		if player == null:
			continue
		if RecruitmentPool.is_player_on_recruitment_cooldown(player):
			continue
		var days_left: int = RecruitmentPool.get_candidate_days_remaining(player)
		if days_left > 1:
			continue
		candidates.append({
			"player": player,
			"days_left": days_left,
			"value": float(player.get_meta("recruitment_value", 0.0)),
		})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("days_left", 99)) == int(b.get("days_left", 99)):
			return float(a.get("value", 0.0)) > float(b.get("value", 0.0))
		return int(a.get("days_left", 99)) < int(b.get("days_left", 99))
	)
	for i in range(mini(candidates.size(), 2)):
		var data: Dictionary = candidates[i]
		var p = data.get("player")
		var days_left: int = int(data.get("days_left", 0))
		var time_text: String = "part aujourd'hui" if days_left <= 0 else "part demain"
		alerts.append({
			"id": "recruit:%s" % str(p.player_id),
			"priority": 32 + days_left,
			"severity": WARNING_SEVERITY,
			"title": "Recrue disponible",
			"text": "%s %s. Niveau %d, skill %d." % [str(p.nom), time_text, int(p.personnage_niveau), int(p.skill)],
			"action": "recruitment",
			"action_label": "Voir",
			"hub": "hub_recruitment",
			"section": "recruitment",
			"candidate": p,
		})

func _add_member_risk_alerts(alerts: Array[Dictionary]) -> void:
	if not GuildManager:
		return
	var risky: Array[Dictionary] = []
	for member in GuildManager.guild_members:
		if member == null or member.get_meta("is_player", false):
			continue
		var burnout: int = int(member.burnout_level)
		var stress: float = float(member.stress_level)
		if burnout < 2 and stress < 80.0:
			continue
		risky.append({
			"member": member,
			"burnout": burnout,
			"stress": stress,
		})
	risky.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("burnout", 0)) == int(b.get("burnout", 0)):
			return float(a.get("stress", 0.0)) > float(b.get("stress", 0.0))
		return int(a.get("burnout", 0)) > int(b.get("burnout", 0))
	)
	for i in range(mini(risky.size(), 2)):
		var data: Dictionary = risky[i]
		var member = data.get("member")
		alerts.append({
			"id": "burnout:%s" % str(member.player_id),
			"priority": 20 + i,
			"severity": WARNING_SEVERITY,
			"title": "Burnout: %s" % str(member.nom),
			"text": "Stress %d/100, niveau burnout %d." % [int(data.get("stress", 0.0)), int(data.get("burnout", 0))],
			"action": "burnout",
			"action_label": "Voir",
			"hub": "hub_business" if _is_phase_unlocked(PhaseManager.GamePhase.ESPORT) else "hub_guild",
			"section": "esport" if _is_phase_unlocked(PhaseManager.GamePhase.ESPORT) else "cohesion",
			"member": member,
			"context": "burnout",
		})

func _add_advisor_alerts(alerts: Array[Dictionary]) -> void:
	if not AdvisorManager or not AdvisorManager.has_method("get_advice"):
		return
	var added: int = 0
	for advice in AdvisorManager.get_advice():
		var severity: int = int(advice.get("severity", TIP_SEVERITY))
		if severity > WARNING_SEVERITY:
			continue
		var title: String = str(advice.get("title", "Conseil"))
		alerts.append({
			"id": "advice:%s" % title,
			"priority": 12 if severity == ALERT_SEVERITY else 45 + added,
			"severity": severity,
			"title": title,
			"text": str(advice.get("text", "")),
			"action": _action_from_advice(title),
			"action_label": "Voir",
			"hub": _hub_from_advice(title),
			"section": _section_from_advice(title),
		})
		added += 1
		if added >= 3:
			return

func _dedupe_alerts(alerts: Array[Dictionary]) -> Array[Dictionary]:
	var seen: Dictionary = {}
	var out: Array[Dictionary] = []
	for alert in alerts:
		var id: String = str(alert.get("id", ""))
		if id == "" or seen.has(id):
			continue
		seen[id] = true
		out.append(alert)
	return out

func _make_alert_card(alert: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style(_severity_color(int(alert.get("severity", TIP_SEVERITY)))))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	card.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 5)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	root.add_child(header)

	var marker := Label.new()
	marker.text = "!"
	marker.custom_minimum_size = Vector2(14, 0)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.add_theme_color_override("font_color", _severity_color(int(alert.get("severity", TIP_SEVERITY))))
	header.add_child(marker)

	var title := Label.new()
	title.text = str(alert.get("title", "Alerte"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_color_override("font_color", UITheme.TEXT)
	header.add_child(title)

	var action_button := Button.new()
	action_button.text = str(alert.get("action_label", "Voir"))
	action_button.custom_minimum_size = Vector2(62, 26)
	action_button.pressed.connect(func() -> void:
		alert_action_requested.emit(str(alert.get("action", "advice")), alert)
	)
	header.add_child(action_button)

	var text := Label.new()
	text.text = str(alert.get("text", ""))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", UITheme.FONT_SMALL)
	text.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	root.add_child(text)

	return card

func _toggle_collapsed() -> void:
	_collapsed = not _collapsed
	refresh()

func _apply_collapsed_state() -> void:
	_toggle_button.text = "+" if _collapsed else "-"
	_toggle_button.tooltip_text = "Deplier les alertes" if _collapsed else "Replier les alertes"
	_empty_label.visible = _empty_label.visible and not _collapsed
	_list.visible = _list.visible and not _collapsed
	custom_minimum_size = Vector2(300, 42 if _collapsed else 360)

func _severity_color(severity: int) -> Color:
	match severity:
		ALERT_SEVERITY:
			return Color(0.90, 0.36, 0.36)
		WARNING_SEVERITY:
			return Color(0.96, 0.71, 0.30)
		_:
			return UITheme.ACCENT

func _card_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UITheme.BG_RAISED
	style.bg_color.a = 0.92
	style.set_corner_radius_all(UITheme.RADIUS)
	style.set_border_width_all(1)
	style.border_color = color.darkened(0.20)
	return style

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UITheme.BG_PANEL
	style.bg_color.a = 0.95
	style.set_corner_radius_all(UITheme.RADIUS)
	style.set_border_width_all(1)
	style.border_color = UITheme.BORDER
	return style

func _action_from_advice(title: String) -> String:
	if title.contains("Tresorerie") or title.contains("Budget"):
		return "finance"
	if title.contains("burnout") or title.contains("Stress"):
		return "burnout"
	if title.contains("Ambiance") or title.contains("Moral") or title.contains("Conflits"):
		return "cohesion"
	if title.contains("Places"):
		return "recruitment"
	return "advice"

func _hub_from_advice(title: String) -> String:
	if title.contains("Tresorerie") or title.contains("Budget"):
		return "hub_business" if _is_phase_unlocked(PhaseManager.GamePhase.NATIONAL) else "hub_advice"
	if title.contains("burnout") or title.contains("Stress"):
		return "hub_business" if _is_phase_unlocked(PhaseManager.GamePhase.ESPORT) else "hub_guild"
	if title.contains("Ambiance") or title.contains("Moral") or title.contains("Conflits"):
		return "hub_guild"
	if title.contains("Places"):
		return "hub_recruitment"
	return "hub_advice"

func _section_from_advice(title: String) -> String:
	if title.contains("Tresorerie") or title.contains("Budget"):
		return "national" if _is_phase_unlocked(PhaseManager.GamePhase.NATIONAL) else "stats"
	if title.contains("burnout") or title.contains("Stress"):
		return "esport" if _is_phase_unlocked(PhaseManager.GamePhase.ESPORT) else "cohesion"
	if title.contains("Ambiance") or title.contains("Moral") or title.contains("Conflits"):
		return "cohesion"
	if title.contains("Places"):
		return "recruitment"
	return "weekly"

func _phase_window(unlocked_window: String, fallback_window: String, phase_required: int = -1) -> String:
	if not PhaseManager:
		return fallback_window
	var required: int = PhaseManager.GamePhase.NATIONAL if phase_required < 0 else phase_required
	if PhaseManager.get_current_phase() >= required:
		return unlocked_window
	return fallback_window

func _is_phase_unlocked(phase: int) -> bool:
	return PhaseManager != null and PhaseManager.get_current_phase() >= phase

func _on_advice_pushed(_advice: Dictionary) -> void:
	refresh()

func _on_drama_changed(_drama: Variant) -> void:
	refresh()

func _on_recruitment_changed() -> void:
	refresh()

func _on_candidate_lost(_player: Variant, _guild_name: String) -> void:
	refresh()

func _on_member_changed(_player: Variant) -> void:
	refresh()

func _on_member_activity_changed(_player: Variant, _activity: Variant) -> void:
	refresh()

func _on_morale_changed(_new_morale: float, _old_morale: float) -> void:
	refresh()

func _on_tension_detected(_player1_name: String, _player2_name: String, _reason: String) -> void:
	refresh()

func _on_tension_resolved(_player1_name: String, _player2_name: String) -> void:
	refresh()

func _on_day_changed(_day: int, _week: int, _year: int) -> void:
	refresh()

func _on_week_changed(_week: int, _year: int) -> void:
	refresh()

func _on_gold_changed(_old_gold: int, _new_gold: int) -> void:
	refresh()

func _on_reputation_changed(_old_reputation: float, _new_reputation: float, _reason: String) -> void:
	refresh()

func _on_save_loaded(_success: bool) -> void:
	refresh()
