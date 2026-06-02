extends Control
class_name DropZone

# Zone réceptrice pour les éléments DraggableItem avec validation et feedback visuel
# Utilisée pour créer des slots d'équipement, zones de groupes, etc.

# Configuration
@export var accepted_types: Array[String] = ["default"] : set = set_accepted_types
@export var max_items: int = 1 : set = set_max_items
@export var allow_reorder: bool = false : set = set_allow_reorder
@export var auto_sort: bool = false
@export var drop_policy: DropPolicy = DropPolicy.REPLACE : set = set_drop_policy

# Feedback visuel
@export var highlight_color: Color = Color(0.4, 0.8, 0.4, 0.3)
@export var invalid_color: Color = Color(0.8, 0.3, 0.3, 0.3)
@export var border_width: int = 2
@export var highlight_animation: bool = true
@export var show_drop_indicator: bool = true

# Validation personnalisée
@export var validation_callback: Callable  # Fonction de validation externe

# Policies de drop
enum DropPolicy {
	REPLACE,    # Remplace l'item existant
	STACK,      # Empile les items (si max_items > 1)
	REJECT,     # Rejette si déjà occupé
	SWAP        # Échange avec l'item existant
}

# État interne
var stored_items: Array[DraggableItem] = []
var is_highlighted: bool = false
var is_invalid_hover: bool = false
var current_hovering_item: DraggableItem = null
var drop_indicator: Control = null
var original_style: StyleBoxFlat = null

# Éléments visuels
var background_panel: PanelContainer
var content_container: Container
var placeholder_label: Label

# Signaux
signal item_dropped(item: DraggableItem, zone: DropZone)
signal item_removed(item: DraggableItem, zone: DropZone)
signal hover_started(item: DraggableItem, zone: DropZone)
signal hover_ended(item: DraggableItem, zone: DropZone)
signal validation_failed(item: DraggableItem, zone: DropZone, reason: String)

func _ready() -> void:
	_setup_ui()
	_setup_drop_detection()

func _setup_ui() -> void:
	"""Configure l'interface visuelle de la drop zone"""
	
	# Panel de fond
	background_panel = PanelContainer.new()
	add_child(background_panel)
	background_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Style par défaut
	original_style = StyleBoxFlat.new()
	original_style.bg_color = Color(0.2, 0.2, 0.2, 0.5)
	original_style.border_color = Color(0.4, 0.4, 0.4, 0.8)
	original_style.border_width_left = 1
	original_style.border_width_right = 1
	original_style.border_width_top = 1
	original_style.border_width_bottom = 1
	original_style.corner_radius_top_left = 4
	original_style.corner_radius_top_right = 4
	original_style.corner_radius_bottom_left = 4
	original_style.corner_radius_bottom_right = 4
	
	background_panel.add_theme_stylebox_override("panel", original_style)
	
	# Container pour le contenu
	content_container = VBoxContainer.new()
	background_panel.add_child(content_container)
	
	# Label de placeholder
	placeholder_label = Label.new()
	placeholder_label.text = "Drop here"
	placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placeholder_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	content_container.add_child(placeholder_label)
	
	_update_placeholder_visibility()

func _setup_drop_detection() -> void:
	"""Configure la détection des drops"""
	mouse_filter = Control.MOUSE_FILTER_PASS

# ==================== SETTERS ====================

func set_accepted_types(types: Array[String]) -> void:
	accepted_types = types

func set_max_items(max_count: int) -> void:
	max_items = max(1, max_count)
	_validate_current_items()

func set_allow_reorder(allow: bool) -> void:
	allow_reorder = allow

func set_drop_policy(policy: DropPolicy) -> void:
	drop_policy = policy

# ==================== API PUBLIQUE - VALIDATION ====================

func can_accept_drop(item: DraggableItem, data: Dictionary = {}) -> bool:
	"""Vérifie si la zone peut accepter un drop"""
	
	# Vérifier les types acceptés
	if not _check_accepted_types(item):
		return false
	
	# Vérifier la limite d'items
	if not _check_item_limit(item):
		return false
	
	# Validation personnalisée
	if validation_callback.is_valid():
		if not validation_callback.call(item, data, self):
			return false
	
	return true

func accept_drop(item: DraggableItem, data: Dictionary = {}) -> bool:
	"""Accepte un drop si valide"""
	
	if not can_accept_drop(item, data):
		validation_failed.emit(item, self, "Drop validation failed")
		return false
	
	# Traiter selon la policy
	match drop_policy:
		DropPolicy.REPLACE:
			_handle_replace_drop(item)
		DropPolicy.STACK:
			_handle_stack_drop(item)
		DropPolicy.REJECT:
			if stored_items.size() >= max_items:
				validation_failed.emit(item, self, "Zone already occupied")
				return false
			_handle_stack_drop(item)
		DropPolicy.SWAP:
			_handle_swap_drop(item)
	
	item_dropped.emit(item, self)
	return true

