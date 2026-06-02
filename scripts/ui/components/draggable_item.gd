extends Control
class_name DraggableItem

# Composant pour rendre un élément draggable avec ghost image et validation
# Utilisé pour drag & drop d'items d'équipement, membres de groupes, etc.

# Configuration
@export var drag_enabled: bool = true : set = set_drag_enabled
@export var drag_data: Dictionary = {} : set = set_drag_data
@export var drag_types: Array[String] = ["default"] : set = set_drag_types
@export var ghost_opacity: float = 0.7
@export var drag_threshold: float = 5.0  # Distance minimum pour commencer le drag
@export var return_animation_duration: float = 0.3
@export var snap_back_if_invalid: bool = true

# Éléments visuels
@export var content_container: Control  # Container du contenu à draguer
@export var ghost_scale: float = 0.9  # Échelle du ghost pendant le drag

# État interne
var is_dragging: bool = false
var drag_start_position: Vector2
var mouse_offset: Vector2
var original_position: Vector2
var original_parent: Node
var original_z_index: int
var ghost_node: Control
var current_drop_zone: Control  # DropZone au-dessus duquel on survole

# Signaux
signal drag_started(item: DraggableItem, data: Dictionary)
signal drag_ended(item: DraggableItem, data: Dictionary, drop_zone: Control)
signal drag_cancelled(item: DraggableItem, data: Dictionary)
signal hover_drop_zone(item: DraggableItem, drop_zone: Control)
signal leave_drop_zone(item: DraggableItem, drop_zone: Control)

func _ready() -> void:
	if not content_container:
		content_container = self

	_setup_mouse_handling()

func _setup_mouse_handling() -> void:
	"""Configure la gestion de la souris"""
	mouse_filter = Control.MOUSE_FILTER_PASS
	gui_input.connect(_on_gui_input)

# ==================== SETTERS ====================

func set_drag_enabled(enabled: bool) -> void:
	drag_enabled = enabled
	if is_inside_tree():
		mouse_filter = Control.MOUSE_FILTER_PASS if enabled else Control.MOUSE_FILTER_IGNORE

func set_drag_data(data: Dictionary) -> void:
	drag_data = data

func set_drag_types(types: Array[String]) -> void:
	drag_types = types

# ==================== GESTION DES ÉVÉNEMENTS ====================

func _on_gui_input(event: InputEvent) -> void:
	if not drag_enabled:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_on_mouse_press(event.position)
			else:
				_on_mouse_release(event.position)
	
	elif event is InputEventMouseMotion and is_dragging:
		_on_mouse_drag(event.position)

func _on_mouse_press(mouse_pos: Vector2) -> void:
	"""Démarre potentiellement un drag"""
	drag_start_position = mouse_pos
	original_position = global_position
	original_parent = get_parent()
	original_z_index = z_index

	# Capturer la souris pour les événements en dehors du control
	set_process_unhandled_input(true)

func _on_mouse_drag(mouse_pos: Vector2) -> void:
	"""Gère le drag en cours"""
	var drag_distance: float = drag_start_position.distance_to(mouse_pos)

	if not is_dragging and drag_distance > drag_threshold:
		_start_drag()

	if is_dragging:
		_update_drag_position(mouse_pos)

func _on_mouse_release(_mouse_pos: Vector2) -> void:
	"""Termine le drag"""
	set_process_unhandled_input(false)

	if is_dragging:
		_end_drag()

func _unhandled_input(event: InputEvent) -> void:
	"""Gère les événements souris globaux pendant le drag"""
	if not is_dragging:
		return
		
	if event is InputEventMouseMotion:
		_update_drag_position(event.position)
		_check_drop_zones(event.position)
	
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_end_drag()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_cancel_drag()

# ==================== LOGIQUE DRAG & DROP ====================

func _start_drag() -> void:
	"""Démarre le drag"""
	is_dragging = true

	# Créer le ghost
	_create_ghost()

	# Modifier l'apparence de l'original
	modulate.a = 0.5

	# Amener au premier plan
	z_index = 1000

	# Émettre le signal
	drag_started.emit(self, drag_data)

