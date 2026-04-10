extends Node
class_name BehaviorSystem

signal behavior_changed(player, change_type)
signal personal_event_triggered(player, event)
signal burnout_level_changed(player, new_level)
signal relationship_formed(player1, player2, relationship_type)

const PersonalEventsScript = preload("res://scripts/data/personal_events.gd")
const BehaviorProfileScript = preload("res://scripts/resources/behavior_profile.gd")

var game_time: Node
var guild_manager: Node
var social_dynamics: Node

# Cache pour optimisation
var connection_probability_cache: Dictionary = {}
var last_cache_update: int = -1

# Horaires personnalisés par joueur (minute précise de connexion/déconnexion prévue)
var player_scheduled_times: Dictionary = {}  # player -> {next_connection: int, next_disconnection: int}

func _ready():
	game_time = GameTime
	guild_manager = GuildManager
	
	# Le social_dynamics sera créé après
	call_deferred("_init_social_dynamics")
	
	if game_time:
		# Se connecter au signal de changement de minute pour plus de granularité
		game_time.minute_changed.connect(_on_minute_changed)
		game_time.hour_changed.connect(_on_hour_changed)
		game_time.day_changed.connect(_on_day_changed)

func _init_social_dynamics():
	var social_dynamics_script = load("res://scripts/systems/social_dynamics.gd")
	social_dynamics = Node.new()
	social_dynamics.set_script(social_dynamics_script)
	social_dynamics.name = "SocialDynamics"
	add_child(social_dynamics)

func _on_minute_changed(minute: int, hour: int):
	"""Appelé chaque minute pour des comportements plus granulaires"""
	
	# Vérifier seulement toutes les 5 minutes pour optimiser les performances
	if minute % 5 != 0:
		return
	
	# Vérifier les connexions/déconnexions planifiées
	_check_scheduled_connections()
	
	# Petite chance de vérifier les événements spontanés
	if randf() < 0.1:  # 10% de chance toutes les 5 minutes
		_check_spontaneous_events()

func _on_hour_changed(hour: int):
	# Vider le cache chaque heure
	if hour != last_cache_update:
		connection_probability_cache.clear()
		last_cache_update = hour
	
	# Mettre à jour la fatigue accumulée
	_update_fatigue_levels()
	
	# Vérifier les événements personnels
	_check_personal_events()

func _on_day_changed(_day: int, _week: int, _year: int):
	# Réinitialiser certains compteurs quotidiens
	for member in guild_manager.guild_members:
		# Réinitialiser le flag d'événement quotidien
		member.daily_event_triggered = false
		
		# Réduire légèrement la fatigue accumulée chaque jour
		if member.fatigue_accumulated > 0:
			member.fatigue_accumulated = max(0, member.fatigue_accumulated - 5)

func should_connect_dynamic(player) -> bool:
	"""Détermine si un joueur devrait se connecter avec le système dynamique"""
	
	# Utiliser le cache si disponible
	if connection_probability_cache.has(player):
		return randf() < connection_probability_cache[player]
	
	# Calculer la probabilité de base depuis le planning
	var base_prob = _get_base_connection_probability(player)
	if base_prob <= 0:
		return false
	
	# Appliquer les modificateurs
	var final_prob = base_prob
	
	# Modificateur de fatigue
	var fatigue = player.fatigue_accumulated if player.fatigue_accumulated != null else 0
	if fatigue > 60:
		final_prob *= 0.7  # -30% si très fatigué
	elif fatigue > 40:
		final_prob *= 0.85  # -15% si fatigué
	
	# Modificateur de burnout
	var burnout = player.burnout_level if player.burnout_level != null else 0
	match burnout:
		1: final_prob *= 0.9
		2: final_prob *= 0.7
		3: final_prob *= 0.4
	
	# Modificateur d'humeur
	var mood = player.mood if player.mood != null else 75
	if mood < 30:
		final_prob *= 0.6
	elif mood > 80:
		final_prob *= 1.2
	
	# Modificateur social (amis en ligne)
	if social_dynamics:
		var friends_online = social_dynamics.get_online_friends(player)
		if friends_online.size() > 0:
			final_prob *= 1.0 + (0.2 * min(3, friends_online.size()))  # +20% par ami, max +60%
	
	# Modificateur d'équipement récent
	var last_epic_loot_day = player.last_epic_loot_day if player.last_epic_loot_day != null else -1
	if last_epic_loot_day > 0:
		var days_since_loot = game_time.current_day - last_epic_loot_day
		if days_since_loot <= 3:
			final_prob *= 1.3  # +30% motivation après loot épique
	
	# Variance personnelle (personnalité)
	if player.behavior_profile != null:
		var variance = player.behavior_profile.get_schedule_variance()
		final_prob += randf_range(-variance, variance)
	
	# Limiter entre 0 et 1
	final_prob = clamp(final_prob, 0.0, 1.0)
	
	# Mettre en cache
	connection_probability_cache[player] = final_prob
	
	return randf() < final_prob

