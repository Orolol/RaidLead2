extends Control
class_name AdvancedTabs

# Système d'onglets avancé avec support pour fermeture, badges, drag & drop et overflow
# Extension du système TabContainer de Godot avec fonctionnalités modernes

# Configuration
@export var closable_tabs: bool = true : set = set_closable_tabs
@export var draggable_tabs: bool = true : set = set_draggable_tabs  
@export var show_overflow_menu: bool = true : set = set_show_overflow_menu
@export var max_visible_tabs: int = 8 : set = set_max_visible_tabs
@export var tab_min_width: int = 100 : set = set_tab_min_width
@export var tab_max_width: int = 200 : set = set_tab_max_width
@export var show_badges: bool = true : set = set_show_badges

# Style
@export var tab_height: int = 32
@export var tab_spacing: int = 2
@export var close_button_size: int = 16
@export var badge_offset: Vector2 = Vector2(5, -5)

# Éléments UI
var tab_bar: HBoxContainer
var tab_content: Control
var overflow_button: MenuButton
var active_tab_index: int = -1

# Données des onglets
var tabs_data: Array[Dictionary] = []  # {title, content, closable, badge_count, icon, etc.}
var overflow_tabs: Array[int] = []  # Index des onglets en overflow

# État du drag
var dragging_tab: int = -1
var drag_preview: Control = null

# Signaux
signal tab_selected(index: int)
signal tab_closed(index: int, tab_data: Dictionary)
signal tab_moved(from_index: int, to_index: int)
signal tab_added(index: int, tab_data: Dictionary)
signal tab_context_menu(index: int, position: Vector2)

func _ready():
	_setup_ui()
	_setup_interactions()

func _setup_ui():
	"""Configure la structure UI"""
	
	# Container principal
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	add_child(main_vbox)
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Barre d'onglets
	var tab_bar_container = PanelContainer.new()
	tab_bar_container.custom_minimum_size = Vector2(0, tab_height)
	main_vbox.add_child(tab_bar_container)
	
	# Style de la barre d'onglets
	var tab_bar_style = StyleBoxFlat.new()
	tab_bar_style.bg_color = Color(0.2, 0.2, 0.25)
	tab_bar_style.border_width_bottom = 1
	tab_bar_style.border_color = Color(0.4, 0.4, 0.4)
	tab_bar_container.add_theme_stylebox_override("panel", tab_bar_style)
	
	var tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 0)
	tab_bar_container.add_child(tab_row)
	
	tab_bar = HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", tab_spacing)
	tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_row.add_child(tab_bar)
	
	# Bouton overflow
	if show_overflow_menu:
		overflow_button = MenuButton.new()
		overflow_button.text = "⋯"
		overflow_button.custom_minimum_size = Vector2(tab_height, tab_height)
		overflow_button.flat = false
		overflow_button.visible = false
		tab_row.add_child(overflow_button)
		
		var popup = overflow_button.get_popup()
		popup.id_pressed.connect(_on_overflow_item_selected)
	
	# Zone de contenu
	tab_content = Control.new()
	tab_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(tab_content)

func _setup_interactions():
	"""Configure les interactions"""
	set_process_unhandled_input(true)

# ==================== SETTERS ====================

func set_closable_tabs(closable: bool):
	closable_tabs = closable
	_update_all_tabs()

func set_draggable_tabs(draggable: bool):
	draggable_tabs = draggable
	_update_all_tabs()

func set_show_overflow_menu(show: bool):
	show_overflow_menu = show
	if overflow_button:
		overflow_button.visible = show and overflow_tabs.size() > 0

func set_max_visible_tabs(max_tabs: int):
	max_visible_tabs = max(1, max_tabs)
	_update_tab_visibility()

func set_tab_min_width(width: int):
	tab_min_width = max(50, width)
	_update_all_tabs()

func set_tab_max_width(width: int):
	tab_max_width = max(tab_min_width, width)
	_update_all_tabs()

func set_show_badges(show: bool):
	show_badges = show
	_update_all_tabs()

# ==================== GESTION DES ONGLETS ====================

