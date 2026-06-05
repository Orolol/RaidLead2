extends Node
class_name BehaviorSystem

signal behavior_changed(player, change_type)
signal personal_event_triggered(player, event)
signal burnout_level_changed(player, new_level)

const PersonalEventsScript = preload("res://scripts/data/personal_events.gd")
const BehaviorProfileScript = preload("res://scripts/resources/behavior_profile.gd")

const DAY_KEYS: Array[String] = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"]
const MINUTES_PER_DAY := 24 * 60
const CONNECTION_WINDOW_MINUTES := 20

var game_time: Node
var guild_manager: Node
var social_dynamics: Node

# Cache pour optimisation
var connection_probability_cache: Dictionary = {}
var last_cache_update: int = -1

# Horaires personnalisés par joueur (minutes absolues de connexion/déconnexion prévues)
var player_scheduled_times: Dictionary = {}

func forget_player(player) -> void:
	"""Purge les caches d'un membre qui quitte la guilde (évite une fuite de références :
	player_scheduled_times n'était jamais nettoyé au départ d'un membre)."""
	player_scheduled_times.erase(player)
	connection_probability_cache.erase(player)

func _ready() -> void:
	game_time = GameTime
	guild_manager = GuildManager

	# Le social_dynamics sera créé après
	call_deferred("_init_social_dynamics")
	
	if game_time:
		# Se connecter au signal de changement de minute pour plus de granularité
		game_time.minute_changed.connect(_on_minute_changed)
		game_time.hour_changed.connect(_on_hour_changed)
		game_time.day_changed.connect(_on_day_changed)

func _init_social_dynamics() -> void:
	var social_dynamics_script = load("res://scripts/systems/social_dynamics.gd")
	social_dynamics = Node.new()
	social_dynamics.set_script(social_dynamics_script)
	social_dynamics.name = "SocialDynamics"
	add_child(social_dynamics)

func _on_minute_changed(minute: int, _hour: int) -> void:
	"""Appelé chaque minute pour des comportements plus granulaires"""
	
	# Vérifier seulement toutes les 5 minutes pour optimiser les performances
	if minute % 5 != 0:
		return
	
	# Vérifier les connexions/déconnexions planifiées
	_check_scheduled_connections()
	
	# Petite chance de vérifier les événements spontanés
	if randf() < 0.1:  # 10% de chance toutes les 5 minutes
		_check_spontaneous_events()

func _on_hour_changed(hour: int) -> void:
	# Vider le cache chaque heure
	if hour != last_cache_update:
		connection_probability_cache.clear()
		last_cache_update = hour
	
	# Mettre à jour la fatigue accumulée
	_update_fatigue_levels()
	
	# Vérifier les événements personnels
	_check_personal_events()

func _on_day_changed(_day: int, _week: int, _year: int) -> void:
	# Réinitialiser certains compteurs quotidiens
	for member in guild_manager.guild_members:
		# Réinitialiser le flag d'événement quotidien
		member.daily_event_triggered = false
		
		# Réduire légèrement la fatigue accumulée chaque jour
		if member.fatigue_accumulated > 0:
			member.fatigue_accumulated = max(0, member.fatigue_accumulated - 5)
		if not member.get_meta("is_player", false) and not member.is_online:
			_schedule_next_connection_time(member)

