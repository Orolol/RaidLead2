extends PanelContainer

var close_button: Button
var title_label: Label
var tab_container: TabContainer

var guild_ranking_list: ItemList
var recruitment_list: ItemList
var recruit_details: VBoxContainer

var available_players: Array = []
var selected_recruit = null
var competing_guilds: Array = []
var recruitment_pool: Node
var guild_manager: Node

signal player_recruited(player)

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(900, 600)
	
	# Récupère les références aux autoloads
	recruitment_pool = get_node("/root/RecruitmentPool")
	guild_manager = get_node("/root/GuildManager")
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)
	
	_setup_header(vbox)
	_setup_content(vbox)
	
	# Connecte aux signaux du RecruitmentPool
	if recruitment_pool:
		recruitment_pool.pool_refreshed.connect(_on_pool_refreshed)
		recruitment_pool.player_lost_to_competition.connect(_on_player_lost_to_competition)
	
	hide()
	_generate_competing_guilds()
	_refresh_recruitment_from_pool()

func _setup_header(parent: VBoxContainer):
	var header = HBoxContainer.new()
	parent.add_child(header)
	
	title_label = Label.new()
	title_label.text = "Vue du Monde"
	title_label.add_theme_font_size_override("font_size", 20)
	header.add_child(title_label)
	
	header.add_spacer(false)
	
	close_button = Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(30, 30)
	close_button.pressed.connect(_on_close_pressed)
	header.add_child(close_button)

func _setup_content(parent: VBoxContainer):
	tab_container = TabContainer.new()
	parent.add_child(tab_container)
	
	_setup_guild_ranking_tab()
	_setup_recruitment_tab()

func _setup_guild_ranking_tab():
	var ranking_panel = PanelContainer.new()
	ranking_panel.name = "Classement Guildes"
	tab_container.add_child(ranking_panel)
	
	var vbox = VBoxContainer.new()
	ranking_panel.add_child(vbox)
	
	var header_label = Label.new()
	header_label.text = "Top 10 des Guildes"
	header_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(header_label)
	
	guild_ranking_list = ItemList.new()
	guild_ranking_list.custom_minimum_size = Vector2(800, 450)
	vbox.add_child(guild_ranking_list)

func _setup_recruitment_tab():
	var recruitment_panel = PanelContainer.new()
	recruitment_panel.name = "Recrutement"
	tab_container.add_child(recruitment_panel)
	
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
	# Utilise les noms de guildes du RecruitmentPool
	var guild_names = [
		"Les Vengeurs d'Azeroth",
		"Légion Noire",
		"Les Gardiens du Crépuscule",
		"Fraternité du Loup",
		"Les Chevaliers de l'Aube",
		"Horde Sauvage",
		"Les Élus de la Lumière",
		"Compagnie du Dragon",
		"Les Forgerons de Guerre"
	]
	
	for guild_name in guild_names:
		competing_guilds.append({
			"name": guild_name,
			"progression": randi_range(0, 100),
			"members": randi_range(15, 40)
		})
	
	# Ajoute la guilde du joueur
	if guild_manager:
		competing_guilds.append({
			"name": "Ma Guilde",  # TODO: Ajouter un vrai nom de guilde
			"progression": _calculate_guild_progression(),
			"members": guild_manager.guild_members.size()
		})
	
	competing_guilds.sort_custom(func(a, b): return a.progression > b.progression)
	_refresh_guild_ranking()

func _calculate_guild_progression() -> int:
	# TODO: Calculer la progression basée sur les donjons/raids complétés
	return 0

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
	var rank = 1
	for guild in competing_guilds:
		var text = "#%d - %s (Progression: %d%%, Membres: %d)" % [rank, guild.name, guild.progression, guild.members]
		guild_ranking_list.add_item(text)
		rank += 1

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
		
		var text = "%s - %s Niv.%d (Équip: %d)%s" % [
			player.nom, 
			player.personnage_classe, 
			player.personnage_niveau,
			player.personnage_equipement,
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
	var recruitment_tab = tab_container.get_child(1)
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
	_add_detail_row(info_grid, "Équipement:", str(selected_recruit.personnage_equipement))
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
	
	var invite_button = Button.new()
	invite_button.text = "Envoyer une invitation"
	invite_button.custom_minimum_size = Vector2(200, 40)
	invite_button.pressed.connect(_on_invite_pressed)
	recruit_details.add_child(invite_button)

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
	if not selected_recruit or not recruitment_pool or not guild_manager:
		return
	
	# Prépare les données de la guilde pour le recrutement
	var guild_data = {
		"guild_size": guild_manager.members.size(),
		"hardcore": false,  # TODO: Déterminer selon l'activité de la guilde
		"recent_raid_success": false  # TODO: Tracker les succès récents
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

func _on_close_pressed():
	hide()