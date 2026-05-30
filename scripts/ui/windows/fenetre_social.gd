extends PanelContainer

## Fenêtre Cohésion (Milestone 5) : moral de guilde, relations sociales, cliques,
## team-building, traditions et gestion des conflits.
## Branchée sur GuildCultureManager (autoload), qui pilote SocialDynamics.

const ACCENT := Color(0.30, 0.64, 0.96)
const DIM := Color(0.62, 0.65, 0.71)
const GOLD := Color(1.0, 0.82, 0.30)
const GREEN := Color(0.55, 0.82, 0.55)
const RED := Color(0.88, 0.45, 0.45)

var advanced_tabs: AdvancedTabs
var _drag_active: bool = false

var _morale_box: VBoxContainer
var _relations_box: VBoxContainer
var _cliques_box: VBoxContainer
var _team_box: VBoxContainer
var _traditions_box: VBoxContainer
var _conflicts_box: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(940, 660)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	_setup_header(vbox)

	advanced_tabs = AdvancedTabs.create_simple_tabs(vbox)
	advanced_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	advanced_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_morale_box = _add_scroll_tab("Moral & Ambiance")
	_relations_box = _add_scroll_tab("Relations")
	_cliques_box = _add_scroll_tab("Cliques")
	_team_box = _add_scroll_tab("Team-building")
	_traditions_box = _add_scroll_tab("Traditions")
	_conflicts_box = _add_scroll_tab("Conflits")

	_connect_signals()
	_refresh_all()
	hide()

