extends PanelContainer

var close_button: Button
var title_label: Label
var _drag_active: bool = false
var advanced_tabs: AdvancedTabs

var guild_ranking_list: ItemList
var recruitment_list: ItemList
var recruit_details: VBoxContainer
var salary_spinbox: SpinBox = null

var available_players: Array = []
var selected_recruit = null
var competing_guilds: Array = []
var recruitment_pool: Node
var guild_manager: Node
var guild_ranking: Node

signal player_recruited(player)

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(900, 600)
	
	# Récupère les références aux autoloads
	recruitment_pool = RecruitmentPool
	guild_manager = GuildManager
	guild_ranking = GuildRanking
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)
	
	_setup_header(vbox)
	_setup_content(vbox)
	
	# Connecte aux signaux du RecruitmentPool
	if recruitment_pool:
		recruitment_pool.pool_refreshed.connect(_on_pool_refreshed)
		recruitment_pool.player_lost_to_competition.connect(_on_player_lost_to_competition)
		
	# Connecte aux signaux du GuildRanking
	if guild_ranking:
		guild_ranking.ranking_updated.connect(_on_ranking_updated)
		guild_ranking.guild_position_changed.connect(_on_guild_position_changed)
		guild_ranking.new_server_first.connect(_on_server_first)
	
	hide()
	_generate_competing_guilds()
	_refresh_recruitment_from_pool()

func _on_header_drag(event: InputEvent) -> void:
	"""Permet de déplacer la fenêtre en glissant sur la barre de titre."""
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag_active = event.pressed
	elif event is InputEventMouseMotion and _drag_active:
		position += event.relative

func _setup_header(parent: VBoxContainer):
	var header = HBoxContainer.new()
	parent.add_child(header)
	
	title_label = Label.new()
	title_label.text = "Vue du Monde"
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

func _setup_content(parent: VBoxContainer):
	advanced_tabs = AdvancedTabs.create_simple_tabs(parent)
	
	_setup_guild_ranking_tab()
	_setup_recruitment_tab()

func _setup_guild_ranking_tab():
	var ranking_panel = PanelContainer.new()
	ranking_panel.name = "Classement Guildes"
	advanced_tabs.add_tab("Classement Guildes", ranking_panel, false)
	
	var main_split = HSplitContainer.new()
	main_split.split_offset = 600
	ranking_panel.add_child(main_split)
	
	# Côté gauche : Liste des guildes
	_setup_guild_list_section(main_split)
	
	# Côté droit : Détails de la guilde sélectionnée
	_setup_guild_details_section(main_split)

func _setup_guild_list_section(parent: HSplitContainer):
	"""Configure la section de liste des guildes"""
	var left_vbox = VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 10)
	parent.add_child(left_vbox)
	
	# Header avec phase actuelle et contrôles
	var header_container = HBoxContainer.new()
	left_vbox.add_child(header_container)
	
	var header_label = Label.new()
	header_label.text = "🏆 Classement des Guildes"
	header_label.add_theme_font_size_override("font_size", 18)
	header_container.add_child(header_label)
	
	header_container.add_spacer(false)
	
	var phase_label = Label.new()
	var phase_manager = get_node_or_null("/root/PhaseManager")
	if phase_manager:
		phase_label.text = "Phase: %s" % phase_manager.get_phase_name(phase_manager.get_current_phase())
	else:
		phase_label.text = "Phase: Serveur"
	phase_label.add_theme_font_size_override("font_size", 14)
	phase_label.modulate = Color(0.8, 0.8, 1.0)
	header_container.add_child(phase_label)
	
	# Informations sur notre position avec style amélioré
	var our_position_container = PanelContainer.new()
	our_position_container.add_theme_stylebox_override("panel", _create_highlight_style())
	left_vbox.add_child(our_position_container)
	
	var our_position_label = Label.new()
	our_position_label.name = "OurPositionLabel"
	our_position_label.add_theme_font_size_override("font_size", 16)
	our_position_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	our_position_container.add_child(our_position_label)
	
	# Contrôles d'affichage
	var controls_container = HBoxContainer.new()
	left_vbox.add_child(controls_container)
	
	var view_mode_label = Label.new()
	view_mode_label.text = "Affichage:"
	controls_container.add_child(view_mode_label)
	
	var view_mode_option = OptionButton.new()
	view_mode_option.name = "ViewModeOption"
	view_mode_option.add_item("Complet")
	view_mode_option.add_item("Top 10")
	view_mode_option.add_item("Autour de nous")
	view_mode_option.selected = 0
	view_mode_option.item_selected.connect(_on_view_mode_changed)
	controls_container.add_child(view_mode_option)
	
	controls_container.add_spacer(false)
	
	# Bouton pour rafraîchir
	var refresh_button = Button.new()
	refresh_button.text = "🔄 Actualiser"
	refresh_button.pressed.connect(_on_refresh_ranking_pressed)
	controls_container.add_child(refresh_button)
	
	# Liste des guildes améliorée
	guild_ranking_list = ItemList.new()
	guild_ranking_list.custom_minimum_size = Vector2(580, 400)
	guild_ranking_list.item_selected.connect(_on_guild_selected)
	guild_ranking_list.allow_reselect = true
	left_vbox.add_child(guild_ranking_list)

