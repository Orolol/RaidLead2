extends Node
class_name WindowManager

# Système de gestion avancé des fenêtres avec support multi-fenêtres,
# z-order, minimisation, sauvegarde layout, animations

# Configuration
const SAVE_FILE_PATH = "user://window_layouts.save"
const ANIMATION_DURATION = 0.3
const CASCADE_OFFSET = Vector2(30, 30)
const MIN_WINDOW_SIZE = Vector2(400, 300)

# Données des fenêtres
var windows = {}  # nom -> config de base
var open_windows = {}  # nom -> instances ouvertes
var window_z_order = []  # ordre des fenêtres (Z-index)
var minimized_windows = []  # fenêtres minimisées
var window_positions = {}  # sauvegarde des positions

# État du gestionnaire
var active_window = null
var max_z_index = 100
var use_animations = true
var taskbar_instance = null
var layouts = {}  # layouts sauvegardés
var current_layout = "default"

# Signaux
signal window_opened(window_name)
signal window_closed(window_name)
signal window_minimized(window_name)
signal window_restored(window_name)
signal window_focused(window_name)
signal layout_saved(layout_name)
signal layout_loaded(layout_name)

func _ready():
	# Charger les layouts sauvegardés
	_load_layouts()
	
	# Connecter les raccourcis clavier
	_setup_keyboard_shortcuts()
	
	# Créer la taskbar si nécessaire
	_setup_taskbar()
	
	GameLog.d("WindowManager avancé initialisé")

func _setup_keyboard_shortcuts():
	"""Configure les raccourcis clavier pour la navigation"""
	# Les raccourcis seront gérés dans _input()
	pass

func _setup_taskbar():
	"""Crée et configure la taskbar pour les fenêtres minimisées"""
	# La taskbar sera créée comme composant séparé plus tard
	pass

func _input(event):
	"""Gère les raccourcis clavier globaux"""
	if event is InputEventKey and event.pressed:
		# Alt+Tab pour cycler entre les fenêtres
		if event.alt_pressed and event.keycode == KEY_TAB:
			cycle_windows()
			get_viewport().set_input_as_handled()
			
		# Ctrl+M pour minimiser la fenêtre active
		elif event.ctrl_pressed and event.keycode == KEY_M:
			if active_window:
				minimize_window(active_window)
			get_viewport().set_input_as_handled()
			
		# Ctrl+Shift+C pour arranger en cascade
		elif event.ctrl_pressed and event.shift_pressed and event.keycode == KEY_C:
			arrange_cascade()
			get_viewport().set_input_as_handled()
			
		# Ctrl+Shift+T pour arranger en tuiles
		elif event.ctrl_pressed and event.shift_pressed and event.keycode == KEY_T:
			arrange_tile()
			get_viewport().set_input_as_handled()

# ==================== GESTION DE BASE DES FENÊTRES ====================

func register_window(window_name: String, window_scene_path: String, allow_multiple: bool = false):
	"""Enregistre une fenêtre avec ses paramètres"""
	windows[window_name] = {
		"scene_path": window_scene_path,
		"allow_multiple": allow_multiple,
		"instances": [],  # Pour support multi-instance
		"default_size": Vector2(800, 600),
		"default_position": Vector2(-1, -1),  # -1 = auto-centré
		"resizable": true,
		"closable": true,
		"minimizable": true
	}

func open_window(window_name: String, force_new: bool = false) -> Control:
	"""Ouvre une fenêtre avec support multi-instance"""
	if not windows.has(window_name):
		push_error("Window not registered: " + window_name)
		return null

	var window_config = windows[window_name]

	# Vérifier si on peut ouvrir une nouvelle instance
	if not window_config.allow_multiple and not force_new:
		var existing_instance = _get_existing_instance(window_name)
		if existing_instance:
			bring_to_front(window_name)
			return existing_instance
	
	# Créer une nouvelle instance
	var scene = load(window_config.scene_path)
	if not scene:
		push_error("Failed to load window scene: " + window_config.scene_path)
		return null
	
	var instance = scene.instantiate()
	var instance_id = _generate_instance_id(window_name)
	
	# Configurer l'instance
	_setup_window_instance(instance, window_name, instance_id, window_config)
	
	# Ajouter au tree (enfant du WindowManager, pas du parent)
	add_child(instance)

	# Appliquer le layout (position/taille) après que la fenêtre soit dans le tree
	_apply_window_layout.call_deferred(instance, window_name, window_config)

	# Enregistrer l'instance
	if not open_windows.has(window_name):
		open_windows[window_name] = []
	open_windows[window_name].append({
		"instance": instance,
		"id": instance_id,
		"is_minimized": false
	})
	window_config.instances.append(instance)
	
	# Mettre à jour le z-order
	_add_to_z_order(window_name, instance_id)

	# Mettre comme fenêtre active
	active_window = window_name

	# Émettre le signal (deferred car l'instance n'est pas encore dans le tree)
	window_opened.emit.call_deferred(window_name)
	window_focused.emit(window_name)
	
	return instance

