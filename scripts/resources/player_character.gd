extends SimulatedPlayer
class_name PlayerCharacter

signal forced_disconnect_requested(recovery_hours: int)

# Propriétés spécifiques au joueur
@export var is_player_controlled: bool = true
@export var player_energy_pool: float = 100.0  # Énergie totale disponible pour la session
@export var max_energy_pool: float = 100.0
@export var current_activity_choice: String = ""  # Activité choisie par le joueur
@export var scheduled_return_time: Dictionary = {}  # Heure de retour programmée
@export var session_start_time: Dictionary = {}
@export var manual_control_enabled: bool = true

# Stats de session
@export var session_xp_gained: int = 0
@export var session_gold_gained: int = 0
@export var session_duration_minutes: int = 0

# Drain d'énergie par activité (par heure)
var energy_drain_rates = {
	"LEVELING": 15.0,
	"FARMING": 10.0,
	"FUN": 5.0,
	"DUNGEON": 20.0,
	"RAID": 25.0,
	"OFFLINE": -10.0  # Récupération
}

# Bonus et malus spécifiques au joueur
@export var consecutive_hours: float = 0.0  # Heures consécutives connecté

func _init():
	super()  # Appelle le constructeur de SimulatedPlayer
	_setup_player_character()

func _setup_player_character():
	# Configuration spécifique au joueur
	nom = "Joueur"  # Sera personnalisable plus tard
	personnage_classe = "Guerrier"
	personnage_niveau = 1
	personnage_xp = 0
	
	# États initiaux
	energy = 100.0
	player_energy_pool = 100.0
	mood = 80.0  # Bon moral au départ
	skill = 30  # Débutant
	integration = 0.0
	
	# Le joueur commence connecté
	is_online = true
	manual_control_enabled = true
	
	# Pas de planning automatique pour le joueur
	planning = {}
	
	# Initialiser l'équipement de base
	if not equipment:
		equipment = EquipmentScript.new()
	
	# Donner l'équipement de départ d'un guerrier niveau 1
	var starting_items = LootTablesScript.create_starting_equipment()
	for item in starting_items:
		equipment.equip_item(item)
	
	# Initialiser la session
	_initialize_session()

func _initialize_session():
	"""Initialise une nouvelle session de jeu"""
	var game_time = _get_game_time()
	if game_time:
		session_start_time = {
			"hour": game_time.current_hour,
			"minute": game_time.current_minute,
			"day": game_time.current_day,
			"week": game_time.current_week,
			"year": game_time.current_year
		}
	
	session_xp_gained = 0
	session_gold_gained = 0
	session_duration_minutes = 0
	consecutive_hours = 0.0
	
	print("Session de jeu initialisée pour %s" % nom)

func choose_activity(activity_type: String) -> bool:
	"""Permet au joueur de choisir manuellement son activité"""
	if not manual_control_enabled:
		return false
	
	# Vérifier si on a assez d'énergie
	var drain_rate = energy_drain_rates.get(activity_type, 10.0)
	if player_energy_pool < drain_rate * 0.5:  # Au moins 30 minutes d'activité
		print("Pas assez d'énergie pour %s" % activity_type)
		return false
	
	current_activity_choice = activity_type
	
	# Démarrer l'activité via l'ActivityManager
	var activity_manager = _get_activity_manager()
	if activity_manager:
		var activity_type_enum = _convert_activity_string_to_enum(activity_type)
		if activity_type_enum != null:
			activity_manager.start_activity(self, activity_type_enum)
			return true
	
	return false

func _convert_activity_string_to_enum(activity_string: String):
	"""Convertit une string d'activité en enum ActivityType"""
	const ActivityScript = preload("res://scripts/resources/activity.gd")
	
	match activity_string:
		"LEVELING": return ActivityScript.ActivityType.LEVELING
		"FARMING": return ActivityScript.ActivityType.FARMING
		"FUN": return ActivityScript.ActivityType.FUN
		"DUNGEON": return ActivityScript.ActivityType.DUNGEON
		"RAID": return ActivityScript.ActivityType.RAID
		"OFFLINE": return ActivityScript.ActivityType.OFFLINE
		_: return null

