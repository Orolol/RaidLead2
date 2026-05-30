extends PanelContainer

## Fenêtre Conseils & Statistiques (Milestone 6, US 6.1 + 6.2).
## - Onglet Conseils : recommandations adaptatives priorisées (AdvisorManager).
## - Onglet Statistiques : tableau de bord guilde + table détaillée par membre.

const ACCENT := Color(0.30, 0.64, 0.96)
const DIM := Color(0.62, 0.65, 0.71)
const GOLD := Color(1.0, 0.82, 0.30)
const GREEN := Color(0.55, 0.82, 0.55)
const RED := Color(0.88, 0.45, 0.45)

var advanced_tabs: AdvancedTabs
var _drag_active: bool = false

var _advice_box: VBoxContainer
var _stats_box: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(900, 640)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	_setup_header(vbox)

	advanced_tabs = AdvancedTabs.create_simple_tabs(vbox)
	advanced_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	advanced_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_advice_box = _add_scroll_tab("Conseils")
	_stats_box = _add_scroll_tab("Statistiques")

	_connect_signals()
	_refresh_all()
	hide()

func _setup_header(parent: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	parent.add_child(header)

	var title := Label.new()
	title.text = "Conseiller de Guilde"
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
	# Rafraîchir au fil du temps de jeu et aux changements de phase.
	if GameTime and GameTime.has_signal("week_changed"):
		GameTime.week_changed.connect(func(_w, _y): _on_changed())
	if PhaseManager and PhaseManager.has_signal("phase_changed"):
		PhaseManager.phase_changed.connect(func(_n, _o): _on_changed())

func _on_changed() -> void:
	if visible:
		_refresh_all()

# Appelée par le WindowManager à l'affichage de la fenêtre.
func refresh_window() -> void:
	_refresh_all()

func _refresh_all() -> void:
	_build_advice()
	_build_stats()

# --- Helpers UI partagés ---

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
	k.custom_minimum_size = Vector2(220, 0)
	k.modulate = DIM
	row.add_child(k)
	var v := Label.new()
	v.text = value
	v.modulate = value_color
	row.add_child(v)

func _fmt_int(n: int) -> String:
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = " " + out
	return out

# --- Onglet Conseils ---

func _build_advice() -> void:
	_clear(_advice_box)
	_section(_advice_box, "Recommandations du conseiller", GOLD)
	_empty_hint(_advice_box, "Analyse en direct de votre guilde : alertes, points de vigilance, astuces et opportunités, classés par priorité.")
	_advice_box.add_child(HSeparator.new())

	if not AdvisorManager:
		_empty_hint(_advice_box, "Conseiller indisponible.")
		return

	var advice: Array = AdvisorManager.get_advice()
	if advice.is_empty():
		_advice_box.add_child(_good_news_card())
		return

	for a in advice:
		_advice_box.add_child(_advice_card(a))

func _good_news_card() -> Control:
	var panel := PanelContainer.new()
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	panel.add_child(inner)
	var title := Label.new()
	title.text = "Tout va bien"
	title.add_theme_font_size_override("font_size", 15)
	title.modulate = GREEN
	inner.add_child(title)
	var desc := Label.new()
	desc.text = "Aucune alerte particulière. Votre guilde est sur de bons rails — continuez votre progression."
	desc.add_theme_font_size_override("font_size", 12)
	desc.modulate = DIM
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(desc)
	return panel

func _advice_card(advice: Dictionary) -> Control:
	var severity: int = advice.get("severity", AdvisorManager.Severity.TIP)
	var panel := PanelContainer.new()
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	panel.add_child(inner)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	inner.add_child(top)

	top.add_child(_severity_chip(severity))

	var title := Label.new()
	title.text = advice.get("title", "")
	title.add_theme_font_size_override("font_size", 15)
	title.modulate = AdvisorManager.get_severity_color(severity)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(title)

	var desc := Label.new()
	desc.text = advice.get("text", "")
	desc.add_theme_font_size_override("font_size", 12)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(desc)
	return panel

func _severity_chip(severity: int) -> Control:
	"""Pastille colorée auto-dimensionnée (PanelContainer = pas de débordement, contrairement au composant Badge)."""
	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var c: Color = AdvisorManager.get_severity_color(severity)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(c.r, c.g, c.b, 0.22)
	style.set_corner_radius_all(9)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	style.set_border_width_all(1)
	style.border_color = c
	pill.add_theme_stylebox_override("panel", style)
	var lbl := Label.new()
	lbl.text = AdvisorManager.get_severity_label(severity)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", c.lightened(0.35))
	pill.add_child(lbl)
	return pill

# --- Onglet Statistiques ---

func _build_stats() -> void:
	_clear(_stats_box)
	if not GuildManager or not GuildManager.guild:
		_empty_hint(_stats_box, "Données de guilde indisponibles.")
		return

	_section(_stats_box, "Vue d'ensemble", ACCENT)
	var overview := _card(_stats_box)
	var guild = GuildManager.guild
	var members: Array = GuildManager.guild_members

	if PhaseManager:
		_kv(overview, "Phase actuelle", PhaseManager.get_phase_name(PhaseManager.get_current_phase()), GOLD)
	_kv(overview, "Niveau de guilde", str(guild.get_level()))
	_kv(overview, "Trésorerie", "%s or" % _fmt_int(guild.gold), GOLD)
	_kv(overview, "Réputation", "%d (%s)" % [int(guild.reputation), guild.get_reputation_tier()], _rep_color(guild.reputation))

	var gcm: Node = get_node_or_null("/root/GuildCultureManager")
	if gcm and gcm.has_method("get_guild_morale"):
		var morale: float = gcm.get_guild_morale()
		_kv(overview, "Moral de guilde", "%d (%s)" % [int(morale), gcm.get_morale_tier()], _morale_color(morale))

	var salaries: int = GuildManager.get_total_weekly_salaries()
	if salaries > 0:
		_kv(overview, "Masse salariale", "%s or / semaine" % _fmt_int(salaries), GOLD)

	_stats_box.add_child(HSeparator.new())
	_section(_stats_box, "Effectif", ACCENT)
	var roster := _card(_stats_box)
	var online: int = GuildManager.get_online_members().size()
	_kv(roster, "Membres", "%d / %d" % [members.size(), guild.get_max_members()])
	_kv(roster, "En ligne", str(online), GREEN if online > 0 else DIM)
	if not members.is_empty():
		_kv(roster, "Niveau moyen", "%.1f" % _avg(members, "personnage_niveau"))
		_kv(roster, "Skill moyen", "%.0f" % _avg(members, "skill"))
		_kv(roster, "Intégration moyenne", "%.0f%%" % _avg(members, "integration"))
		_kv(roster, "Moral moyen", "%.0f" % _avg(members, "mood"))
		_kv(roster, "Stress moyen", "%.0f" % _avg(members, "stress_level"))

	_stats_box.add_child(HSeparator.new())
	_section(_stats_box, "Détail par membre", ACCENT)
	if members.is_empty():
		_empty_hint(_stats_box, "Aucun membre.")
		return
	_stats_box.add_child(_member_header())
	var sorted: Array = members.duplicate()
	sorted.sort_custom(func(a, b): return a.personnage_niveau > b.personnage_niveau)
	for m in sorted:
		_stats_box.add_child(_member_row(m))

func _member_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_cell("Membre", 160, DIM))
	row.add_child(_cell("Classe", 90, DIM))
	row.add_child(_cell("Niv", 40, DIM))
	row.add_child(_cell("Skill", 50, DIM))
	row.add_child(_cell("Moral", 55, DIM))
	row.add_child(_cell("Énergie", 60, DIM))
	row.add_child(_cell("Stress", 55, DIM))
	row.add_child(_cell("Intég.", 55, DIM))
	return row

