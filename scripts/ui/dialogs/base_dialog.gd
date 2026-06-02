extends Window
class_name BaseDialog

# Template de base pour tous les dialogues avec styles cohérents et fonctionnalités communes
# Utilisé comme classe parent pour tous les dialogues personnalisés

# Configuration
@export var dialog_title: String = "Dialog" : set = set_dialog_title
@export var dialog_size: Vector2 = Vector2(400, 300) : set = set_dialog_size
@export var modal: bool = true : set = set_modal
@export var resizable: bool = true : set = set_resizable
@export var closable: bool = true : set = set_closable
@export var center_on_parent: bool = true

# Animations
@export var animate_open: bool = true
@export var animate_close: bool = true
@export var animation_duration: float = 0.3

# Style
@export var background_color: Color = Color(0.15, 0.15, 0.2, 0.95)
@export var title_bar_color: Color = Color(0.2, 0.25, 0.3)
@export var border_color: Color = Color(0.4, 0.4, 0.5)
@export var corner_radius: int = 8

# Éléments UI
var main_container: VBoxContainer
var title_bar: PanelContainer
var title_label: Label
var close_button: Button
var content_area: Control
var button_area: HBoxContainer

# État interne
var is_opening: bool = false
var is_closing: bool = false
var result: Dictionary = {}
var callbacks: Dictionary = {}

# Signaux
signal dialog_opened()
signal dialog_closed(result: Dictionary)
signal dialog_confirmed(result: Dictionary)
signal dialog_cancelled()
signal button_pressed(button_name: String)

func _ready() -> void:
	_setup_window_properties()
	_create_ui_structure()
	_setup_interactions()

	if animate_open:
		_animate_open()

func _setup_window_properties() -> void:
	"""Configure les propriétés de la fenêtre"""
	set_flag(Window.FLAG_POPUP, modal)
	
	if modal:
		popup_window = true
	
	unresizable = not resizable
	size = dialog_size
	
	# Centrer sur le parent
	if center_on_parent:
		popup_centered()

func _create_ui_structure() -> void:
	"""Crée la structure UI du dialogue"""

	# Container principal
	main_container = VBoxContainer.new()
	main_container.add_theme_constant_override("separation", 0)
	add_child(main_container)
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Barre de titre
	_create_title_bar()
	
	# Zone de contenu
	_create_content_area()
	
	# Zone des boutons
	_create_button_area()
	
	# Appliquer les styles
	_apply_styles()

func _create_title_bar() -> void:
	"""Crée la barre de titre"""
	title_bar = PanelContainer.new()
	title_bar.custom_minimum_size = Vector2(0, 40)
	main_container.add_child(title_bar)

	var title_container := HBoxContainer.new()
	title_container.add_theme_constant_override("separation", 10)
	title_bar.add_child(title_container)
	
	# Titre
	title_label = Label.new()
	title_label.text = dialog_title
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_container.add_child(title_label)
	
	# Bouton fermer
	if closable:
		close_button = Button.new()
		close_button.text = "×"
		close_button.custom_minimum_size = Vector2(30, 30)
		close_button.add_theme_font_size_override("font_size", 16)
		close_button.flat = true
		close_button.pressed.connect(_on_close_button_pressed)
		title_container.add_child(close_button)

func _create_content_area() -> void:
	"""Crée la zone de contenu"""
	content_area = Control.new()
	content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_area.add_theme_constant_override("margin_left", 15)
	content_area.add_theme_constant_override("margin_right", 15)
	content_area.add_theme_constant_override("margin_top", 10)
	content_area.add_theme_constant_override("margin_bottom", 10)
	main_container.add_child(content_area)

func _create_button_area() -> void:
	"""Crée la zone des boutons"""
	var button_container := PanelContainer.new()
	button_container.custom_minimum_size = Vector2(0, 50)
	main_container.add_child(button_container)

	button_area = HBoxContainer.new()
	button_area.add_theme_constant_override("separation", 10)
	button_area.alignment = BoxContainer.ALIGNMENT_END
	button_container.add_child(button_area)

	# Style de la zone des boutons
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = background_color.darkened(0.1)
	button_style.corner_radius_bottom_left = corner_radius
	button_style.corner_radius_bottom_right = corner_radius
	button_container.add_theme_stylebox_override("panel", button_style)

func _apply_styles() -> void:
	"""Applique les styles visuels"""

	# Style de la fenêtre principale
	var main_style := StyleBoxFlat.new()
	main_style.bg_color = background_color
	main_style.border_color = border_color
	main_style.border_width_left = 1
	main_style.border_width_right = 1
	main_style.border_width_top = 1
	main_style.border_width_bottom = 1
	main_style.corner_radius_top_left = corner_radius
	main_style.corner_radius_top_right = corner_radius
	main_style.corner_radius_bottom_left = corner_radius
	main_style.corner_radius_bottom_right = corner_radius

	# Style de la barre de titre
	var title_style := StyleBoxFlat.new()
	title_style.bg_color = title_bar_color
	title_style.corner_radius_top_left = corner_radius
	title_style.corner_radius_top_right = corner_radius
	title_bar.add_theme_stylebox_override("panel", title_style)