func _setup_header(parent: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	parent.add_child(header)

	var title := Label.new()
	title.text = "Cohésion de Guilde"
	title.add_theme_font_size_override("font_size", 20)
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	title.mouse_default_cursor_shape = Control.CURSOR_MOVE
	title.tooltip_text = "Glissez pour déplacer la fenêtre"
	title.gui_input.connect(_on_header_drag)
	header.add_child(title)

	header.add_spacer(false)

	var refresh_btn := Button.new()
	refresh_btn.text = "Actualiser"
	refresh_btn.pressed.connect(_refresh_all)
	header.add_child(refresh_btn)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(34, 30)
	close_btn.pressed.connect(func(): hide())
	header.add_child(close_btn)

func _on_header_drag(event: InputEvent) -> void:
	"""Permet de déplacer la fenêtre en glissant sur la barre de titre."""
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag_active = event.pressed
	elif event is InputEventMouseMotion and _drag_active:
		position += event.relative

func _add_scroll_tab(tab_title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	advanced_tabs.add_tab(tab_title, scroll, false)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return box

func _connect_signals() -> void:
	if GuildCultureManager:
		GuildCultureManager.morale_changed.connect(func(_a, _b): _on_changed())
		GuildCultureManager.team_building_done.connect(func(_a, _b): _on_changed())
		GuildCultureManager.tradition_established.connect(func(_a): _on_changed())
		GuildCultureManager.tension_detected.connect(func(_a, _b, _c): _on_changed())
		GuildCultureManager.tension_resolved.connect(func(_a, _b): _on_changed())
	if GameTime and GameTime.has_signal("week_changed"):
		GameTime.week_changed.connect(func(_w, _y): _on_changed())

func _on_changed() -> void:
	if visible:
		_refresh_all()

func _refresh_all() -> void:
	_build_morale()
	_build_relations()
	_build_cliques()
	_build_team_building()
	_build_traditions()
	_build_conflicts()

# --- Helpers UI ---

func _clear(box: VBoxContainer) -> void:
	for child in box.get_children():
		child.queue_free()

func _section(box: VBoxContainer, text: String, color: Color = Color.WHITE) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.modulate = color
	box.add_child(label)

func _empty_hint(box: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = DIM
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)

func _card(parent: VBoxContainer) -> VBoxContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	panel.add_child(inner)
	return inner

func _kv(box: VBoxContainer, key: String, value: String, value_color: Color = Color.WHITE) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var k := Label.new()
	k.text = key
	k.custom_minimum_size = Vector2(200, 0)
	k.modulate = DIM
	row.add_child(k)
	var v := Label.new()
	v.text = value
	v.modulate = value_color
	row.add_child(v)

func _gold() -> int:
	return GuildManager.guild.gold if (GuildManager and GuildManager.guild) else 0

# --- Onglet Moral & Ambiance ---

func _build_morale() -> void:
	_clear(_morale_box)
	if not GuildCultureManager:
		_empty_hint(_morale_box, "Système de culture indisponible.")
		return

	var morale: float = GuildCultureManager.get_guild_morale()
	_section(_morale_box, "Moral de la guilde", GOLD)

	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = morale
	bar.custom_minimum_size = Vector2(0, 22)
	_morale_box.add_child(bar)

	var tier := Label.new()
	tier.text = "%d / 100  —  Ambiance %s" % [int(morale), GuildCultureManager.get_morale_tier()]
	tier.modulate = GREEN if morale >= 70 else (GOLD if morale >= 50 else RED)
	_morale_box.add_child(tier)

	_morale_box.add_child(HSeparator.new())
	_section(_morale_box, "Santé sociale", ACCENT)
	var counts: Dictionary = GuildCultureManager.get_relationship_counts()
	var stats := _card(_morale_box)
	_kv(stats, "Amitiés", str(counts.get("friend", 0)), GREEN)
	_kv(stats, "Mentorats", str(counts.get("mentor", 0)), ACCENT)
	_kv(stats, "Rivalités", str(counts.get("rival", 0)), GOLD)
	_kv(stats, "Inimitiés", str(counts.get("enemy", 0)), RED)

	var hint := Label.new()
	hint.text = "Le moral reflète l'humeur des membres, la qualité des relations et les traditions établies. L'humeur se propage entre membres liés (contagion émotionnelle)."
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = DIM
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_morale_box.add_child(hint)

# --- Onglet Relations ---

func _build_relations() -> void:
	_clear(_relations_box)
	if not GuildCultureManager or not GuildManager:
		return
	_section(_relations_box, "Cercles sociaux des membres", ACCENT)

	var any := false
	for member in GuildManager.guild_members:
		var info: Dictionary = GuildCultureManager.get_member_social(member)
		if info["friends"].is_empty() and info["rivals"].is_empty() and info["enemies"].is_empty() and info["mentors"].is_empty():
			continue
		any = true
		var card := _card(_relations_box)
		var name_label := Label.new()
		name_label.text = "%s (%s)" % [member.nom, member.personnage_classe]
		name_label.add_theme_font_size_override("font_size", 14)
		card.add_child(name_label)
		_relation_line(card, "Amis", info["friends"], GREEN)
		_relation_line(card, "Mentors/élèves", info["mentors"], ACCENT)
		_relation_line(card, "Rivaux", info["rivals"], GOLD)
		_relation_line(card, "Ennemis", info["enemies"], RED)

	if not any:
		_empty_hint(_relations_box, "Aucune relation encore tissée. Les liens se forment au fil des semaines (et plus vite après un team-building).")

func _relation_line(card: VBoxContainer, label_text: String, names: Array, color: Color) -> void:
	if names.is_empty():
		return
	var line := Label.new()
	line.text = "%s : %s" % [label_text, ", ".join(names)]
	line.add_theme_font_size_override("font_size", 12)
	line.modulate = color
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(line)

# --- Onglet Cliques ---

func _build_cliques() -> void:
	_clear(_cliques_box)
	if not GuildCultureManager:
		return
	_section(_cliques_box, "Cliques de la guilde", GOLD)
	var cliques: Array = GuildCultureManager.get_cliques()
	if cliques.is_empty():
		_empty_hint(_cliques_box, "Aucune clique formée. Elles émergent quand des groupes d'amis proches se constituent.")
		return
	for c in cliques:
		var card := _card(_cliques_box)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 8)
		card.add_child(top)
		var name_label := Label.new()
		name_label.text = c.name
		name_label.add_theme_font_size_override("font_size", 15)
		top.add_child(name_label)
		top.add_spacer(false)
		var leader_label := Label.new()
		leader_label.text = ("Leader : %s" % c.leader.nom) if c.leader else "Sans leader"
		leader_label.modulate = DIM
		top.add_child(leader_label)

		var names: Array = []
		for member in c.members:
			names.append(member.nom)
		var members_label := Label.new()
		members_label.text = "Membres : " + ", ".join(names)
		members_label.add_theme_font_size_override("font_size", 12)
		members_label.modulate = DIM
		members_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(members_label)

		var cohesion_bar := ProgressBar.new()
		cohesion_bar.min_value = 0
		cohesion_bar.max_value = 100
		cohesion_bar.value = c.cohesion * 100.0
		cohesion_bar.custom_minimum_size = Vector2(0, 14)
		card.add_child(cohesion_bar)

# --- Onglet Team-building ---

func _build_team_building() -> void:
	_clear(_team_box)
	if not GuildCultureManager:
		return

	var stats := _card(_team_box)
	_kv(stats, "Moral de guilde", "%d / 100" % int(GuildCultureManager.get_guild_morale()), GOLD)
	_kv(stats, "Trésorerie", "%d or" % _gold(), GOLD)
	if not GuildCultureManager.can_team_build():
		_kv(stats, "Disponibilité", "Cooldown : %d sem." % GuildCultureManager.team_building_cooldown, DIM)
	else:
		_kv(stats, "Disponibilité", "Prêt", GREEN)

	_team_box.add_child(HSeparator.new())
	_section(_team_box, "Organiser un événement", ACCENT)

	var on_cooldown: bool = not GuildCultureManager.can_team_build()
	for activity in GuildCultureManager.get_team_building_catalog():
		_team_box.add_child(_team_building_card(activity, on_cooldown))

func _team_building_card(activity: Dictionary, on_cooldown: bool) -> Control:
	var panel := PanelContainer.new()
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	panel.add_child(inner)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	inner.add_child(top)
	var name_label := Label.new()
	name_label.text = activity.get("name", "")
	name_label.add_theme_font_size_override("font_size", 14)
	top.add_child(name_label)
	top.add_spacer(false)
	var cost := Label.new()
	cost.text = "%d or" % activity.get("gold", 0)
	cost.modulate = GOLD
	top.add_child(cost)

	var desc := Label.new()
	desc.text = "%s  (+%d moral, +%d humeur)" % [activity.get("desc", ""), activity.get("morale", 0), activity.get("mood", 0)]
	desc.add_theme_font_size_override("font_size", 11)
	desc.modulate = DIM
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(desc)

	var can_afford: bool = _gold() >= activity.get("gold", 0)
	var btn := Button.new()
	btn.text = "Organiser"
	btn.disabled = on_cooldown or not can_afford
	if on_cooldown:
		btn.tooltip_text = "Un team-building a déjà eu lieu récemment."
	elif not can_afford:
		btn.tooltip_text = "Trésorerie insuffisante."
	var activity_ref: Dictionary = activity
	btn.pressed.connect(func():
		if GuildCultureManager.run_team_building(activity_ref):
			if NotificationManager:
				NotificationManager.show_success("%s organisé !" % activity_ref.get("name", ""), "Team-building")
			_refresh_all()
	)
	inner.add_child(btn)
	return panel

# --- Onglet Traditions ---

func _build_traditions() -> void:
	_clear(_traditions_box)
	if not GuildCultureManager:
		return
	_section(_traditions_box, "Rituels & traditions", GOLD)
	_empty_hint(_traditions_box, "Les traditions établies confèrent des bonus passifs de moral et de cohésion chaque semaine.")

	for t in GuildCultureManager.get_traditions_status():
		_traditions_box.add_child(_tradition_card(t))

func _tradition_card(t: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	panel.add_child(inner)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	inner.add_child(top)
	var name_label := Label.new()
	name_label.text = t.get("name", "")
	name_label.add_theme_font_size_override("font_size", 14)
	top.add_child(name_label)
	if t.get("established", false):
		var badge := Badge.new()
		badge.text = "Établie"
		badge.badge_type = Badge.BadgeType.SUCCESS
		badge.animate_appearance = false
		top.add_child(badge)
	top.add_spacer(false)
	var effect := Label.new()
	effect.text = "+%.1f moral/sem" % t.get("morale_week", 0.0)
	effect.modulate = GREEN
	top.add_child(effect)

	var desc := Label.new()
	desc.text = "%s  (requis : %d membres · %d or)" % [t.get("desc", ""), t.get("req_members", 0), t.get("cost", 0)]
	desc.add_theme_font_size_override("font_size", 11)
	desc.modulate = DIM
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(desc)

	if not t.get("established", false):
		var btn := Button.new()
		btn.text = "Établir"
		btn.disabled = not t.get("can_establish", false)
		if not t.get("can_establish", false):
			btn.tooltip_text = "Conditions non remplies (membres ou trésorerie)."
		var tid: String = t.get("id", "")
		btn.pressed.connect(func():
			if GuildCultureManager.establish_tradition(tid):
				if NotificationManager:
					NotificationManager.show_achievement("Tradition établie : %s" % t.get("name", ""), "Culture")
				_refresh_all()
		)
		inner.add_child(btn)
	return panel

# --- Onglet Conflits ---

func _build_conflicts() -> void:
	_clear(_conflicts_box)
	if not GuildCultureManager:
		return
	_section(_conflicts_box, "Tensions en cours", Color(0.9, 0.4, 0.4))
	var tensions: Array = GuildCultureManager.get_tensions()
	if tensions.is_empty():
		_empty_hint(_conflicts_box, "Aucune tension. L'ambiance est sereine pour l'instant.")
		return
	for tension in tensions:
		_conflicts_box.add_child(_tension_card(tension))

func _tension_card(tension: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	panel.add_child(inner)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	inner.add_child(top)
	var name_label := Label.new()
	name_label.text = "%s  ⚔  %s" % [tension["p1"].nom, tension["p2"].nom]
	name_label.add_theme_font_size_override("font_size", 14)
	top.add_child(name_label)
	var badge := Badge.new()
	badge.animate_appearance = false
	if tension.get("is_enemy", false):
		badge.text = "Inimitié"
		badge.badge_type = Badge.BadgeType.ERROR
	else:
		badge.text = "Rivalité"
		badge.badge_type = Badge.BadgeType.WARNING
	top.add_child(badge)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	inner.add_child(actions)
	var p1 = tension["p1"]
	var p2 = tension["p2"]

	var mediate_btn := Button.new()
	mediate_btn.text = "Médiation"
	mediate_btn.tooltip_text = "Demande à un membre ami des deux d'arbitrer."
	mediate_btn.pressed.connect(func(): _do_resolve(p1, p2, "mediation"))
	actions.add_child(mediate_btn)

	var soothe_btn := Button.new()
	soothe_btn.text = "Apaiser"
	soothe_btn.tooltip_text = "Désamorce directement la tension."
	soothe_btn.pressed.connect(func(): _do_resolve(p1, p2, "team_building"))
	actions.add_child(soothe_btn)

	return panel

func _do_resolve(p1, p2, method: String) -> void:
	var result: Dictionary = GuildCultureManager.resolve_tension(p1, p2, method)
	if NotificationManager:
		if result.get("success", false):
			NotificationManager.show_success("Tension entre %s et %s apaisée." % [p1.nom, p2.nom], "Conflit résolu")
		else:
			NotificationManager.show_warning(result.get("reason", "Échec"), "Conflit")
	_refresh_all()
