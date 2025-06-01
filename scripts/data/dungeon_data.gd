extends Resource
class_name DungeonData

enum InstanceType {
	DUNGEON,
	RAID
}

enum Difficulty {
	NORMAL,
	HEROIC  # Pour le futur
}

# Base de données des donjons (inspirés de WoW Vanilla)
static var DUNGEONS = {
	# Donjons bas niveau (15-30)
	"ragefire_chasm": {
		"name": "Gouffre de Ragefeu",
		"type": InstanceType.DUNGEON,
		"level_min": 13,
		"level_max": 18,
		"level_recommended": 15,
		"group_size": 5,
		"bosses": ["Oggleflint", "Taragaman le Vorace", "Jergosh l'Invocateur", "Bazzalan"],
		"equipment_reward_level": 16,
		"description": "Un réseau de cavernes volcaniques sous Orgrimmar"
	},
	"deadmines": {
		"name": "Les Mortemines",
		"type": InstanceType.DUNGEON,
		"level_min": 17,
		"level_max": 26,
		"level_recommended": 20,
		"group_size": 5,
		"bosses": ["Rhahk'Zor", "Sneed", "Gilnid", "M. Châtiment", "Cookie", "Edwin VanCleef"],
		"equipment_reward_level": 22,
		"description": "Le repaire de la Confrérie Défias"
	},
	"wailing_caverns": {
		"name": "Cavernes des Lamentations",
		"type": InstanceType.DUNGEON,
		"level_min": 17,
		"level_max": 24,
		"level_recommended": 20,
		"group_size": 5,
		"bosses": ["Seigneur Cobrahn", "Lady Anacondra", "Kresh", "Seigneur Pythas", "Mutanus le Dévoreur"],
		"equipment_reward_level": 21,
		"description": "Un labyrinthe de grottes corrompues"
	},
	
	# Donjons niveau moyen (30-45)
	"gnomeregan": {
		"name": "Gnomeregan",
		"type": InstanceType.DUNGEON,
		"level_min": 29,
		"level_max": 38,
		"level_recommended": 33,
		"group_size": 5,
		"bosses": ["Grubbis", "Viscidus", "Electrocuteur 6000", "Mekgineer Thermaplugg"],
		"equipment_reward_level": 35,
		"description": "La cité gnome irradiée"
	},
	"scarlet_monastery": {
		"name": "Monastère Écarlate",
		"type": InstanceType.DUNGEON,
		"level_min": 34,
		"level_max": 45,
		"level_recommended": 40,
		"group_size": 5,
		"bosses": ["Interrogateur Vishas", "Thalnos le Dément", "Champion Mograine", "Whitemane"],
		"equipment_reward_level": 42,
		"description": "Le bastion de la Croisade Écarlate"
	},
	"uldaman": {
		"name": "Uldaman",
		"type": InstanceType.DUNGEON,
		"level_min": 41,
		"level_max": 51,
		"level_recommended": 45,
		"group_size": 5,
		"bosses": ["Revelosh", "Les Sculpteurs de pierre", "Ironaya", "Archaedas"],
		"equipment_reward_level": 47,
		"description": "Une ancienne cité titan"
	},
	
	# Donjons haut niveau (45-60)
	"zul_farrak": {
		"name": "Zul'Farrak",
		"type": InstanceType.DUNGEON,
		"level_min": 44,
		"level_max": 54,
		"level_recommended": 48,
		"group_size": 5,
		"bosses": ["Theka le Martyr", "Antu'sul", "Sorcière docteur Zum'rah", "Chef Ukorz Sandscalp", "Gahz'rilla"],
		"equipment_reward_level": 50,
		"description": "Une cité trolle en ruines dans le désert"
	},
	"blackrock_depths": {
		"name": "Profondeurs de Rochenoire",
		"type": InstanceType.DUNGEON,
		"level_min": 52,
		"level_max": 60,
		"level_recommended": 55,
		"group_size": 5,
		"bosses": ["Interrogateur Gerstahn", "Bael'Gar", "Général Angerforge", "Empereur Dagran Thaurissan"],
		"equipment_reward_level": 57,
		"description": "La capitale des Sombrefer"
	},
	"stratholme": {
		"name": "Stratholme",
		"type": InstanceType.DUNGEON,
		"level_min": 58,
		"level_max": 60,
		"level_recommended": 60,
		"group_size": 5,
		"bosses": ["Le Fras Siabi", "Magistrat Barthilas", "Baron Rivendare", "Balnazzar"],
		"equipment_reward_level": 60,
		"description": "La cité en quarantaine infestée de morts-vivants"
	},
	"scholomance": {
		"name": "Scholomance",
		"type": InstanceType.DUNGEON,
		"level_min": 58,
		"level_max": 60,
		"level_recommended": 60,
		"group_size": 5,
		"bosses": ["Jandice Barov", "Rattlegore", "Ras Frostwhisper", "Darkmaster Gandling"],
		"equipment_reward_level": 60,
		"description": "L'école de nécromancie"
	}
}

