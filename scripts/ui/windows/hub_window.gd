extends PanelContainer

signal close_requested
signal section_requested(window_name: String, section_id: String)
signal legacy_player_recruited(player)

@export var hub_id: String = "guild"

var close_button: Button
var title_label: Label
var description_label: Label
var advanced_tabs: AdvancedTabs
var _drag_active: bool = false
var _section_ids: Array[String] = []
var _pending_context: Dictionary = {}

const HUBS := {
	"guild": {
		"title": "Hub Guilde",
		"description": "Roster, cohesion, profil joueur et equipement.",
		"sections": [
			{"id": "roster", "title": "Roster", "window": "guilde", "summary": "Voir les membres, roles, tags et historique de loot.", "action": "Ouvrir Guilde"},
			{"id": "cohesion", "title": "Cohesion", "window": "cohesion", "summary": "Surveiller moral, relations, cliques, traditions et conflits.", "action": "Ouvrir Cohesion", "scene": "res://scenes/Fenetre_Social.tscn"},
			{"id": "player", "title": "Profil joueur", "window": "personnage", "summary": "Consulter identite, progression personnelle et reputation.", "action": "Ouvrir Profil"},
			{"id": "equipment", "title": "Equipement", "window": "guilde", "summary": "Point d'entree vers les fiches membres et leur equipement.", "action": "Voir membres"},
		],
	},
	"competition": {
		"title": "Hub Competition",
		"description": "PvE, classements et progression de phase.",
		"sections": [
			{"id": "group", "title": "Groupe PvE", "window": "organisation", "summary": "Composer un groupe, verifier les roles et lancer un donjon.", "action": "Composer"},
			{"id": "rankings", "title": "Classements", "window": "monde", "summary": "Comparer la guilde aux concurrents du serveur.", "action": "Voir classement", "scene": "res://scenes/Fenetre_Monde.tscn", "legacy_tab": 0},
			{"id": "progression", "title": "Progression", "window": "personnage", "summary": "Lire les objectifs de phase et les conditions restantes.", "action": "Voir objectifs"},
		],
	},
	"business": {
		"title": "Hub Business",
		"description": "Medias, sponsors, staff, tournois et carriere pro.",
		"sections": [
			{"id": "national", "title": "National", "window": "national", "summary": "Celebrite, medias, sponsors et dramas publics.", "action": "Ouvrir National", "phase_min": 2, "scene": "res://scenes/Fenetre_National.tscn"},
			{"id": "esport", "title": "Esport", "window": "esport", "summary": "Staff, tournois, transferts, bien-etre et legacy.", "action": "Ouvrir Esport", "phase_min": 3, "scene": "res://scenes/Fenetre_Esport.tscn"},
		],
	},
	"recruitment": {
		"title": "Hub Recrutement",
		"description": "Trouver, evaluer et contacter les recrues.",
		"sections": [
			{"id": "recruitment", "title": "Pool de recrues", "window": "monde", "summary": "Voir les candidats disponibles, leurs attentes et leur timer de marche.", "action": "Voir recrues", "scene": "res://scenes/Fenetre_Monde.tscn", "legacy_tab": 1},
			{"id": "roster_needs", "title": "Besoins roster", "window": "guilde", "summary": "Comparer les roles actuels avant de signer un nouveau membre.", "action": "Voir roster"},
		],
	},
	"advice": {
		"title": "Hub Conseil",
		"description": "Synthese hebdo, alertes, stats et equilibrage.",
		"sections": [
			{"id": "weekly", "title": "Cette semaine", "window": "conseils", "summary": "Lire les priorites immediates et les opportunites.", "action": "Voir synthese", "scene": "res://scenes/Fenetre_Conseils.tscn", "legacy_tab": 0},
			{"id": "advice", "title": "Conseils", "window": "conseils", "summary": "Comprendre les blocages et les leviers de progression.", "action": "Voir conseils", "scene": "res://scenes/Fenetre_Conseils.tscn", "legacy_tab": 1},
			{"id": "stats", "title": "Stats", "window": "conseils", "summary": "Consulter indicateurs, tendances et equilibrage.", "action": "Voir stats", "scene": "res://scenes/Fenetre_Conseils.tscn", "legacy_tab": 2},
		],
	},
}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(920, 620)
	add_theme_stylebox_override("panel", _panel_style())

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	_setup_header(root)
	_setup_content(root)
	_connect_refresh_signals()
	set_process_unhandled_input(true)
	hide()