func get_activity_preference(player, activity_type: String) -> float:
	"""Retourne la préférence d'un joueur pour un type d'activité"""
	
	if player.activity_preferences == null or player.activity_preferences.is_empty():
		player.activity_preferences = _initialize_activity_preferences(player)
	
	var base_pref = player.activity_preferences.get(activity_type, 0.5)
	
	# Modificateurs selon l'état
	match activity_type:
		"LEVELING":
			if player.personnage_niveau < 60:
				base_pref *= 1.5
			else:
				base_pref *= 0.1
		
		"FARMING":
			var ilvl = player.get_total_ilvl()
			if ilvl < 50:  # Sous-équipé
				base_pref *= 1.3
		
		"FUN":
			if player.mood < 40:
				base_pref *= 2.0
			if (player.burnout_level if player.burnout_level != null else 0) > 1:
				base_pref *= 1.5
		
		"DUNGEON", "RAID":
			if (player.fatigue_accumulated if player.fatigue_accumulated != null else 0) > 70:
				base_pref *= 0.3
			if (player.burnout_level if player.burnout_level != null else 0) > 2:
				base_pref *= 0.2
			# Boost si récent succès. Le sentinel "jamais" est -1 ; un vrai succès écrit
			# le jour absolu qui peut valoir 0. On teste donc >= 0 (et non > 0, qui
			# ignorerait à tort un succès survenu le jour 0), aligné sur
			# _get_player_motivation_modifier.
			var last_raid_success_day = player.last_raid_success_day if player.last_raid_success_day != null else -1
			if last_raid_success_day >= 0:
				var days_since = _absolute_day() - last_raid_success_day
				if days_since <= 2:
					base_pref *= 1.4
	
	# Influence des tags
	if "tryhard" in player.tags_comportement:
		if activity_type in ["DUNGEON", "RAID"]:
			base_pref *= 1.3
	elif "casual" in player.tags_comportement:
		if activity_type == "FUN":
			base_pref *= 1.2
		elif activity_type in ["DUNGEON", "RAID"]:
			base_pref *= 0.7
	
	return clamp(base_pref, 0.1, 2.0)

func update_activity_preference(player, activity_type: String, experience_quality: float) -> void:
	"""Met à jour les préférences selon l'expérience (quality: -1 à 1)"""
	
	if player.activity_preferences == null or player.activity_preferences.is_empty():
		player.activity_preferences = _initialize_activity_preferences(player)
	
	var current = player.activity_preferences.get(activity_type, 0.5)
	var change = experience_quality * 0.1  # Max ±10% par expérience
	
	player.activity_preferences[activity_type] = clamp(current + change, 0.1, 1.0)
	
	# Mémoriser l'expérience
	if player.recent_events_memory == null:
		player.recent_events_memory = []
	
	player.recent_events_memory.append({
		"type": "activity_experience",
		"activity": activity_type,
		"quality": experience_quality,
		"day": game_time.current_day
	})
	
	# Garder seulement les 20 derniers événements
	if player.recent_events_memory.size() > 20:
		player.recent_events_memory.pop_front()

func apply_circadian_modifier(player, hour: int) -> float:
	"""Retourne un modificateur selon l'heure et le type circadien du joueur"""
	
	var circadian_type = player.circadian_type if player.circadian_type != null else "flexible"
	
	match circadian_type:
		"morning":
			if hour >= 6 and hour < 12:
				return 1.3  # +30% performance le matin
			elif hour >= 22 or hour < 6:
				return 0.6  # -40% tard le soir
		
		"evening":
			if hour >= 20 or hour < 2:
				return 1.3  # +30% performance le soir
			elif hour >= 6 and hour < 10:
				return 0.7  # -30% tôt le matin
		
		"flexible":
			return 1.0  # Pas de modification
	
	return 1.0

func trigger_personal_event(player, event_type: String) -> void:
	"""Déclenche un événement personnel pour un joueur"""

	var event = PersonalEventsScript.get_event(event_type)
	if event.is_empty():
		return

	# Effets génériques sur l'humeur / l'énergie (présents sur la plupart des events)
	if event.has("mood_impact"):
		player.mood = clampf(player.mood + float(event["mood_impact"]), 0.0, 100.0)
	if event.has("energy_boost"):
		player.energy = clampf(player.energy + float(event["energy_boost"]), 0.0, 100.0)

	# Effets spécifiques selon le type
	match event.get("effect_type", ""):
		"immediate_disconnect":
			player.has_urgent_event = true
			if player.is_online:
				behavior_changed.emit(player, "urgent_disconnect")

		"schedule_absence":
			if player.scheduled_absences == null:
				player.scheduled_absences = []
			player.scheduled_absences.append({
				"event": event_type,
				"start_day": _absolute_day() + int(event.get("delay_days", 0)),
				"duration_days": int(event.get("duration_days", 1))
			})

		"bonus_time":
			player.bonus_session_hours = event.get("bonus_hours", 2)
			# Armer le bonus de motivation : il est lu par _get_player_motivation_modifier (+12%)
			# et desarme a la consommation de bonus_session_hours (_schedule_next_disconnection_time).
			player.bonus_session_active = true
			behavior_changed.emit(player, "bonus_time")

		"mood_modifier":
			player.mood = clampf(player.mood + float(event.get("mood_change", 0)), 0.0, 100.0)

		"energy_modifier":
			player.energy = clampf(player.energy + float(event.get("energy_change", 0)), 0.0, 100.0)

	personal_event_triggered.emit(player, event)

	# Mémoriser l'événement (jour absolu)
	if player.recent_events_memory == null:
		player.recent_events_memory = []

	player.recent_events_memory.append({
		"type": "personal_event",
		"event": event_type,
		"day": _absolute_day()
	})

