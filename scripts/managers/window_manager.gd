extends Node
class_name WindowManager

# Gestionnaire de fenêtres en mode MONO-FENÊTRE : la navigation par menu
# (show_window) affiche une fenêtre à la fois et cache les autres. Conserve
# l'ouverture/fermeture, le z-order (focus au clic), la mémorisation des
# positions/tailles sur disque et les animations d'ouverture/fermeture.
# Le multi-fenêtres simultané (Alt+Tab, cascade/tuiles, minimisation/taskbar)
# a été retiré car non fonctionnel avec la navigation exclusive.

# Configuration
const SAVE_FILE_PATH = "user://window_layouts.save"
const ANIMATION_DURATION = 0.3

# Données des fenêtres
var windows = {}  # nom -> config de base
var open_windows = {}  # nom -> instances ouvertes
var window_z_order = []  # ordre des fenêtres (Z-index)
var window_positions = {}  # sauvegarde des positions/tailles par fenêtre

# État du gestionnaire
var active_window = null
var max_z_index = 100
var use_animations = true

# Signaux
signal window_opened(window_name)
signal window_closed(window_name)
signal window_focused(window_name)

func _ready() -> void:
	# Charger les positions de fenêtres sauvegardées
	_load_layouts()
	GameLog.d("WindowManager initialisé (mode mono-fenêtre)")

# ==================== GESTION DE BASE DES FENÊTRES ====================

func register_window(window_name: String, window_scene_path: String, allow_multiple: bool = false) -> void:
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

func show_window(window_name: String) -> Control:
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

func close_window(window_name: String, instance_id: String = "") -> void:
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

func _finalize_window_close(window_name: String, inst_data: Dictionary) -> void:
	"""Finalise la fermeture d'une fenêtre"""
	# Mémoriser la position/taille puis la persister sur disque (restaurée au boot)
	_save_window_position(window_name, inst_data.instance)
	_save_layouts()

	# Supprimer de toutes les listes
	open_windows[window_name].erase(inst_data)
	if open_windows[window_name].is_empty():
		open_windows.erase(window_name)
	
	windows[window_name].instances.erase(inst_data.instance)
	_remove_from_z_order(window_name, inst_data.id)

	# Supprimer l'instance
	if is_instance_valid(inst_data.instance):
		inst_data.instance.queue_free()
	
	# Mettre à jour la fenêtre active
	if active_window == window_name and open_windows.get(window_name, []).is_empty():
		_update_active_window()
	
	window_closed.emit(window_name)

func hide_window(window_name: String, instance_id: String = "") -> void:
	"""Cache une fenêtre sans la fermer"""
	if not open_windows.has(window_name):
		return
	
	var instance_data = _find_instance(window_name, instance_id)
	if instance_data and instance_data.instance:
		instance_data.instance.hide()
		
		if active_window == window_name:
			_update_active_window()

# ==================== GESTION MULTI-FENÊTRES ET Z-ORDER ====================

func bring_to_front(window_name: String, instance_id: String = "") -> void:
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
	# Garder la fenêtre dans l'écran (au cas où le viewport a été redimensionné)
	_keep_window_on_screen(instance_data.instance)

	# Mettre comme active
	active_window = window_name
	window_focused.emit(window_name)

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

# ==================== LAYOUTS ET SAUVEGARDE ====================

func close_all_instances(window_name: String) -> void:
	"""Ferme toutes les instances d'une fenêtre"""
	if not open_windows.has(window_name):
		return
	
	var instances = open_windows[window_name].duplicate()
	for inst_data in instances:
		close_window(window_name, inst_data.id)

# ==================== MÉTHODES UTILITAIRES PRIVÉES ====================

