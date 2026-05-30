extends Node

## Gere la legende et la reconnaissance de la guilde (Phase Esport, US 4.5).
## Accumule des entrees au Hall of Fame et des points de legacy a partir des
## accomplissements (titres de tournois, accession a l'esport), et debloque des
## titres permanents a des seuils.

signal legacy_earned(entry)
signal title_unlocked(title)

var hall_of_fame: Array = []     # Array[Dictionary] {title, description, points, date}
var legacy_points: int = 0
var unlocked_titles: Array = []  # Array[String]

const TITLE_THRESHOLDS := [
	[50, "Espoir prometteur"],
	[150, "Vétéran reconnu"],
	[300, "Légende vivante"],
	[600, "Icône de l'esport"],
	[1000, "Immortel"],
]

func _ready() -> void:
	if TournamentManager and TournamentManager.has_signal("tournament_completed"):
		TournamentManager.tournament_completed.connect(_on_tournament_completed)
	if PhaseManager and PhaseManager.has_signal("phase_changed"):
		PhaseManager.phase_changed.connect(_on_phase_changed)

func _on_tournament_completed(tournament, _stage_reached: int, is_champion: bool, _results: Dictionary) -> void:
	if not is_champion:
		return
	if tournament.is_world_championship():
		add_legacy_entry("Champion du Monde", "Victoire au %s" % tournament.tournament_name, 300)
		_unlock_title("Champion du Monde")
	else:
		add_legacy_entry("Titre remporté", "Vainqueur de %s" % tournament.tournament_name, 80)

func _on_phase_changed(new_phase, _old_phase) -> void:
	if new_phase == PhaseManager.GamePhase.ESPORT:
		add_legacy_entry("Accession à l'élite", "La guilde atteint le niveau Esport mondial.", 100)

func add_legacy_entry(title: String, description: String, points: int) -> void:
	var entry: Dictionary = {
		"title": title,
		"description": description,
		"points": points,
		"date": _date_string(),
	}
	hall_of_fame.append(entry)
	legacy_points += points
	legacy_earned.emit(entry)
	_check_titles()
	var nm: Node = get_node_or_null("/root/NotificationManager")
	if nm:
		nm.show_achievement("%s (+%d legacy)" % [title, points], "Hall of Fame")

func _check_titles() -> void:
	for pair in TITLE_THRESHOLDS:
		if legacy_points >= pair[0]:
			_unlock_title(pair[1])

func _unlock_title(title: String) -> void:
	if title in unlocked_titles:
		return
	unlocked_titles.append(title)
	title_unlocked.emit(title)
	var nm: Node = get_node_or_null("/root/NotificationManager")
	if nm:
		nm.show_achievement("Titre débloqué : %s" % title, "Legacy")

func get_rank_title() -> String:
	"""Titre de rang le plus eleve atteint selon les points de legacy."""
	var current: String = "Sans titre"
	for pair in TITLE_THRESHOLDS:
		if legacy_points >= pair[0]:
			current = pair[1]
	return current

func get_next_threshold() -> int:
	"""Points requis pour le prochain titre de rang (0 si tous atteints)."""
	for pair in TITLE_THRESHOLDS:
		if legacy_points < pair[0]:
			return pair[0]
	return 0

func get_legacy_points() -> int:
	return legacy_points

func _date_string() -> String:
	if GameTime:
		return "S%d A%d" % [GameTime.current_week, GameTime.current_year]
	return ""

func serialize() -> Dictionary:
	return {
		"hall_of_fame": hall_of_fame,
		"legacy_points": legacy_points,
		"unlocked_titles": unlocked_titles,
	}

func deserialize(data: Dictionary) -> void:
	hall_of_fame = data.get("hall_of_fame", [])
	legacy_points = data.get("legacy_points", 0)
	unlocked_titles = data.get("unlocked_titles", [])
