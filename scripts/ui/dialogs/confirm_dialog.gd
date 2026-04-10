extends BaseDialog
class_name ConfirmDialog

# Dialogue de confirmation avec options personnalisables
# Utilisé pour demander une confirmation utilisateur avec callbacks

# Configuration
@export var message: String = "Are you sure?" : set = set_message
@export var confirm_text: String = "Confirm" : set = set_confirm_text
@export var cancel_text: String = "Cancel" : set = set_cancel_text
@export var show_icon: bool = true : set = set_show_icon
@export var icon_type: IconType = IconType.QUESTION : set = set_icon_type
@export var default_button: DefaultButton = DefaultButton.CONFIRM : set = set_default_button

# Types d'icônes
enum IconType {
	QUESTION,   # Icône de question (défaut)
	WARNING,    # Icône d'avertissement
	DANGER,     # Icône de danger
	INFO,       # Icône d'information
	SUCCESS     # Icône de succès
}

# Bouton par défaut (focus)
enum DefaultButton {
	CONFIRM,
	CANCEL,
	NONE
}

# Icônes Unicode par type
const ICON_SYMBOLS = {
	IconType.QUESTION: "❓",
	IconType.WARNING: "⚠️",
	IconType.DANGER: "⚡",
	IconType.INFO: "ℹ️",
	IconType.SUCCESS: "✅"
}

# Couleurs par type
const ICON_COLORS = {
	IconType.QUESTION: Color(0.4, 0.7, 1.0),
	IconType.WARNING: Color(0.9, 0.7, 0.2),
	IconType.DANGER: Color(0.9, 0.3, 0.3),
	IconType.INFO: Color(0.4, 0.7, 1.0),
	IconType.SUCCESS: Color(0.3, 0.8, 0.3)
}

# Éléments UI
var content_container: HBoxContainer
var icon_label: Label
var message_label: RichTextLabel
var confirm_button: Button
var cancel_button: Button

# Callbacks
var confirm_callback: Callable
var cancel_callback: Callable

func _ready():
	super._ready()
	_setup_confirm_dialog()

func _setup_confirm_dialog():
	"""Configure le dialogue de confirmation"""
	
	# Taille par défaut
	dialog_size = Vector2(400, 200)
	set_dialog_size(dialog_size)
	
	# Créer le contenu
	_create_content()
	
	# Créer les boutons
	_create_buttons()
	
	# Focus par défaut
	_set_default_focus()

func _create_content():
	"""Crée le contenu du dialogue"""
	
	content_container = HBoxContainer.new()
	content_container.add_theme_constant_override("separation", 15)
	set_content(content_container)
	
	# Icône
	if show_icon:
		icon_label = Label.new()
		icon_label.text = ICON_SYMBOLS[icon_type]
		icon_label.add_theme_font_size_override("font_size", 32)
		icon_label.add_theme_color_override("font_color", ICON_COLORS[icon_type])
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		icon_label.custom_minimum_size = Vector2(50, 50)
		content_container.add_child(icon_label)
	
	# Message
	message_label = RichTextLabel.new()
	message_label.text = message
	message_label.bbcode_enabled = true
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.fit_content = true
	message_label.scroll_active = false
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.add_child(message_label)

func _create_buttons():
	"""Crée les boutons du dialogue"""
	
	# Bouton Cancel
	cancel_button = add_button(cancel_text, _on_cancel_pressed, ButtonStyle.SECONDARY)
	
	# Bouton Confirm
	var confirm_style = ButtonStyle.PRIMARY
	match icon_type:
		IconType.DANGER:
			confirm_style = ButtonStyle.DANGER
		IconType.WARNING:
			confirm_style = ButtonStyle.WARNING
		IconType.SUCCESS:
			confirm_style = ButtonStyle.SUCCESS
	
	confirm_button = add_button(confirm_text, _on_confirm_pressed, confirm_style)

func _set_default_focus():
	"""Définit le focus par défaut"""
	await get_tree().process_frame
	
	match default_button:
		DefaultButton.CONFIRM:
			if confirm_button:
				confirm_button.grab_focus()
		DefaultButton.CANCEL:
			if cancel_button:
				cancel_button.grab_focus()
		DefaultButton.NONE:
			pass  # Pas de focus