func should_disconnect_dynamic(player) -> bool:
	"""Détermine si un joueur devrait se déconnecter avec le système dynamique"""
	
	# Déconnexion forcée si épuisé
	if player.energy <= 5:
		return true
	
	# Déconnexion si burnout sévère
	if (player.burnout_level if player.burnout_level != null else 0) >= 3 and randf() < 0.3:
		return true
	
	# Vérifier les horaires de base
	var base_should_disconnect = _should_disconnect_by_schedule(player)
	
	# Événement personnel de déconnexion
	if player.has_urgent_event:
		player.has_urgent_event = false
		return true
	
	# Modificateurs selon l'état
	if base_should_disconnect:
		var stay_probability = 0.0
		
		# Peut rester plus longtemps si activité intéressante
		if player.current_activity:
			match player.current_activity.type:
				"DUNGEON", "RAID":
					stay_probability = 0.7  # 70% chance de finir l'activité
				"FUN":
					if player.mood > 70:
						stay_probability = 0.4  # 40% chance de rester si s'amuse
		
		# Influence sociale
		if social_dynamics:
			var friends_online = social_dynamics.get_online_friends(player)
			if friends_online.size() > 0:
				stay_probability += 0.1 * friends_online.size()  # +10% par ami
		
		return randf() > stay_probability
	
	# Déconnexion aléatoire si très tard
	if game_time.current_hour >= 2 and game_time.current_hour < 6:
		var tiredness_factor = (player.energy / 100.0)
		return randf() > tiredness_factor
	
	return false

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
			# Boost si récent succès
			var last_raid_success_day = player.last_raid_success_day if player.last_raid_success_day != null else -1
			if last_raid_success_day > 0:
				var days_since = game_time.current_day - last_raid_success_day
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

func update_activity_preference(player, activity_type: String, experience_quality: float):
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

func trigger_personal_event(player, event_type: String):
	"""Déclenche un événement personnel pour un joueur"""
	
	var event = PersonalEventsScript.get_event(event_type)
	if not event:
		return
	
	# Appliquer les effets de l'événement
	match event.effect_type:
		"immediate_disconnect":
			player.has_urgent_event = true
			if player.is_online:
				behavior_changed.emit(player, "urgent_disconnect")
		
		"schedule_absence":
			if player.scheduled_absences == null:
				player.scheduled_absences = []
			player.scheduled_absences.append({
				"start_day": game_time.current_day + event.get("delay_days", 0),
				"duration_days": event.get("duration_days", 1)
			})
		
		"bonus_time":
			player.bonus_session_hours = event.get("bonus_hours", 2)
			behavior_changed.emit(player, "bonus_time")
	
	personal_event_triggered.emit(player, event)
	
	# Mémoriser l'événement
	if player.recent_events_memory == null:
		player.recent_events_memory = []
	
	player.recent_events_memory.append({
		"type": "personal_event",
		"event": event_type,
		"day": game_time.current_day
	})

func update_burnout_level(player):
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

func add_fatigue(player, amount: float):
	"""Ajoute de la fatigue à un joueur"""
	
	var old_fatigue = player.fatigue_accumulated if player.fatigue_accumulated != null else 0
	player.fatigue_accumulated = clamp(old_fatigue + amount, 0, 100)
	
	# Vérifier si le niveau de burnout change
	update_burnout_level(player)

