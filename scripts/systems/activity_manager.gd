extends Node
const Singletons = preload("res://scripts/utils/singletons.gd")

const ActivityScript = preload("res://scripts/resources/activity.gd")
const DungeonInstanceScript = preload("res://scripts/systems/dungeon_instance.gd")
const DungeonDataScript = preload("res://scripts/data/dungeon_data.gd")

signal activity_started(player, activity)
signal activity_completed(player, activity)
signal activity_interrupted(player, activity, reason)
signal dungeon_started(dungeon_instance)
signal dungeon_ended(dungeon_instance)

var game_time: Node
var active_activities: Dictionary = {}  # player -> Activity
var active_dungeons: Array = []  # Donjons actifs

# Zones de leveling inspirées de WoW Vanilla
var leveling_zones = {
	"1-10": ["Forêt d'Elwynn", "Dun Morogh", "Teldrassil", "Durotar"],
	"10-20": ["Marche de l'Ouest", "Loch Modan", "Sombrivage", "Les Tarides"],
	"20-30": ["Carmines", "Terres Ingrates", "Ashenvale", "Mille Pointes"],
	"30-40": ["Vallée de Strangleronce", "Désolace", "Marais des Chagrins"],
	"40-50": ["Tanaris", "Féralas", "Azshara", "Les Hinterlands"],
	"50-60": ["Cratère d'Un'Goro", "Gangrebois", "Steppes Ardentes", "Maleterres"]
}

func _ready() -> void:
	game_time = GameTime
	if game_time:
		# Se connecter au signal minute_changed pour une mise à jour plus granulaire
		game_time.minute_changed.connect(_on_minute_changed)
		game_time.hour_changed.connect(_on_hour_changed)

func _on_minute_changed(_minute: int, _hour: int) -> void:
	# Mettre à jour les activités toutes les 5 minutes pour un bon équilibre performance/réalisme
	if _minute % 5 == 0:
		_update_all_activities()

func _on_hour_changed(_hour: int) -> void:
	# Garder une mise à jour horaire pour la rétrocompatibilité
	pass

func start_activity(player, activity_type, params: Dictionary = {}) -> void:
	if active_activities.has(player):
		interrupt_activity(player, "Nouvelle activité démarrée")
	
	var activity = ActivityScript.new(activity_type)
	
	# Configuration spécifique selon le type
	match activity_type:
		ActivityScript.ActivityType.LEVELING:
			activity.location = _get_leveling_zone(player.personnage_niveau)
			activity.xp_gain_per_hour = _calculate_xp_per_hour(player.personnage_niveau)
			# Ajouter une durée d'activité prévue (30-90 minutes)
			activity.set_meta("planned_duration", randi_range(30, 90))
			
		ActivityScript.ActivityType.FARMING:
			activity.location = _get_farming_location(player.personnage_niveau)
			activity.set_meta("planned_duration", randi_range(45, 120))  # 45-120 minutes
			
		ActivityScript.ActivityType.FUN:
			activity.name = params.get("name", "Duel amical devant Orgrimmar")
			activity.participants = params.get("participants", [])
			activity.set_meta("planned_duration", randi_range(15, 45))  # 15-45 minutes
		
		ActivityScript.ActivityType.DUNGEON:
			activity.location = params.get(
				"location",
				_get_instance_activity_location(player, DungeonDataScript.InstanceType.DUNGEON)
			)
			activity.set_meta("planned_duration", randi_range(45, 120))
		
		ActivityScript.ActivityType.RAID:
			activity.location = params.get(
				"location",
				_get_instance_activity_location(player, DungeonDataScript.InstanceType.RAID)
			)
			activity.set_meta("planned_duration", randi_range(90, 180))
	
	activity.start_time = {
		"hour": game_time.current_hour,
		"minute": game_time.current_minute,
		"day": game_time.current_day,
		"week": game_time.current_week
	}
	activity.set_meta("start_timestamp", game_time.current_hour * 60 + game_time.current_minute)
	
	active_activities[player] = activity
	player.current_activity = activity
	
	activity_started.emit(player, activity)

