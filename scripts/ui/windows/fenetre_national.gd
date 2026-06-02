extends PanelContainer

## Fenêtre Phase Nationale : gestion de la célébrité, des médias/streaming,
## des sponsors et des dramas. Branchée sur MediaManager, SponsorshipManager,
## DramaManager (autoloads).

const ACCENT := Color(0.30, 0.64, 0.96)
const DIM := Color(0.62, 0.65, 0.71)
const GOLD := Color(1.0, 0.82, 0.30)

var advanced_tabs: AdvancedTabs
var _drag_active: bool = false

var _celebrity_box: VBoxContainer
var _media_box: VBoxContainer
var _sponsors_box: VBoxContainer
var _dramas_box: VBoxContainer

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

	_celebrity_box = _add_scroll_tab("Célébrité")
	_media_box = _add_scroll_tab("Médias")
	_sponsors_box = _add_scroll_tab("Sponsors")
	_dramas_box = _add_scroll_tab("Dramas")

	_connect_signals()
	_refresh_all()
	hide()

func _setup_header(parent: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	parent.add_child(header)

	var title := Label.new()
	title.text = "Scène Nationale"
	title.add_theme_font_size_override("font_size", 20)
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	title.mouse_default_cursor_shape = Control.CURSOR_MOVE
	title.tooltip_text = "Glissez pour déplacer la fenêtre"
	title.gui_input.connect(_on_header_drag)
	header.add_child(title)

	var phase_label := Label.new()
	if PhaseManager:
		phase_label.text = "  —  %s" % PhaseManager.get_phase_name(PhaseManager.get_current_phase())
	phase_label.add_theme_font_size_override("font_size", 13)
	phase_label.modulate = DIM
	header.add_child(phase_label)

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
	"""Crée un onglet scrollable et retourne le VBox de contenu."""
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
	if MediaManager:
		MediaManager.streamer_started.connect(_on_changed)
		MediaManager.media_incident.connect(func(_a, _b, _c): _on_changed())
	if SponsorshipManager:
		SponsorshipManager.sponsor_acquired.connect(_on_changed)
		SponsorshipManager.sponsor_lost.connect(func(_a, _b): _on_changed())
	if DramaManager:
		DramaManager.drama_occurred.connect(_on_changed)
		DramaManager.drama_resolved.connect(_on_changed)
	if GameTime and GameTime.has_signal("week_changed"):
		GameTime.week_changed.connect(func(_w, _y): _on_changed())

func _on_changed(_a = null) -> void:
	if visible:
		_refresh_all()

func _refresh_all() -> void:
	_build_celebrity()
	_build_media()
	_build_sponsors()
	_build_dramas()

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
	box.add_child(label)

func _card(parent: VBoxContainer) -> VBoxContainer:
	"""Crée un panneau-carte stylé par le thème global et retourne son VBox interne."""
	var panel := PanelContainer.new()
	parent.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	panel.add_child(inner)
	return inner

# --- Onglet Célébrité ---

func _build_celebrity() -> void:
	_clear(_celebrity_box)
	if not GuildManager:
		return

	var members: Array = GuildManager.guild_members.duplicate()
	members.sort_custom(func(a, b): return a.celebrity_level > b.celebrity_level)

	_section(_celebrity_box, "Célébrité des membres", GOLD)
	var hint := Label.new()
	hint.text = "La célébrité augmente avec le talent et le streaming. Elle attire sponsors et débauchages."
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = DIM
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_celebrity_box.add_child(hint)
	_celebrity_box.add_child(HSeparator.new())

	var any := false
	for member in members:
		if member.celebrity_level < 0.5:
			continue
		any = true
		_celebrity_box.add_child(_celebrity_row(member))

	if not any:
		_empty_hint(_celebrity_box, "Aucun membre n'est encore célèbre.")

func _celebrity_row(member) -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	var name_label := Label.new()
	name_label.text = "%s (%s)" % [member.nom, member.personnage_classe]
	name_label.custom_minimum_size = Vector2(240, 0)
	row.add_child(name_label)

	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = member.celebrity_level
	bar.custom_minimum_size = Vector2(260, 18)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bar)

	var val := Label.new()
	val.text = "%d" % int(member.celebrity_level)
	val.custom_minimum_size = Vector2(36, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)

	if member.get_meta("is_streamer", false):
		var tag := Badge.new()
		tag.text = "Streamer"
		tag.badge_type = Badge.BadgeType.PRIMARY
		tag.animate_appearance = false
		row.add_child(tag)

	return panel

# --- Onglet Médias / Streaming ---