# Raids niveau 60
static var RAIDS = {
	"molten_core": {
		"name": "Cœur du Magma",
		"type": InstanceType.RAID,
		"level_min": 60,
		"level_max": 60,
		"level_recommended": 60,
		"group_size": 40,
		"bosses": ["Lucifron", "Magmadar", "Gehennas", "Garr", "Baron Geddon", "Shazzrah", "Sulfuron", "Golemagg", "Majordomo", "Ragnaros"],
		"equipment_reward_level": 66,  # T1
		"reset_days": 7,
		"description": "Le domaine du Seigneur du Feu Ragnaros"
	},
	"onyxias_lair": {
		"name": "Repaire d'Onyxia",
		"type": InstanceType.RAID,
		"level_min": 60,
		"level_max": 60,
		"level_recommended": 60,
		"group_size": 40,
		"bosses": ["Onyxia"],
		"equipment_reward_level": 66,
		"reset_days": 5,
		"description": "L'antre de la dragonne noire"
	},
	"blackwing_lair": {
		"name": "Repaire de l'Aile noire",
		"type": InstanceType.RAID,
		"level_min": 60,
		"level_max": 60,
		"level_recommended": 60,
		"group_size": 40,
		"bosses": ["Razorgore", "Vaelastrasz", "Broodlord", "Firemaw", "Ebonroc", "Flamegor", "Chromaggus", "Nefarian"],
		"equipment_reward_level": 70,  # T2
		"reset_days": 7,
		"description": "Le laboratoire de Nefarian"
	},
	"zul_gurub": {
		"name": "Zul'Gurub",
		"type": InstanceType.RAID,
		"level_min": 60,
		"level_max": 60,
		"level_recommended": 60,
		"group_size": 20,
		"bosses": ["Venoxis", "Jeklik", "Mar'li", "Thekal", "Arlokk", "Hakkar"],
		"equipment_reward_level": 68,
		"reset_days": 3,
		"description": "La cité trolle maudite"
	}
}

static func get_all_instances() -> Dictionary:
	var all_instances = {}
	all_instances.merge(DUNGEONS)
	all_instances.merge(RAIDS)
	return all_instances

static func get_instance_data(instance_id: String) -> Dictionary:
	if DUNGEONS.has(instance_id):
		return DUNGEONS[instance_id]
	elif RAIDS.has(instance_id):
		return RAIDS[instance_id]
	return {}

static func get_instances_for_level(level: int, type = -1) -> Array:
	var suitable_instances = []
	var all_instances = get_all_instances()
	
	for id in all_instances:
		var instance = all_instances[id]
		if level >= instance.level_min and level <= instance.level_max:
			if type == -1 or instance.type == type:
				suitable_instances.append({
					"id": id,
					"data": instance
				})
	
	return suitable_instances

static func get_group_composition(instance_id: String) -> Dictionary:
	var instance = get_instance_data(instance_id)
	if instance.is_empty():
		return {}
		
	match instance.type:
		InstanceType.DUNGEON:
			return {
				"Tank": 1,
				"Healer": 1,
				"DPS": 3
			}
		InstanceType.RAID:
			if instance.group_size == 20:
				return {
					"Tank": 2,
					"Healer": 4,
					"DPS": 14
				}
			else:  # 40 joueurs
				return {
					"Tank": 3,
					"Healer": 8,
					"DPS": 29
				}
	
	return {}

static func calculate_difficulty_score(instance_id: String, group: Array) -> float:
	var instance = get_instance_data(instance_id)
	if instance.is_empty():
		return 0.0
		
	var score = 1.0
	
	# Calcul basé sur le niveau moyen du groupe
	var avg_level = 0
	var avg_equipment = 0
	var avg_skill = 0
	
	for member in group:
		avg_level += member.personnage_niveau
		avg_equipment += member.personnage_equipement
		avg_skill += member.skill
		
	avg_level /= float(group.size())
	avg_equipment /= float(group.size())
	avg_skill /= float(group.size())
	
	# Pénalité si sous-niveau
	if avg_level < instance.level_recommended:
		score *= 0.9 ** (instance.level_recommended - avg_level)
		
	# Bonus si sur-niveau (plafonné)
	if avg_level > instance.level_recommended:
		score *= min(1.5, 1.0 + (avg_level - instance.level_recommended) * 0.05)
		
	# Impact de l'équipement
	var expected_equipment = instance.level_recommended * 3
	score *= avg_equipment / expected_equipment
	
	# Impact du skill
	score *= avg_skill / 50.0
	
	return clamp(score, 0.1, 2.0)