func _setup_interactions() -> void:
	"""Configure les interactions"""
	
	# Fermeture par ESC
	set_process_unhandled_key_input(true)
	
	# Signaux de la fenêtre
	close_requested.connect(_on_close_requested)

func _unhandled_key_input(event: InputEvent) -> void:
	"""Gère les raccourcis clavier"""
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				if closable:
					close_dialog()
			KEY_ENTER:
				if callbacks.has("confirm"):
					confirm_dialog()

# ==================== SETTERS ====================

func set_dialog_title(title: String) -> void:
	dialog_title = title
	if title_label:
		title_label.text = title

func set_dialog_size(new_size: Vector2) -> void:
	dialog_size = new_size
	size = new_size

func set_modal(is_modal: bool) -> void:
	modal = is_modal
	if is_inside_tree():
		set_flag(Window.FLAG_POPUP, modal)
		popup_window = modal

func set_resizable(can_resize: bool) -> void:
	resizable = can_resize
	unresizable = not can_resize

func set_closable(can_close: bool) -> void:
	closable = can_close
	if close_button:
		close_button.visible = can_close

# ==================== API PUBLIQUE ====================

func open_dialog() -> void:
	"""Ouvre le dialogue"""
	if is_opening or is_closing:
		return

	popup_centered()

	if animate_open:
		_animate_open()
	else:
		dialog_opened.emit()

func close_dialog(dialog_result: Dictionary = {}) -> void:
	"""Ferme le dialogue avec un résultat"""
	if is_closing:
		return

	result = dialog_result

	if animate_close:
		_animate_close()
	else:
		_finalize_close()

func confirm_dialog(dialog_result: Dictionary = {}) -> void:
	"""Confirme le dialogue"""
	result = dialog_result
	dialog_confirmed.emit(result)
	close_dialog(result)

func cancel_dialog() -> void:
	"""Annule le dialogue"""
	result = {"cancelled": true}
	dialog_cancelled.emit()
	close_dialog(result)

func add_button(text: String, callback: Callable = Callable(), style: ButtonStyle = ButtonStyle.DEFAULT) -> Button:
	"""Ajoute un bouton à la zone des boutons"""
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(80, 30)

	# Appliquer le style
	_apply_button_style(button, style)

	# Connecter le callback
	if callback.is_valid():
		button.pressed.connect(callback)
	else:
		button.pressed.connect(func(): button_pressed.emit(text))

	button_area.add_child(button)
	return button

func add_standard_buttons(show_ok: bool = true, show_cancel: bool = true, ok_text: String = "OK", cancel_text: String = "Cancel") -> void:
	"""Ajoute les boutons standard OK/Cancel"""
	if show_cancel:
		add_button(cancel_text, cancel_dialog, ButtonStyle.SECONDARY)

	if show_ok:
		add_button(ok_text, confirm_dialog, ButtonStyle.PRIMARY)

func set_content(control: Control) -> void:
	"""Définit le contenu du dialogue"""
	# Nettoyer le contenu existant
	for child in content_area.get_children():
		child.queue_free()

	# Ajouter le nouveau contenu
	content_area.add_child(control)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func get_content_area() -> Control:
	"""Retourne la zone de contenu pour y ajouter des éléments"""
	return content_area

func set_callback(action: String, callback: Callable) -> void:
	"""Définit un callback pour une action spécifique"""
	callbacks[action] = callback

# ==================== STYLES DES BOUTONS ====================

enum ButtonStyle {
	DEFAULT,
	PRIMARY,
	SECONDARY,
	SUCCESS,
	WARNING,
	DANGER
}