func add_tab(title: String, content: Control, closable: bool = true, icon: Texture2D = null, badge_count: int = 0) -> int:
	"""Ajoute un nouvel onglet"""
	
	var tab_data = {
		"title": title,
		"content": content,
		"closable": closable and closable_tabs,
		"icon": icon,
		"badge_count": badge_count,
		"id": _generate_tab_id()
	}
	
	var index = tabs_data.size()
	tabs_data.append(tab_data)
	
	# Créer l'onglet visuel
	_create_tab_element(index)
	
	# Ajouter le contenu (caché par défaut)
	tab_content.add_child(content)
	content.visible = false
	
	# Sélectionner le premier onglet
	if tabs_data.size() == 1:
		select_tab(0)
	
	# Mettre à jour la visibilité
	_update_tab_visibility()
	
	tab_added.emit(index, tab_data)
	return index

func remove_tab(index: int) -> bool:
	"""Supprime un onglet"""
	if index < 0 or index >= tabs_data.size():
		return false
	
	var tab_data = tabs_data[index]
	
	# Supprimer le contenu
	if tab_data.content and is_instance_valid(tab_data.content):
		tab_content.remove_child(tab_data.content)
		tab_data.content.queue_free()
	
	# Supprimer l'élément visuel
	var tab_element = tab_bar.get_child(index)
	if tab_element:
		tab_bar.remove_child(tab_element)
		tab_element.queue_free()
	
	# Supprimer des données
	tabs_data.remove_at(index)
	
	# Ajuster l'index actif
	if active_tab_index == index:
		if tabs_data.size() > 0:
			var new_index = min(index, tabs_data.size() - 1)
			select_tab(new_index)
		else:
			active_tab_index = -1
	elif active_tab_index > index:
		active_tab_index -= 1
	
	# Mettre à jour la visibilité
	_update_tab_visibility()
	
	tab_closed.emit(index, tab_data)
	return true

func select_tab(index: int) -> bool:
	"""Sélectionne un onglet"""
	if index < 0 or index >= tabs_data.size():
		return false
	
	# Masquer l'onglet actuel
	if active_tab_index >= 0 and active_tab_index < tabs_data.size():
		var current_content = tabs_data[active_tab_index].content
		if current_content:
			current_content.visible = false
		
		# Désactiver l'onglet visuel
		var current_tab = tab_bar.get_child(active_tab_index)
		if current_tab:
			_set_tab_active(current_tab, false)
	
	# Activer le nouvel onglet
	active_tab_index = index
	var new_content = tabs_data[index].content
	if new_content:
		new_content.visible = true
	
	# Activer l'onglet visuel
	var new_tab = tab_bar.get_child(index)
	if new_tab:
		_set_tab_active(new_tab, true)
	
	tab_selected.emit(index)
	return true

func get_tab_count() -> int:
	"""Retourne le nombre d'onglets"""
	return tabs_data.size()

func get_current_tab_index() -> int:
	"""Retourne l'index de l'onglet actif"""
	return active_tab_index

func get_tab_data(index: int) -> Dictionary:
	"""Retourne les données d'un onglet"""
	if index >= 0 and index < tabs_data.size():
		return tabs_data[index]
	return {}

func set_tab_title(index: int, title: String):
	"""Change le titre d'un onglet"""
	if index >= 0 and index < tabs_data.size():
		tabs_data[index].title = title
		_update_tab_element(index)

func set_tab_badge(index: int, count: int):
	"""Définit le badge d'un onglet"""
	if index >= 0 and index < tabs_data.size():
		tabs_data[index].badge_count = count
		_update_tab_element(index)

func set_tab_icon(index: int, icon: Texture2D):
	"""Définit l'icône d'un onglet"""
	if index >= 0 and index < tabs_data.size():
		tabs_data[index].icon = icon
		_update_tab_element(index)

# ==================== CRÉATION DES ÉLÉMENTS VISUELS ====================