func _connect_refresh_signals() -> void:
	if GuildManager:
		if not GuildManager.member_recruited.is_connected(_on_summary_data_changed):
			GuildManager.member_recruited.connect(_on_summary_data_changed)
		if GuildManager.has_signal("member_left") and not GuildManager.member_left.is_connected(_on_summary_data_changed):
			GuildManager.member_left.connect(_on_summary_data_changed)
		if not GuildManager.member_connected.is_connected(_on_summary_data_changed):
			GuildManager.member_connected.connect(_on_summary_data_changed)
		if not GuildManager.member_disconnected.is_connected(_on_summary_data_changed):
			GuildManager.member_disconnected.connect(_on_summary_data_changed)
		if not GuildManager.member_leveled_up.is_connected(_on_summary_data_changed):
			GuildManager.member_leveled_up.connect(_on_summary_data_changed)
		if GuildManager.has_signal("bank_changed") and not GuildManager.bank_changed.is_connected(_on_summary_data_changed):
			GuildManager.bank_changed.connect(_on_summary_data_changed)
	if PhaseManager:
		if not PhaseManager.phase_changed.is_connected(_on_summary_data_changed):
			PhaseManager.phase_changed.connect(_on_summary_data_changed)
		if not PhaseManager.progression_updated.is_connected(_on_summary_data_changed):
			PhaseManager.progression_updated.connect(_on_summary_data_changed)
	if SaveManager and not SaveManager.load_completed.is_connected(_on_summary_data_changed):
		SaveManager.load_completed.connect(_on_summary_data_changed)

func _setup_header(parent: VBoxContainer) -> void:
	var config: Dictionary = _get_config()
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	parent.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 2)
	header.add_child(title_box)

	title_label = Label.new()
	title_label.text = str(config.get("title", "Hub"))
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.mouse_filter = Control.MOUSE_FILTER_STOP
	title_label.mouse_default_cursor_shape = Control.CURSOR_MOVE
	title_label.tooltip_text = "Glissez pour deplacer la fenetre"
	title_label.gui_input.connect(_on_header_drag)
	title_box.add_child(title_label)

	description_label = Label.new()
	description_label.text = str(config.get("description", ""))
	description_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	description_label.clip_text = true
	description_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_box.add_child(description_label)

	close_button = Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(32, 32)
	close_button.pressed.connect(func() -> void:
		close_requested.emit()
	)
	header.add_child(close_button)

func _setup_content(parent: VBoxContainer) -> void:
	advanced_tabs = AdvancedTabs.create_simple_tabs(parent)
	advanced_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	advanced_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	advanced_tabs.max_visible_tabs = 5
	advanced_tabs.tab_selected.connect(_on_tab_selected)
	_section_ids.clear()

	var sections: Array = _get_visible_sections()
	if sections.is_empty():
		advanced_tabs.add_tab("Verrouille", _make_locked_content(), false)
		_section_ids.append("locked")
		return
	for section in sections:
		advanced_tabs.add_tab(str(section.get("title", "Section")), _make_section_content(section), false)
		_section_ids.append(str(section.get("id", "")))

func _make_section_content(section: Dictionary) -> Control:
	if section.has("scene"):
		return _make_embedded_section_content(section)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _content_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var title := Label.new()
	title.text = str(section.get("title", "Section"))
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", UITheme.ACCENT)
	root.add_child(title)

	var summary := Label.new()
	summary.text = str(section.get("summary", ""))
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_color_override("font_color", UITheme.TEXT)
	root.add_child(summary)

	root.add_child(HSeparator.new())
	_populate_summary_content(root, section)
	root.add_child(HSeparator.new())

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	root.add_child(action_row)

	var action_button := Button.new()
	action_button.text = str(section.get("action", "Ouvrir"))
	action_button.custom_minimum_size = Vector2(170, 36)
	action_button.pressed.connect(func() -> void:
		section_requested.emit(str(section.get("window", "")), str(section.get("id", "")))
	)
	action_row.add_child(action_button)

	return panel