func interrupt_activity(player, reason: String = "Interruption") -> void:
	if not active_activities.has(player):
		return
		
	var activity = active_activities[player]
	active_activities.erase(player)
	player.current_activity = null
	
	activity_interrupted.emit(player, activity, reason)

func _update_all_activities() -> void:
	# Mise à jour par batch pour optimiser les performances
	var players_to_update = active_activities.keys()
	var batch_size = 10  # Traiter 10 joueurs à la fois
	
	for i in range(0, players_to_update.size(), batch_size):
		var batch_end = min(i + batch_size, players_to_update.size())
		for j in range(i, batch_end):
			_update_player_activity(players_to_update[j])

func _update_player_activity(player) -> void:
	if not active_activities.has(player):
		return
		
	# Si c'est un joueur contrôlé manuellement, gérer différemment
	if player.get_meta("is_player", false) and player.has_method("update_player_energy"):
		_update_player_controlled_activity(player)
		return
		
	var activity = active_activities[player]
	
	# Calculer les effets pour 5 minutes (1/12 d'une heure)
	var time_factor = 5.0 / 60.0  # 5 minutes sur 60
	
	# Applique les effets de l'activité proportionnellement au temps écoulé
	# clamp [0,100] : certaines activités (repos/offline) ont un coût négatif (restaurent l'énergie)
	player.energy = clampf(player.energy - (activity.energy_cost_per_hour * time_factor), 0.0, 100.0)
	player.mood = clamp(player.mood + (activity.mood_change_per_hour * time_factor), 0, 100)
	player.update_integration(activity.integration_gain_per_hour * time_factor)
	
	# Effets spécifiques
	match activity.type:
		ActivityScript.ActivityType.LEVELING:
			if player.personnage_niveau < 60:
				# Gain d'XP proportionnel au temps
				var xp_gained = int(activity.xp_gain_per_hour * time_factor)
				# Ajouter un peu de variance (±20%)
				xp_gained = int(xp_gained * randf_range(0.8, 1.2))
				if xp_gained > 0:
					player.gain_experience(xp_gained)
				
		ActivityScript.ActivityType.FARMING:
			# Vérifier si la guilde a débloqué le farming
			var guild_manager = Singletons.get_autoload("GuildManager")
			if guild_manager and guild_manager.guild.has_farming():
				# Ajouter de l'or à la banque de guilde (proportionnel au temps)
				# Base : 10-50 or par heure, donc 0.83-4.17 or par 5 minutes
				if randf() < 0.3:  # 30% de chance de gagner de l'or toutes les 5 minutes
					var gold_gain = randi_range(1, 5)
					guild_manager.guild.add_gold(gold_gain)
	
	# Vérifier si l'activité a atteint sa durée planifiée
	if activity.has_meta("planned_duration") and activity.has_meta("start_timestamp"):
		var current_time = game_time.current_hour * 60 + game_time.current_minute
		var start_time = activity.get_meta("start_timestamp")
		var elapsed = current_time - start_time
		if elapsed < 0:  # Passage à un nouveau jour
			elapsed += 24 * 60
		
		var planned_duration = activity.get_meta("planned_duration")
		if elapsed >= planned_duration:
			# Petite chance de continuer l'activité si elle se passe bien
			var continue_chance = 0.2  # 20% de base
			if player.mood > 70:
				continue_chance += 0.2  # +20% si bonne humeur
			if player.energy > 50:
				continue_chance += 0.1  # +10% si bonne énergie
			
			if randf() > continue_chance:
				interrupt_activity(player, "Activité terminée")
				_decide_next_activity(player)
				return
	
	# Vérifications pour interrompre l'activité
	if player.energy <= 0:
		interrupt_activity(player, "Épuisé - besoin de repos")
		_decide_next_activity(player)
	elif player.mood <= 20 and activity.type != ActivityScript.ActivityType.FUN:
		interrupt_activity(player, "Moral trop bas")
		_decide_next_activity(player)

