extends PanelContainer

# Référencé via preload (et non par class_name) pour ne pas dépendre du cache de
# classes globales de l'éditeur (robuste pour l'export et la CI).
const RecruitmentPanelScript = preload("res://scripts/ui/windows/recruitment_panel.gd")

var close_button: Button
var title_label: Label
var _drag_active: bool = false
var advanced_tabs: AdvancedTabs

var guild_ranking_list: ItemList
var recruitment_panel: RecruitmentPanelScript

var competing_guilds: Array = []
var guild_manager: Node
var guild_ranking: Node

signal player_recruited(player)
signal close_requested

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(900, 600)
	
	# Récupère les références aux autoloads
	guild_manager = GuildManager
	guild_ranking = GuildRanking

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	_setup_header(vbox)
	_setup_content(vbox)

	# Connecte aux signaux du GuildRanking (rafraîchit le classement quand il change)
	if guild_ranking:
		if not guild_ranking.ranking_updated.is_connected(_on_ranking_updated):
			guild_ranking.ranking_updated.connect(_on_ranking_updated)
		if not guild_ranking.guild_position_changed.is_connected(_on_guild_position_changed):
			guild_ranking.guild_position_changed.connect(_on_guild_position_changed)
		if not guild_ranking.new_server_first.is_connected(_on_server_first):
			guild_ranking.new_server_first.connect(_on_server_first)
	
	hide()
	_generate_competing_guilds()

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
	var phase_manager = PhaseManager
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
	var panel := RecruitmentPanelScript.new()
	advanced_tabs.add_tab("Recrutement", panel, false)
	recruitment_panel = panel
	# Réémet le signal du panel pour que main.gd (branché sur la fenêtre) reste informé.
	panel.player_recruited.connect(func(p): player_recruited.emit(p))

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
	var activity_manager = ActivityManager
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
	if recruitment_panel:
		recruitment_panel.refresh()

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
		var guild_name = guild_data.get("name", "Guilde Inconnue")
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
		var text = "%s #%d - %s (Score: %.0f)" % [rank_icon, rank, guild_name, score]
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

func _on_ranking_updated(_rankings: Array):
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
		
		GameLog.d(change_text)
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
	
	GameLog.d(message)
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
		GameLog.d("Actualisation du classement demandée...")
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
		var guild_name = guild_data.get("name", "Guilde Inconnue")
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
		var text = "%s #%d - %s (Score: %.0f)" % [rank_icon, rank, guild_name, score]
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
	
	var guild_title_label = Label.new()
	guild_title_label.text = "#%d - %s" % [rank, guild_name]
	guild_title_label.add_theme_font_size_override("font_size", 18)
	if is_player:
		guild_title_label.modulate = Color(1.0, 0.8, 0.2)
	title_container.add_child(guild_title_label)
	
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
	
	# RichTextLabel : la description des points forts peut contenir du BBCode
	# (ex. [b]…[/b], [color=gray]…[/color]) qui doit être rendu, pas affiché en texte brut.
	var strengths_label = RichTextLabel.new()
	strengths_label.bbcode_enabled = true
	strengths_label.fit_content = true
	strengths_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	strengths_label.scroll_active = false
	strengths_label.text = _get_guild_strengths(guild_data)
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
	var _guild_name = guild_data.get("name", "Guilde")
	var is_player = guild_data.get("is_player", false)
	
	if is_player:
		# Événements RÉELS de notre guilde : derniers runs PvE (fini les faits inventés).
		var added: bool = false
		if GuildRanking and GuildRanking.has_method("get_player_run_history"):
			var runs: Array = GuildRanking.get_player_run_history(4)
			for i in range(runs.size() - 1, -1, -1):
				var r: Dictionary = runs[i]
				var wipes: int = int(r.get("wipes", 0))
				var suffix: String = " (%d wipe(s))" % wipes if wipes > 0 else ""
				list.add_item("• Clear : %s%s" % [str(r.get("name", r.get("content_id", "?"))), suffix])
				added = true
		if not added:
			list.add_item("• Aucun run PvE récent — composez un groupe dans Organisation")
	else:
		# Estimations pour les guildes adverses (information partielle, normal pour un concurrent).
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
		# Points forts dérivés de l'état RÉEL de la guilde.
		var parts: Array[String] = []
		if GuildManager and GuildManager.guild:
			parts.append("Réputation %d" % int(GuildManager.guild.reputation))
		var gcm: Node = GuildCultureManager
		if gcm and gcm.has_method("get_morale_tier"):
			parts.append("Ambiance %s" % gcm.get_morale_tier())
		if GuildManager:
			parts.append("%d membres" % GuildManager.guild_members.size())
		return ", ".join(parts) if not parts.is_empty() else "Guilde en développement"
	
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
	# Délègue la fermeture au WindowManager (qui synchronise son état) au lieu d'un hide() local.
	close_requested.emit()
