extends PanelContainer

signal close_requested

const PlayerTagsData = preload("res://scripts/data/player_tags.gd")
const EquipmentWindow = preload("res://scenes/Fenetre_Equipement.tscn")

var equipment_window_instance = null

var members_list: ItemList
var member_details: VBoxContainer
var close_button: Button
var title_label: Label
var title_bar: Panel
var context_menu: PopupMenu

var guild_members: Array = []
var selected_member = null
var guild_manager: Node
var right_clicked_member_index: int = -1

# Historique de loot
var loot_history_container: VBoxContainer

# Labels pour les infos de guilde
var guild_level_label: Label
var guild_xp_label: Label
var guild_members_label: Label
var guild_perks_label: Label

# Variables pour le redimensionnement et déplacement
var is_dragging: bool = false
var is_resizing: bool = false
var drag_offset: Vector2
var resize_start_pos: Vector2
var resize_start_size: Vector2

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(800, 600)
	size = Vector2(1000, 700)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	add_child(vbox)
	
	_setup_header(vbox)
	_setup_content(vbox)
	_setup_context_menu()
	
	guild_manager = GuildManager
	if guild_manager:
		guild_manager.member_activity_changed.connect(_on_member_activity_changed)
		guild_manager.member_connected.connect(_on_member_status_changed)
		guild_manager.member_disconnected.connect(_on_member_status_changed)
		guild_manager.guild_level_changed.connect(_on_guild_level_changed)
		guild_manager.guild_perk_unlocked.connect(_on_guild_perk_unlocked)
		guild_manager.member_leveled_up.connect(_on_member_leveled_up)
		guild_manager.member_recruited.connect(_on_member_recruited)
		guild_manager.member_left.connect(_on_member_left)
	
	hide()
	_load_test_members()
	_update_guild_info()

func refresh_window() -> void:
	"""Rafraîchit la liste des membres et les infos de guilde (appelé à l'affichage)."""
	_refresh_member_list()
	_update_guild_info()

func _setup_header(parent: VBoxContainer):
	# Barre de titre personnalisée
	title_bar = Panel.new()
	title_bar.custom_minimum_size = Vector2(0, 30)
	title_bar.modulate = Color(0.8, 0.8, 0.9)
	parent.add_child(title_bar)
	
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	title_bar.add_child(header)
	
	# Marge gauche
	header.add_child(Control.new())
	header.get_child(0).custom_minimum_size = Vector2(10, 0)
	
	title_label = Label.new()
	title_label.text = "Gestion de la Guilde"
	title_label.add_theme_font_size_override("font_size", 18)
	header.add_child(title_label)
	
	header.add_spacer(false)
	
	close_button = Button.new()
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(30, 25)
	close_button.flat = true
	close_button.pressed.connect(_on_close_pressed)
	header.add_child(close_button)
	
	# Connecte les événements pour le drag
	title_bar.gui_input.connect(_on_title_bar_input)

func _setup_content(parent: VBoxContainer):
	# Panel d'informations de guilde
	var guild_info_panel: PanelContainer = PanelContainer.new()
	guild_info_panel.custom_minimum_size = Vector2(0, 80)
	parent.add_child(guild_info_panel)

	var guild_info_vbox: VBoxContainer = VBoxContainer.new()
	guild_info_panel.add_child(guild_info_vbox)

	_setup_guild_info(guild_info_vbox)

	# TabContainer pour Membres / Historique
	var tab_container: TabContainer = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(tab_container)

	# --- Onglet Membres ---
	var members_tab: VBoxContainer = VBoxContainer.new()
	members_tab.name = "Membres"
	tab_container.add_child(members_tab)

	var hsplit: HSplitContainer = HSplitContainer.new()
	hsplit.split_offset = 300
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	members_tab.add_child(hsplit)

	var left_panel: PanelContainer = PanelContainer.new()
	hsplit.add_child(left_panel)

	var left_vbox: VBoxContainer = VBoxContainer.new()
	left_panel.add_child(left_vbox)

	var list_label: Label = Label.new()
	list_label.text = "Membres de la Guilde"
	list_label.add_theme_font_size_override("font_size", 16)
	left_vbox.add_child(list_label)

	members_list = ItemList.new()
	members_list.custom_minimum_size = Vector2(300, 500)
	members_list.icon_mode = ItemList.ICON_MODE_LEFT
	members_list.fixed_icon_size = Vector2i(28, 28)  # portraits 1024px -> miniatures lisibles
	members_list.item_selected.connect(_on_member_selected)
	members_list.gui_input.connect(_on_members_list_gui_input)
	left_vbox.add_child(members_list)

	var right_panel: PanelContainer = PanelContainer.new()
	hsplit.add_child(right_panel)

	var scroll_container: ScrollContainer = ScrollContainer.new()
	scroll_container.custom_minimum_size = Vector2(600, 500)
	right_panel.add_child(scroll_container)

	member_details = VBoxContainer.new()
	member_details.add_theme_constant_override("separation", 8)
	member_details.custom_minimum_size = Vector2(580, 0)
	scroll_container.add_child(member_details)

	_setup_member_details()

	# --- Onglet Historique ---
	var history_tab: VBoxContainer = VBoxContainer.new()
	history_tab.name = "Historique"
	tab_container.add_child(history_tab)

	_setup_loot_history_tab(history_tab)

