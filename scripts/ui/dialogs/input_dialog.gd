extends BaseDialog
class_name InputDialog

# Dialogue de saisie avec validation en temps réel
# Support pour texte, nombres, mots de passe avec validation personnalisée

# Configuration
@export var input_label: String = "Enter value:" : set = set_input_label
@export var input_type: InputType = InputType.TEXT : set = set_input_type
@export var placeholder: String = "" : set = set_placeholder
@export var default_value: String = "" : set = set_default_value
@export var max_length: int = 100 : set = set_max_length
@export var multiline: bool = false : set = set_multiline
@export var required: bool = false : set = set_required

# Types de saisie
enum InputType {
	TEXT,           # Texte libre
	NUMBER,         # Nombre entier
	FLOAT,          # Nombre décimal
	PASSWORD,       # Mot de passe (masqué)
	EMAIL,          # Email avec validation
	URL,            # URL avec validation
	GUILD_NAME,     # Nom de guilde (caractères autorisés)
	PLAYER_NAME     # Nom de joueur (caractères autorisés)
}

# Validation
@export var min_value: float = 0.0
@export var max_value: float = 999999.0
@export var allow_empty: bool = true
@export var validation_regex: String = ""

# Éléments UI
var content_container: VBoxContainer
var label_element: Label
var input_field: LineEdit
var text_area: TextEdit
var validation_label: Label
var character_count_label: Label
var ok_button: Button
var cancel_button: Button

# État
var validation_callback: Callable
var is_valid_input: bool = true
var last_valid_value: String = ""

# Signaux
signal input_validated(text: String, is_valid: bool)
signal input_submitted(value: String)

func _ready() -> void:
	super._ready()
	_setup_input_dialog()

func _setup_input_dialog() -> void:
	"""Configure le dialogue de saisie"""
	
	# Taille par défaut selon le type
	if multiline:
		dialog_size = Vector2(500, 400)
	else:
		dialog_size = Vector2(400, 200)
	set_dialog_size(dialog_size)
	
	# Créer le contenu
	_create_content()
	
	# Créer les boutons
	_create_buttons()
	
	# Configuration initiale
	_apply_input_type()
	_validate_input()

func _create_content() -> void:
	"""Crée le contenu du dialogue"""

	content_container = VBoxContainer.new()
	content_container.add_theme_constant_override("separation", 10)
	set_content(content_container)
	
	# Label
	label_element = Label.new()
	label_element.text = input_label
	label_element.add_theme_font_size_override("font_size", 12)
	content_container.add_child(label_element)
	
	# Champ de saisie
	if multiline:
		text_area = TextEdit.new()
		text_area.placeholder_text = placeholder
		text_area.text = default_value
		text_area.custom_minimum_size = Vector2(0, 150)
		text_area.text_changed.connect(_on_text_changed)
		content_container.add_child(text_area)
	else:
		input_field = LineEdit.new()
		input_field.placeholder_text = placeholder
		input_field.text = default_value
		input_field.max_length = max_length
		input_field.text_changed.connect(_on_text_changed)
		input_field.text_submitted.connect(_on_text_submitted)
		content_container.add_child(input_field)
	
	# Label de validation
	validation_label = Label.new()
	validation_label.add_theme_font_size_override("font_size", 10)
	validation_label.add_theme_color_override("font_color", Color.RED)
	validation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	validation_label.visible = false
	content_container.add_child(validation_label)
	
	# Compteur de caractères
	character_count_label = Label.new()
	character_count_label.add_theme_font_size_override("font_size", 10)
	character_count_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	character_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	content_container.add_child(character_count_label)
	
	_update_character_count()

func _create_buttons() -> void:
	"""Crée les boutons du dialogue"""

	cancel_button = add_button("Annuler", _on_cancel_pressed, ButtonStyle.SECONDARY)
	ok_button = add_button("OK", _on_ok_pressed, ButtonStyle.PRIMARY)

	# Focus sur le champ de saisie
	await get_tree().process_frame
	if input_field:
		input_field.grab_focus()
	elif text_area:
		text_area.grab_focus()

