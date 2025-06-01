extends Node
class_name WindowManager

var windows = {}
var active_window = null

func _ready():
	pass

func register_window(window_name: String, window_scene_path: String):
	windows[window_name] = {
		"scene_path": window_scene_path,
		"instance": null
	}

func show_window(window_name: String):
	if not windows.has(window_name):
		push_error("Window not registered: " + window_name)
		return
	
	if active_window:
		hide_window(active_window)
	
	var window_data = windows[window_name]
	
	if not window_data.instance:
		var scene = load(window_data.scene_path)
		if not scene:
			push_error("Failed to load window scene: " + window_data.scene_path)
			return
		window_data.instance = scene.instantiate()
		get_parent().add_child(window_data.instance)
	
	window_data.instance.show()
	active_window = window_name

func hide_window(window_name: String):
	if not windows.has(window_name):
		return
	
	var window_data = windows[window_name]
	if window_data.instance:
		window_data.instance.hide()
	
	if active_window == window_name:
		active_window = null

func close_window(window_name: String):
	if not windows.has(window_name):
		return
	
	var window_data = windows[window_name]
	if window_data.instance:
		window_data.instance.queue_free()
		window_data.instance = null
	
	if active_window == window_name:
		active_window = null