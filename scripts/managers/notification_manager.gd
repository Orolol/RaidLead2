extends Node
# NotificationManager - Système de gestion des notifications toast
# Ne pas utiliser class_name car c'est un autoload

# Énumération des types de notifications
enum NotificationType {
	INFO,
	SUCCESS,
	WARNING,
	ERROR,
	ACHIEVEMENT
}

# Configuration des notifications
const MAX_VISIBLE_NOTIFICATIONS = 3
const DEFAULT_DURATION = 3.0
const ANIMATION_DURATION = 0.3
const VERTICAL_SPACING = 10
const NOTIFICATION_WIDTH = 350
const NOTIFICATION_HEIGHT = 80

# Position des notifications (coin supérieur droit)
const NOTIFICATION_MARGIN_RIGHT = 20
const NOTIFICATION_MARGIN_TOP = 60

# Couleurs par type de notification
const NOTIFICATION_COLORS = {
	NotificationType.INFO: Color(0.2, 0.6, 0.9, 0.95),
	NotificationType.SUCCESS: Color(0.3, 0.8, 0.3, 0.95),
	NotificationType.WARNING: Color(0.9, 0.7, 0.2, 0.95),
	NotificationType.ERROR: Color(0.9, 0.3, 0.3, 0.95),
	NotificationType.ACHIEVEMENT: Color(0.8, 0.4, 0.9, 0.95)
}

# Icônes par type (utilisation de caractères Unicode pour simplicité)
const NOTIFICATION_ICONS = {
	NotificationType.INFO: "ℹ",
	NotificationType.SUCCESS: "✓",
	NotificationType.WARNING: "⚠",
	NotificationType.ERROR: "✗",
	NotificationType.ACHIEVEMENT: "★"
}

# Variables de gestion
var notification_queue: Array = []
var active_notifications: Array = []
var notification_history: Array = []
var notification_container: Control = null

# Signaux
signal notification_shown(notification_data)
signal notification_dismissed(notification_data)
signal history_updated()

func _ready():
	# Créer le container pour les notifications
	_setup_notification_container()
	
	# Connecter aux signaux du jeu pour les notifications automatiques
	_connect_to_game_events()
	
	print("NotificationManager initialized")

func _setup_notification_container():
	"""Crée le container principal pour afficher les notifications"""
	notification_container = Control.new()
	notification_container.name = "NotificationContainer"
	notification_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	notification_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notification_container.z_index = 1000  # Au-dessus de tout
	
	# Ajouter au tree root pour être toujours visible
	get_tree().root.add_child.call_deferred(notification_container)

func _connect_to_game_events():
	"""Connecte aux événements du jeu pour afficher automatiquement des notifications"""
	
	# Connexion au PhaseManager pour les changements de phase
	var phase_manager = get_node_or_null("/root/PhaseManager")
	if phase_manager:
		if phase_manager.has_signal("phase_changed"):
			phase_manager.phase_changed.connect(_on_phase_changed)
		if phase_manager.has_signal("progression_updated"):
			phase_manager.progression_updated.connect(_on_progression_updated)
	
	# Connexion au GuildManager pour les événements de guilde
	var guild_manager = get_node_or_null("/root/GuildManager")
	if guild_manager:
		if guild_manager.has_signal("member_recruited"):
			guild_manager.member_recruited.connect(_on_member_recruited)
		if guild_manager.has_signal("member_left"):
			guild_manager.member_left.connect(_on_member_left)
		if guild_manager.has_signal("guild_level_changed"):
			guild_manager.guild_level_changed.connect(_on_guild_level_up)
		if guild_manager.has_signal("member_connected"):
			guild_manager.member_connected.connect(_on_member_connected)
		if guild_manager.has_signal("member_disconnected"):
			guild_manager.member_disconnected.connect(_on_member_disconnected)
	
	# Connexion à l'ActivityManager pour les activités
	var activity_manager = get_node_or_null("/root/ActivityManager")
	if activity_manager:
		if activity_manager.has_signal("activity_completed"):
			activity_manager.activity_completed.connect(_on_activity_completed)
		if activity_manager.has_signal("dungeon_started"):
			activity_manager.dungeon_started.connect(_on_dungeon_started)
		if activity_manager.has_signal("dungeon_ended"):
			activity_manager.dungeon_ended.connect(_on_dungeon_ended)
	
	# Connexion au RecruitmentPool pour les événements de recrutement
	var recruitment_pool = get_node_or_null("/root/RecruitmentPool")
	if recruitment_pool:
		if recruitment_pool.has_signal("pool_updated"):
			recruitment_pool.pool_updated.connect(_on_recruitment_pool_updated)
	
	# Connexion à l'EventManager pour les événements aléatoires
	var event_manager = get_node_or_null("/root/EventManager")
	if event_manager:
		if event_manager.has_signal("event_triggered"):
			event_manager.event_triggered.connect(_on_random_event_triggered)

