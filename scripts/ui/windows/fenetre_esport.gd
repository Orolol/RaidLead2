extends PanelContainer

## Fenêtre Phase Esport (Milestone 4) : staff professionnel, tournois internationaux,
## bien-être/burnout, transferts internationaux et legacy/Hall of Fame.
## Branchée sur StaffManager, TournamentManager, TransferManager, LegacyManager,
## PhaseManager (autoloads).

# Palette : ACCENT/DIM dérivés de UITheme (source canonique). GOLD/GREEN/RED
# n'ont pas d'équivalent exact dans UITheme et restent littéraux.
const ACCENT := UITheme.ACCENT
const DIM := UITheme.TEXT_DIM
const GOLD := Color(1.0, 0.82, 0.30)
const GREEN := Color(0.55, 0.82, 0.55)
const RED := Color(0.88, 0.45, 0.45)

var advanced_tabs: AdvancedTabs
var _drag_active: bool = false

var _objectives_box: VBoxContainer
var _staff_box: VBoxContainer
var _tournament_box: VBoxContainer
var _wellbeing_box: VBoxContainer
var _transfer_box: VBoxContainer
var _legacy_box: VBoxContainer

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

	_objectives_box = _add_scroll_tab("Objectifs")
	_staff_box = _add_scroll_tab("Staff")
	_tournament_box = _add_scroll_tab("Tournois")
	_wellbeing_box = _add_scroll_tab("Bien-être")
	_transfer_box = _add_scroll_tab("Transferts")
	_legacy_box = _add_scroll_tab("Legacy")

	_connect_signals()
	_refresh_all()
	hide()