func show_window(window_name: String):
	"""Navigation par menu : affiche cette fenêtre seule (cache les autres ouvertes)
	puis rafraîchit son contenu. Le multi-fenêtres reste possible via open_window()."""
	# Navigation exclusive : cacher les autres fenêtres pour éviter l'empilement
	for other_name in open_windows.keys():
		if other_name == window_name:
			continue
		for inst_data in open_windows[other_name]:
			if is_instance_valid(inst_data.instance):
				inst_data.instance.hide()
	var instance: Control = open_window(window_name)
	# Rafraîchir le contenu une fois la fenêtre affichée et dimensionnée
	_refresh_window_content.call_deferred(instance)
	return instance

func _refresh_window_content(instance) -> void:
	"""Appelle la méthode de rafraîchissement d'une fenêtre si elle en expose une."""
	if not is_instance_valid(instance):
		return
	for method_name in ["refresh_window", "_refresh_all", "refresh_display"]:
		if instance.has_method(method_name):
			instance.call(method_name)
			return

func close_window(window_name: String, instance_id: String = ""):
	"""Ferme une fenêtre ou instance spécifique"""
	if not open_windows.has(window_name):
		return
	
	var instances = open_windows[window_name]
	var to_remove = null
	
	for i in range(instances.size()):
		var inst_data = instances[i]
		if instance_id == "" or inst_data.id == instance_id:
			to_remove = inst_data
			break
	
	if to_remove:
		# Animation de fermeture
		if use_animations:
			_animate_window_close(to_remove.instance, func(): _finalize_window_close(window_name, to_remove))
		else:
			_finalize_window_close(window_name, to_remove)

func _finalize_window_close(window_name: String, inst_data: Dictionary):
	"""Finalise la fermeture d'une fenêtre"""
	# Sauvegarder la position si nécessaire
	_save_window_position(window_name, inst_data.instance)
	
	# Supprimer de toutes les listes
	open_windows[window_name].erase(inst_data)
	if open_windows[window_name].is_empty():
		open_windows.erase(window_name)
	
	windows[window_name].instances.erase(inst_data.instance)
	_remove_from_z_order(window_name, inst_data.id)
	minimized_windows.erase(inst_data)
	
	# Supprimer l'instance
	if is_instance_valid(inst_data.instance):
		inst_data.instance.queue_free()
	
	# Mettre à jour la fenêtre active
	if active_window == window_name and open_windows.get(window_name, []).is_empty():
		_update_active_window()
	
	window_closed.emit(window_name)

func hide_window(window_name: String, instance_id: String = ""):
	"""Cache une fenêtre sans la fermer"""
	if not open_windows.has(window_name):
		return
	
	var instance_data = _find_instance(window_name, instance_id)
	if instance_data and instance_data.instance:
		instance_data.instance.hide()
		
		if active_window == window_name:
			_update_active_window()

# ==================== GESTION MULTI-FENÊTRES ET Z-ORDER ====================

func bring_to_front(window_name: String, instance_id: String = ""):
	"""Amène une fenêtre au premier plan"""
	var instance_data = _find_instance(window_name, instance_id)
	if not instance_data:
		return
	
	# Mettre à jour le z-order
	_move_to_front_in_z_order(window_name, instance_data.id)
	
	# Appliquer le nouveau z-index
	_apply_z_order()
	
	# Afficher si cachée
	instance_data.instance.show()
	instance_data.is_minimized = false
	
	# Retirer de la liste des minimisées si présent
	minimized_windows.erase(instance_data)
	
	# Mettre comme active
	active_window = window_name
	window_focused.emit(window_name)