func _decide_next_activity(player):
	# Ne pas assigner d'activité automatique aux joueurs contrôlés manuellement
	if player.get_meta("is_player", false) and player.has_method("choose_activity"):
		return
	
	# Utiliser le système de préférences dynamiques
	if not player.is_online:
		return
	
	# Obtenir le système de comportement
	var behavior_system = (GuildManager.behavior_system if GuildManager else null)
	
	if player.energy < 20:
		# Trop fatigué, se déconnecte
		player.go_offline()
		start_activity(player, ActivityScript.ActivityType.OFFLINE)
		return
	
	# Calculer les poids pour chaque activité
	var activity_weights = {}
	var total_weight = 0.0
	
	if behavior_system:
		# Utiliser les préférences dynamiques
		for activity_type in ["LEVELING", "FARMING", "FUN", "DUNGEON", "RAID"]:
			var weight = behavior_system.get_activity_preference(player, activity_type)
			
			# Ajustements contextuels
			match activity_type:
				"LEVELING":
					if player.personnage_niveau >= 60:
						weight *= 0.1
				"FARMING":
					var guild_manager = GuildManager
					if not guild_manager or not guild_manager.guild.has_farming():
						weight = 0
				"DUNGEON", "RAID":
					if player.energy < 40:
						weight *= 0.3
					if player.mood < 40:
						weight *= 0.5
				"FUN":
					if player.mood < 30:
						weight *= 2.0
			
			if weight > 0:
				activity_weights[activity_type] = weight
				total_weight += weight
	else:
		# Fallback sur l'ancien système
		if player.mood < 30:
			start_activity(player, ActivityScript.ActivityType.FUN, {
				"name": _get_random_fun_activity()
			})
		elif player.personnage_niveau < 60:
			start_activity(player, ActivityScript.ActivityType.LEVELING)
		else:
			start_activity(player, ActivityScript.ActivityType.FARMING)
		return
	
	# Sélectionner une activité selon les poids
	if total_weight > 0:
		var roll = randf() * total_weight
		var cumulative = 0.0
		
		for activity_type in activity_weights:
			cumulative += activity_weights[activity_type]
			if roll <= cumulative:
				# Démarrer l'activité sélectionnée
				match activity_type:
					"FUN":
						start_activity(player, ActivityScript.ActivityType.FUN, {
							"name": _get_random_fun_activity()
						})
					"LEVELING":
						start_activity(player, ActivityScript.ActivityType.LEVELING)
					"FARMING":
						start_activity(player, ActivityScript.ActivityType.FARMING)
					"DUNGEON":
						start_activity(player, ActivityScript.ActivityType.DUNGEON)
					"RAID":
						start_activity(player, ActivityScript.ActivityType.RAID)
				
				# Mettre à jour les préférences selon l'expérience
				if behavior_system:
					# L'expérience sera évaluée lors de la complétion
					player.set_meta("last_activity_choice", activity_type)
				
				return
	
	# Par défaut, activité fun
	start_activity(player, ActivityScript.ActivityType.FUN, {
		"name": _get_random_fun_activity()
	})

func _get_leveling_zone(level: int) -> String:
	for range_str in leveling_zones:
		var parts = range_str.split("-")
		var min_level = int(parts[0])
		var _max_level = int(parts[1])
		if level >= min_level and level <= _max_level:
			var zones = leveling_zones[range_str]
			return zones[randi() % zones.size()]
	return "Maleterres"  # Zone par défaut pour haut niveau

func _get_farming_location(level: int) -> String:
	# Locations de farming selon le niveau
	if level < 20:
		return ["Les Tarides", "Forêt d'Elwynn", "Durotar"].pick_random()
	elif level < 40:
		return ["Mille pointes", "Ashenvale", "Les Serres-Rocheuses"].pick_random()
	elif level < 50:
		return ["Tanaris", "Féralas", "Azshara"].pick_random()
	else:
		return ["Maleterres de l'Ouest", "Maleterres de l'Est", "Berceau-de-l'Hiver"].pick_random()

