extends Control
class_name StatDisplay

# Composant polyvalent pour afficher des statistiques avec icône, valeur, label et couleurs dynamiques
# Utilisé pour montrer HP, XP, niveau, équipement, etc.

# Configuration
@export var stat_name: String = "Stat" : set = set_stat_name
@export var current_value: float = 0.0 : set = set_current_value
@export var max_value: float = 100.0 : set = set_max_value
@export var display_mode: DisplayMode = DisplayMode.VALUE_ONLY : set = set_display_mode
@export var layout: Layout = Layout.HORIZONTAL : set = set_layout
@export var show_icon: bool = true : set = set_show_icon
@export var icon_texture: Texture2D : set = set_icon_texture
@export var icon_text: String = "" : set = set_icon_text  # Alternative à l'icône texture
@export var animate_changes: bool = true
@export var color_by_percentage: bool = true

# Modes d'affichage
enum DisplayMode {
	VALUE_ONLY,        # "75"
	VALUE_MAX,         # "75/100"
	PERCENTAGE,        # "75%"
	VALUE_PERCENTAGE,  # "75 (75%)"
	PROGRESS_BAR,      # Barre de progression + texte
	PROGRESS_ONLY,     # Barre de progression seulement
	CUSTOM            # Format personnalisé
}

# Layouts
enum Layout {
	HORIZONTAL,  # Icône - Texte côte à côte
	VERTICAL,    # Icône au-dessus du texte
	ICON_ONLY,   # Icône seulement
	TEXT_ONLY    # Texte seulement
}

# Configuration visuelle
@export var icon_size: Vector2 = Vector2(24, 24)
@export var font_size: int = 12
@export var spacing: int = 6
@export var custom_format: String = "{value}/{max}"
@export var progress_bar_height: int = 8
@export var show_progress_text: bool = true

# Couleurs dynamiques (par pourcentage)
@export var color_high: Color = Color(0.3, 0.8, 0.3)     # >70%
@export var color_medium: Color = Color(0.9, 0.7, 0.2)   # 30-70%
@export var color_low: Color = Color(0.9, 0.3, 0.3)      # <30%
@export var color_neutral: Color = Color(0.8, 0.8, 0.8)  # Couleur par défaut

# Éléments UI
var container: Container
var icon_element: Control
var text_label: Label
var progress_bar: ProgressBar
var animated_value: float = 0.0

# Animation
var value_tween: Tween

# Signaux
signal value_changed(old_value: float, new_value: float)
signal max_value_changed(old_max: float, new_max: float)
signal percentage_threshold_crossed(threshold: float)

func _ready():
	animated_value = current_value
	_create_ui()
	_update_display()

func _create_ui():
	"""Crée la structure UI selon le layout"""
	
	# Nettoyer les enfants existants
	for child in get_children():
		child.queue_free()
	
	# Créer le container principal selon le layout
	match layout:
		Layout.HORIZONTAL:
			container = HBoxContainer.new()
			container.add_theme_constant_override("separation", spacing)
		Layout.VERTICAL:
			container = VBoxContainer.new()
			container.add_theme_constant_override("separation", spacing)
		Layout.ICON_ONLY, Layout.TEXT_ONLY:
			container = Control.new()
	
	add_child(container)
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Créer l'icône si nécessaire
	if show_icon and layout != Layout.TEXT_ONLY:
		_create_icon()
	
	# Créer le texte si nécessaire
	if layout != Layout.ICON_ONLY:
		_create_text_elements()

func _create_icon():
	"""Crée l'élément icône"""
	
	if icon_texture:
		# Icône texture
		var texture_rect = TextureRect.new()
		texture_rect.texture = icon_texture
		texture_rect.custom_minimum_size = icon_size
		texture_rect.size = icon_size
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_element = texture_rect
	else:
		# Icône texte (caractère Unicode ou emoji)
		var icon_label = Label.new()
		icon_label.text = icon_text if icon_text != "" else "★"
		icon_label.add_theme_font_size_override("font_size", int(icon_size.x * 0.8))
		icon_label.custom_minimum_size = icon_size
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_element = icon_label
	
	container.add_child(icon_element)

func _create_text_elements():
	"""Crée les éléments texte"""
	
	# Container pour texte (peut contenir label + progress bar)
	var text_container: Container
	
	if display_mode == DisplayMode.PROGRESS_BAR and layout == Layout.HORIZONTAL:
		text_container = VBoxContainer.new()
		text_container.add_theme_constant_override("separation", 2)
	else:
		text_container = Control.new()
	
	container.add_child(text_container)
	
	# Label principal
	text_label = Label.new()
	text_label.add_theme_font_size_override("font_size", font_size)
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	if display_mode in [DisplayMode.PROGRESS_BAR, DisplayMode.PROGRESS_ONLY]:
		# Créer la barre de progression
		progress_bar = ProgressBar.new()
		progress_bar.custom_minimum_size = Vector2(100, progress_bar_height)
		progress_bar.show_percentage = show_progress_text and display_mode == DisplayMode.PROGRESS_BAR
		
		if display_mode == DisplayMode.PROGRESS_BAR:
			text_container.add_child(text_label)
			text_container.add_child(progress_bar)
		else:
			container.add_child(progress_bar)
	else:
		if layout == Layout.VERTICAL:
			text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text_container.add_child(text_label)

