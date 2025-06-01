extends PanelContainer

@onready var date_label: Label = $VBoxContainer/DateLabel
@onready var time_label: Label = $VBoxContainer/TimeLabel
@onready var speed_label: Label = $VBoxContainer/HBoxContainer/SpeedLabel
@onready var pause_button: Button = $VBoxContainer/HBoxContainer/PauseButton
@onready var speed_slider: HSlider = $VBoxContainer/SpeedSlider

var game_time: Node

func _ready():
	# On récupérera l'instance de GameTime depuis l'autoload
	game_time = get_node("/root/GameTime") if has_node("/root/GameTime") else null
	
	if game_time:
		# Connecte les signaux
		game_time.hour_changed.connect(_on_hour_changed)
		game_time.day_changed.connect(_on_day_changed)
		
		# Configure les contrôles
		pause_button.pressed.connect(_on_pause_button_pressed)
		speed_slider.value_changed.connect(_on_speed_changed)
		speed_slider.min_value = 0.1
		speed_slider.max_value = 2400.0
		speed_slider.value = game_time.time_speed
		speed_slider.step = 0.1
		
		# Mise à jour initiale
		_update_display()
		_update_speed_label()

func _process(_delta):
	if game_time:
		time_label.text = game_time.get_current_time_string()

func _on_hour_changed(_hour: int):
	_update_display()

func _on_day_changed(_day: int, _week: int, _year: int):
	_update_display()

func _update_display():
	if game_time:
		date_label.text = game_time.get_current_date_string()

func _on_pause_button_pressed():
	if game_time:
		game_time.toggle_pause()
		pause_button.text = "Reprendre" if game_time.is_paused else "Pause"

func _on_speed_changed(value: float):
	if game_time:
		game_time.set_time_speed(value)
		_update_speed_label()

func _update_speed_label():
	if game_time:
		speed_label.text = "Vitesse: x%.1f" % game_time.time_speed