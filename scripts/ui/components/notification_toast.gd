extends PanelContainer
class_name NotificationToast

# Composant de notification toast individuel
# Géré par NotificationManager, ne pas instancier directement

# Types de notification
enum Type {
	INFO,
	SUCCESS,
	WARNING,
	ERROR,
	ACHIEVEMENT
}

# Configuration
var notification_data: Dictionary = {}
var auto_dismiss_time: float = 3.0
var is_dismissing: bool = false

# Éléments UI
var icon_label: Label
var title_label: Label
var message_label: Label
var close_button: Button
var progress_bar: ProgressBar

# Timer
var dismiss_timer: Timer

# Signaux
signal dismissed()
signal clicked()

# Couleurs par type
const TYPE_COLORS = {
	Type.INFO: Color(0.2, 0.6, 0.9, 0.95),
	Type.SUCCESS: Color(0.3, 0.8, 0.3, 0.95),
	Type.WARNING: Color(0.9, 0.7, 0.2, 0.95),
	Type.ERROR: Color(0.9, 0.3, 0.3, 0.95),
	Type.ACHIEVEMENT: Color(0.8, 0.4, 0.9, 0.95)
}

# Icônes par type
const TYPE_ICONS = {
	Type.INFO: "ℹ",
	Type.SUCCESS: "✓",
	Type.WARNING: "⚠",
	Type.ERROR: "✗",
	Type.ACHIEVEMENT: "★"
}

func _ready():
	_setup_ui()
	_setup_timer()
	_apply_notification_data()
	_animate_entrance()

func _setup_ui():
	"""Configure la structure UI du toast"""
	custom_minimum_size = Vector2(350, 80)
	size_flags_horizontal = Control.SIZE_SHRINK_END
	
	# Container horizontal principal
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	add_child(hbox)
	
	# Icône
	icon_label = Label.new()
	icon_label.add_theme_font_size_override("font_size", 24)
	icon_label.add_theme_color_override("font_color", Color.WHITE)
	icon_label.custom_minimum_size = Vector2(32, 32)
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(icon_label)
	
	# Container vertical pour titre et message
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)
	
	# Titre
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title_label)
	
	# Message
	message_label = Label.new()
	message_label.add_theme_font_size_override("font_size", 12)
	message_label.add_theme_color_override("font_color", Color.WHITE.darkened(0.1))
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Largeur de wrap fixe : sans ça, la taille minimale d'un Label autowrap suppose un
	# retour à la ligne au mot le plus étroit -> hauteur géante (toast plein écran).
	message_label.custom_minimum_size = Vector2(250, 0)
	message_label.size_flags_horizontal = Control.SIZE_FILL
	vbox.add_child(message_label)
	
	# Barre de progression du timer (en bas)
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 3)
	progress_bar.show_percentage = false
	progress_bar.modulate = Color(1, 1, 1, 0.3)
	vbox.add_child(progress_bar)
	
	# Bouton fermer
	close_button = Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(24, 24)
	close_button.add_theme_font_size_override("font_size", 18)
	close_button.flat = true
	close_button.add_theme_color_override("font_color", Color.WHITE)
	close_button.pressed.connect(_on_close_pressed)
	hbox.add_child(close_button)
	
	# Interactions
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _setup_timer():
	"""Configure le timer de fermeture automatique"""
	dismiss_timer = Timer.new()
	dismiss_timer.one_shot = true
	dismiss_timer.timeout.connect(_on_timer_timeout)
	add_child(dismiss_timer)

func _apply_notification_data():
	"""Applique les données de notification"""
	if notification_data.is_empty():
		return
	
	var type = notification_data.get("type", Type.INFO)
	var title = notification_data.get("title", "Notification")
	var message = notification_data.get("text", "")
	var icon = notification_data.get("icon", TYPE_ICONS.get(type, "ℹ"))
	var color = notification_data.get("color", TYPE_COLORS.get(type, Color.WHITE))
	var duration = notification_data.get("duration", 3.0)
	
	# Appliquer les valeurs
	icon_label.text = icon
	title_label.text = title
	message_label.text = message
	auto_dismiss_time = duration
	
	# Style du panel
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 3
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = color.lightened(0.2)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)
	
	# Démarrer le timer si durée > 0
	if auto_dismiss_time > 0:
		dismiss_timer.wait_time = auto_dismiss_time
		dismiss_timer.start()
		
		# Configurer la barre de progression
		progress_bar.min_value = 0
		progress_bar.max_value = auto_dismiss_time
		progress_bar.value = auto_dismiss_time

func _animate_entrance():
	"""Animation d'apparition"""
	# Commencer hors écran à droite
	var original_pos = position
	position.x += size.x + 20
	modulate.a = 0.0
	
	# Animer vers la position finale
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:x", original_pos.x, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

func _animate_exit():
	"""Animation de sortie"""
	if is_dismissing:
		return
	
	is_dismissing = true
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:x", position.x + size.x + 20, 0.3).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.finished.connect(_on_animation_finished)

func _on_animation_finished():
	"""Appelé quand l'animation de sortie est terminée"""
	dismissed.emit()
	queue_free()

func _on_gui_input(event: InputEvent):
	"""Gère les interactions avec le toast"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			clicked.emit()
			# Optionnel: fermer après clic
			# dismiss()

func _on_mouse_entered():
	"""Pause le timer quand la souris survole"""
	if dismiss_timer and dismiss_timer.time_left > 0:
		dismiss_timer.paused = true
		progress_bar.modulate = Color(1, 1, 1, 0.5)

func _on_mouse_exited():
	"""Reprend le timer quand la souris quitte"""
	if dismiss_timer and dismiss_timer.time_left > 0:
		dismiss_timer.paused = false
		progress_bar.modulate = Color(1, 1, 1, 0.3)

func _on_close_pressed():
	"""Ferme le toast"""
	dismiss()

func _on_timer_timeout():
	"""Timer expiré, fermer le toast"""
	dismiss()

func _process(delta: float):
	"""Met à jour la barre de progression"""
	if dismiss_timer and not dismiss_timer.is_stopped() and auto_dismiss_time > 0:
		progress_bar.value = dismiss_timer.time_left

# ==================== API PUBLIQUE ====================

func setup(data: Dictionary):
	"""Configure le toast avec des données"""
	notification_data = data
	if is_inside_tree():
		_apply_notification_data()

func dismiss():
	"""Ferme le toast avec animation"""
	if not is_dismissing:
		_animate_exit()

func pause_timer():
	"""Met en pause le timer de fermeture"""
	if dismiss_timer:
		dismiss_timer.paused = true

func resume_timer():
	"""Reprend le timer de fermeture"""
	if dismiss_timer:
		dismiss_timer.paused = false

func set_progress(value: float):
	"""Définit manuellement la progression"""
	if progress_bar:
		progress_bar.value = value