# ==================== SETTERS ====================

func set_stat_name(new_name: String):
	stat_name = new_name
	if is_inside_tree():
		_update_display()

func set_current_value(new_value: float):
	var old_value = current_value
	current_value = max(0.0, new_value)
	
	if animate_changes and is_inside_tree():
		_animate_to_value(current_value)
	else:
		animated_value = current_value
		if is_inside_tree():
			_update_display()
	
	value_changed.emit(old_value, current_value)
	
	# Vérifier les seuils de pourcentage
	if max_value > 0:
		var old_percentage = (old_value / max_value) * 100.0
		var new_percentage = (current_value / max_value) * 100.0
		
		var thresholds = [70.0, 30.0]
		for threshold in thresholds:
			if (old_percentage >= threshold) != (new_percentage >= threshold):
				percentage_threshold_crossed.emit(threshold)

func set_max_value(new_max: float):
	var old_max = max_value
	max_value = max(0.1, new_max)
	
	if progress_bar:
		progress_bar.min_value = 0
		progress_bar.max_value = max_value
	
	if is_inside_tree():
		_update_display()
	
	max_value_changed.emit(old_max, max_value)

func set_display_mode(new_mode: DisplayMode):
	display_mode = new_mode
	if is_inside_tree():
		_create_ui()
		_update_display()

func set_layout(new_layout: Layout):
	layout = new_layout
	if is_inside_tree():
		_create_ui()
		_update_display()

func set_show_icon(show: bool):
	show_icon = show
	if is_inside_tree():
		_create_ui()
		_update_display()

func set_icon_texture(texture: Texture2D):
	icon_texture = texture
	if is_inside_tree() and icon_element is TextureRect:
		(icon_element as TextureRect).texture = texture

func set_icon_text(text: String):
	icon_text = text
	if is_inside_tree() and icon_element is Label:
		(icon_element as Label).text = text

# ==================== API PUBLIQUE ====================

func add_value(delta: float):
	"""Ajoute une valeur à la valeur actuelle"""
	set_current_value(current_value + delta)

func subtract_value(delta: float):
	"""Soustrait une valeur de la valeur actuelle"""
	set_current_value(current_value - delta)

func set_values(current: float, maximum: float):
	"""Définit les deux valeurs en même temps"""
	set_max_value(maximum)
	set_current_value(current)

func get_percentage() -> float:
	"""Retourne le pourcentage actuel (0.0 à 100.0)"""
	if max_value <= 0:
		return 0.0
	return (current_value / max_value) * 100.0

func get_progress() -> float:
	"""Retourne le progrès actuel (0.0 à 1.0)"""
	if max_value <= 0:
		return 0.0
	return current_value / max_value

func is_full() -> bool:
	"""Vérifie si la valeur est au maximum"""
	return current_value >= max_value

func is_empty() -> bool:
	"""Vérifie si la valeur est à zéro"""
	return current_value <= 0.0

func pulse():
	"""Effet de pulsation pour attirer l'attention"""
	if value_tween:
		value_tween.kill()
	
	value_tween = create_tween()
	value_tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.15)
	value_tween.tween_property(self, "scale", Vector2.ONE, 0.15)

func flash_color(color: Color, duration: float = 0.3):
	"""Flash avec une couleur spécifique"""
	var original_modulate = modulate
	var tween = create_tween()
	tween.tween_property(self, "modulate", color, duration * 0.5)
	tween.tween_property(self, "modulate", original_modulate, duration * 0.5)

# ==================== MÉTHODES PRIVÉES ====================

func _animate_to_value(target_value: float):
	"""Anime la valeur vers une cible"""
	if value_tween:
		value_tween.kill()
	
	value_tween = create_tween()
	value_tween.tween_property(self, "animated_value", target_value, 0.3)
	value_tween.tween_callback(_update_display)

func _update_display():
	"""Met à jour l'affichage visuel"""
	
	# Mettre à jour le texte
	if text_label:
		text_label.text = _get_formatted_text()
		
		# Couleur dynamique
		if color_by_percentage:
			text_label.add_theme_color_override("font_color", _get_color_for_percentage())
		else:
			text_label.add_theme_color_override("font_color", color_neutral)
	
	# Mettre à jour la barre de progression
	if progress_bar:
		progress_bar.min_value = 0
		progress_bar.max_value = max_value
		progress_bar.value = animated_value
		
		if color_by_percentage:
			var color = _get_color_for_percentage()
			# Appliquer la couleur via modulate
			progress_bar.modulate = color