func update_player_energy(delta_minutes: float):
	"""Met à jour l'énergie du joueur basée sur l'activité actuelle"""
	if not current_activity:
		return
	
	var activity_name = current_activity.get_type_string().to_upper()
	var drain_rate = energy_drain_rates.get(activity_name, 10.0)
	
	# Calculer le drain pour les minutes écoulées
	var energy_delta = -(drain_rate * delta_minutes / 60.0)
	
	# Appliquer les malus de fatigue
	if consecutive_hours > 4.0:
		energy_delta *= 1.5  # 50% plus de fatigue après 4h consécutives
	
	# Mettre à jour l'énergie
	player_energy_pool = max(0.0, player_energy_pool + energy_delta)
	energy = max(0.0, energy + energy_delta * 0.1)  # Impact aussi sur l'énergie de base
	
	# Accumuler les heures consécutives
	consecutive_hours += delta_minutes / 60.0
	
	# Vérifier si on doit forcer une déconnexion
	if player_energy_pool <= 0:
		force_disconnect("Épuisement - énergie insuffisante")

func schedule_disconnect(return_hour: int, return_minute: int = 0):
	"""Programme une déconnexion avec retour automatique"""
	var game_time = _get_game_time()
	if not game_time:
		return
	
	# Calculer l'heure de retour (même jour ou jour suivant)
	var return_day = game_time.current_day
	if return_hour < game_time.current_hour or (return_hour == game_time.current_hour and return_minute <= game_time.current_minute):
		return_day += 1
		if return_day > 7:
			return_day = 1
	
	scheduled_return_time = {
		"hour": return_hour,
		"minute": return_minute,
		"day": return_day,
		"week": game_time.current_week,
		"year": game_time.current_year
	}
	
	# Se déconnecter immédiatement
	disconnect_player("Déconnexion programmée")
	
	print("Déconnexion programmée - retour prévu : J%d %02d:%02d" % [return_day, return_hour, return_minute])

func disconnect_player(reason: String = "Déconnexion manuelle"):
	"""Déconnecte le joueur et calcule les gains de la session"""
	if not is_online:
		return
	
	# Calculer les gains de session
	_calculate_session_gains()
	
	# Passer en mode offline
	go_offline()
	current_activity_choice = ""
	manual_control_enabled = false
	
	print("Joueur déconnecté: %s" % reason)
	print("Session terminée - XP: +%d, Or: +%d, Durée: %d min" % [session_xp_gained, session_gold_gained, session_duration_minutes])

func force_disconnect(reason: String):
	"""Force une déconnexion (épuisement, etc.)"""
	print("PlayerCharacter: Force disconnect - %s" % reason)
	
	# Déconnecter le joueur
	disconnect_player(reason)
	
	# Émettre le signal pour déclencher le repos forcé
	# La pause sera gérée dans main.gd pour plus de robustesse
	forced_disconnect_requested.emit(12)  # 12h de repos obligatoire

func try_reconnect() -> bool:
	"""Tente de reconnecter le joueur si c'est l'heure"""
	if is_online or not scheduled_return_time.has("hour"):
		return false
	
	var game_time = _get_game_time()
	if not game_time:
		return false
	
	# Vérifier si c'est l'heure de se reconnecter
	if (game_time.current_day == scheduled_return_time.day and 
		game_time.current_hour >= scheduled_return_time.hour and
		game_time.current_minute >= scheduled_return_time.minute):
		
		return reconnect_player()
	
	return false

func reconnect_player() -> bool:
	"""Reconnecte le joueur après une période offline"""
	if is_online:
		return false
	
	# Calculer la récupération d'énergie
	var offline_duration = _calculate_offline_duration()
	var energy_recovery = offline_duration * 10.0  # +10 énergie par heure offline
	
	# Bonus si déconnecté plus de 8h
	if offline_duration >= 8.0:
		energy_recovery += 20.0
		print("Bonus de repos: +20 énergie (déconnecté %d heures)" % int(offline_duration))
	
	player_energy_pool = min(max_energy_pool, player_energy_pool + energy_recovery)
	energy = min(100.0, energy + energy_recovery * 0.5)
	
	# Réduire la fatigue
	consecutive_hours = max(0.0, consecutive_hours - offline_duration * 0.5)
	
	# Reconnecter
	go_online()
	manual_control_enabled = true
	scheduled_return_time.clear()
	
	# Initialiser une nouvelle session
	_initialize_session()
	
	print("Joueur reconnecté! Énergie: %.1f/%.1f" % [player_energy_pool, max_energy_pool])
	return true

func _calculate_offline_duration() -> float:
	"""Calcule la durée en heures passée offline"""
	if not session_start_time.has("hour"):
		return 8.0  # Valeur par défaut
	
	var game_time = _get_game_time()
	if not game_time:
		return 8.0
	
	var current_total_minutes = game_time.current_hour * 60 + game_time.current_minute
	var session_total_minutes = session_start_time.hour * 60 + session_start_time.minute
	
	var diff_minutes = current_total_minutes - session_total_minutes
	if diff_minutes < 0:  # Changement de jour
		diff_minutes += 24 * 60
	
	return diff_minutes / 60.0