func _create_tab_element(index: int):
	"""Crée l'élément visuel d'un onglet"""
	var tab_data = tabs_data[index]
	
	# Container principal de l'onglet
	var tab_element = PanelContainer.new()
	tab_element.custom_minimum_size = Vector2(tab_min_width, tab_height)
	tab_bar.add_child(tab_element)
	
	# Style de l'onglet inactif
	_set_tab_active(tab_element, false)
	
	# Container horizontal pour le contenu
	var tab_content_container = HBoxContainer.new()
	tab_content_container.add_theme_constant_override("separation", 4)
	tab_element.add_child(tab_content_container)
	
	# Icône (optionnelle)
	if tab_data.icon:
		var icon_rect = TextureRect.new()
		icon_rect.texture = tab_data.icon
		icon_rect.custom_minimum_size = Vector2(16, 16)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tab_content_container.add_child(icon_rect)
	
	# Titre
	var title_label = Label.new()
	title_label.text = tab_data.title
	title_label.add_theme_font_size_override("font_size", 12)
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_contents = true
	tab_content_container.add_child(title_label)
	
	# Badge (optionnel)
	if show_badges and tab_data.badge_count > 0:
		var badge_label = Label.new()
		badge_label.text = str(tab_data.badge_count)
		badge_label.add_theme_font_size_override("font_size", 10)
		badge_label.add_theme_color_override("font_color", Color.WHITE)
		badge_label.custom_minimum_size = Vector2(16, 16)
		badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		# Style du badge
		var badge_style = StyleBoxFlat.new()
		badge_style.bg_color = Color.RED
		badge_style.corner_radius_top_left = 8
		badge_style.corner_radius_top_right = 8
		badge_style.corner_radius_bottom_left = 8
		badge_style.corner_radius_bottom_right = 8
		badge_label.add_theme_stylebox_override("normal", badge_style)
		tab_content_container.add_child(badge_label)
	
	# Bouton fermer (optionnel)
	if tab_data.closable:
		var close_button = Button.new()
		close_button.text = "×"
		close_button.custom_minimum_size = Vector2(close_button_size, close_button_size)
		close_button.add_theme_font_size_override("font_size", 12)
		close_button.flat = true
		close_button.pressed.connect(func(): _on_close_tab(index))
		tab_content_container.add_child(close_button)
	
	# Interactions
	tab_element.gui_input.connect(func(event): _on_tab_input(event, index))
	
	# Drag & Drop
	if draggable_tabs:
		var draggable = DraggableItem.new()
		draggable.setup_for_tab({"index": index, "title": tab_data.title})
		# Enrober l'onglet dans le DraggableItem
		tab_bar.remove_child(tab_element)
		tab_bar.add_child(draggable)
		draggable.add_child(tab_element)

func _update_tab_element(index: int):
	"""Met à jour l'élément visuel d'un onglet"""
	if index < 0 or index >= tab_bar.get_child_count():
		return
	
	var tab_element = tab_bar.get_child(index)
	var tab_data = tabs_data[index]
	
	# Trouver le label de titre et le mettre à jour
	var title_label = _find_tab_title_label(tab_element)
	if title_label:
		title_label.text = tab_data.title
	
	# Mettre à jour le badge
	var badge = _find_tab_badge(tab_element)
	if badge:
		if tab_data.badge_count > 0:
			badge.text = str(tab_data.badge_count)
			badge.visible = true
		else:
			badge.visible = false

func _update_all_tabs():
	"""Met à jour tous les onglets"""
	for i in range(tabs_data.size()):
		_update_tab_element(i)

func _set_tab_active(tab_element: Control, active: bool):
	"""Change l'apparence d'un onglet selon son état"""
	var style = StyleBoxFlat.new()
	
	if active:
		style.bg_color = Color(0.3, 0.35, 0.4)
		style.border_width_bottom = 2
		style.border_color = Color(0.4, 0.7, 1.0)
	else:
		style.bg_color = Color(0.25, 0.25, 0.3)
		style.border_width_bottom = 1
		style.border_color = Color(0.4, 0.4, 0.4)
	
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	
	tab_element.add_theme_stylebox_override("panel", style)

# ==================== GESTION DE LA VISIBILITÉ ====================

func _update_tab_visibility():
	"""Met à jour la visibilité des onglets (overflow)"""
	overflow_tabs.clear()
	
	if tabs_data.size() <= max_visible_tabs:
		# Tous les onglets sont visibles
		for i in range(tab_bar.get_child_count()):
			var tab = tab_bar.get_child(i)
			tab.visible = true
		
		if overflow_button:
			overflow_button.visible = false
	else:
		# Certains onglets en overflow
		for i in range(tab_bar.get_child_count()):
			var tab = tab_bar.get_child(i)
			if i < max_visible_tabs:
				tab.visible = true
			else:
				tab.visible = false
				overflow_tabs.append(i)
		
		if overflow_button:
			overflow_button.visible = true
			_update_overflow_menu()

func _update_overflow_menu():
	"""Met à jour le menu overflow"""
	if not overflow_button:
		return
	
	var popup = overflow_button.get_popup()
	popup.clear()
	
	for tab_index in overflow_tabs:
		if tab_index < tabs_data.size():
			var tab_data = tabs_data[tab_index]
			popup.add_item(tab_data.title, tab_index)