func _setup_guild_details_section(parent: HSplitContainer):
	"""Configure la section de détails des guildes"""
	var details_container = VBoxContainer.new()
	details_container.add_theme_constant_override("separation", 10)
	details_container.name = "GuildDetailsContainer"
	parent.add_child(details_container)
	
	# Titre de la section
	var details_title = Label.new()
	details_title.text = "📊 Détails de la Guilde"
	details_title.add_theme_font_size_override("font_size", 16)
	details_title.name = "DetailsTitle"
	details_container.add_child(details_title)
	
	# Container pour le contenu des détails
	var content_scroll = ScrollContainer.new()
	content_scroll.custom_minimum_size = Vector2(380, 500)
	details_container.add_child(content_scroll)
	
	var details_content = VBoxContainer.new()
	details_content.add_theme_constant_override("separation", 15)
	details_content.name = "DetailsContent"
	content_scroll.add_child(details_content)
	
	# Message initial
	var initial_message = Label.new()
	initial_message.text = "Sélectionnez une guilde dans la liste\npour voir ses détails complets"
	initial_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initial_message.modulate = Color(0.7, 0.7, 0.7)
	initial_message.name = "InitialMessage"
	details_content.add_child(initial_message)

func _create_highlight_style() -> StyleBox:
	"""Crée un style visuel pour mettre en évidence notre position"""
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.3, 0.5, 0.3)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.4, 0.6, 1.0, 0.8)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.content_margin_left = 10
	style.content_margin_right = 10
	return style

func _setup_recruitment_tab():
	var recruitment_panel = PanelContainer.new()
	recruitment_panel.name = "Recrutement"
	advanced_tabs.add_tab("Recrutement", recruitment_panel, false)
	
	var hsplit = HSplitContainer.new()
	hsplit.split_offset = 400
	recruitment_panel.add_child(hsplit)
	
	var left_panel = PanelContainer.new()
	hsplit.add_child(left_panel)
	
	var left_vbox = VBoxContainer.new()
	left_panel.add_child(left_vbox)
	
	var filter_hbox = HBoxContainer.new()
	left_vbox.add_child(filter_hbox)
	
	var filter_label = Label.new()
	filter_label.text = "Filtrer par classe:"
	filter_hbox.add_child(filter_label)
	
	var filter_option = OptionButton.new()
	filter_option.add_item("Tous")
	filter_option.add_item("Guerrier")
	filter_option.add_item("Mage")
	filter_option.add_item("Prêtre")
	filter_option.selected = 0
	filter_option.item_selected.connect(_on_filter_changed)
	filter_hbox.add_child(filter_option)
	
	recruitment_list = ItemList.new()
	recruitment_list.custom_minimum_size = Vector2(350, 400)
	recruitment_list.item_selected.connect(_on_recruit_selected)
	left_vbox.add_child(recruitment_list)
	
	var right_panel = PanelContainer.new()
	hsplit.add_child(right_panel)
	
	recruit_details = VBoxContainer.new()
	recruit_details.add_theme_constant_override("separation", 10)
	right_panel.add_child(recruit_details)
	
	_setup_recruit_details()

func _setup_recruit_details():
	var details_label = Label.new()
	details_label.text = "Détails du Candidat"
	details_label.add_theme_font_size_override("font_size", 16)
	recruit_details.add_child(details_label)
	
	var info_label = Label.new()
	info_label.text = "Sélectionnez un joueur pour voir ses détails"
	info_label.modulate = Color(0.7, 0.7, 0.7)
	recruit_details.add_child(info_label)

func _generate_competing_guilds():
	# Cette fonction ne génère plus les guildes - elles sont maintenant gérées par le système IA
	# On force juste une mise à jour du classement
	if guild_ranking:
		guild_ranking.update_rankings()
	else:
		_refresh_guild_ranking()

func _calculate_guild_progression() -> int:
	# Calculer la progression basée sur plusieurs facteurs
	var progression = 0
	
	if not guild_manager:
		return 0
	
	# Niveau moyen des membres (0-30 points)
	var total_level = 0
	var member_count = guild_manager.guild_members.size()
	if member_count > 0:
		for member in guild_manager.guild_members:
			total_level += member.personnage_niveau
		var avg_level = float(total_level) / float(member_count)
		progression += int((avg_level / 60.0) * 30)  # Max level 60
	
	# Nombre de membres (0-20 points)
	progression += min(20, member_count)  # Max 20 points pour 20+ membres
	
	# Équipement moyen (0-20 points)
	if member_count > 0:
		var total_equipment = 0
		for member in guild_manager.guild_members:
			total_equipment += member.get_total_ilvl()
		var avg_equipment = float(total_equipment) / float(member_count)
		progression += int(min(20, avg_equipment * 2))  # Max 10 d'équipement = 20 points
	
	# Bonus d'intégration (0-10 points)
	if guild_manager.guild:
		progression += int(guild_manager.guild.get_integration_bonus() * 10)
	
	# Activités en cours (0-10 points)
	var activity_manager = get_node_or_null("/root/ActivityManager")
	if activity_manager:
		var active_dungeons = activity_manager.active_dungeons.size()
		progression += min(10, active_dungeons * 5)
	
	# Perks de guilde (0-10 points) - Pour l'instant on met un bonus fixe
	# TODO: Implémenter le système de perks de guilde
	if guild_manager.guild:
		progression += 5  # Bonus fixe pour l'instant
	
	return min(100, progression)  # Plafonner à 100