func _build_media() -> void:
	_clear(_media_box)
	if not MediaManager:
		_empty_hint(_media_box, "Système médias indisponible.")
		return

	var total_audience: int = MediaManager.get_total_audience()
	var weekly_rev: float = MediaManager.get_total_weekly_revenue()

	_section(_media_box, "Streaming & Médias", ACCENT)
	var stats := _card(_media_box)
	_kv(stats, "Audience totale", _fmt_int(total_audience) + " spectateurs")
	_kv(stats, "Revenus streaming", "%d or / semaine" % int(weekly_rev))
	_kv(stats, "Part guilde (30%)", "%d or / semaine" % int(weekly_rev * 0.3))
	_media_box.add_child(HSeparator.new())

	_section(_media_box, "Streamers actifs")
	var streamers: Array = MediaManager.get_streamers()
	if streamers.is_empty():
		_empty_hint(_media_box, "Aucun streamer pour l'instant. Les membres célèbres (40+) peuvent se lancer.")
		return

	for member in streamers:
		var card := _card(_media_box)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		card.add_child(line)
		var name_label := Label.new()
		name_label.text = member.nom
		name_label.custom_minimum_size = Vector2(180, 0)
		line.add_child(name_label)
		var aud := Label.new()
		aud.text = "%s spectateurs" % _fmt_int(member.get_meta("audience_size", 0))
		aud.modulate = DIM
		line.add_child(aud)
		line.add_spacer(false)
		var rev := Label.new()
		rev.text = "+%d or/sem" % int(member.get_meta("stream_revenue", 0.0))
		rev.modulate = GOLD
		line.add_child(rev)

# --- Onglet Sponsors ---

func _build_sponsors() -> void:
	_clear(_sponsors_box)
	if not SponsorshipManager:
		_empty_hint(_sponsors_box, "Système sponsors indisponible.")
		return

	var weekly: int = SponsorshipManager.get_weekly_revenue()
	_section(_sponsors_box, "Sponsors actifs  (+%d or/sem)" % weekly, GOLD)

	var active: Array = SponsorshipManager.active_sponsors
	if active.is_empty():
		_empty_hint(_sponsors_box, "Aucun contrat actif. Consultez les offres ci-dessous.")
	else:
		for sponsor in active:
			_sponsors_box.add_child(_active_sponsor_card(sponsor))

	_sponsors_box.add_child(HSeparator.new())
	_section(_sponsors_box, "Offres disponibles", ACCENT)

	var available: Array = SponsorshipManager.available_sponsors
	if available.is_empty():
		_empty_hint(_sponsors_box, "Aucune offre actuellement.")
		return

	var slots_left: int = SponsorshipManager.MAX_ACTIVE_SPONSORS - active.size()
	for sponsor in available:
		_sponsors_box.add_child(_offer_sponsor_card(sponsor, slots_left > 0))

func _active_sponsor_card(sponsor) -> Control:
	var panel := PanelContainer.new()
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	panel.add_child(inner)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	inner.add_child(top)
	var name_label := Label.new()
	name_label.text = sponsor.sponsor_name
	name_label.add_theme_font_size_override("font_size", 15)
	top.add_child(name_label)
	top.add_child(_type_badge(sponsor.sponsor_type))
	top.add_spacer(false)
	var rev := Label.new()
	rev.text = "+%d or/sem" % sponsor.weekly_revenue
	rev.modulate = GOLD
	top.add_child(rev)

	var status := Label.new()
	status.text = sponsor.get_status_text()
	status.add_theme_font_size_override("font_size", 12)
	status.modulate = DIM
	inner.add_child(status)

	var sat := ProgressBar.new()
	sat.min_value = 0
	sat.max_value = 100
	sat.value = sponsor.satisfaction
	sat.custom_minimum_size = Vector2(0, 14)
	inner.add_child(sat)
	return panel