# ==================== GESTION DES DROPS ====================

func _handle_replace_drop(item: DraggableItem) -> void:
	"""Gère le drop en mode REPLACE"""
	# Retirer les items existants
	for existing_item in stored_items.duplicate():
		remove_item(existing_item)

	# Ajouter le nouvel item
	add_item(item)

func _handle_stack_drop(item: DraggableItem) -> void:
	"""Gère le drop en mode STACK"""
	if stored_items.size() < max_items:
		add_item(item)

func _handle_swap_drop(item: DraggableItem) -> void:
	"""Gère le drop en mode SWAP"""
	if stored_items.size() > 0:
		var existing_item: DraggableItem = stored_items[0]
		var source_zone = item.get_parent()

		# Échanger les positions
		remove_item(existing_item)
		add_item(item)

		if source_zone and source_zone.has_method("add_item"):
			source_zone.add_item(existing_item)
	else:
		add_item(item)

# ==================== GESTION DES ITEMS ====================

func add_item(item: DraggableItem) -> bool:
	"""Ajoute un item à la zone"""
	if stored_items.size() >= max_items:
		return false
	
	# Retirer de l'ancienne zone
	var old_parent = item.get_parent()
	if old_parent and old_parent.has_method("remove_item"):
		old_parent.remove_item(item)
	
	# Ajouter à cette zone
	stored_items.append(item)
	content_container.add_child(item)
	
	# Repositionner
	_arrange_items()
	_update_placeholder_visibility()
	
	return true

func remove_item(item: DraggableItem) -> bool:
	"""Retire un item de la zone"""
	if item not in stored_items:
		return false
	
	stored_items.erase(item)
	
	if item.get_parent() == content_container:
		content_container.remove_child(item)
	
	_arrange_items()
	_update_placeholder_visibility()
	
	item_removed.emit(item, self)
	return true

func clear_items() -> void:
	"""Vide la zone de tous ses items"""
	for item in stored_items.duplicate():
		remove_item(item)

func get_items() -> Array[DraggableItem]:
	"""Retourne tous les items dans la zone"""
	return stored_items.duplicate()

func get_item_count() -> int:
	"""Retourne le nombre d'items dans la zone"""
	return stored_items.size()

func is_empty() -> bool:
	"""Vérifie si la zone est vide"""
	return stored_items.is_empty()

func is_full() -> bool:
	"""Vérifie si la zone est pleine"""
	return stored_items.size() >= max_items

# ==================== FEEDBACK VISUEL ====================

func on_drag_hover_enter(item: DraggableItem, data: Dictionary = {}) -> void:
	"""Appelé quand un item entre dans la zone"""
	current_hovering_item = item

	if can_accept_drop(item, data):
		_show_valid_highlight()
	else:
		_show_invalid_highlight()

	hover_started.emit(item, self)

func on_drag_hover_exit(item: DraggableItem, _data: Dictionary = {}) -> void:
	"""Appelé quand un item quitte la zone"""
	current_hovering_item = null
	_hide_highlight()
	hover_ended.emit(item, self)

func _show_valid_highlight() -> void:
	"""Affiche le highlight pour un drop valide"""
	if not highlight_animation:
		_apply_highlight_style(highlight_color)
		return

	var style: StyleBoxFlat = original_style.duplicate()
	style.bg_color = highlight_color
	style.border_color = highlight_color.lightened(0.3)
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width

	background_panel.add_theme_stylebox_override("panel", style)

	# Animation de pulsation
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(background_panel, "modulate:a", 0.7, 0.5)
	tween.tween_property(background_panel, "modulate:a", 1.0, 0.5)

	is_highlighted = true

func _show_invalid_highlight() -> void:
	"""Affiche le highlight pour un drop invalide"""
	_apply_highlight_style(invalid_color)
	is_invalid_hover = true

func _hide_highlight() -> void:
	"""Cache le highlight"""
	background_panel.add_theme_stylebox_override("panel", original_style)
	background_panel.modulate.a = 1.0
	
	# Arrêter l'animation (Godot 4 compatible)
	# Note: En Godot 4, nous n'avons pas besoin d'arrêter les tweens explicitement
	
	is_highlighted = false
	is_invalid_hover = false

func _apply_highlight_style(color: Color) -> void:
	"""Applique un style de highlight"""
	var style: StyleBoxFlat = original_style.duplicate()
	style.bg_color = color
	style.border_color = color.lightened(0.3)
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width

	background_panel.add_theme_stylebox_override("panel", style)

# ==================== VALIDATION ====================

func _check_accepted_types(item: DraggableItem) -> bool:
	"""Vérifie si les types sont acceptés"""
	if accepted_types.is_empty():
		return true
	
	for item_type in item.drag_types:
		if item_type in accepted_types:
			return true
	
	return false