func refresh_window() -> void:
	"""Rafraîchit le classement et le recrutement (appelé à l'affichage de la fenêtre)."""
	_refresh_guild_ranking()
	_refresh_recruitment_from_pool()

func _refresh_recruitment_from_pool():
	if not recruitment_pool:
		return
	
	available_players = recruitment_pool.available_players.duplicate()
	_refresh_recruitment_list()

func _on_pool_refreshed():
	_refresh_recruitment_from_pool()

func _on_player_lost_to_competition(player: SimulatedPlayer, guild_name: String):
	# Notification quand un joueur est recruté par une autre guilde
	if selected_recruit == player:
		selected_recruit = null
		_update_recruit_details()
	
	# Optionnel: afficher une notification
	print("Le joueur %s a été recruté par %s" % [player.nom, guild_name])

func _refresh_guild_ranking():
	guild_ranking_list.clear()
	
	# Récupérer les rankings depuis le système GuildRanking
	var rankings = []
	if guild_ranking:
		rankings = guild_ranking.get_current_rankings()
	
	# Si pas de données du système de ranking, utiliser un fallback
	if rankings.is_empty():
		_setup_fallback_ranking()
		return
	
	# Afficher les rankings
	for guild_data in rankings:
		var rank = guild_data.get("position", 1)
		var name = guild_data.get("name", "Guilde Inconnue")
		var score = guild_data.get("score", 0.0)
		var rank_change = guild_data.get("rank_change", 0)
		var is_player = guild_data.get("is_player", false)
		
		# Icône de changement de rang
		var rank_icon = ""
		if rank_change > 0:
			rank_icon = "▲"
		elif rank_change < 0:
			rank_icon = "▼"
		else:
			rank_icon = "▬"
		
		# Couleur selon si c'est notre guilde
		var text = "%s #%d - %s (Score: %.0f)" % [rank_icon, rank, name, score]
		if is_player:
			text += " ⭐"
		
		guild_ranking_list.add_item(text)
		
		# Colorer différemment notre guilde
		if is_player:
			guild_ranking_list.set_item_custom_bg_color(guild_ranking_list.get_item_count() - 1, Color(0.2, 0.3, 0.5, 0.3))
	
	# Mettre à jour les informations sur notre position
	_update_our_position_info()

func _setup_fallback_ranking():
	"""Setup de ranking basique si le système principal n'est pas disponible"""
	var fallback_guilds = [
		{"name": "Les Vengeurs d'Azeroth", "score": 850.0},
		{"name": "Légion Noire", "score": 820.0},
		{"name": "Les Gardiens du Crépuscule", "score": 790.0},
		{"name": "Fraternité du Loup", "score": 760.0},
		{"name": "Les Chevaliers de l'Aube", "score": 730.0}
	]
	
	# Ajouter la guilde du joueur
	if guild_manager and guild_manager.guild:
		var player_guild = {
			"name": guild_manager.guild.name,
			"score": float(_calculate_guild_progression() * 8),  # Convertir progression en score
			"is_player": true
		}
		fallback_guilds.append(player_guild)
	
	# Trier par score
	fallback_guilds.sort_custom(func(a, b): return a.score > b.score)
	
	# Afficher
	for i in range(fallback_guilds.size()):
		var guild = fallback_guilds[i]
		var rank = i + 1
		var text = "#%d - %s (Score: %.0f)" % [rank, guild.name, guild.score]
		if guild.get("is_player", false):
			text += " ⭐"
		
		guild_ranking_list.add_item(text)
		
		if guild.get("is_player", false):
			guild_ranking_list.set_item_custom_bg_color(guild_ranking_list.get_item_count() - 1, Color(0.2, 0.3, 0.5, 0.3))

func _refresh_recruitment_list(filter_class: String = ""):
	recruitment_list.clear()
	
	if not recruitment_pool:
		return
	
	# Utilise le système de filtres du RecruitmentPool
	var filters = {}
	if filter_class != "":
		filters["class"] = filter_class
	
	var filtered_players = recruitment_pool.get_filtered_players(filters)
	
	for player in filtered_players:
		var difficulty = player.get_meta("recruitment_difficulty", 0.5)
		var difficulty_text = ""
		if difficulty > 0.7:
			difficulty_text = " (Difficile)"
		elif difficulty < 0.3:
			difficulty_text = " (Facile)"
		
		var national_marker = "💼 " if player.get_meta("is_national", false) else ""
		var text = "%s%s - %s Niv.%d (Équip: %d)%s" % [
			national_marker,
			player.nom,
			player.personnage_classe,
			player.personnage_niveau,
			player.get_total_ilvl(),
			difficulty_text
		]
		recruitment_list.add_item(text)

func _on_filter_changed(index: int):
	var filter_class = ""
	match index:
		1: filter_class = "Guerrier"
		2: filter_class = "Mage"
		3: filter_class = "Prêtre"
	_refresh_recruitment_list(filter_class)

