extends Node
class_name ActivityManager

const ActivityScript = preload("res://scripts/resources/activity.gd")

signal activity_started(player, activity)
signal activity_completed(player, activity)
signal activity_interrupted(player, activity, reason)

var game_time: Node
var active_activities: Dictionary = {}  # player -> Activity

# Zones de leveling inspirées de WoW Vanilla
var leveling_zones = {
	"1-10": ["Forêt d'Elwynn", "Dun Morogh", "Teldrassil", "Durotar"],
	"10-20": ["Marche de l'Ouest", "Loch Modan", "Sombrivage", "Les Tarides"],
	"20-30": ["Carmines", "Terres Ingrates", "Ashenvale", "Mille Pointes"],
	"30-40": ["Vallée de Strangleronce", "Désolace", "Marais des Chagrins"],
	"40-50": ["Tanaris", "Féralas", "Azshara", "Les Hinterlands"],
	"50-60": ["Cratère d'Un'Goro", "Gangrebois", "Steppes Ardentes", "Maleterres"]
}

func _ready():
	game_time = get_node("/root/GameTime")
	if game_time:
		game_time.hour_changed.connect(_on_hour_changed)

func _on_hour_changed(_hour: int):
	_update_all_activities()

func start_activity(player, activity_type, params: Dictionary = {}):
	if active_activities.has(player):
		interrupt_activity(player, "Nouvelle activité démarrée")
	
	var activity = ActivityScript.new(activity_type)
	
	# Configuration spécifique selon le type
	match activity_type:
		ActivityScript.ActivityType.LEVELING:
			activity.location = _get_leveling_zone(player.personnage_niveau)
			activity.xp_gain_per_hour = _calculate_xp_per_hour(player.personnage_niveau)
			
		ActivityScript.ActivityType.FUN:
			activity.name = params.get("name", "Duel amical devant Orgrimmar")
			activity.participants = params.get("participants", [])
	
	activity.start_time = {
		"hour": game_time.current_hour,
		"day": game_time.current_day,
		"week": game_time.current_week
	}
	
	active_activities[player] = activity
	player.current_activity = activity
	
	activity_started.emit(player, activity)

func interrupt_activity(player, reason: String = "Interruption"):
	if not active_activities.has(player):
		return
		
	var activity = active_activities[player]
	active_activities.erase(player)
	player.current_activity = null
	
	activity_interrupted.emit(player, activity, reason)

func _update_all_activities():
	for player in active_activities.keys():
		_update_player_activity(player)

func _update_player_activity(player):
	if not active_activities.has(player):
		return
		
	var activity = active_activities[player]
	
	# Applique les effets de l'activité
	player.energy = max(0, player.energy - activity.energy_cost_per_hour)
	player.mood = clamp(player.mood + activity.mood_change_per_hour, 0, 100)
	player.update_integration(activity.integration_gain_per_hour)
	
	# Effets spécifiques
	match activity.type:
		ActivityScript.ActivityType.LEVELING:
			if player.personnage_niveau < 60:
				var _xp_gained = activity.xp_gain_per_hour
				# Simuler le gain d'XP (simplifié pour le MVP)
				# On pourrait avoir un système d'XP plus complexe
				if randf() < 0.1:  # 10% de chance de level up par heure
					player.personnage_niveau += 1
					player.mood += 10  # Boost de moral au level up !
	
	# Vérifications pour interrompre l'activité
	if player.energy <= 0:
		interrupt_activity(player, "Épuisé - besoin de repos")
		_decide_next_activity(player)
	elif player.mood <= 20 and activity.type != ActivityScript.ActivityType.FUN:
		interrupt_activity(player, "Moral trop bas")
		_decide_next_activity(player)

func _decide_next_activity(player):
	# Logique simple pour décider de la prochaine activité
	if not player.is_online:
		return
		
	if player.energy < 20:
		# Trop fatigué, se déconnecte
		player.go_offline()
		start_activity(player, ActivityScript.ActivityType.OFFLINE)
	elif player.mood < 30:
		# Moral bas, besoin de fun
		start_activity(player, ActivityScript.ActivityType.FUN, {
			"name": _get_random_fun_activity()
		})
	elif player.personnage_niveau < 60:
		# Pas encore niveau max, continue le leveling
		start_activity(player, ActivityScript.ActivityType.LEVELING)
	else:
		# Niveau 60, farming
		start_activity(player, ActivityScript.ActivityType.FARMING)

func _get_leveling_zone(level: int) -> String:
	for range_str in leveling_zones:
		var parts = range_str.split("-")
		var min_level = int(parts[0])
		var max_level = int(parts[1])
		if level >= min_level and level <= max_level:
			var zones = leveling_zones[range_str]
			return zones[randi() % zones.size()]
	return "Maleterres"  # Zone par défaut pour haut niveau

func _calculate_xp_per_hour(level: int) -> int:
	# XP/heure diminue avec le niveau (plus dur de monter)
	return 2000 - (level * 20)

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