func _setup_window_instance(instance: Control, window_name: String, instance_id: String, _config: Dictionary) -> void:
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

	# Position et taille restaurées depuis la save (format tableau [x, y] sur disque).
	var saved: Dictionary = window_positions.get(window_name, {})
	var saved_position = saved.get("position")  # tableau [x,y], ou String (ancienne save), ou null
	var saved_size = saved.get("size")
	if saved_size != null:
		instance.size = _to_vec2(saved_size, config.default_size)
	# Position : on n'utilise la save QUE si c'est un tableau [x,y] valide ; sinon
	# position par défaut ou centrage. Une ancienne save au format String (Vector2
	# sérialisé) tomberait sinon en (0,0) → fenêtre collée en haut-gauche (bug).
	if saved_position is Array and saved_position.size() >= 2:
		instance.position = Vector2(saved_position[0], saved_position[1])
	elif config.default_position != Vector2(-1, -1):
		instance.position = config.default_position
	else:
		_center_window(instance)

	# Borne la fenêtre dans l'écran courant (évite une position/taille restaurée hors champ)
	_keep_window_on_screen(instance)

	# S'assurer que la fenêtre est visible et déclencher l'animation
	instance.visible = true
	instance.show()
	if use_animations:
		_animate_window_open(instance)

func _keep_window_on_screen(win: Control) -> void:
	"""Borne la position et la taille d'une fenêtre dans le viewport courant.
	Protège contre une fenêtre restaurée (ou déplacée) hors écran."""
	if not is_instance_valid(win):
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var margin: float = 8.0
	# La taille ne doit pas dépasser l'écran (en gardant une marge minimale).
	var max_size: Vector2 = (viewport_size - Vector2(margin, margin) * 2.0).max(Vector2(100, 100))
	win.size = win.size.min(max_size)
	# La position doit garder la fenêtre entièrement visible.
	var max_pos: Vector2 = (viewport_size - win.size - Vector2(margin, margin)).max(Vector2(margin, margin))
	win.position = win.position.clamp(Vector2(margin, margin), max_pos)

func _connect_window_signals(instance: Control, window_name: String, instance_id: String) -> void:
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

func _add_to_z_order(window_name: String, instance_id: String) -> void:
	"""Ajoute une fenêtre au z-order"""
	var key: String = window_name + ":" + instance_id
	window_z_order.push_front(key)

func _remove_from_z_order(window_name: String, instance_id: String) -> void:
	"""Supprime une fenêtre du z-order"""
	var key: String = window_name + ":" + instance_id
	window_z_order.erase(key)

func _move_to_front_in_z_order(window_name: String, instance_id: String) -> void:
	"""Déplace une fenêtre au début du z-order"""
	_remove_from_z_order(window_name, instance_id)
	_add_to_z_order(window_name, instance_id)

func _apply_z_order() -> void:
	"""Applique les z-index selon l'ordre"""
	for i in range(window_z_order.size()):
		var key = window_z_order[i]
		var parts = key.split(":")
		var win_name = parts[0]
		var instance_id = parts[1]

		var inst_data: Dictionary = _find_instance(win_name, instance_id)
		if inst_data and inst_data.instance:
			inst_data.instance.z_index = max_z_index - i

func _update_active_window() -> void:
	"""Met à jour la fenêtre active"""
	if window_z_order.is_empty():
		active_window = null
		return

	var key = window_z_order[0]
	var parts = key.split(":")
	active_window = parts[0]
	window_focused.emit(active_window)

func _save_window_position(window_name: String, instance: Control):
	"""Sauvegarde la position d'une fenêtre (format JSON-safe : tableaux [x, y],
	car JSON.stringify ne sérialise pas les Vector2 — ils deviendraient des String
	illisibles au rechargement)."""
	window_positions[window_name] = {
		"position": [instance.position.x, instance.position.y],
		"size": [instance.size.x, instance.size.y]
	}

func _to_vec2(value, fallback: Vector2) -> Vector2:
	"""Reconstruit un Vector2 depuis un tableau [x, y] (sauvegarde sur disque),
	un Vector2 (même session), sinon renvoie le repli (anciennes sauvegardes
	corrompues où le Vector2 avait été sérialisé en String)."""
	if value is Array and value.size() >= 2:
		return Vector2(value[0], value[1])
	if value is Vector2:
		return value
	return fallback

func _save_layouts() -> void:
	"""Sauvegarde les positions/tailles des fenêtres sur disque."""
	var save_data = {
		"window_positions": window_positions
	}

	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()

func _load_layouts() -> void:
	"""Charge les positions/tailles des fenêtres depuis le disque."""
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
			var positions = save_data.get("window_positions", {})
			if positions is Dictionary:
				window_positions = positions

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

# ==================== MÉTHODES DE COMPATIBILITÉ ====================

func close_active_window() -> void:
	"""Ferme la fenêtre active (compatibilité)"""
	if active_window:
		close_window(active_window)