func _on_recruit_selected(index: int):
	if not recruitment_pool:
		return
	
	# Récupère la liste filtrée actuelle
	var filter_class = ""
	var filter_option = null
	
	# Navigation dans l'arbre des nodes pour trouver l'OptionButton
	var recruitment_tab_data = advanced_tabs.get_tab_data(1)
	var recruitment_tab = recruitment_tab_data.get("content", null)
	if recruitment_tab:
		var hsplit = recruitment_tab.get_child(0)
		if hsplit and hsplit.get_child_count() > 0:
			var left_panel = hsplit.get_child(0)
			if left_panel and left_panel.get_child_count() > 0:
				var left_vbox = left_panel.get_child(0)
				if left_vbox and left_vbox.get_child_count() > 0:
					var filter_hbox = left_vbox.get_child(0)
					if filter_hbox and filter_hbox.get_child_count() > 1:
						filter_option = filter_hbox.get_child(1)
	
	if filter_option and filter_option is OptionButton:
		match filter_option.selected:
			1: filter_class = "Guerrier"
			2: filter_class = "Mage"
			3: filter_class = "Prêtre"
	
	var filters = {}
	if filter_class != "":
		filters["class"] = filter_class
	
	var filtered_players = recruitment_pool.get_filtered_players(filters)
	
	if index < 0 or index >= filtered_players.size():
		return
	
	selected_recruit = filtered_players[index]
	_update_recruit_details()

func _update_recruit_details():
	for child in recruit_details.get_children():
		child.queue_free()
	
	if not selected_recruit:
		return
	
	var details_label = Label.new()
	details_label.text = "Candidat: " + selected_recruit.nom
	details_label.add_theme_font_size_override("font_size", 18)
	recruit_details.add_child(details_label)
	
	recruit_details.add_child(HSeparator.new())
	
	var info_grid = GridContainer.new()
	info_grid.columns = 2
	info_grid.add_theme_constant_override("h_separation", 20)
	info_grid.add_theme_constant_override("v_separation", 10)
	recruit_details.add_child(info_grid)
	
	_add_detail_row(info_grid, "Classe:", selected_recruit.personnage_classe)
	_add_detail_row(info_grid, "Niveau:", str(selected_recruit.personnage_niveau))
	_add_detail_row(info_grid, "Équipement:", selected_recruit.get_equipment_summary())
	_add_detail_row(info_grid, "Rôle:", selected_recruit.get_role())
	
	recruit_details.add_child(HSeparator.new())
	
	var tags_label = Label.new()
	tags_label.text = "Tags visibles:"
	recruit_details.add_child(tags_label)
	
	var tags_text = Label.new()
	var visible_tags = selected_recruit.get_visible_tags()
	if visible_tags.is_empty():
		tags_text.text = "Aucun tag visible pour le moment"
		tags_text.modulate = Color(0.6, 0.6, 0.6)
	else:
		tags_text.text = ", ".join(visible_tags)
		tags_text.modulate = Color(0.8, 0.8, 1.0)
	recruit_details.add_child(tags_text)
	
	# Ajoute la motivation du joueur
	if recruitment_pool:
		var motivation = selected_recruit.get_meta("recruitment_motivation", "")
		if motivation != "":
			recruit_details.add_child(HSeparator.new())
			
			var motivation_label = Label.new()
			motivation_label.text = "Motivation:"
			recruit_details.add_child(motivation_label)
			
			var motivation_text = Label.new()
			motivation_text.text = motivation
			motivation_text.modulate = Color(0.9, 0.9, 0.7)
			motivation_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			recruit_details.add_child(motivation_text)
	
	var planning_label = Label.new()
	planning_label.text = "\nDisponibilité probable:"
	recruit_details.add_child(planning_label)
	
	var planning_text = Label.new()
	planning_text.text = _get_planning_summary(selected_recruit.planning)
	planning_text.modulate = Color(0.8, 1.0, 0.8)
	recruit_details.add_child(planning_text)
	
	recruit_details.add_child(HSeparator.new())

	# Contrôles de recrutement : négociation salariale pour les recrues semi-pro (national)
	if selected_recruit.get_meta("is_national", false):
		_build_national_recruit_controls()
	else:
		_build_standard_invite_controls()

func _build_standard_invite_controls() -> void:
	var button_container = HBoxContainer.new()
	button_container.add_theme_constant_override("separation", 10)
	recruit_details.add_child(button_container)
	button_container.add_spacer(false)

	var invite_button = Button.new()
	invite_button.text = "Envoyer une invitation"
	invite_button.custom_minimum_size = Vector2(250, 50)
	invite_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if guild_manager and guild_manager.guild:
		if not guild_manager.guild.can_recruit():
			invite_button.disabled = true
			invite_button.tooltip_text = "Votre guilde doit atteindre le niveau 2 pour pouvoir recruter"
	invite_button.pressed.connect(_on_invite_pressed)
	button_container.add_child(invite_button)
	button_container.add_spacer(false)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	recruit_details.add_child(spacer)

