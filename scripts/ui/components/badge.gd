extends Control
class_name Badge

# Badge personnalisé avec différents styles, couleurs et animations
# Utilisé pour afficher des indicateurs visuels (tags, statuts, compteurs, etc.)

# Configuration
@export var text: String = "Badge" : set = set_text
@export var badge_type: BadgeType = BadgeType.DEFAULT : set = set_badge_type
@export var badge_size: BadgeSize = BadgeSize.NORMAL : set = set_badge_size
@export var show_close_button: bool = false : set = set_show_close_button
@export var clickable: bool = false : set = set_clickable
@export var animate_appearance: bool = true
@export var auto_size: bool = true

# Types de badges
enum BadgeType {
	DEFAULT,    # Gris neutre
	PRIMARY,    # Bleu principal
	SUCCESS,    # Vert succès
	WARNING,    # Jaune/Orange attention
	ERROR,      # Rouge erreur
	INFO,       # Bleu information
	TAG,        # Violet pour les tags de joueur
	COUNTER,    # Style spécial pour les compteurs
	STATUS      # Style pour les statuts (connecté/déconnecté)
}

# Tailles de badges
enum BadgeSize {
	SMALL,
	NORMAL,
	LARGE
}

# Couleurs par type
const BADGE_COLORS = {
	BadgeType.DEFAULT: Color(0.5, 0.5, 0.5, 0.9),
	BadgeType.PRIMARY: Color(0.2, 0.6, 0.9, 0.9),
	BadgeType.SUCCESS: Color(0.3, 0.8, 0.3, 0.9),
	BadgeType.WARNING: Color(0.9, 0.7, 0.2, 0.9),
	BadgeType.ERROR: Color(0.9, 0.3, 0.3, 0.9),
	BadgeType.INFO: Color(0.4, 0.7, 1.0, 0.9),
	BadgeType.TAG: Color(0.7, 0.4, 0.9, 0.9),
	BadgeType.COUNTER: Color(0.6, 0.3, 0.3, 0.95),
	BadgeType.STATUS: Color(0.3, 0.6, 0.3, 0.9)
}

# Configurations de tailles
const SIZE_CONFIGS = {
	BadgeSize.SMALL: {
		"font_size": 10,
		"padding_h": 6,
		"padding_v": 2,
		"height": 18,
		"corner_radius": 9
	},
	BadgeSize.NORMAL: {
		"font_size": 12,
		"padding_h": 8,
		"padding_v": 4,
		"height": 24,
		"corner_radius": 12
	},
	BadgeSize.LARGE: {
		"font_size": 14,
		"padding_h": 12,
		"padding_v": 6,
		"height": 32,
		"corner_radius": 16
	}
}

# Éléments UI
var background_panel: PanelContainer
var content_container: HBoxContainer
var text_label: Label
var close_button: Button
var current_tween: Tween

# État interne
var current_color: Color
var is_hovered: bool = false
var is_pressed: bool = false

# Signaux
signal clicked()
signal close_requested()
signal hovered()
signal unhovered()

func _ready():
	_create_ui()
	_apply_styling()
	_setup_interactions()
	
	if animate_appearance:
		_animate_appear()

func _create_ui():
	"""Crée la structure UI du badge"""
	
	# Panel de fond
	background_panel = PanelContainer.new()
	add_child(background_panel)
	
	# Container horizontal pour le contenu
	content_container = HBoxContainer.new()
	content_container.add_theme_constant_override("separation", 4)
	background_panel.add_child(content_container)
	
	# Label pour le texte
	text_label = Label.new()
	text_label.text = text
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_container.add_child(text_label)
	
	# Bouton fermer (optionnel)
	if show_close_button:
		_create_close_button()

func _create_close_button():
	"""Crée le bouton de fermeture"""
	close_button = Button.new()
	close_button.text = "×"
	close_button.flat = true
	close_button.custom_minimum_size = Vector2(16, 16)
	close_button.pressed.connect(_on_close_pressed)
	content_container.add_child(close_button)