func _populate_summary_content(parent: VBoxContainer, section: Dictionary) -> void:
	match str(section.get("id", "")):
		"roster":
			_populate_roster_summary(parent)
		"equipment":
			_populate_equipment_summary(parent)
		"player":
			_populate_player_summary(parent)
		"group":
			_populate_group_summary(parent)
		"progression":
			_populate_progression_summary(parent)
		"roster_needs":
			_populate_roster_needs_summary(parent)
		_:
			_add_empty_summary(parent, "Aucune donnee disponible.")

func _populate_roster_summary(parent: VBoxContainer) -> void:
	var members: Array = GuildManager.guild_members if GuildManager else []
	var online_count: int = GuildManager.get_online_members().size() if GuildManager else 0
	var tanks: int = _count_role(members, "Tank")
	var healers: int = _count_role(members, "Healer")
	var dps: int = _count_role(members, "DPS")
	var risk_count: int = 0
	for member in members:
		if member != null and (float(member.energy) < 25.0 or float(member.stress_level) >= 75.0 or int(member.burnout_level) >= 2):
			risk_count += 1
	var grid := _make_metric_grid(parent)
	_add_metric(grid, "Membres", "%d/%d" % [members.size(), GuildManager.guild.get_max_members() if GuildManager and GuildManager.guild else members.size()])
	_add_metric(grid, "En ligne", str(online_count))
	_add_metric(grid, "Roles", "T%d / H%d / D%d" % [tanks, healers, dps])
	_add_metric(grid, "A surveiller", str(risk_count))
	_add_member_strip(parent, _sort_members_for_attention(members), "A surveiller")

func _populate_equipment_summary(parent: VBoxContainer) -> void:
	var members: Array = GuildManager.guild_members if GuildManager else []
	var total_ilvl: int = 0
	for member in members:
		if member != null:
			total_ilvl += int(member.get_total_ilvl())
	var avg_ilvl: float = float(total_ilvl) / float(maxi(1, members.size()))
	var bank_count: int = GuildManager.guild.get_bank_items().size() if GuildManager and GuildManager.guild else 0
	var grid := _make_metric_grid(parent)
	_add_metric(grid, "iLvl moyen", "%d" % int(round(avg_ilvl)))
	_add_metric(grid, "Banque", "%d objet(s)" % bank_count)
	_add_metric(grid, "Plus faible", _lowest_ilvl_label(members))
	_add_metric(grid, "Loots", str(GuildManager.loot_history.size() if GuildManager else 0))
	_add_member_strip(parent, _sort_members_by_ilvl(members), "Priorite equipement")

func _populate_player_summary(parent: VBoxContainer) -> void:
	var player = GuildManager.get_player_character() if GuildManager and GuildManager.has_method("get_player_character") else null
	if player == null:
		_add_empty_summary(parent, "Joueur indisponible.")
		return
	var grid := _make_metric_grid(parent)
	_add_metric(grid, "Niveau", str(player.personnage_niveau))
	_add_metric(grid, "Classe", str(player.personnage_classe))
	_add_metric(grid, "Energie", "%d/100" % int(round(player.energy)))
	_add_metric(grid, "Activite", _format_activity(player))
	_add_member_strip(parent, [player], "Profil")

func _populate_group_summary(parent: VBoxContainer) -> void:
	var online: Array = GuildManager.get_online_members() if GuildManager else []
	var available: int = 0
	for member in online:
		if member != null and member.is_available_now():
			available += 1
	var grid := _make_metric_grid(parent)
	_add_metric(grid, "Disponibles", "%d/%d" % [available, online.size()])
	_add_metric(grid, "Tanks online", str(_count_role(online, "Tank")))
	_add_metric(grid, "Healers online", str(_count_role(online, "Healer")))
	_add_metric(grid, "DPS online", str(_count_role(online, "DPS")))
	_add_member_strip(parent, _sort_members_for_group(online), "Membres prets")

func _populate_progression_summary(parent: VBoxContainer) -> void:
	if not PhaseManager:
		_add_empty_summary(parent, "Progression indisponible.")
		return
	var phase: Variant = PhaseManager.get_current_phase()
	var progress: Dictionary = PhaseManager.get_requirements_progress(phase)
	var phase_label := Label.new()
	phase_label.text = "%s - %s" % [PhaseManager.get_phase_name(phase), PhaseManager.get_phase_description(phase)]
	phase_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	phase_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	parent.add_child(phase_label)
	for req_name in progress.keys():
		var data: Dictionary = progress[req_name]
		parent.add_child(_make_requirement_row(str(req_name), data))