func _build_national_recruit_controls() -> void:
	var demand: int = selected_recruit.salary_demand
	var has_agent: bool = selected_recruit.get_meta("has_agent", false)

	var header = Label.new()
	header.text = "💼 Recrue semi-professionnelle"
	header.add_theme_font_size_override("font_size", 15)
	header.modulate = Color(1.0, 0.82, 0.30)
	recruit_details.add_child(header)

	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 6)
	recruit_details.add_child(grid)
	_add_detail_row(grid, "Salaire demandé:", "%d or/sem" % demand)
	if has_agent:
		_add_detail_row(grid, "Agent:", "Oui (commission %d or)" % selected_recruit.get_meta("agent_commission", 0))
	else:
		_add_detail_row(grid, "Agent:", "Non")
	_add_detail_row(grid, "Masse salariale actuelle:", "%d or/sem" % (guild_manager.get_total_weekly_salaries() if guild_manager else 0))

	# Négociation salariale
	var neg_box = HBoxContainer.new()
	neg_box.add_theme_constant_override("separation", 8)
	recruit_details.add_child(neg_box)
	var lbl = Label.new()
	lbl.text = "Votre offre:"
	neg_box.add_child(lbl)
	salary_spinbox = SpinBox.new()
	salary_spinbox.min_value = 0
	salary_spinbox.max_value = maxi(demand * 3, 10)
	salary_spinbox.step = 5
	salary_spinbox.value = demand
	neg_box.add_child(salary_spinbox)
	var lbl2 = Label.new()
	lbl2.text = "or/sem"
	neg_box.add_child(lbl2)

	var btn_box = HBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 10)
	recruit_details.add_child(btn_box)
	var negotiate_btn = Button.new()
	negotiate_btn.text = "Négocier"
	negotiate_btn.pressed.connect(_on_negotiate_pressed)
	btn_box.add_child(negotiate_btn)
	var scout_btn = Button.new()
	scout_btn.text = "Scouter (-2 réput.)"
	scout_btn.tooltip_text = "Révèle les traits cachés et le skill réel"
	scout_btn.pressed.connect(_on_scout_pressed)
	btn_box.add_child(scout_btn)

func _on_negotiate_pressed() -> void:
	if not selected_recruit or not recruitment_pool or not salary_spinbox:
		return
	var offer: int = int(salary_spinbox.value)
	var result: Dictionary = recruitment_pool.attempt_national_recruitment(selected_recruit, offer)
	match result.get("step", ""):
		"accepted":
			player_recruited.emit(result.player)
			_show_recruit_dialog(_format_national_signing(result))
			selected_recruit = null
			_refresh_recruitment_list()
			_update_recruit_details()
		"counter":
			_show_counter_offer_dialog(selected_recruit, result.counter_offer)
		"rejected":
			_show_recruit_dialog(result.reason)
		"error":
			_show_recruit_dialog(result.get("reason", "Recrutement impossible"))
		_:
			# Pas d'exigence salariale → recrutement standard
			if result.get("success", false):
				player_recruited.emit(result.player)
				_show_recruit_dialog("%s rejoint la guilde !" % result.player.nom)
				selected_recruit = null
				_refresh_recruitment_list()
				_update_recruit_details()
			else:
				_show_recruit_dialog(result.get("reason", "Recrutement échoué"))

func _show_counter_offer_dialog(player, counter: int) -> void:
	var dialog = ConfirmationDialog.new()
	dialog.title = "Contre-proposition"
	dialog.dialog_text = "%s demande %d or/semaine. Accepter ce contrat ?" % [player.nom, counter]
	get_tree().root.add_child(dialog)
	dialog.confirmed.connect(func():
		var res: Dictionary = recruitment_pool.accept_counter_offer(player, counter)
		if res.get("success", false):
			player_recruited.emit(res.player)
			_show_recruit_dialog(_format_national_signing(res))
			selected_recruit = null
			_refresh_recruitment_list()
			_update_recruit_details()
		else:
			_show_recruit_dialog(res.get("reason", "Recrutement impossible"))
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

func _on_scout_pressed() -> void:
	if not selected_recruit or not recruitment_pool:
		return
	var result: Dictionary = recruitment_pool.scout_player(selected_recruit)
	var msg = "Skill réel : %d\nSalaire demandé : %d or/sem\nAgent : %s" % [
		result.get("skill", 0), result.get("salary_demand", 0),
		"Oui" if result.get("has_agent", false) else "Non"]
	var revealed: Array = result.get("revealed_tags", [])
	if not revealed.is_empty():
		msg += "\nTraits révélés : " + ", ".join(revealed)
	_show_recruit_dialog(msg)
	_update_recruit_details()

func _format_national_signing(result: Dictionary) -> String:
	var player_name: String = result.player.nom if result.get("player", null) else "La recrue"
	var text: String = "%s rejoint la guilde pour %d or/semaine !" % [player_name, result.get("salary", 0)]
	var agent_cost: int = int(result.get("agent_cost", 0))
	if agent_cost > 0:
		text += "\nCommission d'agent payée : %d or." % agent_cost
	return text

func _show_recruit_dialog(text: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.dialog_text = text
	get_tree().root.add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)

func _add_detail_row(parent: GridContainer, label_text: String, value_text: String):
	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 14)
	parent.add_child(label)
	
	var value = Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 14)
	value.modulate = Color(0.9, 0.9, 1.0)
	parent.add_child(value)

