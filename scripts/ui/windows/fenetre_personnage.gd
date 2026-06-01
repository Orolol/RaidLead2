extends PanelContainer

var close_button: Button
var title_label: Label
var content_container: VBoxContainer
var advanced_tabs: AdvancedTabs
var _drag_active: bool = false

var classe_label: Label
var niveau_label: Label
var equipement_label: Label

# Éléments de progression de phase
var current_phase_label: Label
var phase_progress_list: ItemList
var requirements_container: VBoxContainer
var achievements_list: ItemList
var pve_best_clear_label: Label
var pve_run_history_list: ItemList

# Éléments de réputation
var reputation_value_label: Label
var reputation_tier_label: Label
var reputation_history_list: ItemList
var reputation_bonus_label: Label

# Éléments du joueur
var xp_progress_bar: ProgressBar
var xp_label: Label
var energy_label: Label
var mood_label: Label
var session_label: Label

# Timer pour mise à jour automatique
var update_timer: Timer

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(800, 600)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)
	
	_setup_header(vbox)
	_setup_content(vbox)
	
	# Se connecter aux signaux de PhaseManager
	if PhaseManager:
		PhaseManager.connect("phase_changed", _on_phase_changed)
		PhaseManager.connect("progression_updated", _on_progression_updated)
		PhaseManager.connect("phase_requirements_met", _on_requirements_met)
	
	# Actualiser la progression initiale
	call_deferred("_refresh_phase_progression")
	
	# Configurer le timer de mise à jour des infos joueur
	_setup_update_timer()
	
	hide()

func _setup_update_timer():
	"""Configure le timer pour mettre à jour les informations du joueur"""
	update_timer = Timer.new()
	update_timer.wait_time = 3.0  # Mise à jour toutes les 3 secondes
	update_timer.timeout.connect(_on_update_timer_timeout)
	update_timer.autostart = false
	add_child(update_timer)

func _on_update_timer_timeout():
	"""Met à jour les informations du joueur périodiquement"""
	if visible:  # Seulement si la fenêtre est visible
		update_character_info()

func _setup_header(parent: VBoxContainer):
	var header = HBoxContainer.new()
	parent.add_child(header)
	
	title_label = Label.new()
	title_label.text = "Informations du Personnage"
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.mouse_filter = Control.MOUSE_FILTER_STOP
	title_label.mouse_default_cursor_shape = Control.CURSOR_MOVE
	title_label.tooltip_text = "Glissez pour déplacer la fenêtre"
	title_label.gui_input.connect(_on_header_drag)
	header.add_child(title_label)
	
	header.add_spacer(false)
	
	close_button = Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(30, 30)
	close_button.pressed.connect(_on_close_pressed)
	header.add_child(close_button)

func _on_header_drag(event: InputEvent) -> void:
	"""Permet de déplacer la fenêtre en glissant sur la barre de titre."""
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag_active = event.pressed
	elif event is InputEventMouseMotion and _drag_active:
		position += event.relative

func _setup_content(parent: VBoxContainer):
	# Utiliser AdvancedTabs pour organiser les informations
	advanced_tabs = AdvancedTabs.create_simple_tabs(parent)
	
	# Onglet Informations personnage
	_setup_character_info_tab()
	
	# Onglet Progression de phase
	_setup_phase_progression_tab()
	
	# Onglet Réputation
	_setup_reputation_tab()