func _setup_member_details():
	var details_label = Label.new()
	details_label.text = "Détails du Membre"
	details_label.add_theme_font_size_override("font_size", 16)
	member_details.add_child(details_label)
	
	var info_label = Label.new()
	info_label.text = "Sélectionnez un membre pour voir ses détails"
	info_label.modulate = Color(0.7, 0.7, 0.7)
	member_details.add_child(info_label)

func _load_test_members():
	# Utiliser les membres existants du GuildManager au lieu d'en créer de nouveaux
	if guild_manager:
		guild_members = guild_manager.guild_members.duplicate()
	
	_refresh_member_list()

func _refresh_member_list():
	# Synchroniser avec le GuildManager au cas où de nouveaux membres auraient été ajoutés
	if guild_manager:
		guild_members = guild_manager.guild_members.duplicate()

	_refresh_loot_history()

	members_list.clear()
	for member in guild_members:
		var status = "[Hors ligne]"
		if member.is_online:
			status = "[En ligne]"
			if member.current_activity:
				status = "[%s]" % member.current_activity.get_type_string()

		var text = "%s %s - %s Niv.%d" % [member.nom, status, member.personnage_classe, member.personnage_niveau]
		var portrait: Texture2D = AssetLoader.get_class_portrait(member.personnage_classe)
		if portrait:
			members_list.add_item(text, portrait)
		else:
			members_list.add_item(text)
		var idx: int = members_list.item_count - 1
		if not member.is_online:
			members_list.set_item_custom_fg_color(idx, Color(0.5, 0.5, 0.5))
		else:
			members_list.set_item_custom_fg_color(idx, Color(0.90, 0.90, 0.93))

func _on_member_selected(index: int):
	if index < 0 or index >= guild_members.size():
		return
	
	selected_member = guild_members[index]
	_update_member_details()