func show_notification(text: String, type: NotificationType = NotificationType.INFO, duration: float = DEFAULT_DURATION, title: String = "", icon: String = ""):
	"""Affiche une notification avec le texte et type spécifiés"""
	
	var notification_data = {
		"text": text,
		"title": title if title != "" else _get_default_title(type),
		"type": type,
		"duration": duration,
		"icon": icon if icon != "" else NOTIFICATION_ICONS[type],
		"color": NOTIFICATION_COLORS[type],
		"timestamp": Time.get_unix_time_from_system(),
		"id": _generate_notification_id()
	}
	
	# Ajouter à l'historique
	notification_history.append(notification_data)
	if notification_history.size() > 100:  # Limiter l'historique
		notification_history.pop_front()
	
	# Si on a déjà trop de notifications visibles, ajouter à la queue
	if active_notifications.size() >= MAX_VISIBLE_NOTIFICATIONS:
		notification_queue.append(notification_data)
		return
	
	# Sinon, afficher immédiatement
	_display_notification(notification_data)

func show_info(text: String, title: String = "Info"):
	"""Raccourci pour notification info"""
	show_notification(text, NotificationType.INFO, DEFAULT_DURATION, title)

func show_success(text: String, title: String = "Succès"):
	"""Raccourci pour notification succès"""
	show_notification(text, NotificationType.SUCCESS, DEFAULT_DURATION, title)

func show_warning(text: String, title: String = "Attention"):
	"""Raccourci pour notification avertissement"""
	show_notification(text, NotificationType.WARNING, DEFAULT_DURATION * 1.5, title)

func show_error(text: String, title: String = "Erreur"):
	"""Raccourci pour notification erreur"""
	show_notification(text, NotificationType.ERROR, DEFAULT_DURATION * 2, title)

func show_achievement(text: String, title: String = "Achievement"):
	"""Raccourci pour notification achievement"""
	show_notification(text, NotificationType.ACHIEVEMENT, DEFAULT_DURATION * 2, title)

func dismiss_notification(notification_id: String):
	"""Ferme une notification spécifique"""
	for i in range(active_notifications.size()):
		var notif = active_notifications[i]
		if notif.data.id == notification_id:
			_remove_notification(notif)
			break

func clear_all_notifications():
	"""Ferme toutes les notifications actives et vide la queue"""
	for notif in active_notifications.duplicate():
		_remove_notification(notif)
	notification_queue.clear()

func get_notification_history() -> Array:
	"""Retourne l'historique des notifications"""
	return notification_history.duplicate()

func get_active_count() -> int:
	"""Retourne le nombre de notifications actuellement affichées"""
	return active_notifications.size()

func get_queue_count() -> int:
	"""Retourne le nombre de notifications en attente"""
	return notification_queue.size()

func _display_notification(notification_data: Dictionary):
	"""Affiche physiquement une notification à l'écran"""
	
	# Créer l'instance de notification
	var notification_toast = _create_notification_toast(notification_data)
	notification_container.add_child(notification_toast)
	
	# Positionner la notification
	_position_notification(notification_toast, active_notifications.size())
	
	# Ajouter à la liste active
	var notification_instance = {
		"data": notification_data,
		"toast": notification_toast
	}
	active_notifications.append(notification_instance)
	
	# Animation d'apparition
	_animate_notification_in(notification_toast)
	
	# Timer pour auto-dismiss
	if notification_data.duration > 0:
		var timer = Timer.new()
		timer.wait_time = notification_data.duration
		timer.one_shot = true
		timer.timeout.connect(func(): _remove_notification(notification_instance))
		notification_toast.add_child(timer)
		timer.start()
	
	# Émettre le signal
	notification_shown.emit(notification_data)

