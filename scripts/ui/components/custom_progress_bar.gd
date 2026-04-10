extends Control
class_name CustomProgressBar

# ProgressBar personnalisée avec segments, animations et couleurs dynamiques

# Configuration
@export var min_value: float = 0.0
@export var max_value: float = 100.0
@export var current_value: float = 0.0
@export var segment_count: int = 1  # Nombre de segments
@export var show_text: bool = true
@export var text_format: String = "%d/%d"  # Format du texte
@export var show_percentage: bool = false
@export var animate_changes: bool = true
@export var animation_duration: float = 0.5

# Couleurs par seuil (en pourcentage)
@export var color_good: Color = Color(0.3, 0.8, 0.3)  # Vert > 70%
@export var color_medium: Color = Color(0.9, 0.7, 0.2)  # Jaune 30-70%
@export var color_bad: Color = Color(0.9, 0.3, 0.3)  # Rouge < 30%
@export var color_background: Color = Color(0.2, 0.2, 0.2, 0.8)
@export var color_border: Color = Color(0.4, 0.4, 0.4)

# Configuration visuelle
@export var bar_height: int = 20
@export var border_width: int = 1
@export var segment_spacing: int = 2
@export var corner_radius: int = 4

# État interne
var displayed_value: float = 0.0
var tween: Tween
var text_label: Label

# Signaux
signal value_changed(new_value: float, old_value: float)
signal animation_finished()

func _ready():
	custom_minimum_size = Vector2(100, bar_height + 20)  # +20 pour le texte
	_setup_ui()
	_update_display()

func _setup_ui():
	"""Configure les éléments UI"""
	if show_text:
		text_label = Label.new()
		text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text_label.add_theme_font_size_override("font_size", 12)
		text_label.add_theme_color_override("font_color", Color.WHITE)
		add_child(text_label)
		
		# Positionner le label
		text_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		text_label.size.y = 16
		text_label.position.y = bar_height + 2

func _draw():
	"""Dessine la barre de progression"""
	var bar_rect = Rect2(Vector2.ZERO, Vector2(size.x, bar_height))
	
	# Fond
	draw_rect(bar_rect, color_background, true, -1)
	
	# Bordure
	if border_width > 0:
		draw_rect(bar_rect, color_border, false, border_width)
	
	# Barre de progression
	if max_value > min_value and displayed_value > min_value:
		var progress = (displayed_value - min_value) / (max_value - min_value)
		var fill_width = (size.x - 2 * border_width) * progress
		
		if fill_width > 0:
			var fill_rect = Rect2(
				Vector2(border_width, border_width), 
				Vector2(fill_width, bar_height - 2 * border_width)
			)
			
			var fill_color = _get_color_for_progress(progress)
			draw_rect(fill_rect, fill_color, true, -1)
	
	# Segments (lignes de séparation)
	if segment_count > 1:
		_draw_segments(bar_rect)

func _draw_segments(bar_rect: Rect2):
	"""Dessine les lignes de séparation des segments"""
	var segment_width = (size.x - 2 * border_width) / segment_count
	
	for i in range(1, segment_count):
		var x_pos = border_width + i * segment_width
		var line_start = Vector2(x_pos, border_width)
		var line_end = Vector2(x_pos, bar_height - border_width)
		
		draw_line(line_start, line_end, color_border, segment_spacing)

func _get_color_for_progress(progress: float) -> Color:
	"""Retourne la couleur selon le pourcentage de progression"""
	var percentage = progress * 100.0
	
	if percentage >= 70.0:
		return color_good
	elif percentage >= 30.0:
		return color_medium
	else:
		return color_bad

# ==================== API PUBLIQUE ====================

func set_value(new_value: float):
	"""Définit une nouvelle valeur avec animation optionnelle"""
	var old_value = current_value
	current_value = clamp(new_value, min_value, max_value)
	
	if animate_changes and is_inside_tree():
		_animate_to_value(current_value)
	else:
		displayed_value = current_value
		_update_display()
	
	value_changed.emit(current_value, old_value)

func set_value_immediate(new_value: float):
	"""Définit une nouvelle valeur sans animation"""
	var old_value = current_value
	current_value = clamp(new_value, min_value, max_value)
	displayed_value = current_value
	_update_display()
	value_changed.emit(current_value, old_value)

func get_value() -> float:
	"""Retourne la valeur actuelle"""
	return current_value

func get_progress() -> float:
	"""Retourne le pourcentage de progression (0.0 à 1.0)"""
	if max_value <= min_value:
		return 0.0
	return (current_value - min_value) / (max_value - min_value)

func get_progress_percentage() -> float:
	"""Retourne le pourcentage de progression (0.0 à 100.0)"""
	return get_progress() * 100.0