func _get_instance_activity_location(player, instance_type: int) -> String:
	var level: int = player.personnage_niveau if player else 60
	var instances: Array = DungeonDataScript.get_instances_for_level(level, instance_type, true)
	if not instances.is_empty():
		var picked: Dictionary = instances.pick_random()
		return picked.get("data", {}).get("name", "Instance inconnue")
	
	match instance_type:
		DungeonDataScript.InstanceType.RAID:
			return "Préparation raid"
		_:
			return "Recherche de groupe donjon"

func _calculate_xp_per_hour(level: int) -> int:
	# XP/heure avec courbe plus réaliste
	var base_xp = 1000
	
	if level < 10:
		base_xp = 1500  # Leveling rapide au début
	elif level < 20:
		base_xp = 1200
	elif level < 30:
		base_xp = 1000
	elif level < 40:
		base_xp = 800
	elif level < 50:
		base_xp = 600
	else:
		base_xp = 400  # Très lent vers 60
	
	# Réduction supplémentaire basée sur le niveau exact
	var level_penalty = level * 5
	
	return max(100, base_xp - level_penalty)

func _get_random_fun_activity() -> String:
	var activities = [
		"Duel amical devant Orgrimmar",
		"Course de montures à Ironforge", 
		"Pêche tranquille à Booty Bay",
		"Discussion autour du feu de camp",
		"Exploration des zones secrètes",
		"Chasse aux pets rares",
		"Concours de /dance à Stormwind"
	]
	return activities[randi() % activities.size()]

func get_activity_summary(player) -> String:
	if not active_activities.has(player):
		return "Aucune activité"
		
	var activity = active_activities[player]
	var summary = activity.get_type_string()
	
	if activity.location != "":
		summary += " à " + activity.location
		
	return summary

func assign_activity(player, activity) -> void:
	# Interrompre l'activité actuelle si elle existe
	if active_activities.has(player):
		complete_activity(player)
	
	# Assigner la nouvelle activité
	active_activities[player] = activity
	activity_started.emit(player, activity)

func complete_activity(player) -> void:
	if active_activities.has(player):
		var activity = active_activities[player]
		active_activities.erase(player)
		
		# Évaluer l'expérience et mettre à jour les préférences
		var behavior_system = (GuildManager.behavior_system if GuildManager else null)
		if behavior_system and player.has_meta("last_activity_choice"):
			var activity_type = player.get_meta("last_activity_choice")
			var experience_quality = _evaluate_activity_experience(player, activity)
			behavior_system.update_activity_preference(player, activity_type, experience_quality)
			player.remove_meta("last_activity_choice")
		
		activity_completed.emit(player, activity)



# Méthodes pour gérer les donjons
func start_dungeon(dungeon_id: String, group_members: Array):
	# Vérifier que tous les membres sont disponibles
	for member in group_members:
		if active_activities.has(member):
			var current_activity = active_activities[member]
			if current_activity.type == ActivityScript.ActivityType.DUNGEON:
				GameLog.d("Erreur: %s est déjà en donjon" % member.nom)
				return null
	
	# Créer l'instance de donjon
	var dungeon_instance = DungeonInstanceScript.new()
	dungeon_instance.initialize(dungeon_id, group_members)
	
	# Connecter les signaux
	dungeon_instance.dungeon_completed.connect(_on_dungeon_completed.bind(dungeon_instance))
	dungeon_instance.dungeon_abandoned.connect(_on_dungeon_abandoned.bind(dungeon_instance))
	
	# Assigner l'activité donjon à tous les membres
	var dungeon_data = DungeonDataScript.get_instance_data(dungeon_id)
	for member in group_members:
		var activity = ActivityScript.new()
		activity.type = ActivityScript.ActivityType.DUNGEON
		activity.location = dungeon_data.get("name", "Donjon inconnu")
		assign_activity(member, activity)
	
	# Ajouter à la liste des donjons actifs
	active_dungeons.append(dungeon_instance)
	dungeon_started.emit(dungeon_instance)
	
	return dungeon_instance

func _on_dungeon_completed(_total_time: float, _gold_reward: int, dungeon_instance) -> void:
	# Retirer le donjon de la liste active
	active_dungeons.erase(dungeon_instance)
	
	# Libérer les membres du donjon
	for member in dungeon_instance.group_members:
		if active_activities.has(member):
			complete_activity(member)
	
	dungeon_ended.emit(dungeon_instance)