func _check_item_limit(item: DraggableItem) -> bool:
	"""Vérifie la limite d'items"""
	match drop_policy:
		DropPolicy.REPLACE, DropPolicy.SWAP:
			return true
		DropPolicy.STACK:
			return stored_items.size() < max_items
		DropPolicy.REJECT:
			return stored_items.size() < max_items
	
	return false

func _validate_current_items() -> void:
	"""Valide les items actuels après changement de configuration"""
	while stored_items.size() > max_items:
		var item: DraggableItem = stored_items.pop_back()
		content_container.remove_child(item)

# ==================== ARRANGEMENT ====================

func _arrange_items() -> void:
	"""Arrange les items dans la zone"""
	if auto_sort:
		_sort_items()

	# Ajuster la taille si nécessaire
	_resize_to_fit_items()

func _sort_items() -> void:
	"""Trie les items selon un critère"""
	stored_items.sort_custom(func(a: DraggableItem, b: DraggableItem):
		# Exemple : tri par nom
		var name_a = a.drag_data.get("name", "")
		var name_b = b.drag_data.get("name", "")
		return name_a < name_b
	)

	# Réorganiser dans l'UI
	for i in range(stored_items.size()):
		content_container.move_child(stored_items[i], i)

func _resize_to_fit_items() -> void:
	"""Ajuste la taille pour contenir les items"""
	# Implémentation basique - peut être étendue
	pass

func _update_placeholder_visibility() -> void:
	"""Met à jour la visibilité du placeholder"""
	placeholder_label.visible = stored_items.is_empty()

# ==================== API UTILITAIRES ====================

func set_placeholder_text(text: String) -> void:
	"""Définit le texte du placeholder"""
	if placeholder_label:
		placeholder_label.text = text

func set_validation_callback(callback: Callable) -> void:
	"""Définit une fonction de validation personnalisée"""
	validation_callback = callback

func add_accepted_type(type: String) -> void:
	"""Ajoute un type accepté"""
	if type not in accepted_types:
		accepted_types.append(type)

func remove_accepted_type(type: String) -> void:
	"""Supprime un type accepté"""
	accepted_types.erase(type)

func has_item_with_data(key: String, value) -> bool:
	"""Vérifie si un item avec des données spécifiques existe"""
	for item in stored_items:
		if item.drag_data.has(key) and item.drag_data[key] == value:
			return true
	return false

func get_item_with_data(key: String, value) -> DraggableItem:
	"""Trouve un item avec des données spécifiques"""
	for item in stored_items:
		if item.drag_data.has(key) and item.drag_data[key] == value:
			return item
	return null

# ==================== CONFIGURATIONS PRÉDÉFINIES ====================

func setup_for_equipment_slot(slot_type: String) -> void:
	"""Configuration pour un slot d'équipement"""
	accepted_types = ["equipment", "item"]
	max_items = 1
	drop_policy = DropPolicy.REPLACE
	set_placeholder_text(slot_type.capitalize())

	# Validation spécifique à l'équipement
	validation_callback = func(item: DraggableItem, data: Dictionary, zone: DropZone) -> bool:
		return data.get("slot_type", "") == slot_type

func setup_for_group_member_slot(max_members: int = 5) -> void:
	"""Configuration pour les slots de membres de groupe"""
	accepted_types = ["member", "player"]
	max_items = max_members
	drop_policy = DropPolicy.STACK
	allow_reorder = true
	set_placeholder_text("Drop members here")

func setup_for_inventory_slot() -> void:
	"""Configuration pour un slot d'inventaire"""
	accepted_types = ["item", "equipment", "consumable"]
	max_items = 1
	drop_policy = DropPolicy.SWAP
	set_placeholder_text("Empty")

func setup_for_tab_container() -> void:
	"""Configuration pour réorganiser les onglets"""
	accepted_types = ["tab"]
	max_items = -1  # Illimité
	drop_policy = DropPolicy.STACK
	allow_reorder = true
	set_placeholder_text("Tabs area")

# ==================== MÉTHODES STATIQUES ====================

static func create_equipment_slot(slot_type: String, parent: Node) -> DropZone:
	"""Crée un slot d'équipement"""
	var drop_zone := DropZone.new()
	drop_zone.setup_for_equipment_slot(slot_type)
	drop_zone.custom_minimum_size = Vector2(64, 64)
	parent.add_child(drop_zone)
	return drop_zone

static func create_group_slot(max_members: int, parent: Node) -> DropZone:
	"""Crée un slot de groupe"""
	var drop_zone := DropZone.new()
	drop_zone.setup_for_group_member_slot(max_members)
	drop_zone.custom_minimum_size = Vector2(200, 100)
	parent.add_child(drop_zone)
	return drop_zone