func _populate_roster_needs_summary(parent: VBoxContainer) -> void:
	var members: Array = GuildManager.guild_members if GuildManager else []
	var grid := _make_metric_grid(parent)
	_add_metric(grid, "Tanks", "%d / 2+" % _count_role(members, "Tank"))
	_add_metric(grid, "Healers", "%d / 2+" % _count_role(members, "Healer"))
	_add_metric(grid, "DPS", "%d / 5+" % _count_role(members, "DPS"))
	_add_metric(grid, "Places libres", str(_free_roster_slots()))
	_add_empty_summary(parent, _roster_need_hint(members))

func _make_metric_grid(parent: VBoxContainer) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)
	return grid

func _add_metric(parent: GridContainer, label_text: String, value_text: String) -> void:
	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	parent.add_child(label)
	var value := Label.new()
	value.text = value_text
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.add_theme_color_override("font_color", UITheme.TEXT)
	parent.add_child(value)

func _add_empty_summary(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	parent.add_child(label)

func _add_member_strip(parent: VBoxContainer, members: Array, title_text: String) -> void:
	if members.is_empty():
		return
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", UITheme.FONT_SMALL)
	title.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	parent.add_child(title)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 5)
	flow.add_theme_constant_override("v_separation", 5)
	parent.add_child(flow)
	for i in range(mini(members.size(), 6)):
		var member = members[i]
		if member == null:
			continue
		var captured_member = member
		var button := Button.new()
		button.text = "%s N%d" % [str(captured_member.nom), int(captured_member.personnage_niveau)]
		button.custom_minimum_size = Vector2(120, 28)
		button.tooltip_text = "%s %s | iLvl %d | energie %d" % [
			str(captured_member.get_role()),
			str(captured_member.personnage_classe),
			int(captured_member.get_total_ilvl()),
			int(round(captured_member.energy)),
		]
		button.pressed.connect(func() -> void:
			if GuildManager and GuildManager.has_method("select_member"):
				GuildManager.select_member(captured_member, str(title_text).to_lower())
		)
		flow.add_child(button)

func _make_requirement_row(req_name: String, data: Dictionary) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	var header := HBoxContainer.new()
	row.add_child(header)
	var label := Label.new()
	label.text = _requirement_label(req_name)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	var value := Label.new()
	value.text = _format_requirement_progress(req_name, data)
	value.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	header.add_child(value)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = clampf(float(data.get("progress_percent", 0.0)), 0.0, 100.0)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	row.add_child(bar)
	return row

func _count_role(members: Array, role: String) -> int:
	var count: int = 0
	for member in members:
		if member != null and member.get_role() == role:
			count += 1
	return count

func _free_roster_slots() -> int:
	if not (GuildManager and GuildManager.guild):
		return 0
	return maxi(0, GuildManager.guild.get_max_members() - GuildManager.guild_members.size())

func _sort_members_for_attention(members: Array) -> Array:
	var out: Array = members.duplicate()
	out.sort_custom(func(a, b) -> bool:
		return _attention_score(a) > _attention_score(b)
	)
	return out

func _sort_members_by_ilvl(members: Array) -> Array:
	var out: Array = members.duplicate()
	out.sort_custom(func(a, b) -> bool:
		return int(a.get_total_ilvl()) < int(b.get_total_ilvl())
	)
	return out

func _sort_members_for_group(members: Array) -> Array:
	var out: Array = members.duplicate()
	out.sort_custom(func(a, b) -> bool:
		if a.is_available_now() == b.is_available_now():
			return float(a.energy) > float(b.energy)
		return a.is_available_now()
	)
	return out

func _attention_score(member) -> float:
	if member == null:
		return -1.0
	var score: float = 0.0
	score += maxf(0.0, 35.0 - float(member.energy))
	score += maxf(0.0, float(member.stress_level) - 60.0)
	score += float(member.burnout_level) * 22.0
	score += maxf(0.0, 45.0 - float(member.mood)) * 0.5
	return score