func _on_dungeon_abandoned(reason: String, dungeon_instance) -> void:
	# Retirer le donjon de la liste active
	active_dungeons.erase(dungeon_instance)
	
	# Libérer les membres du donjon
	for member in dungeon_instance.group_members:
		if active_activities.has(member):
			interrupt_activity(member, reason)
	
	dungeon_ended.emit(dungeon_instance)

func update_dungeons(delta: float) -> void:
	# Mettre à jour tous les donjons actifs
	for dungeon in active_dungeons:
		if dungeon.is_active:
			dungeon.update(delta, game_time)

func _update_player_controlled_activity(player) -> void:
	"""Met à jour l'activité d'un joueur contrôlé manuellement"""
	if not active_activities.has(player):
		return
	
	var activity = active_activities[player]
	var time_factor = 5.0 / 60.0  # 5 minutes
	
	# Le joueur gère sa propre énergie
	player.update_player_energy(5.0)
	
	# Appliquer les effets de l'activité sur l'humeur et l'intégration
	player.mood = clamp(player.mood + (activity.mood_change_per_hour * time_factor), 0, 100)
	player.update_integration(activity.integration_gain_per_hour * time_factor)
	
	# Effets spécifiques par type d'activité
	match activity.type:
		ActivityScript.ActivityType.LEVELING:
			if player.personnage_niveau < 60:
				var xp_gained = int(activity.xp_gain_per_hour * time_factor)
				xp_gained = int(xp_gained * randf_range(0.8, 1.2))  # Variance ±20%
				if xp_gained > 0:
					player.gain_experience(xp_gained)
		
		ActivityScript.ActivityType.FARMING:
			var guild_manager = Singletons.get_autoload("GuildManager")
			if guild_manager and guild_manager.guild.has_farming():
				if randf() < 0.3:  # 30% de chance toutes les 5 minutes
					var gold_gain = randi_range(2, 8)  # Plus généreux pour le joueur
					player.add_session_gold(gold_gain)
					guild_manager.guild.add_gold(gold_gain)
	
	# Vérifications d'interruption (gérées par le PlayerCharacter)
	if player.player_energy_pool <= 0:
		interrupt_activity(player, "Énergie épuisée")
		return
	
	# Le joueur décide manuellement quand arrêter, pas d'interruption automatique sur humeur

func get_active_dungeon_for_player(player):
	for dungeon in active_dungeons:
		if player in dungeon.group_members:
			return dungeon
	return null

func is_player_in_dungeon(player) -> bool:
	return get_active_dungeon_for_player(player) != null

func _evaluate_activity_experience(player, activity) -> float:
	"""Évalue la qualité de l'expérience d'une activité (-1 à 1)"""
	
	var quality = 0.0
	
	# Évaluer selon le type d'activité
	match activity.type:
		ActivityScript.ActivityType.LEVELING:
			# Positif si gain de niveau, négatif si trop lent
			if player.personnage_niveau > activity.get("start_level", player.personnage_niveau):
				quality = 0.5
			else:
				quality = -0.2
		
		ActivityScript.ActivityType.FARMING:
			# Positif si bon gain d'or
			quality = 0.3  # Neutre-positif par défaut
		
		ActivityScript.ActivityType.FUN:
			# Positif si amélioration du moral
			if player.mood > activity.get("start_mood", player.mood):
				quality = 0.7
			else:
				quality = 0.2  # Légèrement positif même sans gain
		
		ActivityScript.ActivityType.DUNGEON, ActivityScript.ActivityType.RAID:
			# Sera évalué différemment avec succès/échec
			quality = 0.4  # Positif par défaut
	
	# Ajuster selon l'état final du joueur
	if player.energy < 10:
		quality -= 0.3  # Trop épuisant
	
	if player.mood < 30:
		quality -= 0.2  # Expérience frustrante
	elif player.mood > 80:
		quality += 0.2  # Expérience plaisante
	
	return clamp(quality, -1.0, 1.0)