func _get_planning_summary(planning: Dictionary) -> String:
	var active_days = []
	if planning.has("vendredi") and planning["vendredi"].get("soir", false):
		active_days.append("Vendredi soir")
	if planning.has("samedi") and (planning["samedi"].get("apres_midi", false) or planning["samedi"].get("soir", false)):
		active_days.append("Samedi")
	if planning.has("dimanche") and (planning["dimanche"].get("apres_midi", false) or planning["dimanche"].get("soir", false)):
		active_days.append("Dimanche")
	
	if active_days.is_empty():
		return "Peu actif"
	else:
		return "Actif: " + ", ".join(active_days)

func _on_invite_pressed():
	print("Debug: Bouton recruter cliqué")
	print("Debug: selected_recruit = ", selected_recruit)
	print("Debug: recruitment_pool = ", recruitment_pool)
	print("Debug: guild_manager = ", guild_manager)
	
	if not selected_recruit or not recruitment_pool or not guild_manager:
		print("Debug: Une des conditions n'est pas remplie")
		return
	
	# Prépare les données de la guilde pour le recrutement
	var guild_data = {
		"guild_size": guild_manager.guild_members.size(),
		"hardcore": false,  # TODO: Déterminer selon l'activité de la guilde
		"recent_raid_success": false,  # TODO: Tracker les succès récents
		"reputation": guild_manager.guild.get_reputation() if guild_manager.guild else 50.0
	}
	
	# Tente le recrutement via le pool
	var result = recruitment_pool.attempt_recruitment(selected_recruit, guild_data)
	
	if result.success:
		# Le joueur a accepté!
		player_recruited.emit(result.player)
		selected_recruit = null
		_refresh_recruitment_list()
		_update_recruit_details()
		
		var dialog = AcceptDialog.new()
		dialog.dialog_text = "Le joueur a accepté votre invitation et rejoint la guilde!"
		get_tree().root.add_child(dialog)
		dialog.popup_centered()
		dialog.confirmed.connect(dialog.queue_free)
	else:
		# Le joueur a refusé
		var dialog = AcceptDialog.new()
		dialog.dialog_text = "Le joueur a décliné votre invitation.\nRaison: %s" % result.reason
		get_tree().root.add_child(dialog)
		dialog.popup_centered()
		dialog.confirmed.connect(dialog.queue_free)

func _update_our_position_info():
	"""Met à jour les informations sur notre position dans le classement"""
	var position_label = null
	
	# Trouver le label de position dans l'onglet classement
	var ranking_tab_data = advanced_tabs.get_tab_data(0)
	var ranking_tab = ranking_tab_data.get("content", null)
	if ranking_tab:
		var vbox = ranking_tab.get_child(0) if ranking_tab.get_child_count() > 0 else null
		if vbox:
			for child in vbox.get_children():
				if child.name == "OurPositionLabel":
					position_label = child
					break
	
	if not position_label:
		return
		
	var our_position = -1
	if guild_ranking and guild_manager and guild_manager.guild:
		our_position = guild_ranking.get_player_guild_position()
	
	if our_position > 0:
		position_label.text = "🏆 Notre guilde est classée #%d" % our_position
		if our_position == 1:
			position_label.modulate = Color(1.0, 0.8, 0.2)  # Gold pour #1
		elif our_position <= 3:
			position_label.modulate = Color(0.8, 0.8, 0.8)  # Silver pour top 3
		elif our_position <= 10:
			position_label.modulate = Color(0.7, 0.5, 0.3)  # Bronze pour top 10
		else:
			position_label.modulate = Color(0.8, 0.8, 0.8)  # Gris pour le reste
	else:
		position_label.text = "Position de notre guilde inconnue"
		position_label.modulate = Color(0.6, 0.6, 0.6)

# Nouveaux callbacks pour le système de ranking

func _on_ranking_updated(rankings: Array):
	"""Appelé quand le classement est mis à jour"""
	if visible and advanced_tabs and advanced_tabs.get_current_tab_index() == 0:  # Si on est sur l'onglet classement
		_refresh_guild_ranking()

func _on_guild_position_changed(guild_name: String, old_position: int, new_position: int):
	"""Appelé quand une guilde change de position"""
	if guild_manager and guild_manager.guild and guild_name == guild_manager.guild.name:
		# C'est notre guilde qui a changé de position
		var change_text = ""
		if new_position < old_position:
			change_text = "📈 Notre guilde monte au classement ! #%d → #%d" % [old_position, new_position]
		else:
			change_text = "📉 Notre guilde descend au classement. #%d → #%d" % [old_position, new_position]
		
		print(change_text)
		# TODO: Afficher une notification à l'écran
	
	# Mettre à jour l'affichage si visible
	if visible and advanced_tabs and advanced_tabs.get_current_tab_index() == 0:
		_refresh_guild_ranking()

func _on_server_first(guild_name: String, achievement_name: String):
	"""Appelé quand une guilde fait un server first"""
	var message = ""
	if guild_manager and guild_manager.guild and guild_name == guild_manager.guild.name:
		message = "🏆 FÉLICITATIONS ! Nous avons réalisé : %s" % achievement_name
	else:
		message = "📢 %s a réalisé : %s" % [guild_name, achievement_name]
	
	print(message)
	# TODO: Afficher une notification à l'écran
	
	# Mettre à jour le classement
	if visible and advanced_tabs and advanced_tabs.get_current_tab_index() == 0:
		_refresh_guild_ranking()

