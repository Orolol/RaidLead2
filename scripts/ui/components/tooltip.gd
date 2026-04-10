extends PanelContainer
class_name Tooltip

@onready var label: Label = $MarginContainer/Label

var target_node: Control = null
var offset: Vector2 = Vector2(10, 10)

func _ready():
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100  # Toujours au-dessus

func show_tooltip(text: String, node: Control):
	label.text = text
	target_node = node
	show()
	_update_position()

func hide_tooltip():
	hide()
	target_node = null

func _process(_delta):
	if visible and target_node:
		_update_position()

func _update_position():
	if not target_node:
		return
		
	var mouse_pos = get_global_mouse_position()
	var tooltip_size = size
	var viewport_size = get_viewport_rect().size
	
	# Position de base : à droite de la souris
	var new_position = mouse_pos + offset
	
	# Ajuster si dépasse à droite
	if new_position.x + tooltip_size.x > viewport_size.x:
		new_position.x = mouse_pos.x - tooltip_size.x - offset.x
	
	# Ajuster si dépasse en bas
	if new_position.y + tooltip_size.y > viewport_size.y:
		new_position.y = mouse_pos.y - tooltip_size.y - offset.y
	
	global_position = new_position