func _apply_input_type() -> void:
	"""Applique la configuration selon le type de saisie"""

	var field = input_field if input_field else text_area
	if not field:
		return
	
	match input_type:
		InputType.TEXT:
			# Configuration par défaut
			pass
			
		InputType.NUMBER:
			if input_field:
				input_field.placeholder_text = "Entrez un nombre entier"
			
		InputType.FLOAT:
			if input_field:
				input_field.placeholder_text = "Entrez un nombre décimal"
			
		InputType.PASSWORD:
			if input_field:
				input_field.secret = true
				input_field.placeholder_text = "Entrez votre mot de passe"
			
		InputType.EMAIL:
			if input_field:
				input_field.placeholder_text = "exemple@domaine.com"
			
		InputType.URL:
			if input_field:
				input_field.placeholder_text = "https://exemple.com"
			
		InputType.GUILD_NAME:
			if input_field:
				input_field.placeholder_text = "Nom de la guilde"
				max_length = 30
				input_field.max_length = max_length
			
		InputType.PLAYER_NAME:
			if input_field:
				input_field.placeholder_text = "Nom du joueur"
				max_length = 20
				input_field.max_length = max_length

# ==================== SETTERS ====================

func set_input_label(label: String) -> void:
	input_label = label
	if label_element:
		label_element.text = label

func set_input_type(type: InputType) -> void:
	input_type = type
	if is_inside_tree():
		_apply_input_type()
		_validate_input()

func set_placeholder(text: String) -> void:
	placeholder = text
	if input_field:
		input_field.placeholder_text = text
	elif text_area:
		text_area.placeholder_text = text

func set_default_value(value: String) -> void:
	default_value = value
	if input_field:
		input_field.text = value
	elif text_area:
		text_area.text = value

func set_max_length(length: int) -> void:
	max_length = length
	if input_field:
		input_field.max_length = length

func set_multiline(is_multiline: bool) -> void:
	multiline = is_multiline
	# Recréer l'interface si nécessaire
	if is_inside_tree():
		_setup_input_dialog()

func set_required(is_required: bool) -> void:
	required = is_required
	_validate_input()

# ==================== VALIDATION ====================

func _validate_input() -> void:
	"""Valide la saisie actuelle"""

	var current_text: String = get_current_text()
	var validation_result: Dictionary = _perform_validation(current_text)

	is_valid_input = validation_result.is_valid
	
	# Mettre à jour l'UI de validation
	if validation_result.is_valid:
		validation_label.visible = false
		last_valid_value = current_text
		if ok_button:
			ok_button.disabled = false
	else:
		validation_label.text = validation_result.error_message
		validation_label.visible = true
		if ok_button:
			ok_button.disabled = true
	
	input_validated.emit(current_text, validation_result.is_valid)

func _perform_validation(text: String) -> Dictionary:
	"""Effectue la validation selon le type"""
	
	# Vérifier si requis
	if required and text.strip_edges().is_empty():
		return {"is_valid": false, "error_message": "Ce champ est requis."}
	
	# Permettre vide si non requis
	if not required and text.strip_edges().is_empty():
		return {"is_valid": true, "error_message": ""}
	
	# Validation personnalisée
	if validation_callback.is_valid():
		var custom_result = validation_callback.call(text)
		if custom_result is Dictionary:
			return custom_result
		elif custom_result is bool:
			return {"is_valid": custom_result, "error_message": "Validation personnalisée échouée."}
	
	# Validation par type
	match input_type:
		InputType.TEXT:
			return _validate_text(text)
		InputType.NUMBER:
			return _validate_number(text)
		InputType.FLOAT:
			return _validate_float(text)
		InputType.PASSWORD:
			return _validate_password(text)
		InputType.EMAIL:
			return _validate_email(text)
		InputType.URL:
			return _validate_url(text)
		InputType.GUILD_NAME:
			return _validate_guild_name(text)
		InputType.PLAYER_NAME:
			return _validate_player_name(text)
	
	return {"is_valid": true, "error_message": ""}