func update_burnout_level(player) -> void:
	"""Met à jour le niveau de burnout selon la fatigue accumulée"""
	
	var fatigue = player.fatigue_accumulated if player.fatigue_accumulated != null else 0
	var old_burnout = player.burnout_level if player.burnout_level != null else 0
	var new_burnout = 0
	
	# Déterminer le nouveau niveau
	if fatigue >= 90:
		new_burnout = 3
	elif fatigue >= 70:
		new_burnout = 2
	elif fatigue >= 50:
		new_burnout = 1
	else:
		new_burnout = 0
	
	# Appliquer le changement
	if new_burnout != old_burnout:
		player.burnout_level = new_burnout
		burnout_level_changed.emit(player, new_burnout)
		
		# Effets du burnout
		match new_burnout:
			1:
				player.mood = max(player.mood - 10, 0)
			2:
				player.mood = max(player.mood - 20, 0)
				player.energy = min(player.energy, 70)
			3:
				player.mood = max(player.mood - 30, 0)
				player.energy = min(player.energy, 50)
				# Risque de départ augmenté (géré ailleurs)

func add_fatigue(player, amount: float) -> void:
	"""Ajoute de la fatigue à un joueur"""
	
	var old_fatigue = player.fatigue_accumulated if player.fatigue_accumulated != null else 0
	player.fatigue_accumulated = clamp(old_fatigue + amount, 0, 100)
	
	# Vérifier si le niveau de burnout change
	update_burnout_level(player)

func recover_fatigue(player, amount: float) -> void:
	"""Réduit la fatigue d'un joueur"""
	
	var current_fatigue = player.fatigue_accumulated if player.fatigue_accumulated != null else 0
	if current_fatigue <= 0:
		return
	
	player.fatigue_accumulated = max(0, current_fatigue - amount)
	update_burnout_level(player)

# Méthodes privées

func _get_base_connection_probability(player) -> float:
	"""Calcule la probabilité de base de connexion selon le planning"""
	if player and player.has_method("get_connection_score_for_time"):
		return player.get_connection_score_for_time(game_time)
	
	var day_name = game_time.get_day_name().to_lower()
	if not player.planning.has(day_name):
		return 0.0
	
	var day_schedule = player.planning[day_name]
	var prob = 0.0
	
	if game_time.is_evening() and day_schedule.get("soir", false):
		prob = 0.8  # 80% de base le soir
	elif game_time.is_afternoon() and day_schedule.get("apres_midi", false):
		prob = 0.7  # 70% de base l'après-midi
	
	# Variance selon l'heure exacte
	var variance = player.personal_schedule_variance if player.personal_schedule_variance != null else Vector2(-0.5, 0.5)
	if variance != null:
		var hour_offset = randf_range(variance.x, variance.y)
		
		# Ajuster la probabilité selon le décalage
		if abs(hour_offset) > 0.5:
			prob *= 0.8  # Moins probable si en dehors de l'horaire habituel
	
	return prob

func _should_disconnect_by_schedule(player) -> bool:
	"""Vérifie si le joueur devrait se déconnecter selon son planning"""
	if player and player.has_method("get_connection_score_for_time"):
		return player.get_connection_score_for_time(game_time) < 0.08
	
	var day_name = game_time.get_day_name().to_lower()
	if not player.planning.has(day_name):
		return true
	
	var day_schedule = player.planning[day_name]
	var in_schedule = false
	
	if game_time.is_evening() and day_schedule.get("soir", false):
		in_schedule = true
	elif game_time.is_afternoon() and day_schedule.get("apres_midi", false):
		in_schedule = true
	
	# Ajouter de la variance
	var variance = player.personal_schedule_variance if player.personal_schedule_variance != null else Vector2(-0.5, 0.5)
	if variance != null and in_schedule:
		var extend_probability = 0.3 + (player.mood / 200.0)  # 30-80% selon humeur
		if randf() < extend_probability:
			in_schedule = true  # Reste un peu plus
	
	return not in_schedule