func _update_member_details():
	for child in member_details.get_children():
		child.queue_free()
	
	if not selected_member:
		return
	
	# Header avec portrait
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 12)
	member_details.add_child(header_hbox)

	var portrait: Texture2D = AssetLoader.get_class_portrait(selected_member.personnage_classe)
	if portrait:
		var portrait_rect = TextureRect.new()
		portrait_rect.texture = portrait
		portrait_rect.custom_minimum_size = Vector2(64, 64)
		portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		header_hbox.add_child(portrait_rect)

	var name_vbox = VBoxContainer.new()
	header_hbox.add_child(name_vbox)

	var details_label = Label.new()
	details_label.text = selected_member.nom
	details_label.add_theme_font_size_override("font_size", 18)
	name_vbox.add_child(details_label)

	var subtitle_hbox = HBoxContainer.new()
	subtitle_hbox.add_theme_constant_override("separation", 6)
	name_vbox.add_child(subtitle_hbox)

	var role_icon: Texture2D = AssetLoader.get_role_icon(selected_member.get_role())
	if role_icon:
		var role_rect = TextureRect.new()
		role_rect.texture = role_icon
		role_rect.custom_minimum_size = Vector2(20, 20)
		role_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		role_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		subtitle_hbox.add_child(role_rect)

	var subtitle_label = Label.new()
	subtitle_label.text = "%s %s - Niv.%d" % [selected_member.get_role(), selected_member.personnage_classe, selected_member.personnage_niveau]
	subtitle_label.add_theme_font_size_override("font_size", 13)
	subtitle_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	subtitle_hbox.add_child(subtitle_label)

	member_details.add_child(HSeparator.new())

	var info_grid = GridContainer.new()
	info_grid.columns = 2
	info_grid.add_theme_constant_override("h_separation", 20)
	info_grid.add_theme_constant_override("v_separation", 10)
	member_details.add_child(info_grid)

	_add_detail_row(info_grid, "Équipement:", selected_member.get_equipment_summary())
	
	member_details.add_child(HSeparator.new())
	
	# Titre des métriques
	var metrics_label = Label.new()
	metrics_label.text = "Métriques:"
	metrics_label.add_theme_font_size_override("font_size", 14)
	member_details.add_child(metrics_label)
	
	# Container pour les StatDisplay
	var stats_container = VBoxContainer.new()
	stats_container.add_theme_constant_override("separation", 8)
	member_details.add_child(stats_container)
	
	# Énergie avec StatDisplay
	var energy_display = StatDisplay.new()
	energy_display.stat_name = "Énergie"
	energy_display.current_value = selected_member.energy
	energy_display.max_value = 100.0
	energy_display.display_mode = StatDisplay.DisplayMode.PROGRESS_BAR
	energy_display.icon_text = "⚡"
	energy_display.custom_minimum_size = Vector2(300, 25)
	stats_container.add_child(energy_display)
	
	# Humeur avec StatDisplay
	var mood_display = StatDisplay.new()
	mood_display.stat_name = "Humeur"
	mood_display.current_value = selected_member.mood
	mood_display.max_value = 100.0
	mood_display.display_mode = StatDisplay.DisplayMode.PROGRESS_BAR
	mood_display.icon_text = "😊"
	mood_display.custom_minimum_size = Vector2(300, 25)
	stats_container.add_child(mood_display)
	
	# Intégration avec StatDisplay
	var integration_display = StatDisplay.new()
	integration_display.stat_name = "Intégration"
	integration_display.current_value = selected_member.integration
	integration_display.max_value = 100.0
	integration_display.display_mode = StatDisplay.DisplayMode.PROGRESS_BAR
	integration_display.icon_text = "🤝"
	integration_display.custom_minimum_size = Vector2(300, 25)
	stats_container.add_child(integration_display)
	
	# Skill avec StatDisplay
	var skill_display = StatDisplay.new()
	skill_display.stat_name = "Compétence"
	skill_display.current_value = selected_member.skill
	skill_display.max_value = 100.0
	skill_display.display_mode = StatDisplay.DisplayMode.VALUE_PERCENTAGE
	skill_display.icon_text = "⭐"
	skill_display.custom_minimum_size = Vector2(300, 25)
	stats_container.add_child(skill_display)
	
	var status = "Hors ligne"
	if selected_member.is_online:
		status = "En ligne"
	_add_detail_row(info_grid, "Statut:", status)
	
	if selected_member.current_activity:
		var activity_text = selected_member.current_activity.get_type_string()
		if selected_member.current_activity.location != "":
			activity_text += " à " + selected_member.current_activity.location
		_add_detail_row(info_grid, "Activité:", activity_text)
	
	member_details.add_child(HSeparator.new())
	
	# Statistiques d'intégration
	_add_detail_row(info_grid, "Jours dans la guilde:", str(selected_member.days_in_guild))
	_add_detail_row(info_grid, "Activités complétées:", str(selected_member.activities_completed))
	if selected_member.raid_successes > 0:
		_add_detail_row(info_grid, "Succès de raid:", str(selected_member.raid_successes))
	
	member_details.add_child(HSeparator.new())
	
	var tags_label = Label.new()
	tags_label.text = "Tags comportementaux connus:"
	member_details.add_child(tags_label)
	
	var tags_container = HFlowContainer.new()
	tags_container.add_theme_constant_override("h_separation", 5)
	tags_container.add_theme_constant_override("v_separation", 5)
	member_details.add_child(tags_container)
	
	# Affiche les tags visibles
	for tag in selected_member.tags_comportement:
		var tag_button = Button.new()
		tag_button.text = tag
		tag_button.flat = true
		tag_button.tooltip_text = PlayerTagsData.get_tag_description(tag)
		tag_button.modulate = Color(0.8, 0.8, 1.0)
		tags_container.add_child(tag_button)
	
	# Affiche le nombre de tags cachés
	if selected_member.tags_caches.size() > 0:
		var hidden_label = Label.new()
		hidden_label.text = "\n(%d tags encore cachés)" % selected_member.tags_caches.size()
		hidden_label.modulate = Color(0.6, 0.6, 0.6)
		member_details.add_child(hidden_label)
		
		# Indice sur le prochain tag à découvrir
		var potential_reveals = PlayerTagsData.get_potential_reveals({
			"hidden_tags": selected_member.tags_caches,
			"integration": selected_member.integration,
			"days_in_guild": selected_member.days_in_guild,
			"raid_successes": selected_member.raid_successes,
			"wipes_experienced": selected_member.wipes_experienced,
			"loot_conflicts": selected_member.loot_conflicts
		})
		
		if potential_reveals.size() > 0:
			var hint_label = Label.new()
			hint_label.text = "Prochain tag pourrait être révélé bientôt..."
			hint_label.modulate = Color(0.7, 0.7, 0.5)
			hint_label.add_theme_font_size_override("font_size", 12)
			member_details.add_child(hint_label)