func _setup_character_info_tab():
	"""Configure l'onglet des informations de personnage"""
	var info_tab = VBoxContainer.new()
	info_tab.name = "Personnage"
	info_tab.add_theme_constant_override("separation", 15)
	advanced_tabs.add_tab("Personnage", info_tab, false)
	
	var info_panel = PanelContainer.new()
	info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_tab.add_child(info_panel)

	# Disposition en deux colonnes : identité (gauche) / état (droite)
	var columns = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_panel.add_child(columns)

	var info_vbox = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 10)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(info_vbox)

	columns.add_child(VSeparator.new())

	var right_vbox = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 12)
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right_vbox)

	# Header avec portrait (colonne gauche)
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 15)
	info_vbox.add_child(header_hbox)

	var portrait: Texture2D = AssetLoader.get_class_portrait("Guerrier")
	if portrait:
		var portrait_rect = TextureRect.new()
		portrait_rect.texture = portrait
		portrait_rect.custom_minimum_size = Vector2(80, 80)
		portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		header_hbox.add_child(portrait_rect)

	var title_vbox = VBoxContainer.new()
	header_hbox.add_child(title_vbox)

	var character_title = Label.new()
	character_title.text = "Votre Personnage"
	character_title.add_theme_font_size_override("font_size", 18)
	title_vbox.add_child(character_title)

	classe_label = Label.new()
	classe_label.text = "Classe: Guerrier"
	classe_label.add_theme_font_size_override("font_size", 16)
	title_vbox.add_child(classe_label)
	
	niveau_label = Label.new()
	niveau_label.text = "Niveau: 1"
	niveau_label.add_theme_font_size_override("font_size", 16)
	info_vbox.add_child(niveau_label)
	
	equipement_label = Label.new()
	equipement_label.text = "Niveau d'équipement: 0"
	equipement_label.add_theme_font_size_override("font_size", 16)
	info_vbox.add_child(equipement_label)
	
	# Colonne droite : progression XP + état actuel
	_setup_xp_display(right_vbox)
	right_vbox.add_child(HSeparator.new())
	_setup_player_stats(right_vbox)

	# Aperçu de la phase actuelle (sous les deux colonnes)
	var phase_panel = PanelContainer.new()
	info_tab.add_child(phase_panel)
	var phase_vbox = VBoxContainer.new()
	phase_vbox.add_theme_constant_override("separation", 4)
	phase_panel.add_child(phase_vbox)
	var ph_title = Label.new()
	ph_title.text = "Phase actuelle"
	ph_title.add_theme_font_size_override("font_size", 14)
	ph_title.modulate = Color(1.0, 0.82, 0.3)
	phase_vbox.add_child(ph_title)
	var ph_name = Label.new()
	if PhaseManager:
		var cur_phase = PhaseManager.get_current_phase()
		ph_name.text = "%s — %s" % [PhaseManager.get_phase_name(cur_phase), PhaseManager.get_phase_description(cur_phase)]
	ph_name.add_theme_font_size_override("font_size", 12)
	ph_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ph_name.modulate = Color(0.72, 0.74, 0.80)
	phase_vbox.add_child(ph_name)

func _setup_xp_display(parent: VBoxContainer):
	"""Configure l'affichage de progression XP"""
	var xp_container = VBoxContainer.new()
	xp_container.add_theme_constant_override("separation", 5)
	parent.add_child(xp_container)
	
	var xp_title = Label.new()
	xp_title.text = "📈 Progression XP"
	xp_title.add_theme_font_size_override("font_size", 14)
	xp_container.add_child(xp_title)
	
	xp_progress_bar = ProgressBar.new()
	xp_progress_bar.custom_minimum_size = Vector2(0, 25)
	xp_progress_bar.min_value = 0
	xp_progress_bar.max_value = 100
	xp_container.add_child(xp_progress_bar)
	
	xp_label = Label.new()
	xp_label.text = "0 / 250 XP (0%)"
	xp_label.add_theme_font_size_override("font_size", 12)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_container.add_child(xp_label)

func _setup_player_stats(parent: VBoxContainer):
	"""Configure l'affichage des stats du joueur"""
	var stats_container = VBoxContainer.new()
	stats_container.add_theme_constant_override("separation", 5)
	parent.add_child(stats_container)
	
	var stats_title = Label.new()
	stats_title.text = "⚡ État Actuel"
	stats_title.add_theme_font_size_override("font_size", 14)
	stats_container.add_child(stats_title)
	
	energy_label = Label.new()
	energy_label.text = "Énergie: 100/100"
	energy_label.add_theme_font_size_override("font_size", 12)
	stats_container.add_child(energy_label)
	
	mood_label = Label.new()
	mood_label.text = "Moral: 80/100"
	mood_label.add_theme_font_size_override("font_size", 12)
	stats_container.add_child(mood_label)
	
	session_label = Label.new()
	session_label.text = "Session: XP: 0 | Or: 0 | Durée: 0min"
	session_label.add_theme_font_size_override("font_size", 11)
	session_label.modulate = Color(0.8, 0.8, 1.0)
	stats_container.add_child(session_label)

