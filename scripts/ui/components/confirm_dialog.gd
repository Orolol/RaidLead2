extends Control
class_name ConfirmDialog

# Système de dialogue de confirmation réutilisable avec styles prédéfinis
# Utilisé pour confirmer des actions critiques (suppression, reset, etc.)

# Types de dialogues prédéfinis
enum DialogType {
	DEFAULT,
	WARNING,
	ERROR,
	SUCCESS,
	INFO,
	DESTRUCTIVE
}

# Configuration
@export var dialog_type: DialogType = DialogType.DEFAULT : set = set_dialog_type
@export var title_text: String = "Confirmation" : set = set_title_text
@export var message_text: String = "Êtes-vous sûr?" : set = set_message_text
@export var confirm_text: String = "Confirmer" : set = set_confirm_text
@export var cancel_text: String = "Annuler" : set = set_cancel_text
@export var show_icon: bool = true : set = set_show_icon
@export var auto_close_on_action: bool = true
@export var blur_background: bool = true

# Style
@export var dialog_width: int = 400
@export var dialog_min_height: int = 150
@export var button_height: int = 40
@export var icon_size: int = 48

# Éléments UI
var background_overlay: ColorRect
var dialog_panel: PanelContainer
var title_label: Label
var message_label: Label
var icon_texture: TextureRect
var confirm_button: Button
var cancel_button: Button
var close_button: Button

# Signaux
signal confirmed()
signal cancelled()
signal closed()

# Couleurs par type
const TYPE_COLORS = {
	DialogType.DEFAULT: Color(0.3, 0.3, 0.4),
	DialogType.WARNING: Color(0.8, 0.6, 0.2),
	DialogType.ERROR: Color(0.8, 0.2, 0.2),
	DialogType.SUCCESS: Color(0.2, 0.7, 0.3),
	DialogType.INFO: Color(0.3, 0.6, 0.9),
	DialogType.DESTRUCTIVE: Color(0.9, 0.1, 0.1)
}

# Icônes par type (caractères Unicode)
const TYPE_ICONS = {
	DialogType.DEFAULT: "?",
	DialogType.WARNING: "⚠",
	DialogType.ERROR: "✗",
	DialogType.SUCCESS: "✓",
	DialogType.INFO: "ℹ",
	DialogType.DESTRUCTIVE: "⚠"
}

func _ready():
	_setup_ui()
	_apply_type_style()
	hide()

func _setup_ui():
	"""Configure la structure UI"""
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 1000  # Au-dessus de tout
	
	# Overlay de fond
	if blur_background:
		background_overlay = ColorRect.new()
		background_overlay.color = Color(0, 0, 0, 0.5)
		background_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		background_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(background_overlay)
	
	# Panel principal du dialogue
	dialog_panel = PanelContainer.new()
	dialog_panel.custom_minimum_size = Vector2(dialog_width, dialog_min_height)
	dialog_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(dialog_panel)
	
	# Container principal
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	dialog_panel.add_child(main_vbox)
	
	# Header
	_setup_header(main_vbox)
	
	# Contenu
	_setup_content(main_vbox)
	
	# Boutons
	_setup_buttons(main_vbox)
	
	# Style du panel
	_apply_panel_style()

func _setup_header(parent: VBoxContainer):
	"""Configure le header du dialogue"""
	var header_container = HBoxContainer.new()
	header_container.add_theme_constant_override("separation", 10)
	parent.add_child(header_container)
	
	# Titre
	title_label = Label.new()
	title_label.text = title_text
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_container.add_child(title_label)
	
	# Bouton fermer
	close_button = Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(24, 24)
	close_button.flat = true
	close_button.add_theme_font_size_override("font_size", 18)
	close_button.pressed.connect(_on_close_pressed)
	header_container.add_child(close_button)
	
	# Séparateur
	parent.add_child(HSeparator.new())

func _setup_content(parent: VBoxContainer):
	"""Configure le contenu du dialogue"""
	var content_hbox = HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 15)
	parent.add_child(content_hbox)
	
	# Icône
	if show_icon:
		icon_texture = TextureRect.new()
		icon_texture.custom_minimum_size = Vector2(icon_size, icon_size)
		icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# Utiliser un label pour afficher un caractère Unicode comme icône
		var icon_label = Label.new()
		icon_label.text = TYPE_ICONS.get(dialog_type, "?")
		icon_label.add_theme_font_size_override("font_size", 32)
		icon_label.custom_minimum_size = Vector2(icon_size, icon_size)
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		content_hbox.add_child(icon_label)
	
	# Message
	message_label = Label.new()
	message_label.text = message_text
	message_label.add_theme_font_size_override("font_size", 14)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_hbox.add_child(message_label)

func _setup_buttons(parent: VBoxContainer):
	"""Configure les boutons du dialogue"""
	# Séparateur
	parent.add_child(HSeparator.new())
	
	# Container des boutons
	var button_container = HBoxContainer.new()
	button_container.add_theme_constant_override("separation", 10)
	button_container.alignment = BoxContainer.ALIGNMENT_END
	parent.add_child(button_container)
	
	# Bouton Annuler
	cancel_button = Button.new()
	cancel_button.text = cancel_text
	cancel_button.custom_minimum_size = Vector2(100, button_height)
	cancel_button.pressed.connect(_on_cancel_pressed)
	button_container.add_child(cancel_button)
	
	# Bouton Confirmer
	confirm_button = Button.new()
	confirm_button.text = confirm_text
	confirm_button.custom_minimum_size = Vector2(100, button_height)
	confirm_button.pressed.connect(_on_confirm_pressed)
	button_container.add_child(confirm_button)