# ==================== SETTERS ====================

func set_message(new_message: String):
	message = new_message
	if message_label:
		message_label.text = message

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
	if icon_label:
		icon_label.visible = show

func set_icon_type(type: IconType):
	icon_type = type
	if icon_label:
		icon_label.text = ICON_SYMBOLS[type]
		icon_label.add_theme_color_override("font_color", ICON_COLORS[type])

func set_default_button(button: DefaultButton):
	default_button = button
	if is_inside_tree():
		_set_default_focus()

# ==================== API PUBLIQUE ====================

func set_callbacks(on_confirm: Callable = Callable(), on_cancel: Callable = Callable()):
	"""Définit les callbacks pour les actions"""
	confirm_callback = on_confirm
	cancel_callback = on_cancel

func setup_question(question: String, on_yes: Callable = Callable(), on_no: Callable = Callable()):
	"""Configure comme question Oui/Non"""
	set_message(question)
	set_confirm_text("Oui")
	set_cancel_text("Non")
	set_icon_type(IconType.QUESTION)
	set_callbacks(on_yes, on_no)

func setup_warning(warning: String, on_proceed: Callable = Callable(), on_cancel: Callable = Callable()):
	"""Configure comme avertissement"""
	set_message(warning)
	set_confirm_text("Continuer")
	set_cancel_text("Annuler")
	set_icon_type(IconType.WARNING)
	set_default_button(DefaultButton.CANCEL)  # Cancel par défaut pour les warnings
	set_callbacks(on_proceed, on_cancel)

func setup_danger(danger_message: String, on_proceed: Callable = Callable(), on_cancel: Callable = Callable()):
	"""Configure comme action dangereuse"""
	set_message(danger_message)
	set_confirm_text("Supprimer")
	set_cancel_text("Annuler")
	set_icon_type(IconType.DANGER)
	set_default_button(DefaultButton.CANCEL)  # Cancel par défaut pour les actions dangereuses
	set_callbacks(on_proceed, on_cancel)

func setup_delete_confirmation(item_name: String, on_delete: Callable = Callable(), on_cancel: Callable = Callable()):
	"""Configure pour confirmation de suppression"""
	var message_text = "Êtes-vous sûr de vouloir supprimer [b]%s[/b] ?\n\nCette action est [color=red]irréversible[/color]." % item_name
	set_message(message_text)
	set_confirm_text("Supprimer")
	set_cancel_text("Annuler")
	set_icon_type(IconType.DANGER)
	set_default_button(DefaultButton.CANCEL)
	set_callbacks(on_delete, on_cancel)

func setup_save_confirmation(on_save: Callable = Callable(), on_dont_save: Callable = Callable(), on_cancel: Callable = Callable()):
	"""Configure pour confirmation de sauvegarde"""
	set_message("Voulez-vous sauvegarder les modifications ?")
	set_icon_type(IconType.QUESTION)
	
	# Supprimer les boutons par défaut
	for child in button_area.get_children():
		child.queue_free()
	
	# Ajouter trois boutons
	add_button("Annuler", on_cancel, ButtonStyle.SECONDARY)
	add_button("Ne pas sauvegarder", on_dont_save, ButtonStyle.WARNING)
	add_button("Sauvegarder", on_save, ButtonStyle.PRIMARY)

# ==================== GESTIONNAIRES D'ÉVÉNEMENTS ====================

func _on_confirm_pressed():
	"""Bouton confirmer pressé"""
	set_result_data("confirmed", true)
	set_result_data("action", "confirm")
	
	if confirm_callback.is_valid():
		confirm_callback.call(get_result())
	
	confirm_dialog(get_result())

func _on_cancel_pressed():
	"""Bouton annuler pressé"""
	set_result_data("confirmed", false)
	set_result_data("action", "cancel")
	
	if cancel_callback.is_valid():
		cancel_callback.call(get_result())
	
	cancel_dialog()

# ==================== GESTION CLAVIER ====================

