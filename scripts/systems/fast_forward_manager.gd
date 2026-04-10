extends Node
class_name FastForwardManager

signal fast_forward_started()
signal fast_forward_progress(current_time: Dictionary, target_time: Dictionary, progress: float)
signal fast_forward_completed(report: Dictionary)

var game_time: Node
var player_character: Resource = null
var is_fast_forwarding: bool = false
var is_forced_mode: bool = false  # Indique si c'est un fast-forward forcé (non-annulable)

var target_return_time: Dictionary = {}
var start_time: Dictionary = {}
var fast_forward_speed: float = 2400.0  # Très rapide pour le fast-forward

func _ready():
	game_time = get_node("/root/GameTime")
	if not game_time:
		print("ERREUR: FastForwardManager ne peut pas trouver GameTime")

func set_player_character(player: Resource):
	player_character = player

func start_fast_forward(target_hour: int, target_minute: int = 0, forced: bool = false) -> bool:
	"""Démarre le fast-forward jusqu'à l'heure cible"""
	if is_fast_forwarding or not game_time or not player_character:
		return false
	
	# Définir le mode forcé
	is_forced_mode = forced
	
	# S'assurer que le joueur est déconnecté pendant le fast-forward
	if player_character.is_online:
		player_character.disconnect_player("Fast-forward en cours")
	
	# Calculer l'heure cible
	var current_day = game_time.current_day
	var target_day = current_day
	
	# Si l'heure cible est passée aujourd'hui, aller au jour suivant
	if (target_hour < game_time.current_hour or 
		(target_hour == game_time.current_hour and target_minute <= game_time.current_minute)):
		target_day += 1
		if target_day > 7:
			target_day = 1
	
	target_return_time = {
		"hour": target_hour,
		"minute": target_minute,
		"day": target_day,
		"week": game_time.current_week,
		"year": game_time.current_year
	}
	
	start_time = {
		"hour": game_time.current_hour,
		"minute": game_time.current_minute,
		"day": game_time.current_day,
		"week": game_time.current_week,
		"year": game_time.current_year
	}
	
	# Stocker la vitesse actuelle et accélérer
	var original_speed = game_time.time_speed
	game_time.set_time_speed(fast_forward_speed)
	
	# Mettre en pause les événements pendant le fast-forward
	var event_manager = get_node("/root/EventManager")
	if event_manager:
		event_manager.pause_events()
	
	is_fast_forwarding = true
	fast_forward_started.emit()
	
	print("Fast-forward démarré vers J%d %02d:%02d" % [target_day, target_hour, target_minute])
	
	# Démarrer la boucle de vérification
	_check_fast_forward_progress()
	
	return true

func _check_fast_forward_progress():
	"""Vérifie si le fast-forward doit continuer"""
	if not is_fast_forwarding:
		return
	
	# Calculer la progression
	var current_total_minutes = _time_to_minutes(game_time.current_hour, game_time.current_minute, game_time.current_day)
	var target_total_minutes = _time_to_minutes(target_return_time.hour, target_return_time.minute, target_return_time.day)
	var start_total_minutes = _time_to_minutes(start_time.hour, start_time.minute, start_time.day)
	
	# Gérer le passage de jour
	if target_total_minutes < start_total_minutes:
		target_total_minutes += 24 * 60 * 7  # Ajouter une semaine en minutes
	if current_total_minutes < start_total_minutes:
		current_total_minutes += 24 * 60 * 7
	
	var total_duration = target_total_minutes - start_total_minutes
	var elapsed = current_total_minutes - start_total_minutes
	var progress = float(elapsed) / float(total_duration) if total_duration > 0 else 1.0
	
	# Émettre le signal de progression
	var current_time = {
		"hour": game_time.current_hour,
		"minute": game_time.current_minute,
		"day": game_time.current_day
	}
	fast_forward_progress.emit(current_time, target_return_time, clamp(progress, 0.0, 1.0))
	
	# Vérifier si on a atteint l'heure cible
	if _has_reached_target():
		_complete_fast_forward()
		return
	
	# Continuer la vérification
	await get_tree().create_timer(0.1).timeout
	_check_fast_forward_progress()

func _has_reached_target() -> bool:
	"""Vérifie si on a atteint l'heure cible"""
	return (game_time.current_day == target_return_time.day and 
			game_time.current_hour >= target_return_time.hour and
			game_time.current_minute >= target_return_time.minute)

func _complete_fast_forward():
	"""Termine le fast-forward et génère le rapport"""
	if not is_fast_forwarding:
		return
	
	is_fast_forwarding = false
	is_forced_mode = false  # Réinitialiser le mode forcé
	
	# Remettre la vitesse normale
	game_time.set_time_speed(60.0)
	
	# Reprendre les événements
	var event_manager = get_node("/root/EventManager")
	if event_manager:
		event_manager.resume_events()
	
	# Générer le rapport de la période offline
	var report = _generate_offline_report()
	
	# Reconnecter le joueur avec l'énergie récupérée
	if player_character and not player_character.is_online:
		# Restaurer l'énergie avant de reconnecter
		var energy_to_restore = report.get("energy_recovery", 0.0)
		player_character.player_energy_pool = min(
			player_character.max_energy_pool, 
			player_character.player_energy_pool + energy_to_restore
		)
		player_character.reconnect_player()
	
	fast_forward_completed.emit(report)
	print("Fast-forward terminé! Retour à l'heure normale.")