func _on_guild_selected(index: int):
	"""Appelé quand une guilde est sélectionnée dans la liste"""
	var rankings = guild_ranking.get_current_rankings() if guild_ranking else []
	if index >= 0 and index < rankings.size():
		var guild_data = rankings[index]
		_display_guild_details(guild_data)
	else:
		_clear_guild_details()

func _on_refresh_ranking_pressed():
	"""Appelé quand le bouton d'actualisation est pressé"""
	if guild_ranking:
		guild_ranking.update_rankings()
		print("Actualisation du classement demandée...")
	else:
		_refresh_guild_ranking()

func _on_view_mode_changed(index: int):
	"""Appelé quand le mode d'affichage change"""
	_apply_view_mode_filter(index)

func _apply_view_mode_filter(mode_index: int):
	"""Applique le filtre de mode d'affichage"""
	if not guild_ranking:
		return
	
	var all_rankings = guild_ranking.get_current_rankings()
	var filtered_rankings = []
	
	match mode_index:
		0:  # Complet
			filtered_rankings = all_rankings
		1:  # Top 10
			filtered_rankings = all_rankings.slice(0, min(10, all_rankings.size()))
		2:  # Autour de nous
			filtered_rankings = _get_rankings_around_player(all_rankings)
	
	_display_filtered_rankings(filtered_rankings)

func _get_rankings_around_player(all_rankings: Array) -> Array:
	"""Retourne les rankings autour de la position du joueur"""
	if not guild_manager or not guild_manager.guild:
		return all_rankings.slice(0, min(10, all_rankings.size()))
	
	var player_guild_name = guild_manager.guild.name
	var player_position = -1
	
	# Trouver la position du joueur
	for i in range(all_rankings.size()):
		if all_rankings[i].get("name", "") == player_guild_name or all_rankings[i].get("is_player", false):
			player_position = i
			break
	
	if player_position == -1:
		# Si pas trouvé, afficher le top 10
		return all_rankings.slice(0, min(10, all_rankings.size()))
	
	# Afficher 5 avant et 5 après (ou ajuster selon les limites)
	var start_index = max(0, player_position - 5)
	var end_index = min(all_rankings.size(), player_position + 6)  # +6 car slice exclut la fin
	
	return all_rankings.slice(start_index, end_index)

func _display_filtered_rankings(filtered_rankings: Array):
	"""Affiche une liste filtrée de rankings"""
	guild_ranking_list.clear()
	
	for guild_data in filtered_rankings:
		var rank = guild_data.get("position", 1)
		var name = guild_data.get("name", "Guilde Inconnue")
		var score = guild_data.get("score", 0.0)
		var rank_change = guild_data.get("rank_change", 0)
		var is_player = guild_data.get("is_player", false)
		
		# Icône de changement de rang
		var rank_icon = ""
		if rank_change > 0:
			rank_icon = "▲"
		elif rank_change < 0:
			rank_icon = "▼"
		else:
			rank_icon = "▬"
		
		# Couleur selon si c'est notre guilde
		var text = "%s #%d - %s (Score: %.0f)" % [rank_icon, rank, name, score]
		if is_player:
			text += " ⭐"
		
		guild_ranking_list.add_item(text)
		
		# Colorer différemment notre guilde
		if is_player:
			guild_ranking_list.set_item_custom_bg_color(guild_ranking_list.get_item_count() - 1, Color(0.2, 0.3, 0.5, 0.3))
	
	# Mettre à jour les informations sur notre position
	_update_our_position_info()

func _display_guild_details(guild_data: Dictionary):
	"""Affiche les détails d'une guilde sélectionnée"""
	var details_container = _get_guild_details_container()
	if not details_container:
		return
	
	# Nettoyer le contenu précédent
	for child in details_container.get_children():
		child.queue_free()
	
	# Titre avec nom de guilde
	var guild_name = guild_data.get("name", "Guilde Inconnue")
	var rank = guild_data.get("position", 0)
	var is_player = guild_data.get("is_player", false)
	
	var title_container = HBoxContainer.new()
	details_container.add_child(title_container)
	
	var title_label = Label.new()
	title_label.text = "#%d - %s" % [rank, guild_name]
	title_label.add_theme_font_size_override("font_size", 18)
	if is_player:
		title_label.modulate = Color(1.0, 0.8, 0.2)
	title_container.add_child(title_label)
	
	if is_player:
		title_container.add_spacer(false)
		var player_icon = Label.new()
		player_icon.text = "⭐"
		player_icon.add_theme_font_size_override("font_size", 20)
		title_container.add_child(player_icon)
	
	details_container.add_child(HSeparator.new())
	
	# Statistiques principales
	var stats_title = Label.new()
	stats_title.text = "📊 Statistiques"
	stats_title.add_theme_font_size_override("font_size", 14)
	details_container.add_child(stats_title)
	
	var stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 15)
	stats_grid.add_theme_constant_override("v_separation", 5)
	details_container.add_child(stats_grid)
	
	_add_stat_row(stats_grid, "Score total:", "%.0f" % guild_data.get("score", 0.0))
	_add_stat_row(stats_grid, "Membres actifs:", str(guild_data.get("active_members", "N/A")))
	_add_stat_row(stats_grid, "Réputation:", "%.0f" % guild_data.get("reputation", 0.0))
	
	var rank_change = guild_data.get("rank_change", 0)
	var trend_text = ""
	var trend_color = Color.WHITE
	if rank_change > 0:
		trend_text = "↗️ +%d" % rank_change
		trend_color = Color.GREEN
	elif rank_change < 0:
		trend_text = "↘️ %d" % rank_change
		trend_color = Color.RED
	else:
		trend_text = "➡️ Stable"
		trend_color = Color.YELLOW
	
	_add_stat_row(stats_grid, "Tendance:", trend_text, trend_color)
	
	details_container.add_child(HSeparator.new())
	
	# Progression récente (simulée)
	var progress_title = Label.new()
	progress_title.text = "📈 Progression récente"
	progress_title.add_theme_font_size_override("font_size", 14)
	details_container.add_child(progress_title)
	
	var progress_list = ItemList.new()
	progress_list.custom_minimum_size = Vector2(0, 120)
	details_container.add_child(progress_list)
	
	# Simuler quelques événements récents
	_populate_recent_events(progress_list, guild_data)
	
	details_container.add_child(HSeparator.new())
	
	# Spécialités/Points forts
	var strengths_title = Label.new()
	strengths_title.text = "💪 Points forts"
	strengths_title.add_theme_font_size_override("font_size", 14)
	details_container.add_child(strengths_title)
	
	var strengths_label = Label.new()
	strengths_label.text = _get_guild_strengths(guild_data)
	strengths_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	strengths_label.modulate = Color(0.8, 0.9, 1.0)
	details_container.add_child(strengths_label)