func _update_fatigue_levels() -> void:
	"""Met à jour la fatigue de tous les membres"""
	
	for member in guild_manager.guild_members:
		if not member.is_online:
			# Récupération hors ligne
			recover_fatigue(member, 2.0)
		else:
			# Fatigue selon l'activité
			if member.current_activity:
				var fatigue_rate = 1.0

				match member.current_activity.type:
					Activity.ActivityType.RAID:
						fatigue_rate = 3.0
					Activity.ActivityType.DUNGEON:
						fatigue_rate = 2.0
					Activity.ActivityType.FARMING:
						fatigue_rate = 1.5
					Activity.ActivityType.LEVELING:
						fatigue_rate = 1.0
					Activity.ActivityType.FUN:
						fatigue_rate = -0.5  # Récupère en s'amusant
				
				if fatigue_rate > 0:
					add_fatigue(member, fatigue_rate * _get_energy_drain_modifier())
				else:
					recover_fatigue(member, abs(fatigue_rate))

func _get_energy_drain_modifier() -> float:
	if ServerVersion and ServerVersion.has_method("get_hype_energy_drain_multiplier"):
		return ServerVersion.get_hype_energy_drain_multiplier()
	return 1.0

func _check_personal_events() -> void:
	"""Vérifie et déclenche les événements personnels"""
	
	for member in guild_manager.guild_members:
		# Passer si déjà eu un événement aujourd'hui
		if member.daily_event_triggered:
			continue
		
		# Passer le joueur
		if member.get_meta("is_player", false):
			continue

		# Probabilité globale d'avoir un événement (modulée par profil/burnout)
		if not PersonalEventsScript.should_trigger_event(member):
			continue

		# Choisir un événement adapté à l'état du membre dans toute la base (~18 events)
		var event: Dictionary = PersonalEventsScript.get_event_for_player(member)
		if event.is_empty():
			continue

		trigger_personal_event(member, event.get("id", ""))
		member.daily_event_triggered = true

func _initialize_activity_preferences(player) -> Dictionary:
	"""Initialise les préférences d'activité selon la personnalité"""
	
	var prefs = {
		"LEVELING": 0.5,
		"FARMING": 0.5,
		"FUN": 0.5,
		"DUNGEON": 0.5,
		"RAID": 0.5
	}
	
	# Ajuster selon les tags
	if "tryhard" in player.tags_comportement:
		prefs["RAID"] = 0.8
		prefs["DUNGEON"] = 0.7
		prefs["FUN"] = 0.3
	elif "casual" in player.tags_comportement:
		prefs["FUN"] = 0.7
		prefs["RAID"] = 0.3
		prefs["DUNGEON"] = 0.4
	
	if "social" in player.tags_comportement:
		prefs["FUN"] = min(prefs["FUN"] + 0.2, 1.0)
	
	if "solitaire" in player.tags_comportement:
		prefs["FARMING"] = 0.7
		prefs["LEVELING"] = 0.6
	
	return prefs

func _absolute_day() -> int:
	if game_time and game_time.has_method("get_total_days_elapsed"):
		return game_time.get_total_days_elapsed()
	return 0

func _current_absolute_minutes() -> int:
	if not game_time:
		return 0
	return _absolute_day() * MINUTES_PER_DAY + game_time.current_hour * 60 + game_time.current_minute

func _get_connection_chance(player) -> float:
	var base_prob: float = _get_base_connection_probability(player)
	if base_prob <= 0.0:
		return 0.0

	var final_prob: float = base_prob * _connection_state_modifier(player)
	var last_epic_loot_day: int = player.last_epic_loot_day if player.last_epic_loot_day != null else -1
	if last_epic_loot_day >= 0:
		var days_since_loot: int = _absolute_day() - last_epic_loot_day
		if days_since_loot <= 3:
			final_prob *= 1.18

	if player.behavior_profile != null:
		var variance: float = player.behavior_profile.get_schedule_variance() * 0.08
		final_prob += randf_range(-variance, variance)

	# Phase 0 (LEVELING) : bonus de connexion (config "connection_bonus", ~+20%).
	# Modélise l'engouement de début de serveur sur les horaires de connexion.
	final_prob *= 1.0 + _get_leveling_connection_bonus()

	return clampf(final_prob, 0.0, 0.98)

