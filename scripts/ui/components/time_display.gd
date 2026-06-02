extends PanelContainer

@onready var date_label: Label = $VBoxContainer/DateLabel
@onready var time_label: Label = $VBoxContainer/TimeLabel
@onready var server_version_label: Label = $VBoxContainer/ServerVersionLabel
@onready var speed_label: Label = $VBoxContainer/HBoxContainer/SpeedLabel
@onready var pause_button: Button = $VBoxContainer/HBoxContainer/PauseButton
@onready var debug_version_button: Button = $VBoxContainer/HBoxContainer/DebugVersionButton
@onready var speed_slider: HSlider = $VBoxContainer/SpeedSlider

var game_time: Node
var server_version: Node

## Paliers de vitesse discrets (le slider continu seul est difficile à régler au point près).
const SPEED_PRESETS := [
	{"label": "1x", "value": 1.0},
	{"label": "10x", "value": 10.0},
	{"label": "60x", "value": 60.0},
	{"label": "600x", "value": 600.0},
	{"label": "Max", "value": 2400.0},
]
var _speed_preset_buttons: Array = []

func _ready() -> void:
	# On récupérera l'instance de GameTime depuis l'autoload
	game_time = GameTime
	server_version = ServerVersion
	
	if game_time:
		# Connecte les signaux (event-driven, plus de polling dans _process)
		game_time.minute_changed.connect(_on_minute_changed)
		game_time.hour_changed.connect(_on_hour_changed)
		game_time.day_changed.connect(_on_day_changed)

		# Configure les contrôles
		pause_button.pressed.connect(_on_pause_button_pressed)
		debug_version_button.visible = OS.is_debug_build()
		if debug_version_button.visible:
			debug_version_button.pressed.connect(_on_debug_version_button_pressed)
		speed_slider.value_changed.connect(_on_speed_changed)
		speed_slider.min_value = 0.1
		speed_slider.max_value = 2400.0
		speed_slider.value = game_time.time_speed
		speed_slider.step = 0.1
		_setup_speed_presets()

		# Mise à jour initiale
		_update_time_label()
		_update_display()
		_update_speed_label()

	if server_version:
		server_version.version_updated.connect(_on_server_version_updated)
		_update_server_version_display()

func _on_minute_changed(_minute: int, _hour: int) -> void:
	_update_time_label()

func _on_hour_changed(_hour: int) -> void:
	_update_display()

func _on_day_changed(_day: int, _week: int, _year: int) -> void:
	_update_display()

func _update_time_label() -> void:
	if not game_time:
		return
	time_label.text = game_time.get_current_time_string()
	# Indicateur de pause (mis à jour aussi depuis le callback du bouton)
	if game_time.is_paused:
		time_label.text += " [PAUSE]"
		time_label.modulate = Color(1, 1, 0.5)  # Jaune pâle
	else:
		time_label.modulate = Color.WHITE

func _update_display() -> void:
	if game_time:
		date_label.text = game_time.get_current_date_string()

func _on_pause_button_pressed() -> void:
	if game_time:
		game_time.toggle_pause()
		pause_button.text = "Reprendre" if game_time.is_paused else "Pause"
		# Le label [PAUSE] est rafraîchi immédiatement (sinon il attendrait
		# le prochain tick de minute, qui est figé pendant la pause).
		_update_time_label()

func _on_debug_version_button_pressed() -> void:
	if server_version:
		var current = server_version.get_current_version()
		var next_version = null
		var all_versions = server_version.get_all_versions()
		
		for version in all_versions:
			if version > current:
				if next_version == null or version < next_version:
					next_version = version
		
		if next_version:
			server_version.force_version_update(next_version)
			print("Version forcée vers %s" % next_version)

func _on_speed_changed(value: float) -> void:
	if game_time:
		game_time.set_time_speed(value)
		_update_speed_label()
		_highlight_active_preset()

func _setup_speed_presets() -> void:
	"""Boutons de paliers de vitesse (Football-Manager-like) sous le slider."""
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	$VBoxContainer.add_child(row)
	for preset in SPEED_PRESETS:
		var b := Button.new()
		b.text = preset.label
		b.toggle_mode = true
		b.tooltip_text = "Vitesse x%s" % str(preset.value)
		b.custom_minimum_size = Vector2(44, 0)
		b.pressed.connect(_set_speed_preset.bind(preset.value))
		row.add_child(b)
		_speed_preset_buttons.append({"button": b, "value": preset.value})
	_highlight_active_preset()

func _set_speed_preset(value: float) -> void:
	if game_time:
		game_time.set_time_speed(value)
		speed_slider.set_value_no_signal(value)
		_update_speed_label()
		_highlight_active_preset()

func _highlight_active_preset() -> void:
	if not game_time:
		return
	for entry in _speed_preset_buttons:
		entry.button.set_pressed_no_signal(is_equal_approx(entry.value, game_time.time_speed))

func _update_speed_label() -> void:
	if game_time:
		speed_label.text = "Vitesse: x%.1f" % game_time.time_speed

func _on_server_version_updated(_new_version: float, _update_name: String) -> void:
	_update_server_version_display()

func _update_server_version_display() -> void:
	if server_version and server_version_label:
		var version_info = server_version.get_current_version_info()
		var days_until_next = server_version.get_days_until_next_version()
		
		var text = "Serveur v%s - %s" % [server_version.get_current_version(), version_info.get("name", "")]
		if days_until_next > 0:
			text += " (Mise à jour dans %d jours)" % days_until_next
		elif days_until_next == 0:
			text += " (Mise à jour imminente)"
		
		server_version_label.text = text