func cycle_windows():
	"""Cycle entre les fenêtres ouvertes (Alt+Tab)"""
	if window_z_order.size() <= 1:
		return
	
	# Prendre la fenêtre suivante dans l'ordre
	var current_index = 0
	var current_key = window_z_order[0] if window_z_order.size() > 0 else ""
	
	# Trouver l'index actuel
	for i in range(window_z_order.size()):
		if window_z_order[i].begins_with(active_window if active_window else ""):
			current_index = i
			break
	
	# Aller à la suivante
	var next_index = (current_index + 1) % window_z_order.size()
	var next_key = window_z_order[next_index]
	var window_name = next_key.split(":")[0]
	var instance_id = next_key.split(":")[1] if ":" in next_key else ""
	
	bring_to_front(window_name, instance_id)

func get_open_windows() -> Array:
	"""Retourne la liste des fenêtres ouvertes"""
	return open_windows.keys()

func is_window_open(window_name: String) -> bool:
	"""Vérifie si une fenêtre est ouverte"""
	return open_windows.has(window_name) and not open_windows[window_name].is_empty()

func get_window_instance(window_name: String) -> Control:
	return _get_existing_instance(window_name)

func refresh_window(window_name: String) -> void:
	_refresh_window_content(get_window_instance(window_name))

# ==================== MINIMISATION ET TASKBAR ====================

func minimize_window(window_name: String, instance_id: String = ""):
	"""Minimise une fenêtre dans la taskbar"""
	var instance_data = _find_instance(window_name, instance_id)
	if not instance_data or instance_data.is_minimized:
		return
	
	# Marquer comme minimisée
	instance_data.is_minimized = true
	minimized_windows.append(instance_data)
	
	# Cacher la fenêtre avec animation
	if use_animations:
		_animate_window_minimize(instance_data.instance)
	else:
		instance_data.instance.hide()
	
	# Mettre à jour la fenêtre active
	if active_window == window_name:
		_update_active_window()
	
	window_minimized.emit(window_name)

func restore_window(window_name: String, instance_id: String = ""):
	"""Restaure une fenêtre minimisée"""
	var instance_data = _find_instance(window_name, instance_id)
	if not instance_data or not instance_data.is_minimized:
		return
	
	# Marquer comme restaurée
	instance_data.is_minimized = false
	minimized_windows.erase(instance_data)
	
	# Afficher la fenêtre avec animation
	if use_animations:
		_animate_window_restore(instance_data.instance)
	else:
		instance_data.instance.show()
	
	# Amener au premier plan
	bring_to_front(window_name, instance_data.id)
	
	window_restored.emit(window_name)

func get_minimized_windows() -> Array:
	"""Retourne la liste des fenêtres minimisées"""
	return minimized_windows.duplicate()

# ==================== LAYOUTS ET SAUVEGARDE ====================

func save_layout(layout_name: String = ""):
	"""Sauvegarde le layout actuel"""
	if layout_name == "":
		layout_name = current_layout
	
	var layout_data = {}
	
	for window_name in open_windows:
		var instances_data = []
		for inst_data in open_windows[window_name]:
			var instance = inst_data.instance
			instances_data.append({
				"position": instance.position,
				"size": instance.size,
				"is_minimized": inst_data.is_minimized,
				"z_index": instance.z_index
			})
		layout_data[window_name] = instances_data
	
	layouts[layout_name] = layout_data
	current_layout = layout_name
	
	_save_layouts()
	layout_saved.emit(layout_name)

func load_layout(layout_name: String):
	"""Charge un layout sauvegardé"""
	if not layouts.has(layout_name):
		push_warning("Layout not found: " + layout_name)
		return
	
	# Fermer toutes les fenêtres ouvertes
	for window_name in open_windows.keys().duplicate():
		close_all_instances(window_name)
	
	# Ouvrir les fenêtres selon le layout
	var layout_data = layouts[layout_name]
	for window_name in layout_data:
		var instances_data = layout_data[window_name]
		for inst_data in instances_data:
			var instance = open_window(window_name, true)
			if instance:
				instance.position = inst_data.position
				instance.size = inst_data.size
				
				if inst_data.is_minimized:
					minimize_window(window_name, _get_instance_id(window_name, instance))
	
	current_layout = layout_name
	layout_loaded.emit(layout_name)

func get_available_layouts() -> Array:
	"""Retourne la liste des layouts disponibles"""
	return layouts.keys()

# ==================== ARRANGEMENT DES FENÊTRES ====================

func arrange_cascade():
	"""Arrange les fenêtres en cascade"""
	var offset = Vector2(0, 0)
	var viewport_size = get_viewport().get_visible_rect().size
	
	for window_name in window_z_order:
		var parts = window_name.split(":")
		var name = parts[0]
		var instance_id = parts[1] if parts.size() > 1 else ""
		
		var instance_data = _find_instance(name, instance_id)
		if instance_data and not instance_data.is_minimized:
			var instance = instance_data.instance
			instance.position = offset
			
			# S'assurer que la fenêtre reste dans l'écran
			var max_pos = viewport_size - instance.size
			if offset.x > max_pos.x or offset.y > max_pos.y:
				offset = Vector2(0, 0)
			else:
				offset += CASCADE_OFFSET