func _get_leveling_connection_bonus() -> float:
	"""Retourne le bonus de connexion de la Phase 0 (LEVELING), 0.0 hors LEVELING.
	Lit la valeur "connection_bonus" de la config de phase via PhaseManager."""
	if not PhaseManager:
		return 0.0
	if PhaseManager.current_phase != PhaseManager.GamePhase.LEVELING:
		return 0.0
	var config: Dictionary = PhaseManager.get_current_phase_config()
	return float(config.get("connection_bonus", 0.0))

func _connection_state_modifier(player) -> float:
	"""Multiplicateur de présence selon l'état dynamique du membre (1.0 = neutre).
	C'est ce qui fait que fatigue / burnout / humeur / amis en ligne influencent
	réellement la connexion."""
	var m: float = 1.0

	# Fatigue
	var fatigue: float = player.fatigue_accumulated if player.fatigue_accumulated != null else 0.0
	if fatigue > 60.0:
		m *= 0.7
	elif fatigue > 40.0:
		m *= 0.85

	# Burnout
	var burnout: int = player.burnout_level if player.burnout_level != null else 0
	match burnout:
		1: m *= 0.9
		2: m *= 0.7
		3: m *= 0.4

	# Humeur
	var mood: float = player.mood if player.mood != null else 75.0
	if mood < 30.0:
		m *= 0.6
	elif mood > 80.0:
		m *= 1.2

	# Influence sociale : des amis en ligne donnent envie de se connecter (+20%/ami, max +60%)
	if social_dynamics:
		var friends_online: Array = social_dynamics.get_online_friends(player)
		if friends_online.size() > 0:
			m *= 1.0 + (0.2 * min(3, friends_online.size()))

	var integration: float = player.integration if player.integration != null else 50.0
	if integration >= 75.0:
		m *= 1.08
	elif integration < 25.0:
		m *= 0.92

	m *= _get_player_motivation_modifier(player)
	m *= _get_server_hype_modifier()
	m *= _get_guild_morale_modifier()

	return clampf(m, 0.2, 2.0)

func _get_player_motivation_modifier(player) -> float:
	var modifier: float = 1.0
	if player.behavior_profile != null:
		modifier *= lerpf(0.88, 1.16, clampf(player.behavior_profile.achievement_drive, 0.0, 1.0))

	var today: int = _absolute_day()
	var last_success: int = player.last_raid_success_day if player.last_raid_success_day != null else -1
	if last_success >= 0 and today - last_success <= 2:
		modifier *= 1.08

	var last_wipe: int = player.last_wipe_day if player.last_wipe_day != null else -1
	if last_wipe >= 0 and today - last_wipe <= 1:
		modifier *= 0.92

	if player.bonus_session_active:
		modifier *= 1.12

	return clampf(modifier, 0.75, 1.25)

func _get_server_hype_modifier() -> float:
	if ServerVersion and ServerVersion.has_method("get_hype_connection_multiplier"):
		return ServerVersion.get_hype_connection_multiplier()
	return 1.0

func _get_guild_morale_modifier() -> float:
	if GuildCultureManager and GuildCultureManager.has_method("get_guild_morale"):
		var morale: float = GuildCultureManager.get_guild_morale()
		return clampf(0.78 + morale / 250.0, 0.75, 1.18)
	return 1.0

func _should_force_disconnect(player) -> bool:
	"""Déconnexion imposée par l'état : épuisement ou burnout sévère."""
	if player.energy <= 5.0:
		return true
	var burnout: int = player.burnout_level if player.burnout_level != null else 0
	if burnout >= 3 and randf() < 0.3:
		return true
	return false