func _setup_phase_progression_tab():
	"""Configure l'onglet de progression de phase"""
	var progress_tab: VBoxContainer = VBoxContainer.new()
	progress_tab.name = "Progression"
	progress_tab.add_theme_constant_override("separation", 15)
	progress_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	advanced_tabs.add_tab("Progression", progress_tab, false)
	
	# Header avec phase actuelle
	var phase_header: HBoxContainer = HBoxContainer.new()
	phase_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_tab.add_child(phase_header)
	
	current_phase_label = Label.new()
	current_phase_label.text = "Phase Actuelle: Serveur"
	current_phase_label.add_theme_font_size_override("font_size", 18)
	current_phase_label.modulate = Color(1.0, 0.8, 0.2)
	phase_header.add_child(current_phase_label)
	
	phase_header.add_spacer(false)
	
	var refresh_button = Button.new()
	refresh_button.text = "Actualiser"
	refresh_button.pressed.connect(_refresh_phase_progression)
	phase_header.add_child(refresh_button)
	
	progress_tab.add_child(HSeparator.new())
	
	# Container pour le contenu de progression
	var progress_content: HSplitContainer = HSplitContainer.new()
	progress_content.split_offset = 400
	progress_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	progress_tab.add_child(progress_content)
	
	# Côté gauche : Requirements
	_setup_requirements_section(progress_content)
	
	# Côté droit : Achievements
	_setup_achievements_section(progress_content)

func _setup_requirements_section(parent: HSplitContainer):
	"""Configure la section des requirements"""
	var requirements_panel: VBoxContainer = VBoxContainer.new()
	requirements_panel.custom_minimum_size = Vector2(420, 0)
	requirements_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	requirements_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	requirements_panel.add_theme_constant_override("separation", 8)
	parent.add_child(requirements_panel)
	
	var req_title = Label.new()
	req_title.text = "🎯 Objectifs pour la prochaine phase"
	req_title.add_theme_font_size_override("font_size", 16)
	requirements_panel.add_child(req_title)
	
	var requirements_scroll: ScrollContainer = ScrollContainer.new()
	requirements_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	requirements_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	requirements_panel.add_child(requirements_scroll)
	
	requirements_container = VBoxContainer.new()
	requirements_container.add_theme_constant_override("separation", 8)
	requirements_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	requirements_scroll.add_child(requirements_container)

func _setup_achievements_section(parent: HSplitContainer):
	"""Configure la section des achievements"""
	var achievements_panel: VBoxContainer = VBoxContainer.new()
	achievements_panel.custom_minimum_size = Vector2(260, 0)
	achievements_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	achievements_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	achievements_panel.add_theme_constant_override("separation", 8)
	parent.add_child(achievements_panel)
	
	var ach_title = Label.new()
	ach_title.text = "🏆 Réalisations"
	ach_title.add_theme_font_size_override("font_size", 16)
	achievements_panel.add_child(ach_title)
	
	achievements_list = ItemList.new()
	achievements_list.custom_minimum_size = Vector2(260, 200)
	achievements_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	achievements_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	achievements_panel.add_child(achievements_list)
	
	achievements_panel.add_child(HSeparator.new())
	
	var runs_title = Label.new()
	runs_title.text = "⚔️ Derniers runs PvE"
	runs_title.add_theme_font_size_override("font_size", 16)
	achievements_panel.add_child(runs_title)
	
	pve_best_clear_label = Label.new()
	pve_best_clear_label.text = "Meilleur clear: aucun run enregistre."
	pve_best_clear_label.add_theme_font_size_override("font_size", 12)
	pve_best_clear_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pve_best_clear_label.modulate = Color(0.78, 0.82, 0.92)
	achievements_panel.add_child(pve_best_clear_label)
	
	pve_run_history_list = ItemList.new()
	pve_run_history_list.custom_minimum_size = Vector2(260, 160)
	pve_run_history_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pve_run_history_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	achievements_panel.add_child(pve_run_history_list)

func _on_close_pressed():
	hide()

func _notification(what: int):
	match what:
		NOTIFICATION_VISIBILITY_CHANGED:
			if visible and update_timer:
				update_timer.start()
				# Mise à jour immédiate
				update_character_info()
			elif not visible and update_timer:
				update_timer.stop()