func _clear_guild_details():
	"""Efface les détails de guilde et affiche le message initial"""
	var details_container = _get_guild_details_container()
	if not details_container:
		return
	
	# Nettoyer le contenu
	for child in details_container.get_children():
		child.queue_free()
	
	# Remettre le message initial
	var initial_message = Label.new()
	initial_message.text = "Sélectionnez une guilde dans la liste\npour voir ses détails complets"
	initial_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initial_message.modulate = Color(0.7, 0.7, 0.7)
	initial_message.name = "InitialMessage"
	details_container.add_child(initial_message)

func _get_guild_details_container() -> VBoxContainer:
	"""Récupère le container de détails des guildes"""
	var ranking_tab_data = advanced_tabs.get_tab_data(0)
	var ranking_tab = ranking_tab_data.get("content", null)
	if not ranking_tab:
		return null
	
	var main_split = ranking_tab.get_child(0) if ranking_tab.get_child_count() > 0 else null
	if not main_split or main_split.get_child_count() < 2:
		return null
	
	var details_section = main_split.get_child(1)
	if not details_section or details_section.get_child_count() < 2:
		return null
	
	var scroll_container = details_section.get_child(1)
	if not scroll_container or scroll_container.get_child_count() == 0:
		return null
	
	return scroll_container.get_child(0) as VBoxContainer

func _add_stat_row(grid: GridContainer, label_text: String, value_text: String, value_color: Color = Color.WHITE):
	"""Ajoute une ligne de statistique"""
	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 12)
	grid.add_child(label)
	
	var value = Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 12)
	value.modulate = value_color
	grid.add_child(value)

func _populate_recent_events(list: ItemList, guild_data: Dictionary):
	"""Remplit la liste des événements récents (simulés)"""
	var guild_name = guild_data.get("name", "Guilde")
	var is_player = guild_data.get("is_player", false)
	
	if is_player:
		# Événements pour notre guilde
		list.add_item("• Recrutement de 2 nouveaux membres")
		list.add_item("• Clear de Scholomance avec succès")
		list.add_item("• Organisation d'un événement de guilde")
	else:
		# Événements simulés pour les autres guildes
		var events = [
			"• Clear d'un nouveau donjon",
			"• Recrutement d'un joueur expérimenté",
			"• Participation à un événement serveur",
			"• Amélioration de l'équipement moyen",
			"• Succès en JcJ organisé"
		]
		
		# Ajouter 2-4 événements aléatoires
		events.shuffle()
		var count = randi_range(2, 4)
		for i in range(min(count, events.size())):
			list.add_item(events[i])

func _get_guild_strengths(guild_data: Dictionary) -> String:
	"""Retourne les points forts d'une guilde"""
	var is_player = guild_data.get("is_player", false)
	var score = guild_data.get("score", 0.0)
	
	if is_player:
		return "Forte cohésion d'équipe, progression équilibrée, gestion active des membres"
	
	# Générer des points forts basés sur le score et le nom
	var strengths = []
	
	if score > 800:
		strengths.append("Performance exceptionnelle en PvE")
	elif score > 600:
		strengths.append("Bonne progression en contenu")
	else:
		strengths.append("Guilde en développement")
	
	# Ajouter des spécialités aléatoires mais cohérentes
	var possible_strengths = [
		"Spécialisée en raids",
		"Active en JcJ",
		"Excellente organisation",
		"Recrutement sélectif",
		"Bonne ambiance",
		"Formation des nouveaux joueurs"
	]
	
	possible_strengths.shuffle()
	for i in range(2):
		strengths.append(possible_strengths[i])
	
	return ", ".join(strengths)

func _on_close_pressed():
	hide()