func _is_member_absent_today(member) -> bool:
	"""Vrai si le membre a une absence planifiée (événement personnel) couvrant le jour courant."""
	if not member:
		return false
	var absences: Array = member.scheduled_absences if member.scheduled_absences != null else []
	if absences.is_empty():
		return false
	var today: int = _absolute_day()
	for a in absences:
		var start: int = int(a.get("start_day", -1))
		var dur: int = int(a.get("duration_days", 0))
		if start >= 0 and today >= start and today < start + dur:
			return true
	return false

func _check_scheduled_connections() -> void:
	var current_abs: int = _current_absolute_minutes()

	for member in guild_manager.guild_members:
		if member.get_meta("is_player", false):
			continue

		if not player_scheduled_times.has(member):
			_schedule_next_connection_time(member)
			continue

		var schedule: Dictionary = player_scheduled_times[member]

		if not member.is_online and _is_member_absent_today(member):
			continue

		if member.is_online and _should_force_disconnect(member):
			behavior_changed.emit(member, "spontaneous_disconnection")
			_schedule_next_connection_time(member, current_abs + randi_range(60, 240))
			continue

		if not member.is_online:
			if not schedule.has("next_connection_abs"):
				_schedule_next_connection_time(member)
				continue
			var connection_abs: int = int(schedule.get("next_connection_abs", 0))
			if current_abs > connection_abs + CONNECTION_WINDOW_MINUTES:
				_schedule_next_connection_time(member, current_abs + randi_range(30, 120))
				continue
			if current_abs >= connection_abs:
				var connect_chance: float = _get_connection_chance(member)
				if randf() < connect_chance:
					member.go_online()
					behavior_changed.emit(member, "scheduled_connection")
					_schedule_next_disconnection_time(member)
		else:
			if not schedule.has("next_disconnection_abs"):
				_schedule_next_disconnection_time(member)
				continue
			var disconnection_abs: int = int(schedule.get("next_disconnection_abs", 0))
			if current_abs >= disconnection_abs:
				var overtime: int = current_abs - disconnection_abs
				var disconnect_prob: float = clampf(0.12 + float(overtime) * 0.012, 0.08, 0.92)
				disconnect_prob = clampf(disconnect_prob / maxf(_connection_state_modifier(member), 0.25), 0.04, 0.95)
				if member.current_activity and member.current_activity.type in [Activity.ActivityType.DUNGEON, Activity.ActivityType.RAID]:
					disconnect_prob *= 0.45
				if randf() < disconnect_prob:
					behavior_changed.emit(member, "scheduled_disconnection")
					_schedule_next_connection_time(member, current_abs + randi_range(240, 720))
	return

func _schedule_next_connection_time(member, earliest_abs: int = -1) -> void:
	if not member or not game_time:
		return
	if member.has_method("ensure_play_schedule"):
		member.ensure_play_schedule()

	var now_abs: int = _current_absolute_minutes()
	var search_from: int = earliest_abs if earliest_abs >= 0 else now_abs + 5
	var current_weekday_index: int = clampi(game_time.current_day - 1, 0, 6)
	var current_day_abs: int = _absolute_day()
	var chosen_abs: int = -1

	for offset in range(0, 8):
		var day_index: int = (current_weekday_index + offset) % DAY_KEYS.size()
		var day_name: String = DAY_KEYS[day_index]
		if day_name not in member.active_days:
			continue

		var day_abs: int = current_day_abs + offset
		var base_minute: int = int(member.preferred_start_hour * 60.0)
		var jitter: int = _connection_jitter_minutes(member)
		var candidate_abs: int = day_abs * MINUTES_PER_DAY + base_minute + jitter
		var session_end_abs: int = day_abs * MINUTES_PER_DAY + int((member.preferred_start_hour + member.preferred_session_hours) * 60.0)
		if session_end_abs <= candidate_abs:
			session_end_abs += MINUTES_PER_DAY

		if candidate_abs < search_from and search_from < session_end_abs:
			candidate_abs = search_from + randi_range(5, 35)
		if candidate_abs >= search_from:
			chosen_abs = candidate_abs
			break

	if chosen_abs < 0:
		chosen_abs = search_from + randi_range(8 * 60, 20 * 60)

	if not player_scheduled_times.has(member):
		player_scheduled_times[member] = {}
	player_scheduled_times[member]["next_connection_abs"] = chosen_abs
	player_scheduled_times[member].erase("next_disconnection_abs")
	return