func _offer_sponsor_card(sponsor, has_slot: bool) -> Control:
	var panel := PanelContainer.new()
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	panel.add_child(inner)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	inner.add_child(top)
	var name_label := Label.new()
	name_label.text = sponsor.sponsor_name
	name_label.add_theme_font_size_override("font_size", 15)
	top.add_child(name_label)
	top.add_child(_type_badge(sponsor.sponsor_type))
	top.add_spacer(false)
	var rev := Label.new()
	rev.text = "+%d or/sem · %d sem." % [sponsor.weekly_revenue, sponsor.duration_weeks]
	rev.modulate = GOLD
	top.add_child(rev)

	# Exigences
	var rep: float = GuildManager.guild.reputation if GuildManager.guild else 50.0
	var members: int = GuildManager.guild_members.size()
	var audience: int = MediaManager.get_total_audience() if MediaManager else 0
	var weeks_scandal: int = SponsorshipManager.weeks_since_last_scandal
	var meets: bool = sponsor.check_requirements(rep, members, audience, weeks_scandal)

	var reqs := Label.new()
	reqs.text = _format_requirements(sponsor, rep, members, audience)
	reqs.add_theme_font_size_override("font_size", 11)
	reqs.modulate = Color(0.55, 0.8, 0.55) if meets else Color(0.85, 0.5, 0.5)
	reqs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(reqs)

	var sign_btn := Button.new()
	sign_btn.text = "Signer le contrat"
	sign_btn.disabled = not (meets and has_slot)
	if not has_slot:
		sign_btn.tooltip_text = "Nombre maximum de sponsors atteint."
	elif not meets:
		sign_btn.tooltip_text = "Exigences non remplies."
	var sponsor_ref = sponsor
	sign_btn.pressed.connect(func():
		if SponsorshipManager.try_sign_sponsor(sponsor_ref):
			_refresh_all()
	)
	inner.add_child(sign_btn)
	return panel

func _format_requirements(sponsor, rep: float, members: int, audience: int) -> String:
	var parts: Array = []
	parts.append("Réput. %d/%d" % [int(rep), int(sponsor.min_reputation)])
	if sponsor.min_members > 0:
		parts.append("Membres %d/%d" % [members, sponsor.min_members])
	if sponsor.min_audience > 0:
		parts.append("Audience %s/%s" % [_fmt_int(audience), _fmt_int(sponsor.min_audience)])
	return "Exigences : " + "  ·  ".join(parts)

func _type_badge(sponsor_type: String) -> Badge:
	var b := Badge.new()
	b.text = sponsor_type
	b.badge_type = Badge.BadgeType.INFO
	b.animate_appearance = false
	return b

# --- Onglet Dramas ---

func _build_dramas() -> void:
	_clear(_dramas_box)
	if not DramaManager:
		_empty_hint(_dramas_box, "Système dramas indisponible.")
		return

	_section(_dramas_box, "Crises en cours", Color(0.9, 0.4, 0.4))
	var active: Array = DramaManager.active_dramas
	if active.is_empty():
		_empty_hint(_dramas_box, "Aucune crise en cours. Tout est calme... pour l'instant.")
	else:
		for drama in active:
			_dramas_box.add_child(_drama_card(drama))

	_dramas_box.add_child(HSeparator.new())
	_section(_dramas_box, "Historique récent", DIM)
	var resolved: Array = DramaManager.resolved_dramas
	if resolved.is_empty():
		_empty_hint(_dramas_box, "Aucun drama résolu.")
	else:
		var recent := resolved.duplicate()
		recent.reverse()
		for i in range(mini(8, recent.size())):
			var d = recent[i]
			var line := Label.new()
			line.text = "• %s (%s) — %s" % [d.get_type_name(), d.get_severity_name(), d.source_member]
			line.add_theme_font_size_override("font_size", 12)
			line.modulate = DIM
			_dramas_box.add_child(line)

func _drama_card(drama) -> Control:
	var panel := PanelContainer.new()
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	panel.add_child(inner)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	inner.add_child(top)
	var type_label := Label.new()
	type_label.text = drama.get_type_name()
	type_label.add_theme_font_size_override("font_size", 15)
	top.add_child(type_label)
	top.add_child(_severity_badge(drama.severity))

	var desc := Label.new()
	desc.text = drama.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(desc)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	inner.add_child(actions)
	var resolutions := [
		["Silence", "silence"],
		["Communiquer", "communication"],
		["Sanctions", "sanctions"],
		["Exclure", "exclusion"],
	]
	for r in resolutions:
		var btn := Button.new()
		btn.text = r[0]
		var res: String = r[1]
		var drama_ref = drama
		btn.pressed.connect(func():
			DramaManager.resolve_drama(drama_ref, res)
			_refresh_all()
		)
		actions.add_child(btn)
	return panel

func _severity_badge(severity: int) -> Badge:
	var b := Badge.new()
	b.animate_appearance = false
	match severity:
		3:
			b.text = "Grave"
			b.badge_type = Badge.BadgeType.ERROR
		2:
			b.text = "Moyen"
			b.badge_type = Badge.BadgeType.WARNING
		_:
			b.text = "Mineur"
			b.badge_type = Badge.BadgeType.DEFAULT
	return b

# --- Utilitaires ---

func _kv(box: VBoxContainer, key: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var k := Label.new()
	k.text = key
	k.custom_minimum_size = Vector2(180, 0)
	k.modulate = DIM
	row.add_child(k)
	var v := Label.new()
	v.text = value
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
