extends Control
class_name GameMenuBar

signal personnage_button_pressed
signal guilde_button_pressed
signal monde_button_pressed
signal organisation_button_pressed
signal national_button_pressed
signal esport_button_pressed
signal cohesion_button_pressed

var _buttons: Dictionary = {}  # window_name -> Button

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	custom_minimum_size.y = 80
	
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	panel.add_child(hbox)
	
	var personnage_btn = _create_menu_button("Personnage", "personnage", _on_personnage_pressed)
	var guilde_btn = _create_menu_button("Guilde", "guilde", _on_guilde_pressed)
	var monde_btn = _create_menu_button("Monde", "monde", _on_monde_pressed)
	var organisation_btn = _create_menu_button("Organisation", "organisation", _on_organisation_pressed)
	var national_btn = _create_menu_button("National", "national", _on_national_pressed)
	var esport_btn = _create_menu_button("Esport", "esport", _on_esport_pressed)
	var cohesion_btn = _create_menu_button("Cohésion", "cohesion", _on_cohesion_pressed)

	hbox.add_child(personnage_btn)
	hbox.add_child(guilde_btn)
	hbox.add_child(monde_btn)
	hbox.add_child(organisation_btn)
	hbox.add_child(national_btn)
	hbox.add_child(esport_btn)
	hbox.add_child(cohesion_btn)

func _create_menu_button(text: String, window_name: String, callback: Callable) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150, 50)
	var icon_tex: Texture2D = AssetLoader.get_menu_icon(text)
	if icon_tex:
		button.icon = icon_tex
		button.expand_icon = true
	button.pressed.connect(callback)
	button.toggle_mode = true
	_buttons[window_name] = button
	return button

func set_active_window(window_name: String) -> void:
	"""Surligne le bouton de la fenêtre active et estompe les autres."""
	for wname in _buttons:
		var btn: Button = _buttons[wname]
		var is_active: bool = wname == window_name
		btn.button_pressed = is_active
		btn.modulate = Color(1, 1, 1, 1) if is_active else Color(0.60, 0.63, 0.70, 1.0)

func _on_personnage_pressed():
	personnage_button_pressed.emit()

func _on_guilde_pressed():
	guilde_button_pressed.emit()

func _on_monde_pressed():
	monde_button_pressed.emit()

func _on_organisation_pressed():
	organisation_button_pressed.emit()

func _on_national_pressed():
	national_button_pressed.emit()

func _on_esport_pressed():
	esport_button_pressed.emit()

func _on_cohesion_pressed():
	cohesion_button_pressed.emit()