func _connection_jitter_minutes(member) -> int:
	var variance_hours: float = 0.5
	if member.behavior_profile:
		variance_hours = maxf(0.15, absf(member.behavior_profile.get_schedule_variance()))
	if "planning_chaotique" in member.get_all_tags():
		variance_hours += 0.45
	if "ponctuel" in member.get_all_tags():
		variance_hours *= 0.45
	if "retardataire" in member.get_all_tags():
		variance_hours += 0.25
	return int(randf_range(-variance_hours * 60.0, variance_hours * 60.0))

func _schedule_next_disconnection_time(member) -> void:
	if not member or not game_time or not member.is_online:
		return

	var current_abs: int = _current_absolute_minutes()
	var session_duration: int = int(maxf(0.75, member.preferred_session_hours) * 60.0)

	if member.energy > 80.0:
		session_duration += 45
	elif member.energy < 35.0:
		session_duration -= 35
	if member.mood > 80.0:
		session_duration += 30
	elif member.mood < 40.0:
		session_duration -= 30
	if member.current_activity and member.current_activity.type in [Activity.ActivityType.DUNGEON, Activity.ActivityType.RAID]:
		session_duration += 45

	session_duration = int(float(session_duration) * (1.0 / maxf(_get_energy_drain_modifier(), 0.55)) * 0.85)
	session_duration = int(float(session_duration) * _get_guild_morale_modifier())
	session_duration += randi_range(-25, 35)

	var bonus_hours: float = member.bonus_session_hours if member.bonus_session_hours != null else 0.0
	if bonus_hours > 0.0:
		session_duration += int(bonus_hours * 60.0)
		member.bonus_session_hours = 0
		member.bonus_session_active = false

	var burnout: int = member.burnout_level if member.burnout_level != null else 0
	if burnout > 0:
		session_duration = int(float(session_duration) * (1.0 - float(burnout) * 0.18))

	session_duration = clampi(session_duration, 30, 8 * 60)
	var disconnection_abs: int = current_abs + session_duration
	var disconnect_hour: int = int((disconnection_abs / 60) % 24)
	if disconnect_hour >= 2 and disconnect_hour < 6 and not ("insomniaque" in member.get_all_tags()):
		var current_hour: int = int((current_abs / 60) % 24)
		if current_hour < 2:
			var current_day_start: int = current_abs - (current_abs % MINUTES_PER_DAY)
			disconnection_abs = current_day_start + 2 * 60 + randi_range(0, 20)
		else:
			disconnection_abs = current_abs + randi_range(15, 45)

	if not player_scheduled_times.has(member):
		player_scheduled_times[member] = {}
	player_scheduled_times[member]["next_disconnection_abs"] = disconnection_abs
	player_scheduled_times[member].erase("next_connection_abs")
	return

func _check_spontaneous_events() -> void:
	for member in guild_manager.guild_members:
		if member.get_meta("is_player", false):
			continue

		if not member.is_online:
			var base_score: float = _get_base_connection_probability(member)
			if base_score <= 0.02:
				continue
			var spontaneous_chance: float = clampf(member.schedule_spontaneity * 0.12 * _connection_state_modifier(member), 0.002, 0.08)
			if social_dynamics:
				var friends_online: Array = social_dynamics.get_online_friends(member)
				spontaneous_chance *= 1.0 + 0.18 * min(3, friends_online.size())
			if randf() < spontaneous_chance:
				member.go_online()
				behavior_changed.emit(member, "spontaneous_connection")
				_schedule_next_disconnection_time(member)
		else:
			var presence_score: float = _get_base_connection_probability(member)
			var fatigue: float = member.fatigue_accumulated if member.fatigue_accumulated != null else 0.0
			var disconnect_chance: float = 0.004
			if presence_score < 0.08:
				disconnect_chance += 0.02
			if member.energy < 25.0:
				disconnect_chance += 0.025
			if fatigue > 65.0:
				disconnect_chance += 0.02
			if randf() < disconnect_chance:
				behavior_changed.emit(member, "spontaneous_disconnection")
				_schedule_next_connection_time(member, _current_absolute_minutes() + randi_range(90, 360))
	return