func _setup_header(parent: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	parent.add_child(header)

	var title := Label.new()
	title.text = "Scène Esport Mondiale"
	title.add_theme_font_size_override("font_size", 20)
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	title.mouse_default_cursor_shape = Control.CURSOR_MOVE
	title.tooltip_text = "Glissez pour déplacer la fenêtre"
	title.gui_input.connect(_on_header_drag)
	header.add_child(title)

	var subtitle := Label.new()
	if LegacyManager:
		subtitle.text = "  —  %s" % LegacyManager.get_rank_title()
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.modulate = GOLD
	header.add_child(subtitle)

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
	if StaffManager:
		StaffManager.staff_hired.connect(_on_changed)
		StaffManager.staff_fired.connect(_on_changed)
		StaffManager.staff_pool_refreshed.connect(_on_changed)
	if TournamentManager:
		TournamentManager.tournament_completed.connect(func(_a, _b, _c, _d): _on_changed())
		TournamentManager.tournament_available.connect(_on_changed)
		TournamentManager.bootcamp_started.connect(_on_changed)
	if TransferManager:
		TransferManager.transfer_window_opened.connect(_on_changed)
		TransferManager.transfer_window_closed.connect(_on_changed)
		TransferManager.transfer_completed.connect(_on_changed)
	if LegacyManager:
		LegacyManager.legacy_earned.connect(_on_changed)
		LegacyManager.title_unlocked.connect(_on_changed)
	if GameTime and GameTime.has_signal("week_changed"):
		GameTime.week_changed.connect(func(_w, _y): _on_changed())

func _on_changed(_a = null) -> void:
	if visible:
		_refresh_all()

func _refresh_all() -> void:
	_build_objectives()
	_build_staff()
	_build_tournaments()
	_build_wellbeing()
	_build_transfers()
	_build_legacy()

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
	k.custom_minimum_size = Vector2(200, 0)
	k.modulate = DIM
	row.add_child(k)
	var v := Label.new()
	v.text = value
	v.modulate = value_color
	row.add_child(v)

func _gold() -> int:
	return GuildManager.guild.gold if GuildManager and GuildManager.guild else 0

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

# --- Onglet Objectifs (maîtrise de la phase finale) ---

func _build_objectives() -> void:
	_clear(_objectives_box)
	_section(_objectives_box, "Objectifs de maîtrise — Niveau Esport", GOLD)
	_empty_hint(_objectives_box, "La phase Esport est l'aboutissement du jeu. Atteignez ces objectifs pour asseoir votre légende mondiale.")
	_objectives_box.add_child(HSeparator.new())

	if not PhaseManager or not PhaseManager.has_method("get_requirements_progress"):
		_empty_hint(_objectives_box, "Système de progression indisponible.")
		return

	var progress: Dictionary = PhaseManager.get_requirements_progress(PhaseManager.GamePhase.ESPORT)
	var labels: Dictionary = {
		"world_championship_wins": "Titres de Champion du Monde",
		"professional_staff_count": "Membres du staff professionnel",
		"international_reputation": "Réputation internationale",
		"team_stability": "Stabilité de l'équipe",
	}
	for req_name in labels:
		if not progress.has(req_name):
			continue
		var data: Dictionary = progress[req_name]
		_objectives_box.add_child(_objective_row(labels[req_name], data))

func _objective_row(label_text: String, data: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	panel.add_child(inner)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	inner.add_child(top)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.custom_minimum_size = Vector2(280, 0)
	top.add_child(name_label)

	var met: bool = data.get("met", false)
	var status := Label.new()
	status.text = "%s / %s" % [_fmt_value(data.get("current", 0)), _fmt_value(data.get("required", 0))]
	status.modulate = GREEN if met else RED
	top.add_child(status)

	top.add_spacer(false)
	var badge := Badge.new()
	badge.animate_appearance = false
	if met:
		badge.text = "Atteint"
		badge.badge_type = Badge.BadgeType.SUCCESS
	else:
		badge.text = "En cours"
		badge.badge_type = Badge.BadgeType.WARNING
	top.add_child(badge)

	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = data.get("progress_percent", 0.0)
	bar.custom_minimum_size = Vector2(0, 14)
	inner.add_child(bar)
	return panel

func _fmt_value(v) -> String:
	if v is float:
		return "%.0f" % v
	return str(v)

# --- Onglet Staff ---

func _build_staff() -> void:
	_clear(_staff_box)
	if not StaffManager:
		_empty_hint(_staff_box, "Système de staff indisponible.")
		return

	var count: int = StaffManager.get_staff_count()
	var stats := _card(_staff_box)
	_kv(stats, "Staff employé", "%d / %d" % [count, StaffManager.MAX_STAFF])
	_kv(stats, "Masse salariale staff", "%d or / semaine" % StaffManager.get_total_weekly_salary(), GOLD)
	_kv(stats, "Synergie", "x%.2f" % StaffManager.get_synergy_multiplier(), ACCENT)
	_kv(stats, "Trésorerie guilde", "%s or" % _fmt_int(_gold()), GOLD)

	_staff_box.add_child(HSeparator.new())
	_section(_staff_box, "Staff employé", ACCENT)
	if StaffManager.hired_staff.is_empty():
		_empty_hint(_staff_box, "Aucun membre du staff. Embauchez coachs, analystes, psychologues et managers ci-dessous.")
	else:
		for s in StaffManager.hired_staff:
			_staff_box.add_child(_hired_staff_card(s))

	_staff_box.add_child(HSeparator.new())
	_section(_staff_box, "Candidats disponibles", GOLD)
	if StaffManager.available_staff.is_empty():
		_empty_hint(_staff_box, "Aucun candidat actuellement.")
	else:
		var roster_full: bool = count >= StaffManager.MAX_STAFF
		for s in StaffManager.available_staff:
			_staff_box.add_child(_available_staff_card(s, roster_full))

func _hired_staff_card(staff) -> Control:
	var panel := PanelContainer.new()
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	panel.add_child(inner)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	inner.add_child(top)
	var name_label := Label.new()
	name_label.text = "%s — %s" % [staff.staff_name, staff.get_role_name()]
	name_label.add_theme_font_size_override("font_size", 14)
	top.add_child(name_label)
	var tier := Badge.new()
	tier.text = staff.get_quality_tier()
	tier.badge_type = Badge.BadgeType.INFO
	tier.animate_appearance = false
	top.add_child(tier)
	top.add_spacer(false)
	var salary := Label.new()
	salary.text = "%d or/sem" % staff.weekly_salary
	salary.modulate = GOLD
	top.add_child(salary)

	var desc := Label.new()
	desc.text = staff.get_role_description()
	desc.add_theme_font_size_override("font_size", 11)
	desc.modulate = DIM
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(desc)

	var fire_btn := Button.new()
	fire_btn.text = "Renvoyer"
	var staff_ref = staff
	fire_btn.pressed.connect(func():
		StaffManager.fire_staff(staff_ref)
		_refresh_all()
	)
	inner.add_child(fire_btn)
	return panel

func _available_staff_card(staff, roster_full: bool) -> Control:
	var panel := PanelContainer.new()
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	panel.add_child(inner)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	inner.add_child(top)
	var name_label := Label.new()
	name_label.text = "%s — %s" % [staff.staff_name, staff.get_role_name()]
	name_label.add_theme_font_size_override("font_size", 14)
	top.add_child(name_label)
	var tier := Badge.new()
	tier.text = "%s (skill %d)" % [staff.get_quality_tier(), staff.skill_level]
	tier.badge_type = Badge.BadgeType.DEFAULT
	tier.animate_appearance = false
	top.add_child(tier)
	top.add_spacer(false)
	var salary := Label.new()
	salary.text = "%d or/sem" % staff.weekly_salary
	salary.modulate = GOLD
	top.add_child(salary)

	var signing_fee: int = staff.weekly_salary * StaffManager.SIGNING_FEE_MULTIPLIER
	var fee_label := Label.new()
	fee_label.text = "Frais d'embauche : %d or" % signing_fee
	fee_label.add_theme_font_size_override("font_size", 11)
	fee_label.modulate = DIM
	inner.add_child(fee_label)

	var can_afford: bool = _gold() >= signing_fee
	var hire_btn := Button.new()
	hire_btn.text = "Embaucher"
	hire_btn.disabled = roster_full or not can_afford
	if roster_full:
		hire_btn.tooltip_text = "Effectif de staff complet."
	elif not can_afford:
		hire_btn.tooltip_text = "Trésorerie insuffisante."
	var staff_ref = staff
	hire_btn.pressed.connect(func():
		if StaffManager.hire_staff(staff_ref):
			_refresh_all()
	)
	inner.add_child(hire_btn)
	return panel

# --- Onglet Tournois ---

func _build_tournaments() -> void:
	_clear(_tournament_box)
	if not TournamentManager:
		_empty_hint(_tournament_box, "Système de tournois indisponible.")
		return

	var stats := _card(_tournament_box)
	_kv(stats, "Réputation internationale", "%d / 100" % int(TournamentManager.get_international_reputation()), ACCENT)
	_kv(stats, "Titres mondiaux", str(TournamentManager.get_world_championship_wins()), GOLD)
	_kv(stats, "Tournois remportés", str(TournamentManager.total_tournaments_won))
	_kv(stats, "Force de l'équipe", "%d" % int(TournamentManager.get_roster_strength()))
	if TournamentManager.bootcamp_bonus > 0.0:
		_kv(stats, "Bonus bootcamp actif", "+%d%%" % int(TournamentManager.bootcamp_bonus * 100), GREEN)

	# Dernier résultat
	if not TournamentManager.last_results.is_empty():
		var lr: Dictionary = TournamentManager.last_results
		var res_card := _card(_tournament_box)
		var res_title := Label.new()
		if lr.get("is_champion", false):
			res_title.text = "🏆 Champion : %s" % lr.get("tournament", "")
			res_title.modulate = GOLD
		else:
			res_title.text = "Éliminé au tour %d/%d : %s" % [lr.get("stage_reached", 0), lr.get("rounds", 0), lr.get("tournament", "")]
			res_title.modulate = DIM
		res_card.add_child(res_title)
		var res_reward := Label.new()
		res_reward.text = "Gains : %d or  ·  +%.0f prestige" % [lr.get("gold", 0), lr.get("prestige", 0.0)]
		res_reward.add_theme_font_size_override("font_size", 11)
		res_reward.modulate = DIM
		res_card.add_child(res_reward)

	# Bootcamp
	_tournament_box.add_child(HSeparator.new())
	var bootcamp_btn := Button.new()
	bootcamp_btn.text = "Lancer un bootcamp (%d or, +stress)" % TournamentManager.BOOTCAMP_COST
	bootcamp_btn.disabled = _gold() < TournamentManager.BOOTCAMP_COST
	bootcamp_btn.pressed.connect(func():
		if TournamentManager.run_bootcamp():
			_refresh_all()
	)
	_tournament_box.add_child(bootcamp_btn)

	_tournament_box.add_child(HSeparator.new())
	_section(_tournament_box, "Tournois disponibles", GOLD)
	if TournamentManager.available_tournaments.is_empty():
		_empty_hint(_tournament_box, "Aucun tournoi proposé pour l'instant. De nouveaux apparaissent régulièrement.")
	else:
		for t in TournamentManager.available_tournaments:
			_tournament_box.add_child(_tournament_card(t))

func _tournament_card(tournament) -> Control:
	var panel := PanelContainer.new()
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	panel.add_child(inner)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	inner.add_child(top)
	var name_label := Label.new()
	name_label.text = tournament.tournament_name
	name_label.add_theme_font_size_override("font_size", 15)
	top.add_child(name_label)
	var type_badge := Badge.new()
	type_badge.text = tournament.get_type_name()
	type_badge.badge_type = Badge.BadgeType.PRIMARY if tournament.is_world_championship() else Badge.BadgeType.INFO
	type_badge.animate_appearance = false
	top.add_child(type_badge)
	top.add_spacer(false)
	var prize := Label.new()
	prize.text = "%s or · %d prestige" % [_fmt_int(tournament.base_prize), int(tournament.prestige)]
	prize.modulate = GOLD
	top.add_child(prize)

	var info := Label.new()
	info.text = "Région : %s   ·   %d tours   ·   Difficulté %d" % [tournament.region, tournament.rounds, int(tournament.difficulty)]
	info.add_theme_font_size_override("font_size", 11)
	info.modulate = DIM
	inner.add_child(info)

	var play_btn := Button.new()
	play_btn.text = "Participer"
	var t_ref = tournament
	play_btn.pressed.connect(func():
		TournamentManager.participate(t_ref)
		_refresh_all()
	)
	inner.add_child(play_btn)
	return panel

# --- Onglet Bien-être (burnout) ---

func _build_wellbeing() -> void:
	_clear(_wellbeing_box)
	if not GuildManager:
		return

	var stats := _card(_wellbeing_box)
	var stability: float = 0.0
	if PhaseManager and PhaseManager.has_method("get_requirements_progress"):
		var prog: Dictionary = PhaseManager.get_requirements_progress(PhaseManager.GamePhase.ESPORT)
		if prog.has("team_stability"):
			stability = prog["team_stability"].get("current", 0.0)
	_kv(stats, "Stabilité de l'équipe", "%d / 100" % int(stability), GREEN if stability >= 80 else RED)
	if StaffManager:
		_kv(stats, "Relief de stress (staff)", "-%d / semaine" % int(StaffManager.get_total_stress_relief()), ACCENT)

	# Bouton repos
	var rest_btn := Button.new()
	var on_cooldown: bool = StaffManager and not StaffManager.can_grant_rest()
	rest_btn.text = "Accorder du repos à l'équipe" if not on_cooldown else "Repos en cooldown (%d sem.)" % StaffManager.rest_cooldown_weeks
	rest_btn.disabled = on_cooldown
	rest_btn.tooltip_text = "Réduit fortement le stress et la fatigue de toute l'équipe."
	rest_btn.pressed.connect(func():
		if StaffManager and StaffManager.grant_team_rest():
			_refresh_all()
	)
	_wellbeing_box.add_child(rest_btn)

	_wellbeing_box.add_child(HSeparator.new())
	_section(_wellbeing_box, "Stress des joueurs", GOLD)

	var members: Array = GuildManager.guild_members.duplicate()
	members.sort_custom(func(a, b): return a.stress_level > b.stress_level)
	if members.is_empty():
		_empty_hint(_wellbeing_box, "Aucun membre.")
		return
	for member in members:
		_wellbeing_box.add_child(_wellbeing_row(member))

func _wellbeing_row(member) -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	var name_label := Label.new()
	name_label.text = member.nom
	name_label.custom_minimum_size = Vector2(200, 0)
	row.add_child(name_label)

	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = member.stress_level
	bar.custom_minimum_size = Vector2(220, 18)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bar)

	var tier := Label.new()
	tier.text = member.get_stress_tier()
	tier.custom_minimum_size = Vector2(80, 0)
	var st: float = member.stress_level
	tier.modulate = RED if st >= 60 else (GOLD if st >= 35 else GREEN)
	row.add_child(tier)

	if member.burnout_level > 0:
		var b := Badge.new()
		b.text = "Burnout %d" % member.burnout_level
		b.badge_type = Badge.BadgeType.ERROR
		b.animate_appearance = false
		row.add_child(b)

	return panel

# --- Onglet Transferts ---

func _build_transfers() -> void:
	_clear(_transfer_box)
	if not TransferManager:
		_empty_hint(_transfer_box, "Système de transferts indisponible.")
		return

	var open: bool = TransferManager.transfer_window_open
	var status := _card(_transfer_box)
	if open:
		_kv(status, "Fenêtre de transfert", "OUVERTE", GREEN)
	else:
		_kv(status, "Fenêtre de transfert", "Fermée — ouvre dans %d sem." % TransferManager.weeks_until_window(), DIM)
	_kv(status, "Trésorerie guilde", "%s or" % _fmt_int(_gold()), GOLD)
	_empty_hint(_transfer_box, "Les joueurs d'élite mondiale exigent un salaire hebdomadaire et une prime de transfert (4 semaines de salaire + commission d'agent).")

	_transfer_box.add_child(HSeparator.new())
	_section(_transfer_box, "Marché des transferts", ACCENT)

	var pool: Array = TransferManager.get_pool()
	if pool.is_empty():
		_empty_hint(_transfer_box, "Aucun joueur sur le marché.")
		return
	for player in pool:
		_transfer_box.add_child(_transfer_card(player, open))

func _transfer_card(player, window_open: bool) -> Control:
	var panel := PanelContainer.new()
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	panel.add_child(inner)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	inner.add_child(top)
	var name_label := Label.new()
	name_label.text = "%s (%s)" % [player.nom, player.personnage_classe]
	name_label.add_theme_font_size_override("font_size", 14)
	top.add_child(name_label)
	var region_badge := Badge.new()
	region_badge.text = player.get_meta("region", "?")
	region_badge.badge_type = Badge.BadgeType.INFO
	region_badge.animate_appearance = false
	top.add_child(region_badge)
	top.add_spacer(false)
	var skill_label := Label.new()
	skill_label.text = "Skill %d · Niv %d" % [player.skill, player.personnage_niveau]
	skill_label.modulate = DIM
	top.add_child(skill_label)

	var agent_suffix: String = ""
	if player.get_meta("has_agent", false):
		agent_suffix = "   ·   Agent (commission %d or)" % player.get_meta("agent_commission", 0)
	var demand := Label.new()
	demand.text = "Exigence salariale : %d or/sem%s" % [player.salary_demand, agent_suffix]
	demand.add_theme_font_size_override("font_size", 11)
	demand.modulate = GOLD
	inner.add_child(demand)

	if not window_open:
		var closed := Label.new()
		closed.text = "Recrutement impossible hors fenêtre de transfert."
		closed.add_theme_font_size_override("font_size", 11)
		closed.modulate = DIM
		inner.add_child(closed)
		return panel

	# Ligne d'offre
	var offer_row := HBoxContainer.new()
	offer_row.add_theme_constant_override("separation", 8)
	inner.add_child(offer_row)
	var spin := SpinBox.new()
	spin.min_value = 0
	spin.max_value = 5000
	spin.step = 50
	spin.value = player.salary_demand
	spin.custom_minimum_size = Vector2(120, 0)
	offer_row.add_child(spin)
	var offer_btn := Button.new()
	offer_btn.text = "Faire une offre"
	var player_ref = player
	var spin_ref = spin
	offer_btn.pressed.connect(func(): _attempt_offer(player_ref, int(spin_ref.value)))
	offer_row.add_child(offer_btn)

	return panel

func _attempt_offer(player, salary: int) -> void:
	var result: Dictionary = TransferManager.make_offer(player, salary)
	var step: String = result.get("step", "error")
	match step:
		"accepted":
			if NotificationManager:
				NotificationManager.show_success("%s rejoint la guilde (%d or/sem)" % [player.nom, salary], "Transfert")
			_refresh_all()
		"counter":
			_show_counter_offer(player, result.get("counter_offer", salary))
		"rejected", "closed", "error":
			if NotificationManager:
				NotificationManager.show_warning(result.get("reason", "Offre refusée"), "Transfert")

func _show_counter_offer(player, counter: int) -> void:
	var cd := ConfirmationDialog.new()
	cd.dialog_text = "%s : l'agent demande %d or/sem (prime : %d or). Accepter ?" % [
		player.nom, counter, TransferManager.get_transfer_fee(player, counter)]
	cd.title = "Contre-proposition"
	cd.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(cd)
	var player_ref = player
	var counter_ref = counter
	cd.confirmed.connect(func():
		var res: Dictionary = TransferManager.accept_counter(player_ref, counter_ref)
		if res.get("success", false):
			if NotificationManager:
				NotificationManager.show_success("%s rejoint la guilde (%d or/sem)" % [player_ref.nom, counter_ref], "Transfert")
		elif NotificationManager:
			NotificationManager.show_warning(res.get("reason", "Transfert échoué"), "Transfert")
		_refresh_all()
		cd.queue_free()
	)
	cd.canceled.connect(func(): cd.queue_free())
	cd.popup_centered(Vector2(440, 160))

# --- Onglet Legacy ---

func _build_legacy() -> void:
	_clear(_legacy_box)
	if not LegacyManager:
		_empty_hint(_legacy_box, "Système de legacy indisponible.")
		return

	var stats := _card(_legacy_box)
	_kv(stats, "Titre actuel", LegacyManager.get_rank_title(), GOLD)
	_kv(stats, "Points de legacy", str(LegacyManager.get_legacy_points()), ACCENT)
	var next_threshold: int = LegacyManager.get_next_threshold()
	if next_threshold > 0:
		_kv(stats, "Prochain palier", "%d points" % next_threshold, DIM)
	else:
		_kv(stats, "Prochain palier", "Rang maximal atteint", GREEN)

	# Titres débloqués
	if not LegacyManager.unlocked_titles.is_empty():
		var titles_label := Label.new()
		titles_label.text = "Titres débloqués : " + "   ·   ".join(LegacyManager.unlocked_titles)
		titles_label.modulate = GREEN
		titles_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_legacy_box.add_child(titles_label)

	_legacy_box.add_child(HSeparator.new())
	_section(_legacy_box, "Hall of Fame", GOLD)
	if LegacyManager.hall_of_fame.is_empty():
		_empty_hint(_legacy_box, "Aucun accomplissement légendaire pour l'instant. Remportez des tournois pour entrer dans l'histoire.")
		return
	var entries: Array = LegacyManager.hall_of_fame.duplicate()
	entries.reverse()
	for entry in entries:
		var card := _card(_legacy_box)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 8)
		card.add_child(top)
		var title := Label.new()
		title.text = entry.get("title", "")
		title.add_theme_font_size_override("font_size", 14)
		title.modulate = GOLD
		top.add_child(title)
		top.add_spacer(false)
		var pts := Label.new()
		pts.text = "+%d  ·  %s" % [entry.get("points", 0), entry.get("date", "")]
		pts.add_theme_font_size_override("font_size", 11)
		pts.modulate = DIM
		top.add_child(pts)
		var desc := Label.new()
		desc.text = entry.get("description", "")
		desc.add_theme_font_size_override("font_size", 11)
		desc.modulate = DIM
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(desc)