func recover_fatigue(player, amount: float):
	"""Réduit la fatigue d'un joueur"""
	
	var current_fatigue = player.fatigue_accumulated if player.fatigue_accumulated != null else 0
	if current_fatigue <= 0:
		return
	
	player.fatigue_accumulated = max(0, current_fatigue - amount)
	update_burnout_level(player)

# Méthodes privées

func _get_base_connection_probability(player) -> float:
	"""Calcule la probabilité de base de connexion selon le planning"""
	
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

func _update_fatigue_levels():
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
					"RAID":
						fatigue_rate = 3.0
					"DUNGEON":
						fatigue_rate = 2.0
					"FARMING":
						fatigue_rate = 1.5
					"LEVELING":
						fatigue_rate = 1.0
					"FUN":
						fatigue_rate = -0.5  # Récupère en s'amusant
				
				if fatigue_rate > 0:
					add_fatigue(member, fatigue_rate)
				else:
					recover_fatigue(member, abs(fatigue_rate))

func _check_personal_events():
	"""Vérifie et déclenche les événements personnels"""
	
	for member in guild_manager.guild_members:
		# Passer si déjà eu un événement aujourd'hui
		if member.daily_event_triggered:
			continue
		
		# Passer le joueur
		if member.get_meta("is_player", false):
			continue
		
		# Probabilités d'événements
		var rand = randf()
		
		if rand < 0.05:  # 5% urgence
			trigger_personal_event(member, "urgent_family")
			member.daily_event_triggered = true
		elif rand < 0.15:  # 10% obligation
			trigger_personal_event(member, "planned_obligation")
			member.daily_event_triggered = true
		elif rand < 0.23:  # 8% temps bonus
			trigger_personal_event(member, "free_evening")
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

func _check_scheduled_connections():
	"""Vérifie et exécute les connexions/déconnexions planifiées"""
	
	var current_time = game_time.current_hour * 60 + game_time.current_minute
	
	for member in guild_manager.guild_members:
		# Ne pas gérer le joueur
		if member.get_meta("is_player", false):
			continue
		
		# Initialiser les horaires si nécessaire
		if not player_scheduled_times.has(member):
			_schedule_next_connection_time(member)
			continue
		
		var schedule = player_scheduled_times[member]
		
		# Vérifier connexion
		if not member.is_online and schedule.has("next_connection"):
			var connection_time = schedule["next_connection"]
			if current_time >= connection_time and current_time < connection_time + 10:
				# Fenêtre de 10 minutes pour se connecter
				if randf() < 0.3:  # 30% de chance par vérification
					member.go_online()
					behavior_changed.emit(member, "scheduled_connection")
					_schedule_next_disconnection_time(member)
		
		# Vérifier déconnexion
		elif member.is_online and schedule.has("next_disconnection"):
			var disconnection_time = schedule["next_disconnection"]
			if current_time >= disconnection_time:
				# Probabilité croissante de se déconnecter après l'heure prévue
				var overtime = current_time - disconnection_time
				var disconnect_prob = min(0.1 + (overtime * 0.02), 0.8)  # Max 80%
				
				if randf() < disconnect_prob:
					behavior_changed.emit(member, "scheduled_disconnection")
					_schedule_next_connection_time(member)