# ==================== ÉVÉNEMENTS ====================

func _on_tab_input(event: InputEvent, index: int):
	"""Gère les événements sur un onglet"""
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				select_tab(index)
			MOUSE_BUTTON_RIGHT:
				tab_context_menu.emit(index, event.global_position)
			MOUSE_BUTTON_MIDDLE:
				if tabs_data[index].closable:
					_on_close_tab(index)

func _on_close_tab(index: int):
	"""Ferme un onglet"""
	if index >= 0 and index < tabs_data.size():
		if tabs_data[index].closable:
			remove_tab(index)

func _on_overflow_item_selected(id: int):
	"""Onglet sélectionné depuis le menu overflow"""
	select_tab(id)
	
	# Optionnel: déplacer l'onglet en zone visible
	if id in overflow_tabs:
		move_tab(id, max_visible_tabs - 1)

# ==================== DRAG & DROP ====================

func move_tab(from_index: int, to_index: int) -> bool:
	"""Déplace un onglet"""
	if from_index == to_index or from_index < 0 or from_index >= tabs_data.size():
		return false
	
	to_index = clamp(to_index, 0, tabs_data.size() - 1)
	
	# Déplacer dans les données
	var tab_data = tabs_data[from_index]
	tabs_data.remove_at(from_index)
	tabs_data.insert(to_index, tab_data)
	
	# Déplacer dans l'UI
	var tab_element = tab_bar.get_child(from_index)
	tab_bar.move_child(tab_element, to_index)
	
	# Ajuster l'index actif
	if active_tab_index == from_index:
		active_tab_index = to_index
	elif active_tab_index > from_index and active_tab_index <= to_index:
		active_tab_index -= 1
	elif active_tab_index < from_index and active_tab_index >= to_index:
		active_tab_index += 1
	
	tab_moved.emit(from_index, to_index)
	return true

# ==================== UTILITAIRES ====================

func _find_tab_title_label(tab_element: Control) -> Label:
	"""Trouve le label de titre dans un onglet"""
	for child in tab_element.get_children():
		if child is HBoxContainer:
			for subchild in child.get_children():
				if subchild is Label:
					return subchild
	return null

func _find_tab_badge(tab_element: Control) -> Label:
	"""Trouve le badge dans un onglet"""
	for child in tab_element.get_children():
		if child is HBoxContainer:
			for subchild in child.get_children():
				if subchild is Label and subchild.custom_minimum_size == Vector2(16, 16):
					return subchild
	return null

func _generate_tab_id() -> String:
	"""Génère un ID unique pour un onglet"""
	return "tab_" + str(Time.get_ticks_msec()) + "_" + str(randi())

# ==================== API PUBLIQUE ÉTENDUE ====================

func find_tab_by_title(title: String) -> int:
	"""Trouve un onglet par son titre"""
	for i in range(tabs_data.size()):
		if tabs_data[i].title == title:
			return i
	return -1

func find_tab_by_content(content: Control) -> int:
	"""Trouve un onglet par son contenu"""
	for i in range(tabs_data.size()):
		if tabs_data[i].content == content:
			return i
	return -1

func get_tab_titles() -> Array[String]:
	"""Retourne tous les titres d'onglets"""
	var titles: Array[String] = []
	for tab_data in tabs_data:
		titles.append(tab_data.title)
	return titles

func close_all_tabs():
	"""Ferme tous les onglets"""
	while tabs_data.size() > 0:
		remove_tab(tabs_data.size() - 1)

func close_other_tabs(keep_index: int):
	"""Ferme tous les onglets sauf celui spécifié"""
	for i in range(tabs_data.size() - 1, -1, -1):
		if i != keep_index and tabs_data[i].closable:
			remove_tab(i)

# ==================== MÉTHODES STATIQUES ====================

static func create_simple_tabs(parent: Node) -> AdvancedTabs:
	"""Crée un système d'onglets simple"""
	var tabs = AdvancedTabs.new()
	tabs.closable_tabs = false
	tabs.draggable_tabs = false
	tabs.show_overflow_menu = true
	parent.add_child(tabs)
	return tabs

static func create_closable_tabs(parent: Node) -> AdvancedTabs:
	"""Crée un système d'onglets avec fermeture"""
	var tabs = AdvancedTabs.new()
	tabs.closable_tabs = true
	tabs.draggable_tabs = true
	tabs.show_badges = true
	parent.add_child(tabs)
	return tabs