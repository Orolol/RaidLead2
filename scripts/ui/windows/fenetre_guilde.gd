extends PanelContainer

const PlayerTagsData = preload("res://scripts/data/player_tags.gd")

var members_list: ItemList
var member_details: VBoxContainer
var close_button: Button
var title_label: Label
var title_bar: Panel

var guild_members: Array = []
var selected_member = null
var guild_manager: Node

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
	
	guild_manager = get_node("/root/GuildManager")
	if guild_manager:
		guild_manager.member_activity_changed.connect(_on_member_activity_changed)
		guild_manager.member_connected.connect(_on_member_status_changed)
		guild_manager.member_disconnected.connect(_on_member_status_changed)
	
	hide()
	_load_test_members()

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
	var hsplit = HSplitContainer.new()
	hsplit.split_offset = 300
	parent.add_child(hsplit)
	
	var left_panel = PanelContainer.new()
	hsplit.add_child(left_panel)
	
	var left_vbox = VBoxContainer.new()
	left_panel.add_child(left_vbox)
	
	var list_label = Label.new()
	list_label.text = "Membres de la Guilde"
	list_label.add_theme_font_size_override("font_size", 16)
	left_vbox.add_child(list_label)
	
	members_list = ItemList.new()
	members_list.custom_minimum_size = Vector2(300, 500)
	members_list.item_selected.connect(_on_member_selected)
	left_vbox.add_child(members_list)
	
	var right_panel = PanelContainer.new()
	hsplit.add_child(right_panel)
	
	var scroll_container = ScrollContainer.new()
	scroll_container.custom_minimum_size = Vector2(600, 500)
	right_panel.add_child(scroll_container)
	
	member_details = VBoxContainer.new()
	member_details.add_theme_constant_override("separation", 8)
	member_details.custom_minimum_size = Vector2(580, 0)  # Largeur fixe pour éviter le redimensionnement
	scroll_container.add_child(member_details)
	
	_setup_member_details()

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
	for i in 5:
		var member = SimulatedPlayer.new()
		guild_members.append(member)
		if guild_manager:
			guild_manager.add_member(member)
	
	_refresh_member_list()

func _refresh_member_list():
	members_list.clear()
	for member in guild_members:
		var status = "[Hors ligne]"
		if member.is_online:
			status = "[En ligne]"
			if member.current_activity:
				status = "[%s]" % member.current_activity.get_type_string()
		
		var text = "%s %s - %s Niv.%d" % [member.nom, status, member.personnage_classe, member.personnage_niveau]
		members_list.add_item(text)

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
	
	var details_label = Label.new()
	details_label.text = "Détails de " + selected_member.nom
	details_label.add_theme_font_size_override("font_size", 18)
	member_details.add_child(details_label)
	
	member_details.add_child(HSeparator.new())
	
	var info_grid = GridContainer.new()
	info_grid.columns = 2
	info_grid.add_theme_constant_override("h_separation", 20)
	info_grid.add_theme_constant_override("v_separation", 10)
	member_details.add_child(info_grid)
	
	_add_detail_row(info_grid, "Classe:", selected_member.personnage_classe)
	_add_detail_row(info_grid, "Niveau:", str(selected_member.personnage_niveau))
	_add_detail_row(info_grid, "Équipement:", str(selected_member.personnage_equipement))
	_add_detail_row(info_grid, "Rôle:", selected_member.get_role())
	
	member_details.add_child(HSeparator.new())
	
	_add_detail_row(info_grid, "Énergie:", "%.0f/100" % selected_member.energy)
	_add_detail_row(info_grid, "Humeur:", "%.0f/100" % selected_member.mood)
	_add_detail_row(info_grid, "Intégration:", "%.0f%%" % selected_member.integration)
	_add_detail_row(info_grid, "Skill:", "%d/100" % selected_member.skill)
	
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
	hide()

func add_member(player):
	guild_members.append(player)
	if guild_manager:
		guild_manager.add_member(player)
	_refresh_member_list()

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