func _apply_styling():
	"""Applique le style visuel au badge"""
	
	var size_config = SIZE_CONFIGS[badge_size]
	current_color = BADGE_COLORS[badge_type]
	
	# Style du panel de fond
	var style = StyleBoxFlat.new()
	style.bg_color = current_color
	style.corner_radius_top_left = size_config.corner_radius
	style.corner_radius_top_right = size_config.corner_radius
	style.corner_radius_bottom_left = size_config.corner_radius
	style.corner_radius_bottom_right = size_config.corner_radius
	style.content_margin_left = size_config.padding_h
	style.content_margin_right = size_config.padding_h
	style.content_margin_top = size_config.padding_v
	style.content_margin_bottom = size_config.padding_v
	
	# Ajouter une bordure subtile
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = current_color.lightened(0.2)
	
	background_panel.add_theme_stylebox_override("panel", style)
	
	# Style du texte
	text_label.add_theme_font_size_override("font_size", size_config.font_size)
	text_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Style du bouton fermer
	if close_button:
		close_button.add_theme_font_size_override("font_size", size_config.font_size - 2)
		close_button.add_theme_color_override("font_color", Color.WHITE.darkened(0.2))
	
	# Taille du badge
	custom_minimum_size = Vector2(0, size_config.height)
	
	if auto_size:
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER

func _setup_interactions():
	"""Configure les interactions souris"""
	
	if clickable:
		mouse_filter = Control.MOUSE_FILTER_PASS
		gui_input.connect(_on_gui_input)
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

# ==================== SETTERS ====================

func set_text(new_text: String):
	text = new_text
	if text_label:
		text_label.text = text

func set_badge_type(new_type: BadgeType):
	badge_type = new_type
	if is_inside_tree():
		_apply_styling()

func set_badge_size(new_size: BadgeSize):
	badge_size = new_size
	if is_inside_tree():
		_apply_styling()

func set_show_close_button(show: bool):
	show_close_button = show
	if is_inside_tree():
		if show and not close_button:
			_create_close_button()
		elif not show and close_button:
			close_button.queue_free()
			close_button = null

func set_clickable(is_clickable: bool):
	clickable = is_clickable
	if is_inside_tree():
		_setup_interactions()

# ==================== API PUBLIQUE ====================

func update_text(new_text: String):
	"""Met à jour le texte du badge"""
	set_text(new_text)

func update_type(new_type: BadgeType):
	"""Met à jour le type du badge avec animation"""
	if current_tween:
		current_tween.kill()
	
	var old_color = current_color
	badge_type = new_type
	var new_color = BADGE_COLORS[badge_type]
	
	# Animation de transition de couleur
	current_tween = create_tween()
	current_tween.tween_method(_animate_color, old_color, new_color, 0.3)
	current_tween.finished.connect(func(): _apply_styling())

func pulse():
	"""Effet de pulsation pour attirer l'attention"""
	if current_tween:
		current_tween.kill()
	
	current_tween = create_tween()
	current_tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.15)
	current_tween.tween_property(self, "scale", Vector2.ONE, 0.15)

func flash(color: Color = Color.WHITE, duration: float = 0.2):
	"""Effet de flash coloré"""
	if current_tween:
		current_tween.kill()
	
	var original_modulate = modulate
	current_tween = create_tween()
	current_tween.tween_property(self, "modulate", color, duration * 0.5)
	current_tween.tween_property(self, "modulate", original_modulate, duration * 0.5)

func fade_in(duration: float = 0.3):
	"""Animation d'apparition en fondu"""
	modulate.a = 0.0
	visible = true
	
	if current_tween:
		current_tween.kill()
	
	current_tween = create_tween()
	current_tween.tween_property(self, "modulate:a", 1.0, duration)

func fade_out(duration: float = 0.3, hide_after: bool = true):
	"""Animation de disparition en fondu"""
	if current_tween:
		current_tween.kill()
	
	current_tween = create_tween()
	current_tween.tween_property(self, "modulate:a", 0.0, duration)
	if hide_after:
		current_tween.finished.connect(func(): visible = false)

func get_display_text() -> String:
	"""Retourne le texte affiché"""
	return text

func is_close_button_visible() -> bool:
	"""Vérifie si le bouton fermer est visible"""
	return show_close_button and close_button != null

# ==================== MÉTHODES PRIVÉES ====================

func _animate_appear():
	"""Animation d'apparition du badge"""
	scale = Vector2.ZERO
	modulate.a = 0.0
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)

func _animate_color(color: Color):
	"""Animation de changement de couleur"""
	current_color = color
	var style = background_panel.get_theme_stylebox("panel").duplicate()
	style.bg_color = color
	style.border_color = color.lightened(0.2)
	background_panel.add_theme_stylebox_override("panel", style)