func _unhandled_key_input(event: InputEvent):
	"""Gère les raccourcis clavier spécifiques"""
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_Y:
				if confirm_text.to_lower().begins_with("oui") or confirm_text.to_lower().begins_with("yes"):
					_on_confirm_pressed()
					return
			KEY_N:
				if cancel_text.to_lower().begins_with("non") or cancel_text.to_lower().begins_with("no"):
					_on_cancel_pressed()
					return
	
	# Appeler le parent pour ESC et Enter
	super._unhandled_key_input(event)

# ==================== MÉTHODES STATIQUES ====================

static func show_question(title: String, question: String, on_yes: Callable = Callable(), on_no: Callable = Callable(), parent: Node = null) -> ConfirmDialog:
	"""Affiche une question simple"""
	var dialog = ConfirmDialog.new()
	dialog.dialog_title = title
	dialog.setup_question(question, on_yes, on_no)
	
	if parent:
		parent.add_child(dialog)
	else:
		Engine.get_main_loop().root.add_child(dialog)
	
	dialog.open_dialog()
	return dialog

static func show_warning(title: String, warning: String, on_proceed: Callable = Callable(), on_cancel: Callable = Callable(), parent: Node = null) -> ConfirmDialog:
	"""Affiche un avertissement"""
	var dialog = ConfirmDialog.new()
	dialog.dialog_title = title
	dialog.setup_warning(warning, on_proceed, on_cancel)
	
	if parent:
		parent.add_child(dialog)
	else:
		Engine.get_main_loop().root.add_child(dialog)
	
	dialog.open_dialog()
	return dialog

static func show_delete_confirmation(title: String, item_name: String, on_delete: Callable = Callable(), on_cancel: Callable = Callable(), parent: Node = null) -> ConfirmDialog:
	"""Affiche une confirmation de suppression"""
	var dialog = ConfirmDialog.new()
	dialog.dialog_title = title
	dialog.setup_delete_confirmation(item_name, on_delete, on_cancel)
	
	if parent:
		parent.add_child(dialog)
	else:
		Engine.get_main_loop().root.add_child(dialog)
	
	dialog.open_dialog()
	return dialog

static func show_save_confirmation(title: String = "Sauvegarder", on_save: Callable = Callable(), on_dont_save: Callable = Callable(), on_cancel: Callable = Callable(), parent: Node = null) -> ConfirmDialog:
	"""Affiche une confirmation de sauvegarde"""
	var dialog = ConfirmDialog.new()
	dialog.dialog_title = title
	dialog.setup_save_confirmation(on_save, on_dont_save, on_cancel)
	
	if parent:
		parent.add_child(dialog)
	else:
		Engine.get_main_loop().root.add_child(dialog)
	
	dialog.open_dialog()
	return dialog

# ==================== CONFIGURATIONS PRÉDÉFINIES ====================

func setup_for_guild_member_removal(member_name: String, on_remove: Callable = Callable()):
	"""Configuration pour suppression de membre de guilde"""
	var message_text = "Êtes-vous sûr de vouloir retirer [b]%s[/b] de la guilde ?\n\nLe joueur perdra tous ses privilèges et son historique." % member_name
	setup_danger(message_text, on_remove)
	set_confirm_text("Retirer")

func setup_for_equipment_replacement(item_name: String, on_replace: Callable = Callable()):
	"""Configuration pour remplacement d'équipement"""
	var message_text = "Remplacer l'équipement actuel par [b]%s[/b] ?" % item_name
	setup_question(message_text, on_replace)
	set_confirm_text("Remplacer")

func setup_for_dungeon_abandon(on_abandon: Callable = Callable()):
	"""Configuration pour abandon de donjon"""
	var message_text = "Abandonner le donjon en cours ?\n\n[color=orange]Attention :[/color] Tous les progrès seront perdus."
	setup_warning(message_text, on_abandon)
	set_confirm_text("Abandonner")

func setup_for_phase_transition(phase_name: String, on_proceed: Callable = Callable()):
	"""Configuration pour transition de phase"""
	var message_text = "Passer à la phase [b]%s[/b] ?\n\nCette action déclenchera de nouveaux défis et mécaniques." % phase_name
	setup_question(message_text, on_proceed)
	set_confirm_text("Progresser")
	set_icon_type(IconType.SUCCESS)