func arrange_tile():
	"""Arrange les fenêtres en tuiles"""
	var visible_windows = []
	for window_name in open_windows:
		for inst_data in open_windows[window_name]:
			if not inst_data.is_minimized:
				visible_windows.append(inst_data.instance)
	
	if visible_windows.is_empty():
		return
	
	var viewport_size = get_viewport().get_visible_rect().size
	var count = visible_windows.size()
	var cols = int(ceil(sqrt(count)))
	var rows = int(ceil(float(count) / cols))
	
	var window_size = Vector2(viewport_size.x / cols, viewport_size.y / rows)
	
	for i in range(count):
		var window = visible_windows[i]
		var row = i / cols
		var col = i % cols
		
		window.position = Vector2(col * window_size.x, row * window_size.y)
		window.size = window_size

func close_all_instances(window_name: String):
	"""Ferme toutes les instances d'une fenêtre"""
	if not open_windows.has(window_name):
		return
	
	var instances = open_windows[window_name].duplicate()
	for inst_data in instances:
		close_window(window_name, inst_data.id)

# ==================== MÉTHODES UTILITAIRES PRIVÉES ====================

func _setup_window_instance(instance: Control, window_name: String, instance_id: String, config: Dictionary):
	"""Configure une instance de fenêtre"""
	# Z-index
	instance.z_index = max_z_index
	max_z_index += 1

	# Connecter les signaux si la fenêtre les supporte
	_connect_window_signals(instance, window_name, instance_id)

func _apply_window_layout(instance: Control, window_name: String, config: Dictionary) -> void:
	"""Applique position/taille après que la fenêtre soit dans le tree et _ready() terminé.
	Appelé via call_deferred depuis open_window pour garantir que les anchors des fenêtres
	sont déjà appliqués et qu'on peut les override."""
	# Forcer le layout en position absolue (pas d'anchors)
	instance.anchor_left = 0
	instance.anchor_top = 0
	instance.anchor_right = 0
	instance.anchor_bottom = 0
	instance.offset_left = 0
	instance.offset_top = 0
	instance.offset_right = 0
	instance.offset_bottom = 0

	# Taille
	if config.default_size != Vector2.ZERO:
		instance.size = config.default_size

	# Position
	if window_positions.has(window_name):
		var saved: Dictionary = window_positions[window_name]
		instance.position = saved.get("position", Vector2.ZERO)
		instance.size = saved.get("size", config.default_size)
	elif config.default_position != Vector2(-1, -1):
		instance.position = config.default_position
	else:
		_center_window(instance)

	# S'assurer que la fenêtre est visible et déclencher l'animation
	instance.visible = true
	instance.show()
	if use_animations:
		_animate_window_open(instance)

func _connect_window_signals(instance: Control, window_name: String, instance_id: String):
	"""Connecte les signaux d'une fenêtre"""
	# Signal de fermeture
	if instance.has_signal("close_requested"):
		instance.close_requested.connect(func(): close_window(window_name, instance_id))
	
	# Signal de focus/clic
	if instance.has_signal("gui_input"):
		instance.gui_input.connect(func(event): 
			if event is InputEventMouseButton and event.pressed:
				bring_to_front(window_name, instance_id)
		)

func _center_window(window: Control):
	"""Centre une fenêtre dans la zone sûre (au-dessus de la barre de menu, sur l'écran)."""
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var menu_bar_h: float = 90.0
	var margin: float = 16.0
	var pos: Vector2 = (viewport_size - window.size) / 2.0
	# Rester au-dessus de la barre de menu et dans l'écran
	var max_y: float = maxf(margin, viewport_size.y - menu_bar_h - window.size.y)
	var max_x: float = maxf(margin, viewport_size.x - margin - window.size.x)
	pos.x = clampf(pos.x, margin, max_x)
	pos.y = clampf(pos.y, margin, max_y)
	window.position = pos

func _generate_instance_id(window_name: String) -> String:
	"""Génère un ID unique pour une instance"""
	return window_name + "_" + str(Time.get_unix_time_from_system()) + "_" + str(randi())