func _create_notification_toast(notification_data: Dictionary) -> Control:
	"""Crée l'élément visuel de la notification"""
	
	# Charger la scène NotificationToast
	var toast_scene = load("res://scenes/NotificationToast.tscn")
	if toast_scene:
		var toast = toast_scene.instantiate()
		toast.setup(notification_data)
		return toast
	
	# Fallback si la scène n'existe pas
	var toast = PanelContainer.new()
	toast.custom_minimum_size = Vector2(NOTIFICATION_WIDTH, NOTIFICATION_HEIGHT)
	toast.size = Vector2(NOTIFICATION_WIDTH, NOTIFICATION_HEIGHT)
	
	# Style du panel
	var style = StyleBoxFlat.new()
	style.bg_color = notification_data.color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 3
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = notification_data.color.lightened(0.2)
	toast.add_theme_stylebox_override("panel", style)
	
	# Container horizontal
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	toast.add_child(hbox)
	
	# Icône
	var icon_label = Label.new()
	icon_label.text = notification_data.icon
	icon_label.add_theme_font_size_override("font_size", 24)
	icon_label.add_theme_color_override("font_color", Color.WHITE)
	icon_label.custom_minimum_size = Vector2(32, 32)
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(icon_label)
	
	# Container vertical pour texte
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)
	
	# Titre
	var title_label = Label.new()
	title_label.text = notification_data.title
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	# Note: add_theme_font_weight_override n'existe pas en Godot 4
	# Utiliser add_theme_font_size_override pour l'emphase
	vbox.add_child(title_label)
	
	# Message
	var message_label = Label.new()
	message_label.text = notification_data.text
	message_label.add_theme_font_size_override("font_size", 12)
	message_label.add_theme_color_override("font_color", Color.WHITE.darkened(0.1))
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(message_label)
	
	# Bouton fermer
	var close_button = Button.new()
	close_button.text = "×"
	close_button.add_theme_font_size_override("font_size", 18)
	close_button.add_theme_color_override("font_color", Color.WHITE)
	close_button.flat = true
	close_button.custom_minimum_size = Vector2(24, 24)
	close_button.pressed.connect(func(): dismiss_notification(notification_data.id))
	hbox.add_child(close_button)
	
	return toast

func _position_notification(toast: Control, index: int):
	"""Positionne une notification selon son index"""
	var viewport_size = get_viewport().get_visible_rect().size
	
	var x = viewport_size.x - NOTIFICATION_WIDTH - NOTIFICATION_MARGIN_RIGHT
	var y = NOTIFICATION_MARGIN_TOP + index * (NOTIFICATION_HEIGHT + VERTICAL_SPACING)
	
	toast.position = Vector2(x, y)

func _animate_notification_in(toast: Control):
	"""Animation d'apparition de la notification"""
	var original_pos = toast.position
	toast.position.x += NOTIFICATION_WIDTH  # Start hors écran à droite
	toast.modulate.a = 0.0  # Start transparent
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(toast, "position:x", original_pos.x, ANIMATION_DURATION).set_ease(Tween.EASE_OUT)
	tween.tween_property(toast, "modulate:a", 1.0, ANIMATION_DURATION).set_ease(Tween.EASE_OUT)

func _animate_notification_out(toast: Control, callback: Callable):
	"""Animation de disparition de la notification"""
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(toast, "position:x", toast.position.x + NOTIFICATION_WIDTH, ANIMATION_DURATION).set_ease(Tween.EASE_IN)
	tween.tween_property(toast, "modulate:a", 0.0, ANIMATION_DURATION).set_ease(Tween.EASE_IN)
	tween.finished.connect(callback)

func _remove_notification(notification_instance: Dictionary):
	"""Supprime une notification et réorganise les autres"""
	
	if notification_instance not in active_notifications:
		return

	var toast = notification_instance.toast
	# Retirer immédiatement de la liste active : évite qu'un autre repositionnement
	# accède à ce toast pendant son animation de sortie (accès après libération).
	active_notifications.erase(notification_instance)

	if not is_instance_valid(toast):
		_reposition_notifications()
		_process_notification_queue()
		notification_dismissed.emit(notification_instance.data)
		return

	# Animation de sortie puis libération
	_animate_notification_out(toast, func():
		if is_instance_valid(toast):
			toast.queue_free()
		_reposition_notifications()
		_process_notification_queue()
		notification_dismissed.emit(notification_instance.data)
	)

func _reposition_notifications():
	"""Repositionne toutes les notifications actives (en ignorant les toasts libérés)."""
	# Purge défensive : retire les notifications dont le toast a déjà été libéré
	active_notifications = active_notifications.filter(func(n): return is_instance_valid(n.toast))
	for i in range(active_notifications.size()):
		var toast = active_notifications[i].toast
		var target_pos = Vector2(
			toast.position.x,
			NOTIFICATION_MARGIN_TOP + i * (NOTIFICATION_HEIGHT + VERTICAL_SPACING)
		)
		var tween = create_tween()
		tween.tween_property(toast, "position", target_pos, ANIMATION_DURATION * 0.5).set_ease(Tween.EASE_OUT)