func _apply_button_style(button: Button, style: ButtonStyle) -> void:
	"""Applique un style à un bouton"""
	var button_style := StyleBoxFlat.new()
	button_style.corner_radius_top_left = 4
	button_style.corner_radius_top_right = 4
	button_style.corner_radius_bottom_left = 4
	button_style.corner_radius_bottom_right = 4
	
	match style:
		ButtonStyle.PRIMARY:
			button_style.bg_color = Color(0.2, 0.6, 0.9)
			button.add_theme_color_override("font_color", Color.WHITE)
		ButtonStyle.SECONDARY:
			button_style.bg_color = Color(0.5, 0.5, 0.5)
			button.add_theme_color_override("font_color", Color.WHITE)
		ButtonStyle.SUCCESS:
			button_style.bg_color = Color(0.3, 0.8, 0.3)
			button.add_theme_color_override("font_color", Color.WHITE)
		ButtonStyle.WARNING:
			button_style.bg_color = Color(0.9, 0.7, 0.2)
			button.add_theme_color_override("font_color", Color.BLACK)
		ButtonStyle.DANGER:
			button_style.bg_color = Color(0.9, 0.3, 0.3)
			button.add_theme_color_override("font_color", Color.WHITE)
		ButtonStyle.DEFAULT:
			button_style.bg_color = Color(0.3, 0.3, 0.3)
			button.add_theme_color_override("font_color", Color.WHITE)
	
	button.add_theme_stylebox_override("normal", button_style)

	# Style hover
	var hover_style: StyleBoxFlat = button_style.duplicate()
	hover_style.bg_color = hover_style.bg_color.lightened(0.1)
	button.add_theme_stylebox_override("hover", hover_style)

	# Style pressed
	var pressed_style: StyleBoxFlat = button_style.duplicate()
	pressed_style.bg_color = pressed_style.bg_color.darkened(0.1)
	button.add_theme_stylebox_override("pressed", pressed_style)

# ==================== ANIMATIONS ====================

func _animate_open() -> void:
	"""Animation d'ouverture (fondu du contenu ; un Window ne supporte ni modulate ni scale)"""
	is_opening = true

	if not main_container:
		is_opening = false
		dialog_opened.emit()
		return

	main_container.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(main_container, "modulate:a", 1.0, animation_duration)
	tween.finished.connect(func():
		is_opening = false
		dialog_opened.emit()
	)

func _animate_close() -> void:
	"""Animation de fermeture (fondu du contenu)"""
	is_closing = true

	if not main_container:
		_finalize_close()
		return

	var tween := create_tween()
	tween.tween_property(main_container, "modulate:a", 0.0, animation_duration)
	tween.finished.connect(_finalize_close)

func _finalize_close() -> void:
	"""Finalise la fermeture"""
	is_closing = false
	dialog_closed.emit(result)
	queue_free()

# ==================== GESTIONNAIRES D'ÉVÉNEMENTS ====================

func _on_close_button_pressed() -> void:
	"""Bouton fermer pressé"""
	cancel_dialog()

func _on_close_requested() -> void:
	"""Fermeture demandée par la fenêtre"""
	cancel_dialog()

# ==================== MÉTHODES UTILITAIRES ====================

func center_on_screen() -> void:
	"""Centre le dialogue sur l'écran"""
	popup_centered()

func center_on_control(control: Control) -> void:
	"""Centre le dialogue sur un control spécifique"""
	if control:
		var control_center = control.global_position + control.size / 2
		position = control_center - size / 2

func set_minimum_size_auto() -> void:
	"""Définit la taille minimale automatiquement"""
	await get_tree().process_frame
	var content_size: Vector2 = content_area.get_combined_minimum_size()
	var title_height: float = title_bar.size.y if title_bar else 40
	var button_height: int = 50

	var min_size := Vector2(
		max(300, content_size.x + 30),  # +30 pour les marges
		content_size.y + title_height + button_height + 20  # +20 pour les séparations
	)

	set_dialog_size(min_size)

# ==================== MÉTHODES STATIQUES ====================

static func create_simple_dialog(title: String, message: String, parent: Node = null) -> BaseDialog:
	"""Crée un dialogue simple avec un message"""
	var dialog := BaseDialog.new()
	dialog.dialog_title = title

	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog.set_content(label)

	dialog.add_standard_buttons()

	if parent:
		parent.add_child(dialog)
	else:
		dialog.get_tree().root.add_child(dialog)

	return dialog

static func show_message(title: String, message: String, parent: Node = null) -> void:
	"""Affiche un message simple"""
	var dialog := create_simple_dialog(title, message, parent)
	dialog.open_dialog()

static func show_confirmation(title: String, message: String, callback: Callable, parent: Node = null) -> void:
	"""Affiche une confirmation avec callback"""
	var dialog := create_simple_dialog(title, message, parent)
	dialog.dialog_confirmed.connect(func(result): callback.call(true))
	dialog.dialog_cancelled.connect(func(): callback.call(false))
	dialog.open_dialog()

# ==================== GESTION DES DONNÉES ====================

func get_result() -> Dictionary:
	"""Retourne le résultat du dialogue"""
	return result

func set_result_data(key: String, value) -> void:
	"""Définit une donnée de résultat"""
	result[key] = value

func get_result_data(key: String, default_value = null):
	"""Récupère une donnée de résultat"""
	return result.get(key, default_value)

func clear_result() -> void:
	"""Efface le résultat"""
	result.clear()