func _validate_text(text: String) -> Dictionary:
	"""Validation pour texte libre"""
	if validation_regex != "":
		var regex := RegEx.new()
		regex.compile(validation_regex)
		if not regex.search(text):
			return {"is_valid": false, "error_message": "Format invalide."}
	
	return {"is_valid": true, "error_message": ""}

func _validate_number(text: String) -> Dictionary:
	"""Validation pour nombre entier"""
	if not text.is_valid_int():
		return {"is_valid": false, "error_message": "Veuillez entrer un nombre entier valide."}

	var value: int = text.to_int()
	if value < min_value or value > max_value:
		return {"is_valid": false, "error_message": "La valeur doit être entre %d et %d." % [min_value, max_value]}
	
	return {"is_valid": true, "error_message": ""}

func _validate_float(text: String) -> Dictionary:
	"""Validation pour nombre décimal"""
	if not text.is_valid_float():
		return {"is_valid": false, "error_message": "Veuillez entrer un nombre décimal valide."}

	var value: float = text.to_float()
	if value < min_value or value > max_value:
		return {"is_valid": false, "error_message": "La valeur doit être entre %.2f et %.2f." % [min_value, max_value]}
	
	return {"is_valid": true, "error_message": ""}

func _validate_password(text: String) -> Dictionary:
	"""Validation pour mot de passe"""
	if text.length() < 6:
		return {"is_valid": false, "error_message": "Le mot de passe doit contenir au moins 6 caractères."}
	
	return {"is_valid": true, "error_message": ""}

func _validate_email(text: String) -> Dictionary:
	"""Validation pour email"""
	var regex := RegEx.new()
	regex.compile("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$")
	
	if not regex.search(text):
		return {"is_valid": false, "error_message": "Veuillez entrer une adresse email valide."}
	
	return {"is_valid": true, "error_message": ""}

func _validate_url(text: String) -> Dictionary:
	"""Validation pour URL"""
	if not (text.begins_with("http://") or text.begins_with("https://")):
		return {"is_valid": false, "error_message": "L'URL doit commencer par http:// ou https://"}
	
	return {"is_valid": true, "error_message": ""}

func _validate_guild_name(text: String) -> Dictionary:
	"""Validation pour nom de guilde"""
	if text.length() < 3:
		return {"is_valid": false, "error_message": "Le nom de guilde doit contenir au moins 3 caractères."}
	
	var regex := RegEx.new()
	regex.compile("^[a-zA-Z0-9\\s\\-_]+$")
	
	if not regex.search(text):
		return {"is_valid": false, "error_message": "Caractères autorisés : lettres, chiffres, espaces, tirets et underscores."}
	
	return {"is_valid": true, "error_message": ""}

func _validate_player_name(text: String) -> Dictionary:
	"""Validation pour nom de joueur"""
	if text.length() < 2:
		return {"is_valid": false, "error_message": "Le nom de joueur doit contenir au moins 2 caractères."}
	
	var regex := RegEx.new()
	regex.compile("^[a-zA-Z0-9_]+$")
	
	if not regex.search(text):
		return {"is_valid": false, "error_message": "Caractères autorisés : lettres, chiffres et underscores uniquement."}
	
	return {"is_valid": true, "error_message": ""}

# ==================== ÉVÉNEMENTS ====================

func _on_text_changed(_new_text: String = "") -> void:
	"""Texte modifié"""
	_validate_input()
	_update_character_count()

func _on_text_submitted(_text: String) -> void:
	"""Texte soumis (Entrée)"""
	if is_valid_input:
		_on_ok_pressed()