func _update_drag_position(_mouse_pos: Vector2) -> void:
	"""Met à jour la position pendant le drag"""
	if not is_dragging or not ghost_node:
		return

	# Calculer la position globale de la souris
	var global_mouse_pos: Vector2 = get_global_mouse_position()

	# Positionner le ghost
	ghost_node.global_position = global_mouse_pos - mouse_offset

func _check_drop_zones(mouse_pos: Vector2) -> void:
	"""Vérifie si on survole une drop zone valide"""
	var new_drop_zone: Control = _find_drop_zone_at_position(mouse_pos)

	if new_drop_zone != current_drop_zone:
		# Quitter l'ancienne zone
		if current_drop_zone:
			_leave_drop_zone(current_drop_zone)
		
		# Entrer dans la nouvelle zone
		if new_drop_zone:
			_enter_drop_zone(new_drop_zone)
		
		current_drop_zone = new_drop_zone

func _find_drop_zone_at_position(global_pos: Vector2) -> Control:
	"""Trouve la drop zone à une position donnée"""
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = global_pos
	query.collision_mask = 1  # Ajuster selon les besoins

	# Méthode alternative : parcourir les drop zones connues
	return _find_drop_zone_recursive(get_tree().root, global_pos)

func _find_drop_zone_recursive(node: Node, global_pos: Vector2) -> Control:
	"""Recherche récursive de drop zones"""
	if node.has_method("can_accept_drop") and node is Control:
		var control = node as Control
		if control.get_global_rect().has_point(global_pos):
			if control.can_accept_drop(self, drag_data):
				return control

	for child in node.get_children():
		var result: Control = _find_drop_zone_recursive(child, global_pos)
		if result:
			return result

	return null

func _enter_drop_zone(drop_zone: Control) -> void:
	"""Entre dans une drop zone"""
	if drop_zone.has_method("on_drag_hover_enter"):
		drop_zone.on_drag_hover_enter(self, drag_data)

	hover_drop_zone.emit(self, drop_zone)

func _leave_drop_zone(drop_zone: Control) -> void:
	"""Quitte une drop zone"""
	if drop_zone.has_method("on_drag_hover_exit"):
		drop_zone.on_drag_hover_exit(self, drag_data)

	leave_drop_zone.emit(self, drop_zone)

func _end_drag() -> void:
	"""Termine le drag"""
	if not is_dragging:
		return
	
	var successful_drop: bool = false

	# Tenter le drop dans la zone courante
	if current_drop_zone:
		if current_drop_zone.has_method("accept_drop"):
			successful_drop = current_drop_zone.accept_drop(self, drag_data)

	# Nettoyer
	_cleanup_drag()

	if successful_drop:
		drag_ended.emit(self, drag_data, current_drop_zone)
	else:
		if snap_back_if_invalid:
			_animate_back_to_original()
		drag_cancelled.emit(self, drag_data)

func _cancel_drag() -> void:
	"""Annule le drag (clic droit)"""
	if not is_dragging:
		return

	_cleanup_drag()
	_animate_back_to_original()
	drag_cancelled.emit(self, drag_data)

func _cleanup_drag() -> void:
	"""Nettoie après un drag"""
	is_dragging = false
	set_process_unhandled_input(false)
	
	# Restaurer l'apparence
	modulate.a = 1.0
	z_index = original_z_index
	
	# Supprimer le ghost
	if ghost_node:
		ghost_node.queue_free()
		ghost_node = null
	
	# Quitter la drop zone
	if current_drop_zone:
		_leave_drop_zone(current_drop_zone)
		current_drop_zone = null

func _animate_back_to_original() -> void:
	"""Anime le retour à la position originale"""
	if not original_parent:
		return

	var tween := create_tween()
	tween.tween_property(self, "global_position", original_position, return_animation_duration)
	tween.set_ease(Tween.EASE_OUT)

# ==================== GESTION DU GHOST ====================