func _lowest_ilvl_label(members: Array) -> String:
	if members.is_empty():
		return "--"
	var sorted: Array = _sort_members_by_ilvl(members)
	var member = sorted[0]
	return "%s (%d)" % [str(member.nom), int(member.get_total_ilvl())]

func _roster_need_hint(members: Array) -> String:
	if _free_roster_slots() <= 0:
		return "Roster plein. Remplacez seulement si une recrue est nettement meilleure."
	if _count_role(members, "Tank") < 2:
		return "Priorite recrutement : tank fiable."
	if _count_role(members, "Healer") < 2:
		return "Priorite recrutement : healer disponible."
	if _count_role(members, "DPS") < 5:
		return "Priorite recrutement : DPS regulier."
	return "Roster equilibre. Cherchez surtout des profils haut skill ou tres disponibles."

func _format_activity(player) -> String:
	if player == null or player.current_activity == null:
		return "En attente"
	var text: String = player.current_activity.get_type_string()
	if player.current_activity.location != "":
		text += " a " + player.current_activity.location
	return text

func _format_requirement_progress(req_name: String, data: Dictionary) -> String:
	var current_value: Variant = data.get("current", 0)
	var required_value: Variant = data.get("required", 0)
	match req_name:
		"server_rank_position", "national_rank_position":
			var current_rank: int = int(current_value)
			if current_rank > 0:
				return "#%d / #%d" % [current_rank, int(required_value)]
			return "non classe / #%d" % int(required_value)
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

func _make_embedded_section_content(section: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _content_style())

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)

	var summary := Label.new()
	summary.text = str(section.get("summary", ""))
	summary.clip_text = true
	summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(summary)

	var open_button := Button.new()
	open_button.text = "Ouvrir"
	open_button.custom_minimum_size = Vector2(92, 30)
	open_button.tooltip_text = "Ouvrir cette section en fenetre dediee"
	open_button.pressed.connect(func() -> void:
		section_requested.emit(str(section.get("window", "")), str(section.get("id", "")))
	)
	header.add_child(open_button)

	var embedded := _instantiate_embedded_window(section)
	if embedded:
		root.add_child(embedded)
		panel.set_meta("embedded_window", embedded)
	else:
		var fallback := Label.new()
		fallback.text = "Section indisponible."
		fallback.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		root.add_child(fallback)

	return panel

func _instantiate_embedded_window(section: Dictionary) -> Control:
	var scene_path: String = str(section.get("scene", ""))
	var packed: PackedScene = load(scene_path)
	if not packed:
		push_warning("HubWindow: scene introuvable %s" % scene_path)
		return null
	var embedded: Control = packed.instantiate()
	embedded.set_meta("hub_embedded", true)
	embedded.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	embedded.size_flags_vertical = Control.SIZE_EXPAND_FILL
	embedded.custom_minimum_size = Vector2.ZERO
	embedded.visibility_changed.connect(func() -> void:
		if is_instance_valid(embedded) and not embedded.visible:
			embedded.show()
	)
	embedded.ready.connect(_prepare_embedded_window.bind(embedded, section), CONNECT_ONE_SHOT)
	return embedded

func _prepare_embedded_window(embedded: Control, section: Dictionary) -> void:
	if not is_instance_valid(embedded):
		return
	embedded.show()
	embedded.visible = true
	embedded.custom_minimum_size = Vector2.ZERO
	embedded.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	embedded.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_strip_embedded_chrome(embedded)
	_focus_embedded_tab(embedded, int(section.get("legacy_tab", 0)))
	if embedded.has_method("set_guild_members") and GuildManager:
		embedded.call("set_guild_members", GuildManager.guild_members)
	if embedded.has_signal("player_recruited") and not embedded.player_recruited.is_connected(_on_embedded_player_recruited):
		embedded.player_recruited.connect(_on_embedded_player_recruited)
	if embedded.has_method("refresh_window"):
		embedded.call("refresh_window")
	_apply_context_to_embedded(embedded, _pending_context)

func _strip_embedded_chrome(embedded: Control) -> void:
	if embedded.get_child_count() == 0:
		return
	var first_child := embedded.get_child(0)
	if first_child is VBoxContainer and first_child.get_child_count() > 0:
		var header := first_child.get_child(0)
		if header is HBoxContainer:
			header.visible = false