func _setup_loot_history_tab(parent: VBoxContainer):
	var title_label_hist: Label = Label.new()
	title_label_hist.text = "Historique des Loots"
	title_label_hist.add_theme_font_size_override("font_size", 16)
	parent.add_child(title_label_hist)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 400)
	parent.add_child(scroll)

	loot_history_container = VBoxContainer.new()
	loot_history_container.add_theme_constant_override("separation", 4)
	loot_history_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(loot_history_container)

	_refresh_loot_history()

func _refresh_loot_history():
	if not loot_history_container:
		return

	for child in loot_history_container.get_children():
		child.queue_free()

	if not guild_manager:
		return

	var history: Array = guild_manager.loot_history
	if history.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "Aucun loot enregistré pour le moment."
		empty_label.modulate = Color(0.6, 0.6, 0.6)
		loot_history_container.add_child(empty_label)
		return

	# Afficher du plus récent au plus ancien
	for i in range(history.size() - 1, -1, -1):
		var entry: Dictionary = history[i]
		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		loot_history_container.add_child(hbox)

		# Timestamp
		var ts: Dictionary = entry.get("timestamp", {})
		var ts_text: String = "J%d S%d" % [ts.get("day", 0), ts.get("week", 0)]
		var ts_label: Label = Label.new()
		ts_label.text = ts_text
		ts_label.custom_minimum_size = Vector2(60, 0)
		ts_label.add_theme_font_size_override("font_size", 12)
		ts_label.modulate = Color(0.6, 0.6, 0.6)
		hbox.add_child(ts_label)

		# Nom du membre
		var member_label: Label = Label.new()
		member_label.text = entry.get("member_name", "?")
		member_label.custom_minimum_size = Vector2(140, 0)
		member_label.add_theme_font_size_override("font_size", 12)
		hbox.add_child(member_label)

		# Nom de l'item coloré par rareté
		var item = entry.get("item", null)
		var item_label: Label = Label.new()
		if item and item is Item:
			item_label.text = "%s (iLvl %d)" % [item.name, item.ilvl]
			item_label.modulate = item.get_rarity_color()
		else:
			item_label.text = "Item inconnu"
			item_label.modulate = Color(0.5, 0.5, 0.5)
		item_label.custom_minimum_size = Vector2(200, 0)
		item_label.add_theme_font_size_override("font_size", 12)
		hbox.add_child(item_label)

		# Donjon
		var dungeon_label: Label = Label.new()
		dungeon_label.text = entry.get("dungeon_name", "")
		dungeon_label.add_theme_font_size_override("font_size", 12)
		dungeon_label.modulate = Color(0.7, 0.7, 0.7)
		hbox.add_child(dungeon_label)

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