func _get_existing_instance(window_name: String) -> Control:
	"""Retourne la première instance existante d'une fenêtre"""
	if not open_windows.has(window_name) or open_windows[window_name].is_empty():
		return null
	return open_windows[window_name][0].instance

func _find_instance(window_name: String, instance_id: String = "") -> Dictionary:
	"""Trouve une instance spécifique"""
	if not open_windows.has(window_name):
		return {}
	
	if instance_id == "":
		return open_windows[window_name][0] if not open_windows[window_name].is_empty() else {}
	
	for inst_data in open_windows[window_name]:
		if inst_data.id == instance_id:
			return inst_data
	
	return {}

func _get_instance_id(window_name: String, instance: Control) -> String:
	"""Trouve l'ID d'une instance"""
	if not open_windows.has(window_name):
		return ""
	
	for inst_data in open_windows[window_name]:
		if inst_data.instance == instance:
			return inst_data.id
	
	return ""

func _add_to_z_order(window_name: String, instance_id: String):
	"""Ajoute une fenêtre au z-order"""
	var key = window_name + ":" + instance_id
	window_z_order.push_front(key)

func _remove_from_z_order(window_name: String, instance_id: String):
	"""Supprime une fenêtre du z-order"""
	var key = window_name + ":" + instance_id
	window_z_order.erase(key)

func _move_to_front_in_z_order(window_name: String, instance_id: String):
	"""Déplace une fenêtre au début du z-order"""
	_remove_from_z_order(window_name, instance_id)
	_add_to_z_order(window_name, instance_id)

func _apply_z_order():
	"""Applique les z-index selon l'ordre"""
	for i in range(window_z_order.size()):
		var key = window_z_order[i]
		var parts = key.split(":")
		var name = parts[0]
		var instance_id = parts[1]
		
		var inst_data = _find_instance(name, instance_id)
		if inst_data and inst_data.instance:
			inst_data.instance.z_index = max_z_index - i

func _update_active_window():
	"""Met à jour la fenêtre active"""
	if window_z_order.is_empty():
		active_window = null
		return
	
	var key = window_z_order[0]
	var parts = key.split(":")
	active_window = parts[0]
	window_focused.emit(active_window)

func _save_window_position(window_name: String, instance: Control):
	"""Sauvegarde la position d'une fenêtre"""
	window_positions[window_name] = {
		"position": instance.position,
		"size": instance.size
	}

func _save_layouts():
	"""Sauvegarde les layouts sur disque"""
	var save_data = {
		"layouts": layouts,
		"window_positions": window_positions,
		"current_layout": current_layout
	}
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()

func _load_layouts():
	"""Charge les layouts depuis le disque"""
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		return
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var result = json.parse(json_text)
		
		if result == OK and json.data is Dictionary:
			var save_data: Dictionary = json.data
			layouts = save_data.get("layouts", {})
			window_positions = save_data.get("window_positions", {})
			current_layout = save_data.get("current_layout", "default")

# ==================== ANIMATIONS ====================

func _animate_window_open(window: Control):
	"""Animation d'ouverture de fenêtre"""
	var original_size = window.size
	window.size = Vector2.ZERO
	window.modulate.a = 0.0
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(window, "size", original_size, ANIMATION_DURATION).set_ease(Tween.EASE_OUT)
	tween.tween_property(window, "modulate:a", 1.0, ANIMATION_DURATION).set_ease(Tween.EASE_OUT)

func _animate_window_close(window: Control, callback: Callable):
	"""Animation de fermeture de fenêtre"""
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(window, "size", Vector2.ZERO, ANIMATION_DURATION).set_ease(Tween.EASE_IN)
	tween.tween_property(window, "modulate:a", 0.0, ANIMATION_DURATION).set_ease(Tween.EASE_IN)
	tween.finished.connect(callback)

func _animate_window_minimize(window: Control):
	"""Animation de minimisation"""
	var tween = create_tween()
	tween.tween_property(window, "scale", Vector2(0.1, 0.1), ANIMATION_DURATION).set_ease(Tween.EASE_IN)
	tween.finished.connect(func(): window.hide())

func _animate_window_restore(window: Control):
	"""Animation de restauration"""
	window.show()
	window.scale = Vector2(0.1, 0.1)
	var tween = create_tween()
	tween.tween_property(window, "scale", Vector2.ONE, ANIMATION_DURATION).set_ease(Tween.EASE_OUT)

# ==================== MÉTHODES DE COMPATIBILITÉ ====================

func close_active_window() -> void:
	"""Ferme la fenêtre active (compatibilité)"""
	if active_window:
		close_window(active_window)