func _get_formatted_text() -> String:
	"""Retourne le texte formaté selon le mode d'affichage"""
	
	var value_int = int(animated_value)
	var max_int = int(max_value)
	var percentage = get_percentage()
	
	match display_mode:
		DisplayMode.VALUE_ONLY:
			return str(value_int)
		DisplayMode.VALUE_MAX:
			return "%d/%d" % [value_int, max_int]
		DisplayMode.PERCENTAGE:
			return "%.1f%%" % percentage
		DisplayMode.VALUE_PERCENTAGE:
			return "%d (%.1f%%)" % [value_int, percentage]
		DisplayMode.PROGRESS_BAR:
			return stat_name if stat_name != "" else "Progress"
		DisplayMode.PROGRESS_ONLY:
			return ""
		DisplayMode.CUSTOM:
			return custom_format.format({
				"name": stat_name,
				"value": value_int,
				"max": max_int,
				"percentage": "%.1f" % percentage
			})
		_:
			return str(value_int)

func _get_color_for_percentage() -> Color:
	"""Retourne la couleur selon le pourcentage"""
	var percentage = get_percentage()
	
	if percentage >= 70.0:
		return color_high
	elif percentage >= 30.0:
		return color_medium
	else:
		return color_low

# ==================== MÉTHODES UTILITAIRES STATIQUES ====================

static func create_health_display(current_hp: int, max_hp: int, parent: Node) -> StatDisplay:
	"""Crée un affichage de santé"""
	var stat = StatDisplay.new()
	stat.stat_name = "HP"
	stat.icon_text = "♥"
	stat.display_mode = DisplayMode.VALUE_MAX
	stat.layout = Layout.HORIZONTAL
	stat.set_values(current_hp, max_hp)
	stat.color_high = Color(0.3, 0.8, 0.3)
	stat.color_medium = Color(0.9, 0.7, 0.2)
	stat.color_low = Color(0.9, 0.3, 0.3)
	parent.add_child(stat)
	return stat

static func create_experience_display(current_xp: int, xp_to_next: int, parent: Node) -> StatDisplay:
	"""Crée un affichage d'expérience avec barre"""
	var stat = StatDisplay.new()
	stat.stat_name = "XP"
	stat.icon_text = "★"
	stat.display_mode = DisplayMode.PROGRESS_BAR
	stat.layout = Layout.HORIZONTAL
	stat.set_values(current_xp, xp_to_next)
	stat.color_high = Color(0.4, 0.7, 1.0)
	stat.color_medium = Color(0.4, 0.7, 1.0)
	stat.color_low = Color(0.4, 0.7, 1.0)
	parent.add_child(stat)
	return stat

static func create_level_display(level: int, parent: Node) -> StatDisplay:
	"""Crée un affichage de niveau"""
	var stat = StatDisplay.new()
	stat.stat_name = "Niveau"
	stat.icon_text = "Lv"
	stat.display_mode = DisplayMode.VALUE_ONLY
	stat.layout = Layout.HORIZONTAL
	stat.set_values(level, level)
	stat.color_by_percentage = false
	parent.add_child(stat)
	return stat

static func create_equipment_display(ilvl: int, parent: Node) -> StatDisplay:
	"""Crée un affichage d'équipement"""
	var stat = StatDisplay.new()
	stat.stat_name = "iLvl"
	stat.icon_text = "⚔"
	stat.display_mode = DisplayMode.VALUE_ONLY
	stat.layout = Layout.HORIZONTAL
	stat.set_values(ilvl, 100)  # Max hypothétique
	stat.color_by_percentage = false
	parent.add_child(stat)
	return stat

# ==================== CONFIGURATIONS PRÉDÉFINIES ====================

func setup_for_health(current_hp: int, max_hp: int):
	"""Configuration prédéfinie pour la santé"""
	stat_name = "HP"
	icon_text = "♥"
	display_mode = DisplayMode.VALUE_MAX
	layout = Layout.HORIZONTAL
	set_values(current_hp, max_hp)

func setup_for_experience(current_xp: int, xp_needed: int):
	"""Configuration prédéfinie pour l'expérience"""
	stat_name = "XP"
	icon_text = "★"
	display_mode = DisplayMode.PROGRESS_BAR
	layout = Layout.HORIZONTAL
	set_values(current_xp, xp_needed)

func setup_for_level(level: int):
	"""Configuration prédéfinie pour le niveau"""
	stat_name = "Niveau"
	icon_text = "Lv"
	display_mode = DisplayMode.VALUE_ONLY
	layout = Layout.HORIZONTAL
	color_by_percentage = false
	set_values(level, level)

func setup_for_equipment(ilvl: int):
	"""Configuration prédéfinie pour l'équipement"""
	stat_name = "iLvl"
	icon_text = "⚔"
	display_mode = DisplayMode.VALUE_ONLY
	layout = Layout.HORIZONTAL
	color_by_percentage = false
	set_values(ilvl, 100)

func setup_for_percentage_stat(stat_name_param: String, value: float, icon_param: String = "●"):
	"""Configuration pour une statistique en pourcentage"""
	stat_name = stat_name_param
	icon_text = icon_param
	display_mode = DisplayMode.PERCENTAGE
	layout = Layout.HORIZONTAL
	set_values(value, 100.0)