func _calculate_session_gains():
	"""Calcule les gains de la session actuelle"""
	var game_time = _get_game_time()
	if not game_time or not session_start_time.has("hour"):
		return
	
	var current_total_minutes = game_time.current_hour * 60 + game_time.current_minute
	var session_total_minutes = session_start_time.hour * 60 + session_start_time.minute
	
	session_duration_minutes = current_total_minutes - session_total_minutes
	if session_duration_minutes < 0:  # Changement de jour
		session_duration_minutes += 24 * 60
	
	# Les gains XP et or sont calculés en temps réel, pas besoin de les recalculer

func get_session_report() -> Dictionary:
	"""Retourne un rapport de la session actuelle"""
	return {
		"xp_gained": session_xp_gained,
		"gold_gained": session_gold_gained,
		"duration_minutes": session_duration_minutes,
		"energy_remaining": player_energy_pool,
		"levels_gained": personnage_niveau - 1,  # Commence niveau 1
		"activity_time": _get_activity_breakdown()
	}

func _get_activity_breakdown() -> Dictionary:
	"""Retourne la répartition du temps par activité (placeholder)"""
	return {
		"LEVELING": 0,
		"FARMING": 0,
		"FUN": 0,
		"DUNGEON": 0
	}

func gain_experience(amount: int) -> void:
	"""Override pour tracker l'XP de session"""
	var old_level = personnage_niveau
	super.gain_experience(amount)
	
	# Tracker les gains de session
	session_xp_gained += amount
	
	# Bonus de moral pour level up
	if personnage_niveau > old_level:
		mood = min(100.0, mood + 10.0)
		print("LEVEL UP! %s est maintenant niveau %d" % [nom, personnage_niveau])

func add_session_gold(amount: int):
	"""Ajoute de l'or gagné durant la session"""
	session_gold_gained += amount
	or_actuel += amount

# Override des méthodes de connexion automatique pour les désactiver
func should_connect(game_time: Node) -> bool:
	"""Le joueur ne se connecte pas automatiquement"""
	if is_player_controlled:
		return try_reconnect()
	return super.should_connect(game_time)

func should_disconnect(game_time: Node) -> bool:
	"""Le joueur ne se déconnecte pas automatiquement (sauf si forcé)"""
	if is_player_controlled and manual_control_enabled:
		return false
	return super.should_disconnect(game_time)

# Méthodes utilitaires
func _get_game_time() -> Node:
	"""Récupère le nœud GameTime"""
	if Engine.has_singleton("GameTime"):
		return Engine.get_singleton("GameTime")
	var tree = Engine.get_main_loop()
	if tree and tree.root:
		return tree.root.get_node_or_null("/root/GameTime")
	return null

func _get_activity_manager() -> Node:
	"""Récupère l'ActivityManager"""
	var tree = Engine.get_main_loop()
	if tree and tree.root:
		return tree.root.get_node_or_null("/root/ActivityManager")
	return null

func get_energy_percentage() -> float:
	"""Retourne le pourcentage d'énergie restante"""
	return (player_energy_pool / max_energy_pool) * 100.0

func is_energy_low() -> bool:
	"""Vérifie si l'énergie est faible (< 25%)"""
	return get_energy_percentage() < 25.0

func is_energy_critical() -> bool:
	"""Vérifie si l'énergie est critique (< 10%)"""
	return get_energy_percentage() < 10.0

func can_perform_activity(activity_type: String) -> bool:
	"""Vérifie si le joueur peut effectuer une activité"""
	var drain_rate = energy_drain_rates.get(activity_type, 10.0)
	return player_energy_pool >= drain_rate * 0.5  # Au moins 30 min

func get_available_activities() -> Array[String]:
	"""Retourne la liste des activités disponibles"""
	var activities: Array[String] = []
	
	for activity in ["LEVELING", "FARMING", "FUN", "DUNGEON", "RAID"]:
		if can_perform_activity(activity):
			activities.append(activity)
	
	return activities

func get_activity_display_name(activity_type: String) -> String:
	"""Retourne le nom d'affichage d'une activité"""
	match activity_type:
		"LEVELING": return "Leveling"
		"FARMING": return "Farming"
		"FUN": return "Glander en ville"
		"DUNGEON": return "Donjon"
		"RAID": return "Raid"
		_: return activity_type