func update_character_info():
	"""Met à jour les informations du personnage joueur"""
	var guild_manager = get_node_or_null("/root/GuildManager")
	if not guild_manager:
		return
	
	var player = guild_manager.get_player_character()
	if not player:
		return
	
	# Informations de base
	classe_label.text = "Classe: " + player.personnage_classe
	niveau_label.text = "Niveau: " + str(player.personnage_niveau)
	
	var ilvl = player.get_total_ilvl() if player.has_method("get_total_ilvl") else 0
	equipement_label.text = "Niveau d'équipement: " + str(ilvl)
	
	# Progression XP
	if player.has_method("get_xp_progress"):
		var xp_progress = player.get_xp_progress()
		var progress_percent = xp_progress.progress_percent
		xp_progress_bar.value = progress_percent
		xp_label.text = "%d / %d XP (%.0f%%)" % [
			xp_progress.current_xp,
			xp_progress.xp_for_next,
			progress_percent
		]
	
	# Stats actuelles
	if player.has_method("get_energy_percentage"):
		var energy_percent = player.get_energy_percentage()
		energy_label.text = "Énergie: %.0f/%.0f (%.0f%%)" % [
			player.player_energy_pool,
			player.max_energy_pool,
			energy_percent
		]
		
		# Coloration selon l'état
		if energy_percent < 25:
			energy_label.modulate = Color.RED
		elif energy_percent < 50:
			energy_label.modulate = Color.ORANGE
		else:
			energy_label.modulate = Color.WHITE
	
	mood_label.text = "Moral: %.0f/100" % player.mood
	if player.mood < 30:
		mood_label.modulate = Color.RED
	elif player.mood < 60:
		mood_label.modulate = Color.ORANGE
	else:
		mood_label.modulate = Color.WHITE
	
	# Informations de session
	if player.has_method("get_session_report"):
		var report = player.get_session_report()
		session_label.text = "Session: XP: +%d | Or: +%d | Durée: %dmin" % [
			report.xp_gained,
			report.gold_gained,
			report.duration_minutes
		]

# Fonctions de gestion de la progression

func _refresh_phase_progression():
	"""Met à jour l'affichage de la progression de phase"""
	if not PhaseManager:
		return
	
	# Mettre à jour la phase actuelle
	var current_phase = PhaseManager.get_current_phase()
	var phase_name = PhaseManager.get_phase_name(current_phase)
	current_phase_label.text = "Phase Actuelle: " + phase_name
	
	# Mettre à jour les requirements
	_update_requirements_display()
	
	# Mettre à jour les achievements
	_update_achievements_display()
	
	# Mettre à jour l'historique PvE
	_update_pve_run_history_display()

func _update_requirements_display():
	"""Met à jour l'affichage des requirements"""
	# Nettoyer l'affichage précédent
	for child in requirements_container.get_children():
		child.queue_free()
	
	if not PhaseManager:
		return
	
	var requirements: Dictionary = PhaseManager.get_current_requirements()
	
	# Vérifier si on est déjà en phase finale
	var phase_config: Dictionary = PhaseManager.get_current_phase_config()
	if not phase_config.has("next_phase") or phase_config.next_phase == null:
		var final_label = Label.new()
		final_label.text = "🎉 Vous avez atteint la phase finale !"
		final_label.add_theme_font_size_override("font_size", 16)
		final_label.modulate = Color(0.2, 1.0, 0.2)
		requirements_container.add_child(final_label)
		return
	
	# Lecture sans effet de bord : check_phase_progression() émet phase_requirements_met,
	# qui rappelle _on_requirements_met -> _refresh_phase_progression -> récursion infinie.
	# get_requirements_progress() calcule la progression sans émettre de signal.
	var progress_data: Dictionary = PhaseManager.get_requirements_progress(PhaseManager.get_current_phase())
	
	if requirements.is_empty():
		var no_req_label = Label.new()
		no_req_label.text = "Aucun objectif défini pour cette phase."
		no_req_label.modulate = Color(0.7, 0.7, 0.7)
		requirements_container.add_child(no_req_label)
		return
	
	for req_name in requirements:
		var requirement_card: PanelContainer = PanelContainer.new()
		requirement_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		requirements_container.add_child(requirement_card)
		
		var requirement_box: VBoxContainer = VBoxContainer.new()
		requirement_box.add_theme_constant_override("separation", 5)
		requirement_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		requirement_card.add_child(requirement_box)
		
		var req_container: HBoxContainer = HBoxContainer.new()
		req_container.add_theme_constant_override("separation", 8)
		req_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		requirement_box.add_child(req_container)
		
		# Statut (✓ ou ✗)
		var status_label: Label = Label.new()
		var progress_item: Dictionary = progress_data.get(req_name, {})
		var is_met: bool = bool(progress_item.get("met", false))
		var current_value: Variant = progress_item.get("current", 0)
		var required_value: Variant = progress_item.get("required", 0)
		var progress_percent: float = float(progress_item.get("progress_percent", 0.0))
		
		status_label.text = "✓" if is_met else "✗"
		status_label.modulate = Color.GREEN if is_met else Color.RED
		status_label.custom_minimum_size = Vector2(24, 0)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		req_container.add_child(status_label)
		
		# Description du requirement
		var desc_label: Label = Label.new()
		desc_label.text = _get_requirement_description(str(req_name), required_value)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.custom_minimum_size = Vector2(220, 0)
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		req_container.add_child(desc_label)
		
		# Progression
		var progress_label: Label = Label.new()
		progress_label.text = "%.0f%%" % progress_percent
		progress_label.custom_minimum_size = Vector2(56, 0)
		progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if is_met:
			progress_label.modulate = Color.GREEN
		elif progress_percent > 50:
			progress_label.modulate = Color.YELLOW
		else:
			progress_label.modulate = Color.WHITE
		req_container.add_child(progress_label)
		
		# Barre de progression
		var progress_bar: ProgressBar = ProgressBar.new()
		progress_bar.min_value = 0
		progress_bar.max_value = 100
		progress_bar.value = progress_percent
		progress_bar.custom_minimum_size = Vector2(0, 18)
		progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		requirement_box.add_child(progress_bar)
		
		# Détails numériques
		if not is_met:
			var detail_label: Label = Label.new()
			detail_label.text = "Actuel: %s / Requis: %s" % [str(current_value), str(required_value)]
			detail_label.add_theme_font_size_override("font_size", 12)
			detail_label.modulate = Color(0.8, 0.8, 0.8)
			detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			requirement_box.add_child(detail_label)