func _process_notification_queue():
	"""Traite la queue de notifications en attente"""
	if notification_queue.size() > 0 and active_notifications.size() < MAX_VISIBLE_NOTIFICATIONS:
		var next_notification = notification_queue.pop_front()
		_display_notification(next_notification)

func _get_default_title(type: NotificationType) -> String:
	"""Retourne un titre par défaut selon le type"""
	match type:
		NotificationType.INFO:
			return "Information"
		NotificationType.SUCCESS:
			return "Succès"
		NotificationType.WARNING:
			return "Attention"
		NotificationType.ERROR:
			return "Erreur"
		NotificationType.ACHIEVEMENT:
			return "Achievement"
		_:
			return "Notification"

func _generate_notification_id() -> String:
	"""Génère un ID unique pour une notification"""
	return "notif_" + str(Time.get_unix_time_from_system()) + "_" + str(randi())

# Gestionnaires d'événements du jeu
func _on_member_recruited(member):
	"""Quand un membre est recruté"""
	show_success("%s a rejoint la guilde !" % member.nom, "Nouveau membre")

func _on_member_left(member):
	"""Quand un membre quitte"""
	show_warning("%s a quitté la guilde." % member.nom, "Membre parti")

func _on_guild_level_up(new_level):
	"""Quand la guilde monte de niveau"""
	show_achievement("La guilde a atteint le niveau %d !" % new_level, "Level Up!")

# Nouveaux gestionnaires d'événements
func _on_phase_changed(new_phase, _old_phase):
	"""Quand la phase du jeu change"""
	var phase_name := str(new_phase)
	if PhaseManager and PhaseManager.has_method("get_phase_name"):
		phase_name = PhaseManager.get_phase_name(new_phase)
	show_info("Nouvelle phase : %s" % phase_name, "Phase changée")

func _on_progression_updated(phase, progress):
	"""Quand la progression d'une phase est mise à jour"""
	# progress peut être un Dictionary contenant différentes métriques
	if typeof(progress) == TYPE_DICTIONARY:
		# Vérifier s'il y a une progression globale
		if progress.has("completion") and progress.completion >= 1.0:
			show_success("Phase %s terminée !" % phase, "Progression")
		elif progress.has("percentage") and progress.percentage >= 100:
			show_success("Phase %s terminée !" % phase, "Progression")
	elif typeof(progress) == TYPE_FLOAT or typeof(progress) == TYPE_INT:
		if progress >= 1.0:
			show_success("Phase %s terminée !" % phase, "Progression")

func _on_member_connected(member):
	"""Quand un membre se connecte"""
	show_info("%s s'est connecté." % member.nom, "Connexion")

func _on_member_disconnected(member):
	"""Quand un membre se déconnecte"""
	show_info("%s s'est déconnecté." % member.nom, "Déconnexion")

func _on_activity_completed(player, activity):
	"""Quand une activité est terminée"""
	match activity.type:
		"dungeon":
			show_success("%s a terminé %s" % [player.nom, activity.name], "Donjon terminé")
		"raid":
			show_success("%s a terminé %s" % [player.nom, activity.name], "Raid terminé")
		"leveling":
			if player.personnage_niveau % 5 == 0:  # Notification tous les 5 niveaux
				show_info("%s a atteint le niveau %d !" % [player.nom, player.personnage_niveau], "Level Up")

func _on_dungeon_started(dungeon_instance):
	"""Quand un donjon commence"""
	var group_names = []
	for member in dungeon_instance.group_members:
		group_names.append(member.nom)
	# DungeonInstance expose dungeon_data (Dictionary), pas instance_data
	show_info("Donjon %s démarré avec : %s" % [dungeon_instance.dungeon_data.get("name", "Donjon"), ", ".join(group_names)], "Donjon démarré")

func _on_dungeon_ended(dungeon_instance):
	"""Quand un donjon se termine"""
	var total: int = dungeon_instance.dungeon_data.get("bosses", []).size()
	var defeated: int = dungeon_instance.current_boss_index
	var dname: String = dungeon_instance.dungeon_data.get("name", "Donjon")
	var success: bool = total > 0 and defeated >= total
	if success:
		show_success("Donjon %s terminé avec succès !" % dname, "Victoire!")
	else:
		show_warning("Donjon %s échoué (%d/%d boss vaincus)" % [dname, defeated, total], "Défaite")

func _on_recruitment_pool_updated(_pool):
	"""Quand le pool de recrutement est mis à jour"""
	show_info("Nouveaux candidats disponibles !", "Recrutement")

func _on_random_event_triggered(event):
	"""Quand un événement aléatoire se déclenche"""
	show_warning(event.description, "Événement : %s" % event.title)
