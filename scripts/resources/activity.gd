extends Resource
class_name Activity

enum ActivityType {
	NONE,
	LEVELING,
	FARMING,
	FUN,
	DUNGEON,
	RAID,
	OFFLINE
}

@export var type: ActivityType = ActivityType.NONE
@export var name: String = ""
@export var description: String = ""
@export var start_time: Dictionary = {}  # Stocke l'heure de début
@export var duration_minutes: int = 0  # Durée prévue en minutes
@export var participants: Array = []
@export var location: String = ""  # Zone de leveling, instance, etc.

# Effets de l'activité
@export var energy_cost_per_hour: float = 10.0
@export var mood_change_per_hour: float = 0.0
@export var integration_gain_per_hour: float = 0.0
@export var xp_gain_per_hour: int = 0

func _init(p_type: ActivityType = ActivityType.NONE, p_name: String = "") -> void:
	type = p_type
	name = p_name
	_setup_activity_defaults()

func _setup_activity_defaults() -> void:
	match type:
		ActivityType.LEVELING:
			name = "Leveling" if name == "" else name
			description = "Tuer des monstres pour gagner de l'expérience"
			energy_cost_per_hour = 15.0
			mood_change_per_hour = -5.0
			integration_gain_per_hour = 1.0
			xp_gain_per_hour = 1000  # À ajuster selon le niveau
			
		ActivityType.FARMING:
			name = "Farming" if name == "" else name
			description = "Récolter des ressources et de l'or"
			energy_cost_per_hour = 20.0
			mood_change_per_hour = -10.0
			integration_gain_per_hour = 0.5
			
		ActivityType.FUN:
			name = "Activité Fun" if name == "" else name
			description = "Se détendre et s'amuser avec la guilde"
			energy_cost_per_hour = 5.0
			mood_change_per_hour = 20.0
			integration_gain_per_hour = 5.0
		
		ActivityType.DUNGEON:
			name = "Donjon" if name == "" else name
			description = "Préparer ou participer à une sortie donjon"
			energy_cost_per_hour = 25.0
			mood_change_per_hour = -2.0
			integration_gain_per_hour = 3.0
		
		ActivityType.RAID:
			name = "Raid" if name == "" else name
			description = "Préparer ou participer à une sortie raid"
			energy_cost_per_hour = 35.0
			mood_change_per_hour = -5.0
			integration_gain_per_hour = 4.0
			
		ActivityType.OFFLINE:
			name = "Hors ligne" if name == "" else name
			description = "Le joueur n'est pas connecté"
			energy_cost_per_hour = -30.0  # Récupération d'énergie
			mood_change_per_hour = 5.0  # Récupération légère de moral

func get_type_string() -> String:
	match type:
		ActivityType.NONE: return "Aucune"
		ActivityType.LEVELING: return "Leveling"
		ActivityType.FARMING: return "Farming"
		ActivityType.FUN: return "Fun"
		ActivityType.DUNGEON: return "Donjon"
		ActivityType.RAID: return "Raid"
		ActivityType.OFFLINE: return "Hors ligne"
		_: return "Inconnue"

func is_group_activity() -> bool:
	return type in [ActivityType.DUNGEON, ActivityType.RAID, ActivityType.FUN]

func can_be_interrupted() -> bool:
	return type in [ActivityType.LEVELING, ActivityType.FARMING]