func _get_requirement_description(req_name: String, required_value) -> String:
	"""Retourne une description lisible du requirement"""
	match req_name:
		"server_rank_position":
			return "Atteindre la position #%d du serveur" % required_value
		"server_rank_duration":
			return "Maintenir le TOP 1 pendant %d jours" % required_value
		"active_members_min":
			return "Avoir au moins %d membres actifs" % required_value
		"integration_threshold":
			return "Intégration moyenne de %.0f%%" % required_value
		"content_cleared_percent":
			return "Clear %.0f%% du contenu disponible" % required_value
		"national_rank_position":
			return "Atteindre le TOP 1 national"
		"national_rank_duration":
			return "Maintenir le TOP 1 national pendant %d jours" % required_value
		"max_dramas_per_year":
			return "Maximum %d dramas majeurs par an" % required_value
		"active_sponsors":
			return "Avoir au moins %d sponsor actif" % required_value
		"world_first_count":
			return "Réaliser au moins %d world first" % required_value
		"media_reputation":
			return "Réputation média de %.0f%%" % required_value
		_:
			return req_name.capitalize() + ": " + str(required_value)

func _update_achievements_display():
	"""Met à jour l'affichage des achievements"""
	achievements_list.clear()
	
	if not PhaseManager:
		return
	
	var all_achievements = PhaseManager.get_all_achievements()
	
	if all_achievements.is_empty():
		achievements_list.add_item("Aucune réalisation pour le moment...")
		return
	
	# Trier par date (plus récent en premier)
	all_achievements.sort_custom(func(a, b): 
		var date_a = a.get("date", {})
		var date_b = b.get("date", {})
		return _compare_dates(date_a, date_b) > 0
	)
	
	for achievement in all_achievements:
		var name = achievement.get("name", "Achievement inconnu")
		var description = achievement.get("description", "")
		var date = achievement.get("date", {})
		var phase = achievement.get("phase", PhaseManager.GamePhase.SERVEUR)
		
		var item_text = "🏆 %s" % name
		if description != "":
			item_text += "\n   %s" % description
		
		var phase_name = PhaseManager.get_phase_name(phase)
		item_text += "\n   Phase: %s" % phase_name
		
		achievements_list.add_item(item_text)
		
		# Colorer selon la phase
		var item_index = achievements_list.get_item_count() - 1
		match phase:
			PhaseManager.GamePhase.SERVEUR:
				achievements_list.set_item_custom_bg_color(item_index, Color(0.2, 0.3, 0.5, 0.3))
			PhaseManager.GamePhase.NATIONAL:
				achievements_list.set_item_custom_bg_color(item_index, Color(0.5, 0.3, 0.2, 0.3))
			PhaseManager.GamePhase.ESPORT:
				achievements_list.set_item_custom_bg_color(item_index, Color(0.5, 0.5, 0.2, 0.3))

