extends Node

signal hour_changed(hour: int)
signal day_changed(day: int, week: int, year: int)
signal week_changed(week: int, year: int)
signal year_changed(year: int)

const MINUTES_PER_HOUR = 60
const HOURS_PER_DAY = 24
const DAYS_PER_WEEK = 7
const WEEKS_PER_YEAR = 52

# Vitesse du temps (1.0 = temps réel, 60.0 = 1 minute réelle = 1 heure de jeu)
var time_speed: float = 60.0

# État actuel du temps
var current_minute: int = 0
var current_hour: int = 9  # Commence à 9h du matin
var current_day: int = 1   # 1-7 (Lundi-Dimanche)
var current_week: int = 1  # 1-52
var current_year: int = 1

# Contrôle du temps
var is_paused: bool = false
var accumulated_time: float = 0.0

# Noms des jours (pour l'affichage)
var day_names = ["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi", "Dimanche"]

func _ready():
	set_process(true)

func _process(delta):
	if is_paused:
		return
	
	# Accumule le temps écoulé avec la vitesse définie
	accumulated_time += delta * time_speed
	
	# Convertit en minutes de jeu
	while accumulated_time >= 60.0:
		accumulated_time -= 60.0
		advance_minute()

func advance_minute():
	current_minute += 1
	
	if current_minute >= MINUTES_PER_HOUR:
		current_minute = 0
		advance_hour()

func advance_hour():
	current_hour += 1
	
	if current_hour >= HOURS_PER_DAY:
		current_hour = 0
		advance_day()
	
	hour_changed.emit(current_hour)

func advance_day():
	current_day += 1
	
	if current_day > DAYS_PER_WEEK:
		current_day = 1
		advance_week()
	
	day_changed.emit(current_day, current_week, current_year)

func advance_week():
	current_week += 1
	
	if current_week > WEEKS_PER_YEAR:
		current_week = 1
		advance_year()
	
	week_changed.emit(current_week, current_year)

func advance_year():
	current_year += 1
	year_changed.emit(current_year)

# Fonctions de contrôle
func pause():
	is_paused = true

func resume():
	is_paused = false

func toggle_pause():
	is_paused = !is_paused

func set_time_speed(speed: float):
	time_speed = max(0.1, speed)  # Minimum 0.1x

func fast_forward_hours(hours: int):
	for i in range(hours):
		for j in range(MINUTES_PER_HOUR):
			advance_minute()

# Fonctions utilitaires
func get_current_time_string() -> String:
	return "%02d:%02d" % [current_hour, current_minute]

func get_current_date_string() -> String:
	return "%s - Semaine %d, Année %d" % [day_names[current_day - 1], current_week, current_year]

func get_full_datetime_string() -> String:
	return "%s %s" % [get_current_date_string(), get_current_time_string()]

func get_day_name(day: int = current_day) -> String:
	if day >= 1 and day <= 7:
		return day_names[day - 1]
	return "Invalide"

func is_weekend() -> bool:
	return current_day >= 6  # Samedi et Dimanche

func is_weekday() -> bool:
	return current_day <= 5  # Lundi à Vendredi

func is_evening() -> bool:
	return current_hour >= 18 or current_hour < 2

func is_night() -> bool:
	return current_hour >= 23 or current_hour < 6

func is_morning() -> bool:
	return current_hour >= 6 and current_hour < 12

func is_afternoon() -> bool:
	return current_hour >= 12 and current_hour < 18

# Sauvegarde et chargement
func save_time_data() -> Dictionary:
	return {
		"minute": current_minute,
		"hour": current_hour,
		"day": current_day,
		"week": current_week,
		"year": current_year,
		"time_speed": time_speed
	}

func load_time_data(data: Dictionary):
	current_minute = data.get("minute", 0)
	current_hour = data.get("hour", 9)
	current_day = data.get("day", 1)
	current_week = data.get("week", 1)
	current_year = data.get("year", 1)
	time_speed = data.get("time_speed", 60.0)