func _focus_embedded_tab(embedded: Control, tab_index: int) -> void:
	if not embedded.get("advanced_tabs"):
		return
	var tabs: AdvancedTabs = embedded.get("advanced_tabs")
	if tabs and tab_index >= 0 and tab_index < tabs.get_tab_count():
		tabs.select_tab(tab_index)

func _on_embedded_player_recruited(player) -> void:
	legacy_player_recruited.emit(player)

func select_section(section_id: String) -> bool:
	if not advanced_tabs:
		return false
	var index: int = _section_ids.find(section_id)
	if index < 0:
		return false
	return advanced_tabs.select_tab(index)

func apply_context(context: Dictionary) -> void:
	_pending_context = context.duplicate()
	var embedded: Control = _get_current_embedded_window()
	if embedded:
		_apply_context_to_embedded(embedded, _pending_context)

func _get_current_embedded_window() -> Control:
	if not advanced_tabs:
		return null
	var index: int = advanced_tabs.get_current_tab_index()
	if index < 0:
		return null
	var tab_data: Dictionary = advanced_tabs.get_tab_data(index)
	var content: Control = tab_data.get("content", null)
	if content and content.has_meta("embedded_window"):
		return content.get_meta("embedded_window") as Control
	return null

func _apply_context_to_embedded(embedded: Control, context: Dictionary) -> void:
	if not is_instance_valid(embedded) or context.is_empty():
		return
	var member: SimulatedPlayer = context.get("member", null) as SimulatedPlayer
	if member and embedded.has_method("focus_member"):
		embedded.call_deferred("focus_member", member)
	var candidate: SimulatedPlayer = context.get("candidate", null) as SimulatedPlayer
	if candidate and embedded.has_method("focus_candidate"):
		embedded.call_deferred("focus_candidate", candidate)

func _on_tab_selected(_index: int) -> void:
	if not _pending_context.is_empty():
		var embedded: Control = _get_current_embedded_window()
		if embedded:
			_apply_context_to_embedded(embedded, _pending_context)

func _on_summary_data_changed(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	if visible and is_node_ready():
		refresh_window.call_deferred()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not advanced_tabs:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
			return
		if key.keycode == KEY_TAB:
			_select_relative_section(1 if not key.shift_pressed else -1)
			get_viewport().set_input_as_handled()
		elif key.keycode >= KEY_1 and key.keycode <= KEY_9:
			var index: int = int(key.keycode - KEY_1)
			if index < advanced_tabs.get_tab_count():
				advanced_tabs.select_tab(index)
				get_viewport().set_input_as_handled()

func _select_relative_section(delta: int) -> void:
	var count: int = advanced_tabs.get_tab_count()
	if count <= 0:
		return
	var current: int = advanced_tabs.get_current_tab_index()
	var next_index: int = posmod(current + delta, count)
	advanced_tabs.select_tab(next_index)

func _make_locked_content() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _content_style())
	var label := Label.new()
	label.text = "Aucune section debloquee pour cette phase."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	panel.add_child(label)
	return panel

func _get_config() -> Dictionary:
	return HUBS.get(hub_id, HUBS["guild"])

func _get_visible_sections() -> Array:
	var out: Array = []
	var current_phase: int = PhaseManager.get_current_phase() if PhaseManager else 0
	for section in _get_config().get("sections", []):
		var phase_min: int = int(section.get("phase_min", 0))
		if current_phase >= phase_min:
			out.append(section)
	return out

func refresh_window() -> void:
	if not is_node_ready():
		return
	if advanced_tabs:
		var parent: Node = advanced_tabs.get_parent()
		parent.remove_child(advanced_tabs)
		advanced_tabs.free()
		advanced_tabs = null
		_setup_content(parent as VBoxContainer)

func _on_header_drag(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag_active = event.pressed
	elif event is InputEventMouseMotion and _drag_active:
		position += event.relative

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UITheme.BG_PANEL
	style.set_corner_radius_all(UITheme.RADIUS)
	style.set_border_width_all(1)
	style.border_color = UITheme.BORDER
	return style

func _content_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UITheme.BG_RAISED
	style.bg_color.a = 0.92
	style.set_corner_radius_all(UITheme.RADIUS)
	style.set_border_width_all(1)
	style.border_color = UITheme.BORDER_SUBTLE
	return style