func cancel_fast_forward():
	"""Annule le fast-forward en cours"""
	if not is_fast_forwarding:
		return
	
	# INTERDIRE l'annulation en mode forcé
	if is_forced_mode:
		print("ERREUR: Impossible d'annuler un fast-forward forcé!")
		return
	
	is_fast_forwarding = false
	is_forced_mode = false
	
	# Remettre la vitesse normale
	game_time.set_time_speed(60.0)
	
	# Reprendre les événements
	var event_manager = get_node("/root/EventManager")
	if event_manager:
		event_manager.resume_events()
	
	# Reconnecter le joueur sans récupération d'énergie
	if player_character and not player_character.is_online:
		player_character.reconnect_player()
	
	print("Fast-forward annulé! Retour à l'heure normale.")

func _generate_offline_report() -> Dictionary:
	"""Génère un rapport de ce qui s'est passé pendant le fast-forward"""
	var offline_duration = _calculate_duration_hours()
	
	# Calcul de la récupération d'énergie selon la nouvelle formule
	var energy_recovery_percent = 0.0
	if offline_duration >= 12.0:
		energy_recovery_percent = 100.0  # 100% pour 12h+
	elif offline_duration >= 8.0:
		energy_recovery_percent = 80.0   # 80% pour 8h+
	elif offline_duration >= 6.0:
		energy_recovery_percent = 50.0   # 50% pour 6h+
	else:
		energy_recovery_percent = offline_duration * 8.0  # Approximation linéaire pour moins de 6h
	
	var energy_recovery = (player_character.max_energy_pool * energy_recovery_percent / 100.0)
	
	# Événements simulés pendant l'absence
	var events = _simulate_offline_events(offline_duration)
	
	# Progression de la guilde
	var guild_progress = _simulate_guild_progress(offline_duration)
	
	return {
		"duration_hours": offline_duration,
		"energy_recovery": energy_recovery,
		"events_missed": events,
		"guild_progress": guild_progress,
		"summary": _format_offline_summary(offline_duration, energy_recovery, events.size())
	}

func _simulate_offline_events(duration_hours: float) -> Array:
	"""Simule les événements qui ont pu arriver pendant l'absence"""
	var events = []
	
	# Plus longue l'absence, plus d'événements potentiels
	var event_chance = 0.1 * duration_hours  # 10% par heure
	var num_events = 0
	
	while randf() < event_chance and num_events < 5:  # Max 5 événements
		var event_types = [
			"Nouveau membre recruté par la guilde IA",
			"Donjon complété par un groupe de membres",
			"Conflit résolu entre membres",
			"Membre a gagné plusieurs niveaux",
			"Rival guild a fait une tentative de débauchage"
		]
		
		events.append(event_types[randi() % event_types.size()])
		num_events += 1
		event_chance *= 0.5  # Réduire la chance pour les événements suivants
	
	return events

func _simulate_guild_progress(duration_hours: float) -> Dictionary:
	"""Simule la progression de la guilde pendant l'absence"""
	return {
		"members_leveled": int(duration_hours * 0.5),  # Approximativement
		"dungeons_completed": int(duration_hours * 0.3),
		"reputation_change": randf_range(-2.0, 3.0) * (duration_hours / 24.0)  # Petits changements
	}

func _format_offline_summary(duration: float, energy: float, events: int) -> String:
	"""Formate un résumé de la période offline"""
	var duration_text = ""
	if duration >= 24:
		var days = int(duration / 24)
		var hours = int(duration) % 24
		duration_text = "%d jour(s) %d heure(s)" % [days, hours]
	else:
		duration_text = "%d heure(s)" % int(duration)
	
	return "Absent pendant %s\n+%.0f énergie récupérée\n%d événement(s) manqué(s)" % [
		duration_text, 
		energy, 
		events
	]

func _time_to_minutes(hour: int, minute: int, day: int) -> int:
	"""Convertit une heure en minutes totales depuis le début de la semaine"""
	return ((day - 1) * 24 * 60) + (hour * 60) + minute

func _calculate_duration_hours() -> float:
	"""Calcule la durée en heures entre le début et la fin du fast-forward"""
	var start_minutes = _time_to_minutes(start_time.hour, start_time.minute, start_time.day)
	var end_minutes = _time_to_minutes(game_time.current_hour, game_time.current_minute, game_time.current_day)
	
	# Gérer le passage de semaine
	if end_minutes < start_minutes:
		end_minutes += 24 * 60 * 7
	
	return float(end_minutes - start_minutes) / 60.0

func is_active() -> bool:
	"""Retourne si le fast-forward est actif"""
	return is_fast_forwarding