func _on_close_pressed():
	close_requested.emit()

func add_member(player):
	guild_members.append(player)
	if guild_manager:
		guild_manager.add_member(player)
	_refresh_member_list()
	_update_guild_info()

func _on_member_activity_changed(player, _activity):
	if player in guild_members:
		_refresh_member_list()
		if selected_member == player:
			_update_member_details()

func _on_member_status_changed(player):
	if player in guild_members:
		_refresh_member_list()
		if selected_member == player:
			_update_member_details()

func _on_member_leveled_up(player, _new_level: int):
	_refresh_member_list()
	if selected_member == player:
		_update_member_details()

func _on_member_recruited(_player):
	_refresh_member_list()
	_update_guild_info()

func _on_member_left(_player):
	_refresh_member_list()
	_update_guild_info()

# Gestion du drag de la fenêtre
func _on_title_bar_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				drag_offset = global_position - event.global_position
			else:
				is_dragging = false

func _gui_input(event: InputEvent):
	if event is InputEventMouseMotion:
		if is_dragging:
			global_position = event.global_position + drag_offset
		elif is_resizing:
			var new_size = resize_start_size + (event.global_position - resize_start_pos)
			size = Vector2(
				max(custom_minimum_size.x, new_size.x),
				max(custom_minimum_size.y, new_size.y)
			)
		else:
			# Vérifie si on est sur le bord pour redimensionner
			_update_cursor(event.position)
			
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _is_on_resize_edge(event.position):
					is_resizing = true
					resize_start_pos = event.global_position
					resize_start_size = size
			else:
				is_resizing = false

func _is_on_resize_edge(pos: Vector2) -> bool:
	var margin = 10
	return (pos.x > size.x - margin and pos.y > size.y - margin) or \
		   (pos.x > size.x - margin) or \
		   (pos.y > size.y - margin)

func _update_cursor(pos: Vector2):
	if _is_on_resize_edge(pos):
		mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	else:
		mouse_default_cursor_shape = Control.CURSOR_ARROW

func _setup_guild_info(parent: VBoxContainer):
	var guild_name_label = Label.new()
	guild_name_label.text = "Ma Guilde"
	guild_name_label.add_theme_font_size_override("font_size", 20)
	parent.add_child(guild_name_label)
	
	var info_hbox = HBoxContainer.new()
	info_hbox.add_theme_constant_override("separation", 30)
	parent.add_child(info_hbox)
	
	# Niveau et XP
	var level_vbox = VBoxContainer.new()
	info_hbox.add_child(level_vbox)
	
	guild_level_label = Label.new()
	guild_level_label.text = "Niveau 1"
	guild_level_label.add_theme_font_size_override("font_size", 16)
	level_vbox.add_child(guild_level_label)
	
	guild_xp_label = Label.new()
	guild_xp_label.text = "XP: 0 / 200"
	guild_xp_label.modulate = Color(0.8, 0.8, 0.8)
	level_vbox.add_child(guild_xp_label)
	
	# Membres
	guild_members_label = Label.new()
	guild_members_label.text = "Membres: 0 / 5"
	guild_members_label.add_theme_font_size_override("font_size", 14)
	info_hbox.add_child(guild_members_label)
	
	# Perks actifs
	var perks_vbox = VBoxContainer.new()
	info_hbox.add_child(perks_vbox)
	
	var perks_title = Label.new()
	perks_title.text = "Perks actifs:"
	perks_title.add_theme_font_size_override("font_size", 12)
	perks_vbox.add_child(perks_title)
	
	guild_perks_label = Label.new()
	guild_perks_label.text = "Aucun"
	guild_perks_label.modulate = Color(0.7, 0.7, 0.7)
	guild_perks_label.add_theme_font_size_override("font_size", 11)
	perks_vbox.add_child(guild_perks_label)
	
	_update_guild_info()