func set_range(new_min: float, new_max: float):
	"""Définit une nouvelle plage de valeurs"""
	min_value = new_min
	max_value = new_max
	current_value = clamp(current_value, min_value, max_value)
	displayed_value = clamp(displayed_value, min_value, max_value)
	_update_display()

func set_segments(count: int):
	"""Définit le nombre de segments"""
	segment_count = max(1, count)
	queue_redraw()

func set_colors(good: Color, medium: Color, bad: Color):
	"""Définit les couleurs par seuil"""
	color_good = good
	color_medium = medium
	color_bad = bad
	queue_redraw()

func set_text_format(format: String):
	"""Définit le format du texte"""
	text_format = format
	_update_text()

func add_value(delta: float):
	"""Ajoute une valeur à la valeur actuelle"""
	set_value(current_value + delta)

func subtract_value(delta: float):
	"""Soustrait une valeur de la valeur actuelle"""
	set_value(current_value - delta)

func is_full() -> bool:
	"""Vérifie si la barre est pleine"""
	return current_value >= max_value

func is_empty() -> bool:
	"""Vérifie si la barre est vide"""
	return current_value <= min_value

func reset():
	"""Remet la barre à zéro"""
	set_value(min_value)

func fill():
	"""Remplit complètement la barre"""
	set_value(max_value)

# ==================== ANIMATIONS ====================

func _animate_to_value(target_value: float):
	"""Anime la progression vers une valeur cible"""
	if tween:
		tween.kill()
	
	tween = create_tween()
	tween.tween_property(self, "displayed_value", target_value, animation_duration)
	tween.tween_callback(_on_animation_finished)

func _on_animation_finished():
	"""Appelée quand l'animation est terminée"""
	animation_finished.emit()

# ==================== MISE À JOUR AFFICHAGE ====================

func _update_display():
	"""Met à jour l'affichage visuel"""
	queue_redraw()
	_update_text()

func _update_text():
	"""Met à jour le texte affiché"""
	if not text_label:
		return
	
	var text = ""
	
	if show_percentage:
		text = "%.1f%%" % get_progress_percentage()
	else:
		if text_format.find("%d") != -1:
			text = text_format % [int(current_value), int(max_value)]
		elif text_format.find("%.1f") != -1:
			text = text_format % [current_value, max_value]
		else:
			text = text_format
	
	text_label.text = text

# ==================== PROPRIÉTÉS ANIMÉES ====================

func _set_displayed_value(value: float):
	"""Setter pour l'animation de displayed_value"""
	displayed_value = value
	queue_redraw()
	_update_text()

# ==================== UTILITAIRES ====================

func get_segment_for_value(value: float) -> int:
	"""Retourne le numéro du segment pour une valeur donnée"""
	if segment_count <= 1:
		return 0
	
	var progress = (value - min_value) / (max_value - min_value)
	var segment = int(progress * segment_count)
	return clamp(segment, 0, segment_count - 1)

func get_current_segment() -> int:
	"""Retourne le segment actuel"""
	return get_segment_for_value(current_value)

func is_segment_filled(segment_index: int) -> bool:
	"""Vérifie si un segment est rempli"""
	if segment_index >= segment_count:
		return false
	
	var segment_threshold = min_value + (max_value - min_value) * (segment_index + 1) / segment_count
	return current_value >= segment_threshold

func get_filled_segments_count() -> int:
	"""Retourne le nombre de segments remplis"""
	var count = 0
	for i in range(segment_count):
		if is_segment_filled(i):
			count += 1
	return count

func set_segment_progress(segment_index: int, progress: float):
	"""Définit la progression d'un segment spécifique (0.0 à 1.0)"""
	if segment_index >= segment_count or segment_index < 0:
		return
	
	var segment_size = (max_value - min_value) / segment_count
	var segment_start = min_value + segment_index * segment_size
	var target_value = segment_start + progress * segment_size
	
	set_value(target_value)

# ==================== EXEMPLES D'USAGE ====================

func setup_for_phases(current_phase: int, total_phases: int):
	"""Configuration spéciale pour les phases de jeu"""
	set_range(0, total_phases)
	set_segments(total_phases)
	set_value(current_phase)
	set_text_format("Phase %d/%d")

func setup_for_health(current_hp: int, max_hp: int):
	"""Configuration spéciale pour la santé"""
	set_range(0, max_hp)
	set_segments(1)
	set_value(current_hp)
	set_text_format("%d/%d HP")

func setup_for_experience(current_xp: int, xp_to_next_level: int):
	"""Configuration spéciale pour l'expérience"""
	set_range(0, xp_to_next_level)
	set_segments(4)  # Quarts de niveau
	set_value(current_xp)
	show_percentage = true