func _update_pve_run_history_display() -> void:
	"""Met à jour l'affichage des derniers runs PvE de la guilde."""
	pve_run_history_list.clear()
	
	if not GuildRanking or not GuildRanking.has_method("get_player_run_history"):
		pve_best_clear_label.text = "Meilleur clear: indisponible."
		pve_run_history_list.add_item("Historique PvE indisponible.")
		return
	
	var runs: Array = GuildRanking.get_player_run_history(5)
	if runs.is_empty():
		pve_best_clear_label.text = "Meilleur clear: aucun run enregistre."
		pve_run_history_list.add_item("Aucun run enregistré pour le moment.")
		return
	
	_update_pve_best_clear_display(runs[runs.size() - 1])
	
	runs.reverse()
	for run_data in runs:
		var item_text: String = _format_pve_run_history_item(run_data)
		pve_run_history_list.add_item(item_text)
		
		var item_index: int = pve_run_history_list.get_item_count() - 1
		if bool(run_data.get("is_heroic", false)):
			pve_run_history_list.set_item_custom_bg_color(item_index, Color(0.45, 0.25, 0.08, 0.35))
		elif int(run_data.get("type", -1)) == DungeonData.InstanceType.RAID:
			pve_run_history_list.set_item_custom_bg_color(item_index, Color(0.35, 0.18, 0.45, 0.35))

func _update_pve_best_clear_display(latest_run: Dictionary) -> void:
	"""Affiche le meilleur clear connu pour le dernier contenu joue."""
	if not GuildRanking or not GuildRanking.has_method("get_player_best_clear"):
		pve_best_clear_label.text = "Meilleur clear: indisponible."
		return
	
	var content_id: String = str(latest_run.get("content_id", ""))
	if content_id == "":
		pve_best_clear_label.text = "Meilleur clear: contenu inconnu."
		return
	
	var best_clear: Dictionary = GuildRanking.get_player_best_clear(content_id)
	if best_clear.is_empty():
		pve_best_clear_label.text = "Meilleur clear: aucun detail."
		return
	
	var content_name: String = best_clear.get("name", content_id)
	var duration_text: String = _format_duration_seconds(float(best_clear.get("duration_seconds", 0.0)))
	var wipes: int = int(best_clear.get("wipes", 0))
	var gold_reward: int = int(best_clear.get("gold_reward", 0))
	var date_text: String = _format_date(best_clear.get("date", {}))
	
	if duration_text == "":
		pve_best_clear_label.text = "Meilleur clear %s : %d wipe(s), %d or" % [content_name, wipes, gold_reward]
	else:
		pve_best_clear_label.text = "Meilleur clear %s : %s, %d wipe(s), %d or" % [content_name, duration_text, wipes, gold_reward]
	
	if date_text != "":
		pve_best_clear_label.text += " - %s" % date_text

func _format_pve_run_history_item(run_data: Dictionary) -> String:
	var content_name: String = run_data.get("name", run_data.get("content_id", "Contenu inconnu"))
	var duration_text: String = _format_duration_seconds(float(run_data.get("duration_seconds", 0.0)))
	var wipes: int = int(run_data.get("wipes", 0))
	var gold_reward: int = int(run_data.get("gold_reward", 0))
	var performance_score: int = int(run_data.get("performance_score", -1))
	var date_text: String = _format_date(run_data.get("date", {}))
	var item_text: String = "%s" % content_name
	
	if duration_text != "":
		item_text += "\n   Durée: %s | Wipes: %d | Or: %d" % [duration_text, wipes, gold_reward]
	else:
		item_text += "\n   Wipes: %d | Or: %d" % [wipes, gold_reward]
	
	if performance_score >= 0:
		item_text += " | Score: %d" % performance_score
	
	if date_text != "":
		item_text += "\n   %s" % date_text
	
	return item_text

func _format_duration_seconds(seconds: float) -> String:
	if seconds <= 0.0:
		return ""
	var total_seconds: int = int(seconds)
	var minutes: int = int(total_seconds / 60)
	var remaining_seconds: int = total_seconds % 60
	return "%02d:%02d" % [minutes, remaining_seconds]

func _format_date(date: Dictionary) -> String:
	if date.is_empty():
		return ""
	return "Année %d, Semaine %d, Jour %d" % [
		int(date.get("year", 1)),
		int(date.get("week", 1)),
		int(date.get("day", 1))
	]