func _on_gui_input(event: InputEvent):
	"""Gère les événements de souris"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_pressed = true
				_update_hover_state()
			else:
				if is_pressed and is_hovered:
					clicked.emit()
				is_pressed = false
				_update_hover_state()

func _on_mouse_entered():
	"""Souris entre dans le badge"""
	is_hovered = true
	_update_hover_state()
	hovered.emit()

func _on_mouse_exited():
	"""Souris sort du badge"""
	is_hovered = false
	is_pressed = false
	_update_hover_state()
	unhovered.emit()

func _update_hover_state():
	"""Met à jour l'apparence selon l'état hover/pressed"""
	if not background_panel:
		return
	
	var style = background_panel.get_theme_stylebox("panel").duplicate()
	
	if is_pressed:
		style.bg_color = current_color.darkened(0.2)
		scale = Vector2(0.95, 0.95)
	elif is_hovered:
		style.bg_color = current_color.lightened(0.1)
		scale = Vector2(1.05, 1.05)
	else:
		style.bg_color = current_color
		scale = Vector2.ONE
	
	background_panel.add_theme_stylebox_override("panel", style)

func _on_close_pressed():
	"""Bouton fermer pressé"""
	close_requested.emit()

# ==================== MÉTHODES UTILITAIRES ====================

static func create_tag_badge(tag_text: String, parent: Node) -> Badge:
	"""Crée un badge de tag de joueur"""
	var badge = Badge.new()
	badge.text = tag_text
	badge.badge_type = BadgeType.TAG
	badge.badge_size = BadgeSize.SMALL
	badge.clickable = true
	badge.show_close_button = false
	parent.add_child(badge)
	return badge

static func create_counter_badge(count: int, parent: Node) -> Badge:
	"""Crée un badge compteur"""
	var badge = Badge.new()
	badge.text = str(count)
	badge.badge_type = BadgeType.COUNTER
	badge.badge_size = BadgeSize.SMALL
	badge.auto_size = true
	parent.add_child(badge)
	return badge

static func create_status_badge(is_online: bool, parent: Node) -> Badge:
	"""Crée un badge de statut en ligne/hors ligne"""
	var badge = Badge.new()
	badge.text = "●"  # Caractère cercle
	badge.badge_type = BadgeType.SUCCESS if is_online else BadgeType.ERROR
	badge.badge_size = BadgeSize.SMALL
	badge.auto_size = false
	badge.custom_minimum_size = Vector2(16, 16)
	parent.add_child(badge)
	return badge

# ==================== MÉTHODES POUR LES CAS D'USAGE SPÉCIFIQUES ====================

func setup_for_player_tag(tag_name: String, removable: bool = false):
	"""Configuration spéciale pour les tags de joueur"""
	update_text(tag_name)
	update_type(BadgeType.TAG)
	set_badge_size(BadgeSize.SMALL)
	set_show_close_button(removable)
	set_clickable(true)

func setup_for_notification_count(count: int):
	"""Configuration spéciale pour les compteurs de notifications"""
	update_text(str(count))
	update_type(BadgeType.COUNTER)
	set_badge_size(BadgeSize.SMALL)
	if count == 0:
		visible = false
	else:
		visible = true

func setup_for_connection_status(is_connected: bool):
	"""Configuration spéciale pour le statut de connexion"""
	update_text("●")
	update_type(BadgeType.SUCCESS if is_connected else BadgeType.ERROR)
	set_badge_size(BadgeSize.SMALL)
	custom_minimum_size = Vector2(12, 12)

# ==================== ANIMATIONS AVANCÉES ====================

func bounce():
	"""Animation de rebond"""
	if current_tween:
		current_tween.kill()
	
	current_tween = create_tween()
	current_tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
	current_tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.1)
	current_tween.tween_property(self, "scale", Vector2.ONE, 0.1)

func shake():
	"""Animation de secousse pour attirer l'attention"""
	if current_tween:
		current_tween.kill()
	
	var original_pos = position
	current_tween = create_tween()
	for i in range(6):
		var offset = Vector2(randf_range(-2, 2), randf_range(-2, 2))
		current_tween.tween_property(self, "position", original_pos + offset, 0.05)
	current_tween.tween_property(self, "position", original_pos, 0.05)