func _update_guild_info():
	if not guild_manager or not guild_manager.guild:
		return
		
	var guild = guild_manager.guild
	var level = guild.get_level()
	var xp_progress = guild.get_xp_progress()
	
	guild_level_label.text = "Niveau %d" % level
	guild_xp_label.text = "XP: %d / %d" % [xp_progress.progress, xp_progress.needed + xp_progress.progress]
	
	var max_members = guild.get_max_members()
	guild_members_label.text = "Membres: %d / %d" % [guild_members.size(), max_members]
	
	# Mise à jour des perks
	var perks = guild.get_active_perks()
	if perks.is_empty():
		guild_perks_label.text = "Aucun"
	else:
		var perk_names = []
		for perk in perks:
			perk_names.append(perk.name)
		guild_perks_label.text = ", ".join(perk_names)

func _on_guild_level_changed(_new_level: int):
	_update_guild_info()
	
func _on_guild_perk_unlocked(_perk_name: String, _level: int):
	_update_guild_info()
	# On pourrait afficher une notification ici

func _setup_context_menu():
	# Créer le menu contextuel
	context_menu = PopupMenu.new()
	add_child(context_menu)
	
	# Ajouter les options du menu
	context_menu.add_item("Voir l'équipement", 0)
	context_menu.add_separator()
	context_menu.add_item("Promouvoir", 1)  
	context_menu.add_item("Exclure de la guilde", 2)
	
	# Griser les options non implémentées pour l'instant
	context_menu.set_item_disabled(1, true)
	# Activer l'exclusion maintenant qu'on a ConfirmDialog
	context_menu.set_item_disabled(2, false)
	
	# Connecter le signal de sélection
	context_menu.id_pressed.connect(_on_context_menu_pressed)

func _on_context_menu_pressed(id: int):
	if right_clicked_member_index < 0 or right_clicked_member_index >= guild_members.size():
		return
		
	var member = guild_members[right_clicked_member_index]
	
	match id:
		0: # Voir l'équipement
			_show_equipment_window(member)
		1: # Promouvoir (pas encore implémenté)
			print("Promouvoir %s (pas encore implémenté)" % member.nom)
		2: # Exclure de la guilde
			_confirm_kick_member(member)

func _confirm_kick_member(member):
	"""Affiche une confirmation avant d'exclure un membre"""
	var dialog = load("res://scripts/ui/components/confirm_dialog.gd").new()
	dialog.dialog_type = dialog.DialogType.DESTRUCTIVE
	dialog.title_text = "Exclure un membre"
	dialog.message_text = "Êtes-vous sûr de vouloir exclure %s de la guilde?\nCette action est irréversible." % member.nom
	dialog.confirm_text = "Exclure"
	dialog.confirmed.connect(func(): _kick_member(member))
	get_tree().root.add_child(dialog)
	dialog.show_dialog()

func _kick_member(member):
	"""Exclut un membre de la guilde"""
	if guild_manager:
		guild_manager.remove_member(member)
		_refresh_member_list()
		_update_guild_info()
		
		# Notification
		var notification_manager = NotificationManager
		if notification_manager:
			notification_manager.show_warning(
				"%s a été exclu de la guilde." % member.nom,
				"Membre exclu"
			)

func _show_equipment_window(member):
	# Nettoyer l'ancienne instance si elle existe
	if equipment_window_instance:
		equipment_window_instance.queue_free()
		equipment_window_instance = null
	
	# Créer nouvelle instance de la fenêtre d'équipement
	equipment_window_instance = EquipmentWindow.instantiate()
	get_tree().current_scene.add_child(equipment_window_instance)
	
	# Afficher l'équipement du membre
	equipment_window_instance.show_member_equipment(member)

func _on_members_list_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Trouver l'index de l'item sous la souris
			var item_index = members_list.get_item_at_position(event.position, true)
			if item_index >= 0 and item_index < guild_members.size():
				right_clicked_member_index = item_index
				
				# Sélectionner l'item aussi
				members_list.select(item_index)
				_on_member_selected(item_index)
				
				# Afficher le menu contextuel à la position du clic
				var menu_position: Vector2 = members_list.global_position + event.position
				context_menu.position = Vector2i(menu_position)
				context_menu.popup()