func _member_row(m) -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)

	var name_color: Color = GOLD if m.get_meta("is_player", false) else Color.WHITE
	row.add_child(_cell(m.nom, 160, name_color))
	row.add_child(_cell(m.personnage_classe, 90, DIM))
	row.add_child(_cell(str(m.personnage_niveau), 40))
	row.add_child(_cell(str(m.skill), 50))
	row.add_child(_cell("%d" % int(m.mood), 55, _pct_color(m.mood)))
	row.add_child(_cell("%d" % int(m.energy), 60, _pct_color(m.energy)))
	row.add_child(_cell("%d" % int(m.stress_level), 55, _stress_color(m.stress_level)))
	row.add_child(_cell("%d" % int(m.integration), 55, _pct_color(m.integration)))
	return panel

func _cell(text: String, width: int, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(width, 0)
	label.clip_text = true
	label.modulate = color
	return label

# --- Couleurs ---

func _avg(members: Array, prop: String) -> float:
	if members.is_empty():
		return 0.0
	var total: float = 0.0
	for m in members:
		total += float(m.get(prop))
	return total / float(members.size())

func _pct_color(v: float) -> Color:
	if v >= 66.0:
		return GREEN
	elif v >= 33.0:
		return GOLD
	return RED

func _stress_color(v: float) -> Color:
	if v >= 60.0:
		return RED
	elif v >= 35.0:
		return GOLD
	return GREEN

func _rep_color(v: float) -> Color:
	if v >= 60.0:
		return GREEN
	elif v >= 40.0:
		return GOLD
	return RED

func _morale_color(v: float) -> Color:
	if v >= 70.0:
		return GREEN
	elif v >= 50.0:
		return GOLD
	return RED