func _compare_dates(date_a: Dictionary, date_b: Dictionary) -> int:
	"""Compare deux dates (retourne > 0 si date_a > date_b)"""
	var year_diff = date_a.get("year", 1) - date_b.get("year", 1)
	if year_diff != 0:
		return year_diff
	
	var week_diff = date_a.get("week", 1) - date_b.get("week", 1)
	if week_diff != 0:
		return week_diff
	
	return date_a.get("day", 1) - date_b.get("day", 1)

# Callbacks des signaux PhaseManager

func _on_phase_changed(new_phase, old_phase):
	"""Réagit aux changements de phase"""
	if visible:
		_refresh_phase_progression()
		
		# Afficher une notification si la fenêtre est ouverte
		var notification = Label.new()
		notification.text = "🎉 NOUVELLE PHASE DÉBLOQUÉE: %s" % PhaseManager.get_phase_name(new_phase)
		notification.add_theme_font_size_override("font_size", 18)
		notification.modulate = Color(0.2, 1.0, 0.2)
		notification.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		# Ajouter temporairement en haut de la fenêtre
		var vbox = get_children()[0] as VBoxContainer
		if vbox:
			vbox.add_child(notification)
			vbox.move_child(notification, 1)  # Après le header
			
			# Supprimer après 5 secondes
			get_tree().create_timer(5.0).timeout.connect(notification.queue_free)

func _on_progression_updated(phase, progress: Dictionary):
	"""Réagit à la mise à jour de progression"""
	if visible and advanced_tabs.get_current_tab_index() == 1:  # Onglet Progression
		_update_requirements_display()

func _on_requirements_met(phase):
	"""Réagit quand tous les requirements sont satisfaits"""
	if visible:
		var popup = AcceptDialog.new()
		popup.dialog_text = "🎉 FÉLICITATIONS !\n\nTous les objectifs de la phase %s sont remplis !\nVous pouvez maintenant passer à la phase suivante." % PhaseManager.get_phase_name(phase)
		get_tree().root.add_child(popup)
		popup.popup_centered()
		popup.confirmed.connect(popup.queue_free)
		
		_refresh_phase_progression()
func _setup_reputation_tab():
	"""Configure l'onglet de réputation de guilde"""
	var reputation_tab = VBoxContainer.new()
	reputation_tab.name = "Réputation"
	reputation_tab.add_theme_constant_override("separation", 15)
	advanced_tabs.add_tab("Réputation", reputation_tab, false)
	
	# Header avec réputation actuelle
	var reputation_header = VBoxContainer.new()
	reputation_header.add_theme_constant_override("separation", 5)
	reputation_tab.add_child(reputation_header)
	
	var reputation_title = Label.new()
	reputation_title.text = "🏆 Réputation de la Guilde"
	reputation_title.add_theme_font_size_override("font_size", 18)
	reputation_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reputation_header.add_child(reputation_title)
	
	# Valeur et tier de réputation
	var reputation_info_container = HBoxContainer.new()
	reputation_header.add_child(reputation_info_container)
	
	var value_label = Label.new()
	value_label.text = "Valeur: "
	reputation_info_container.add_child(value_label)
	
	reputation_value_label = Label.new()
	reputation_value_label.text = "50.0 / 100.0"
	reputation_value_label.add_theme_font_size_override("font_size", 16)
	reputation_value_label.modulate = Color(0.9, 0.9, 1.0)
	reputation_info_container.add_child(reputation_value_label)
	
	reputation_info_container.add_spacer(false)
	
	var tier_label = Label.new()
	tier_label.text = "Niveau: "
	reputation_info_container.add_child(tier_label)
	
	reputation_tier_label = Label.new()
	reputation_tier_label.text = "Correcte"
	reputation_tier_label.add_theme_font_size_override("font_size", 16)
	reputation_tier_label.modulate = Color(1.0, 0.8, 0.2)
	reputation_info_container.add_child(reputation_tier_label)
	
	reputation_tab.add_child(HSeparator.new())
	
	# Bonus de réputation
	var bonus_section = VBoxContainer.new()
	reputation_tab.add_child(bonus_section)
	
	var bonus_title = Label.new()
	bonus_title.text = "📈 Effets de la réputation"
	bonus_title.add_theme_font_size_override("font_size", 14)
	bonus_section.add_child(bonus_title)
	
	reputation_bonus_label = Label.new()
	reputation_bonus_label.text = "Bonus de recrutement: +0%"
	reputation_bonus_label.modulate = Color(0.8, 1.0, 0.8)
	bonus_section.add_child(reputation_bonus_label)
	
	reputation_tab.add_child(HSeparator.new())
	
	# Historique de réputation
	var history_section = VBoxContainer.new()
	reputation_tab.add_child(history_section)
	
	var history_header = HBoxContainer.new()
	history_section.add_child(history_header)
	
	var history_title = Label.new()
	history_title.text = "📚 Historique récent"
	history_title.add_theme_font_size_override("font_size", 14)
	history_header.add_child(history_title)
	
	history_header.add_spacer(false)
	
	var refresh_reputation_button = Button.new()
	refresh_reputation_button.text = "Actualiser"
	refresh_reputation_button.pressed.connect(_refresh_reputation_display)
	history_header.add_child(refresh_reputation_button)
	
	reputation_history_list = ItemList.new()
	reputation_history_list.custom_minimum_size = Vector2(0, 200)
	history_section.add_child(reputation_history_list)
	
	# Actualiser immédiatement
	call_deferred("_refresh_reputation_display")

