extends Control
class_name GameMenuBar

signal personnage_button_pressed
signal guilde_button_pressed
signal monde_button_pressed
signal organisation_button_pressed

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
	
	var personnage_btn = _create_menu_button("Personnage", _on_personnage_pressed)
	var guilde_btn = _create_menu_button("Guilde", _on_guilde_pressed)
	var monde_btn = _create_menu_button("Monde", _on_monde_pressed)
	var organisation_btn = _create_menu_button("Organisation", _on_organisation_pressed)
	
	hbox.add_child(personnage_btn)
	hbox.add_child(guilde_btn)
	hbox.add_child(monde_btn)
	hbox.add_child(organisation_btn)

func _create_menu_button(text: String, callback: Callable) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150, 50)
	var icon_tex: Texture2D = AssetLoader.get_menu_icon(text)
	if icon_tex:
		button.icon = icon_tex
		button.expand_icon = true
	button.pressed.connect(callback)
	return button

func _on_personnage_pressed():
	personnage_button_pressed.emit()

func _on_guilde_pressed():
	guilde_button_pressed.emit()

func _on_monde_pressed():
	monde_button_pressed.emit()

func _on_organisation_pressed():
	organisation_button_pressed.emit()