func _schedule_next_connection_time(member):
	"""Planifie la prochaine heure de connexion avec variance"""
	
	var day_name = game_time.get_day_name().to_lower()
	if not member.planning.has(day_name):
		return
	
	var day_schedule = member.planning[day_name]
	var scheduled_time = -1
	
	# Déterminer l'heure de base selon le planning
	if game_time.is_morning() and day_schedule.get("apres_midi", false):
		# Connexion l'après-midi entre 14h et 16h
		scheduled_time = randi_range(14 * 60, 16 * 60)
	elif (game_time.is_morning() or game_time.is_afternoon()) and day_schedule.get("soir", false):
		# Connexion le soir entre 19h et 21h
		scheduled_time = randi_range(19 * 60, 21 * 60)
	
	if scheduled_time > 0:
		# Ajouter variance personnelle (-30 à +30 minutes)
		var variance = member.personal_schedule_variance if member.personal_schedule_variance != null else Vector2(-0.5, 0.5)
		var variance_minutes = int(randf_range(variance.x * 60, variance.y * 60))
		scheduled_time = max(0, scheduled_time + variance_minutes)
		
		# Ajuster selon le type circadien
		match member.circadian_type:
			"morning":
				scheduled_time -= randi_range(30, 60)  # Se connecte plus tôt
			"evening":
				scheduled_time += randi_range(30, 60)  # Se connecte plus tard
		
		# S'assurer que c'est dans le futur
		var current_time = game_time.current_hour * 60 + game_time.current_minute
		if scheduled_time <= current_time:
			scheduled_time += 24 * 60  # Reporter au lendemain
		
		if not player_scheduled_times.has(member):
			player_scheduled_times[member] = {}
		player_scheduled_times[member]["next_connection"] = scheduled_time % (24 * 60)

func _schedule_next_disconnection_time(member):
	"""Planifie la prochaine heure de déconnexion avec variance"""
	
	if not member.is_online:
		return
	
	var current_time = game_time.current_hour * 60 + game_time.current_minute
	
	# Durée de session de base selon l'énergie et l'humeur
	var base_duration = 120  # 2 heures de base
	
	if member.energy > 80:
		base_duration += 60  # +1h si plein d'énergie
	elif member.energy < 40:
		base_duration -= 30  # -30min si fatigué
	
	if member.mood > 80:
		base_duration += 30  # +30min si bonne humeur
	elif member.mood < 40:
		base_duration -= 30  # -30min si mauvaise humeur
	
	# Variance de ±30 minutes
	var duration_variance = randi_range(-30, 30)
	var session_duration = max(30, base_duration + duration_variance)  # Minimum 30 minutes
	
	# Ajuster selon le burnout
	var burnout = member.burnout_level if member.burnout_level != null else 0
	if burnout > 0:
		session_duration = int(session_duration * (1.0 - burnout * 0.2))  # -20% par niveau
	
	# Calculer l'heure de déconnexion
	var disconnection_time = current_time + session_duration
	
	# Forcer déconnexion tard la nuit
	var hour_of_disconnect = (disconnection_time / 60) % 24
	if hour_of_disconnect >= 2 and hour_of_disconnect < 6:
		# Réduire fortement la durée si ça tombe très tard
		disconnection_time = current_time + randi_range(15, 45)
	
	if not player_scheduled_times.has(member):
		player_scheduled_times[member] = {}
	player_scheduled_times[member]["next_disconnection"] = disconnection_time % (24 * 60)

func _check_spontaneous_events():
	"""Vérifie les événements spontanés (connexions/déconnexions imprévues)"""
	
	for member in guild_manager.guild_members:
		if member.get_meta("is_player", false):
			continue
		
		# Connexion spontanée (ami en ligne, envie soudaine)
		if not member.is_online and randf() < 0.02:  # 2% de chance
			# Vérifier si c'est raisonnable de se connecter
			if game_time.current_hour >= 8 and game_time.current_hour < 24:
				if member.energy > 30 and member.mood > 20:
					# Bonus si des amis sont en ligne
					var friend_bonus = 1.0
					if social_dynamics:
						var friends_online = social_dynamics.get_online_friends(member)
						friend_bonus = 1.0 + (0.3 * min(3, friends_online.size()))
					
					if randf() < 0.1 * friend_bonus:  # 10% de base, jusqu'à 40% avec amis
						member.go_online()
						behavior_changed.emit(member, "spontaneous_connection")
						_schedule_next_disconnection_time(member)
		
		# Déconnexion spontanée (urgence, fatigue soudaine)
		elif member.is_online and randf() < 0.01:  # 1% de chance
			if member.energy < 20 or randf() < 0.05:  # Très fatigué ou 5% urgence
				behavior_changed.emit(member, "spontaneous_disconnection")
				_schedule_next_connection_time(member)