func _on_ok_pressed() -> void:
	"""Bouton OK pressé"""
	var current_text: String = get_current_text()

	if not is_valid_input:
		return

	set_result_data("text", current_text)
	set_result_data("submitted", true)

	# Conversion selon le type
	match input_type:
		InputType.NUMBER:
			set_result_data("value", current_text.to_int())
		InputType.FLOAT:
			set_result_data("value", current_text.to_float())
		_:
			set_result_data("value", current_text)

	input_submitted.emit(current_text)
	confirm_dialog(get_result())

func _on_cancel_pressed() -> void:
	"""Bouton annuler pressé"""
	set_result_data("text", "")
	set_result_data("submitted", false)
	cancel_dialog()

func _update_character_count() -> void:
	"""Met à jour le compteur de caractères"""
	var current_text: String = get_current_text()
	var count_text: String = "%d" % current_text.length()

	if max_length > 0:
		count_text += "/%d" % max_length

		# Couleur selon la proximité de la limite
		var ratio: float = float(current_text.length()) / float(max_length)
		var color: Color = Color.WHITE
		if ratio >= 0.9:
			color = Color.RED
		elif ratio >= 0.7:
			color = Color.YELLOW

		character_count_label.add_theme_color_override("font_color", color)

	character_count_label.text = count_text

# ==================== API PUBLIQUE ====================

func get_current_text() -> String:
	"""Retourne le texte actuel"""
	if input_field:
		return input_field.text
	elif text_area:
		return text_area.text
	return ""

func set_validation_callback(callback: Callable) -> void:
	"""Définit un callback de validation personnalisée"""
	validation_callback = callback
	_validate_input()

func set_number_range(min_val: float, max_val: float) -> void:
	"""Définit la plage pour les nombres"""
	min_value = min_val
	max_value = max_val
	_validate_input()

func clear_input() -> void:
	"""Efface la saisie"""
	if input_field:
		input_field.text = ""
	elif text_area:
		text_area.text = ""

func select_all() -> void:
	"""Sélectionne tout le texte"""
	if input_field:
		input_field.select_all()
	elif text_area:
		text_area.select_all()

# ==================== MÉTHODES STATIQUES ====================

static func show_text_input(title: String, label: String, default: String = "", callback: Callable = Callable(), parent: Node = null) -> InputDialog:
	"""Affiche une saisie de texte simple"""
	var dialog := InputDialog.new()
	dialog.dialog_title = title
	dialog.set_input_label(label)
	dialog.set_default_value(default)
	dialog.input_type = InputType.TEXT
	
	if callback.is_valid():
		dialog.input_submitted.connect(callback)
	
	if parent:
		parent.add_child(dialog)
	else:
		Engine.get_main_loop().root.add_child(dialog)
	
	dialog.open_dialog()
	return dialog

static func show_number_input(title: String, label: String, default_val: int = 0, min_val: int = 0, max_val: int = 999999, callback: Callable = Callable(), parent: Node = null) -> InputDialog:
	"""Affiche une saisie de nombre"""
	var dialog := InputDialog.new()
	dialog.dialog_title = title
	dialog.set_input_label(label)
	dialog.set_default_value(str(default_val))
	dialog.input_type = InputType.NUMBER
	dialog.set_number_range(min_val, max_val)
	
	if callback.is_valid():
		dialog.input_submitted.connect(callback)
	
	if parent:
		parent.add_child(dialog)
	else:
		Engine.get_main_loop().root.add_child(dialog)
	
	dialog.open_dialog()
	return dialog

static func show_guild_name_input(title: String = "Nom de Guilde", default_name: String = "", callback: Callable = Callable(), parent: Node = null) -> InputDialog:
	"""Affiche une saisie de nom de guilde"""
	var dialog := InputDialog.new()
	dialog.dialog_title = title
	dialog.set_input_label("Entrez le nom de la guilde :")
	dialog.set_default_value(default_name)
	dialog.input_type = InputType.GUILD_NAME
	dialog.required = true
	
	if callback.is_valid():
		dialog.input_submitted.connect(callback)
	
	if parent:
		parent.add_child(dialog)
	else:
		Engine.get_main_loop().root.add_child(dialog)
	
	dialog.open_dialog()
	return dialog