func _refresh_reputation_display():
	"""Met à jour l'affichage de la réputation"""
	var guild_manager = get_node_or_null("/root/GuildManager")
	if not guild_manager or not guild_manager.guild:
		return
	
	var guild = guild_manager.guild
	var reputation = guild.get_reputation()
	
	# Mettre à jour les valeurs
	reputation_value_label.text = "%.1f / 100.0" % reputation
	reputation_tier_label.text = guild.get_reputation_tier()
	
	# Colorer selon le niveau
	if reputation >= 80:
		reputation_tier_label.modulate = Color(0.2, 1.0, 0.2)  # Vert pour excellent
	elif reputation >= 60:
		reputation_tier_label.modulate = Color(0.8, 0.8, 1.0)  # Bleu pour bon
	elif reputation >= 40:
		reputation_tier_label.modulate = Color(1.0, 1.0, 0.2)  # Jaune pour correct
	else:
		reputation_tier_label.modulate = Color(1.0, 0.6, 0.6)  # Rouge pour mauvais
	
	# Bonus de réputation
	var bonus_percent = guild.get_recruitment_reputation_bonus() * 100
	if bonus_percent > 0:
		reputation_bonus_label.text = "Bonus de recrutement: +%.0f%%" % bonus_percent
		reputation_bonus_label.modulate = Color(0.2, 1.0, 0.2)
	elif bonus_percent < 0:
		reputation_bonus_label.text = "Malus de recrutement: %.0f%%" % bonus_percent
		reputation_bonus_label.modulate = Color(1.0, 0.6, 0.6)
	else:
		reputation_bonus_label.text = "Bonus de recrutement: +0% (neutre)"
		reputation_bonus_label.modulate = Color(0.8, 0.8, 0.8)
	
	# Historique
	_refresh_reputation_history()

func _refresh_reputation_history():
	"""Met à jour l'historique de réputation"""
	reputation_history_list.clear()
	
	var guild_manager = get_node_or_null("/root/GuildManager")
	if not guild_manager or not guild_manager.guild:
		reputation_history_list.add_item("Aucune donnée de réputation disponible")
		return
	
	var guild = guild_manager.guild
	var recent_events = guild.get_recent_reputation_events(15)
	
	if recent_events.is_empty():
		reputation_history_list.add_item("Aucun événement de réputation récent")
		return
	
	for event in recent_events:
		var change = event.get("change", 0.0)
		var reason = event.get("reason", "Événement inconnu")
		var reputation_after = event.get("reputation_after", 50.0)
		var date = event.get("date", {})
		
		var change_text = ""
		if change > 0:
			change_text = "+%.1f" % change
		else:
			change_text = "%.1f" % change
		
		var date_text = ""
		if date.has("year") and date.has("week") and date.has("day"):
			date_text = "S%d J%d" % [date.week, date.day]
		
		var item_text = "%s %s - %s (%.1f)" % [date_text, change_text, reason, reputation_after]
		reputation_history_list.add_item(item_text)
		
		# Colorer selon le type de changement
		var item_index = reputation_history_list.get_item_count() - 1
		if change > 0:
			reputation_history_list.set_item_custom_bg_color(item_index, Color(0.2, 0.5, 0.2, 0.3))
		elif change < 0:
			reputation_history_list.set_item_custom_bg_color(item_index, Color(0.5, 0.2, 0.2, 0.3))