func _apply_panel_style():
	"""Applique le style au panel"""
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = TYPE_COLORS.get(dialog_type, Color(0.4, 0.4, 0.4))
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	
	dialog_panel.add_theme_stylebox_override("panel", style)

func _apply_type_style():
	"""Applique le style selon le type de dialogue"""
	var color = TYPE_COLORS.get(dialog_type, Color.WHITE)
	
	if title_label:
		title_label.modulate = color
	
	if confirm_button:
		# Style du bouton confirmer selon le type
		var button_style = StyleBoxFlat.new()
		button_style.bg_color = color.darkened(0.3)
		button_style.corner_radius_top_left = 4
		button_style.corner_radius_top_right = 4
		button_style.corner_radius_bottom_left = 4
		button_style.corner_radius_bottom_right = 4
		confirm_button.add_theme_stylebox_override("normal", button_style)
		
		var hover_style = button_style.duplicate()
		hover_style.bg_color = color.darkened(0.1)
		confirm_button.add_theme_stylebox_override("hover", hover_style)
		
		if dialog_type == DialogType.DESTRUCTIVE:
			confirm_button.add_theme_color_override("font_color", Color.WHITE)
	
	_apply_panel_style()

# ==================== SETTERS ====================

func set_dialog_type(type: DialogType):
	dialog_type = type
	if is_inside_tree():
		_apply_type_style()

func set_title_text(text: String):
	title_text = text
	if title_label:
		title_label.text = text

func set_message_text(text: String):
	message_text = text
	if message_label:
		message_label.text = text

func set_confirm_text(text: String):
	confirm_text = text
	if confirm_button:
		confirm_button.text = text

func set_cancel_text(text: String):
	cancel_text = text
	if cancel_button:
		cancel_button.text = text

func set_show_icon(show: bool):
	show_icon = show
	if icon_texture:
		icon_texture.visible = show

# ==================== ÉVÉNEMENTS ====================

func _on_confirm_pressed():
	"""Gère le clic sur Confirmer"""
	confirmed.emit()
	if auto_close_on_action:
		hide_dialog()

func _on_cancel_pressed():
	"""Gère le clic sur Annuler"""
	cancelled.emit()
	if auto_close_on_action:
		hide_dialog()

func _on_close_pressed():
	"""Gère le clic sur Fermer"""
	closed.emit()
	hide_dialog()

# ==================== API PUBLIQUE ====================

func show_dialog():
	"""Affiche le dialogue"""
	show()
	
	# Animation d'apparition
	dialog_panel.scale = Vector2(0.8, 0.8)
	dialog_panel.modulate.a = 0.0
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(dialog_panel, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(dialog_panel, "modulate:a", 1.0, 0.2)
	
	if background_overlay:
		background_overlay.modulate.a = 0.0
		create_tween().tween_property(background_overlay, "modulate:a", 1.0, 0.2)

func hide_dialog():
	"""Cache le dialogue avec animation"""
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(dialog_panel, "scale", Vector2(0.8, 0.8), 0.2).set_ease(Tween.EASE_IN)
	tween.tween_property(dialog_panel, "modulate:a", 0.0, 0.2)
	
	if background_overlay:
		create_tween().tween_property(background_overlay, "modulate:a", 0.0, 0.2)
	
	tween.finished.connect(hide)

func set_dialog_data(title: String, message: String, type: DialogType = DialogType.DEFAULT):
	"""Configure rapidement le dialogue"""
	set_title_text(title)
	set_message_text(message)
	set_dialog_type(type)

# ==================== MÉTHODES STATIQUES ====================

static func create_confirmation(parent: Node, title: String, message: String, on_confirm: Callable) -> ConfirmDialog:
	"""Crée un dialogue de confirmation simple"""
	var dialog = ConfirmDialog.new()
	dialog.set_dialog_data(title, message, DialogType.DEFAULT)
	dialog.confirmed.connect(on_confirm)
	parent.add_child(dialog)
	dialog.show_dialog()
	return dialog

static func create_warning(parent: Node, title: String, message: String, on_confirm: Callable) -> ConfirmDialog:
	"""Crée un dialogue d'avertissement"""
	var dialog = ConfirmDialog.new()
	dialog.set_dialog_data(title, message, DialogType.WARNING)
	dialog.confirmed.connect(on_confirm)
	parent.add_child(dialog)
	dialog.show_dialog()
	return dialog

static func create_destructive(parent: Node, title: String, message: String, on_confirm: Callable) -> ConfirmDialog:
	"""Crée un dialogue pour action destructive"""
	var dialog = ConfirmDialog.new()
	dialog.set_dialog_data(title, message, DialogType.DESTRUCTIVE)
	dialog.confirm_text = "Supprimer"
	dialog.confirmed.connect(on_confirm)
	parent.add_child(dialog)
	dialog.show_dialog()
	return dialog

static func create_info(parent: Node, title: String, message: String) -> ConfirmDialog:
	"""Crée un dialogue d'information (un seul bouton OK)"""
	var dialog = ConfirmDialog.new()
	dialog.set_dialog_data(title, message, DialogType.INFO)
	dialog.cancel_button.visible = false
	dialog.confirm_text = "OK"
	parent.add_child(dialog)
	dialog.show_dialog()
	return dialog