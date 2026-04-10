extends PanelContainer
class_name ResizableWindow

signal close_requested

var is_dragging: bool = false
var is_resizing: bool = false
var drag_offset: Vector2
var resize_margin: int = 10
var min_size: Vector2 = Vector2(400, 300)

var title_bar: PanelContainer
var title_label: Label
var close_button: Button
var content_container: VBoxContainer

func _ready():
	mouse_filter = Control.MOUSE_FILTER_PASS
	
func setup_window(title: String, initial_size: Vector2):
	custom_minimum_size = initial_size
	size = initial_size
	
	# Container principal
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	add_child(main_vbox)
	
	# Barre de titre
	title_bar = PanelContainer.new()
	title_bar.custom_minimum_size = Vector2(0, 30)
	title_bar.modulate = Color(0.8, 0.8, 0.8)
	main_vbox.add_child(title_bar)
	
	var title_hbox = HBoxContainer.new()
	title_bar.add_child(title_hbox)
	
	title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 16)
	title_hbox.add_child(title_label)
	
	title_hbox.add_spacer(false)
	
	close_button = Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(30, 25)
	close_button.pressed.connect(_on_close_pressed)
	title_hbox.add_child(close_button)
	
	# Conteneur pour le contenu
	content_container = VBoxContainer.new()
	content_container.add_theme_constant_override("separation", 10)
	main_vbox.add_child(content_container)
	
	# Connecte les événements de souris
	title_bar.gui_input.connect(_on_title_bar_input)
	gui_input.connect(_on_window_input)

func _on_title_bar_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				drag_offset = global_position - event.global_position
			else:
				is_dragging = false

func _on_window_input(event: InputEvent):
	if event is InputEventMouseMotion:
		if is_dragging:
			global_position = event.global_position + drag_offset
		elif is_resizing:
			var new_size = event.global_position - global_position
			size = Vector2(
				max(min_size.x, new_size.x),
				max(min_size.y, new_size.y)
			)
		else:
			# Vérifie si on est sur le bord pour redimensionner
			var cursor_type = _get_resize_cursor(event.position)
			if cursor_type != "":
				mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
			else:
				mouse_default_cursor_shape = Control.CURSOR_ARROW
				
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var cursor_type = _get_resize_cursor(event.position)
				if cursor_type != "":
					is_resizing = true
			else:
				is_resizing = false

func _get_resize_cursor(pos: Vector2) -> String:
	var margin = resize_margin
	
	# Coin bas-droite
	if pos.x > size.x - margin and pos.y > size.y - margin:
		return "resize_br"
	# Bord droit
	elif pos.x > size.x - margin:
		return "resize_r"
	# Bord bas
	elif pos.y > size.y - margin:
		return "resize_b"
		
	return ""

func _on_close_pressed():
	close_requested.emit()
	hide()

func get_content_container() -> VBoxContainer:
	return content_container

func set_window_title(title: String):
	if title_label:
		title_label.text = title