func _create_ghost() -> void:
	"""Crée l'image fantôme pendant le drag"""
	if not content_container:
		return
	
	# Créer un duplicate du contenu
	ghost_node = Control.new()
	ghost_node.name = "DragGhost"
	
	# Copier l'apparence
	var ghost_content: Control = _create_ghost_content()
	ghost_node.add_child(ghost_content)
	
	# Style du ghost
	ghost_node.modulate.a = ghost_opacity
	ghost_node.scale = Vector2(ghost_scale, ghost_scale)
	ghost_node.z_index = 1001  # Au-dessus de tout
	
	# Ajouter au tree root pour qu'il soit visible partout
	get_tree().root.add_child(ghost_node)
	
	# Calculer l'offset de la souris
	mouse_offset = get_local_mouse_position()
	
	# Position initiale
	ghost_node.global_position = global_position

func _create_ghost_content() -> Control:
	"""Crée le contenu visuel du ghost"""
	# Pour l'instant, copier simplement l'apparence
	var ghost_content := ColorRect.new()
	ghost_content.color = Color(0.8, 0.8, 0.8, 0.5)
	ghost_content.size = content_container.size

	# Ajouter un label si on a des données textuelles
	if drag_data.has("text"):
		var label := Label.new()
		label.text = drag_data.text
		label.add_theme_color_override("font_color", Color.WHITE)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ghost_content.add_child(label)
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	return ghost_content

# ==================== API PUBLIQUE ====================

func start_drag_programmatically() -> void:
	"""Démarre un drag par programmation"""
	if drag_enabled and not is_dragging:
		drag_start_position = Vector2.ZERO
		original_position = global_position
		original_parent = get_parent()
		original_z_index = z_index
		_start_drag()

func cancel_drag_programmatically() -> void:
	"""Annule un drag par programmation"""
	if is_dragging:
		_cancel_drag()

func set_drag_content(content: Control) -> void:
	"""Définit le contenu à draguer"""
	content_container = content

func add_drag_type(type: String) -> void:
	"""Ajoute un type de drag"""
	if type not in drag_types:
		drag_types.append(type)

func remove_drag_type(type: String) -> void:
	"""Supprime un type de drag"""
	drag_types.erase(type)

func has_drag_type(type: String) -> bool:
	"""Vérifie si l'item a un type de drag spécifique"""
	return type in drag_types

func get_drag_info() -> Dictionary:
	"""Retourne les informations de drag"""
	return {
		"types": drag_types,
		"data": drag_data,
		"is_dragging": is_dragging,
		"source_item": self
	}

# ==================== MÉTHODES UTILITAIRES ====================

static func make_draggable(control: Control, types: Array[String] = ["default"], data: Dictionary = {}) -> DraggableItem:
	"""Utilitaire pour rendre un Control draggable"""
	var draggable := DraggableItem.new()
	draggable.name = "DraggableWrapper"
	draggable.drag_types = types
	draggable.drag_data = data
	draggable.content_container = control

	# Remplacer le control par le draggable
	var parent: Node = control.get_parent()
	var index: int = control.get_index()
	
	parent.remove_child(control)
	parent.add_child(draggable)
	parent.move_child(draggable, index)
	draggable.add_child(control)
	
	# Ajuster les propriétés
	draggable.size = control.size
	draggable.position = control.position
	control.position = Vector2.ZERO
	
	return draggable

func get_content() -> Control:
	"""Retourne le contenu dragué"""
	return content_container

# ==================== CONFIGURATIONS PRÉDÉFINIES ====================

func setup_for_equipment_item(item_data: Dictionary) -> void:
	"""Configuration pour les objets d'équipement"""
	drag_types = ["equipment", "item"]
	drag_data = item_data
	ghost_scale = 0.8
	ghost_opacity = 0.8

func setup_for_guild_member(member_data: Dictionary) -> void:
	"""Configuration pour les membres de guilde"""
	drag_types = ["member", "player"]
	drag_data = member_data
	ghost_scale = 0.9
	ghost_opacity = 0.7

func setup_for_tab(tab_data: Dictionary) -> void:
	"""Configuration pour les onglets"""
	drag_types = ["tab"]
	drag_data = tab_data
	ghost_scale = 0.95
	ghost_opacity = 0.6