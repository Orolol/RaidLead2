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
		"description": "Un réseau de cavernes volcaniques sous Orgrimmar",
		"difficulty": 1.0,
		"duration_minutes": 45,
		"gold_reward": 50,
		"boss_difficulty_multiplier": 1.2  # Le dernier boss est 20% plus dur
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
		"description": "Le repaire de la Confrérie Défias",
		"difficulty": 1.2,
		"duration_minutes": 60,
		"gold_reward": 75,
		"boss_difficulty_multiplier": 1.2
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
		"description": "Un labyrinthe de grottes corrompues",
		"difficulty": 1.1,
		"duration_minutes": 55,
		"gold_reward": 75,
		"boss_difficulty_multiplier": 1.2
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
		"description": "La cité gnome irradiée",
		"difficulty": 1.4,
		"duration_minutes": 81,
		"gold_reward": 140,
		"boss_difficulty_multiplier": 1.2
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
		"description": "Le bastion de la Croisade Écarlate",
		"difficulty": 1.5,
		"duration_minutes": 95,
		"gold_reward": 175,
		"boss_difficulty_multiplier": 1.2
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
		"description": "Une ancienne cité titan",
		"difficulty": 1.6,
		"duration_minutes": 105,
		"gold_reward": 200,
		"boss_difficulty_multiplier": 1.2
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
		"description": "Une cité trolle en ruines dans le désert",
		"difficulty": 1.7,
		"duration_minutes": 111,
		"gold_reward": 215,
		"boss_difficulty_multiplier": 1.2
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
		"description": "La capitale des Sombrefer",
		"difficulty": 1.8,
		"duration_minutes": 125,
		"gold_reward": 250,
		"boss_difficulty_multiplier": 1.25
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
		"description": "La cité en quarantaine infestée de morts-vivants",
		"difficulty": 1.9,
		"duration_minutes": 135,
		"gold_reward": 275,
		"boss_difficulty_multiplier": 1.25
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
		"description": "L'école de nécromancie",
		"difficulty": 1.9,
		"duration_minutes": 135,
		"gold_reward": 275,
		"boss_difficulty_multiplier": 1.25
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
		"description": "Le domaine du Seigneur du Feu Ragnaros",
		"difficulty": 2.9,
		"duration_minutes": 240,
		"gold_reward": 2750,
		"boss_difficulty_multiplier": 1.3
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
		"description": "L'antre de la dragonne noire",
		"difficulty": 2.5,
		"duration_minutes": 90,
		"gold_reward": 1500,
		"boss_difficulty_multiplier": 1.5
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
		"description": "Le laboratoire de Nefarian",
		"difficulty": 3.2,
		"duration_minutes": 300,
		"gold_reward": 3500,
		"boss_difficulty_multiplier": 1.4
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
		"description": "La cité trolle maudite",
		"difficulty": 2.3,
		"duration_minutes": 180,
		"gold_reward": 1800,
		"boss_difficulty_multiplier": 1.3
	}
}

static func get_all_instances() -> Dictionary:
	var all_instances = {}
	all_instances.merge(DUNGEONS)
	all_instances.merge(RAIDS)
	return all_instances

static func get_available_instances() -> Dictionary:
	var available_instances = {}
	
	if not ServerVersion:
		return get_all_instances()
	
	var available_dungeons = ServerVersion.get_available_dungeons()
	var available_raids = ServerVersion.get_available_raids()
	
	# Ajouter les donjons disponibles
	for dungeon_id in available_dungeons:
		if DUNGEONS.has(dungeon_id):
			available_instances[dungeon_id] = DUNGEONS[dungeon_id]
	
	# Ajouter les raids disponibles
	for raid_id in available_raids:
		if RAIDS.has(raid_id):
			available_instances[raid_id] = RAIDS[raid_id]
	
	return available_instances

static func get_instance_data(instance_id: String) -> Dictionary:
	if DUNGEONS.has(instance_id):
		return DUNGEONS[instance_id]
	elif RAIDS.has(instance_id):
		return RAIDS[instance_id]
	elif instance_id.ends_with("_heroic"):
		# Les variantes héroïques sont générées dynamiquement (pas dans DUNGEONS)
		var heroics = get_heroic_dungeons()
		if heroics.has(instance_id):
			return heroics[instance_id]
	return {}

static func is_instance_available(instance_id: String) -> bool:
	if not ServerVersion:
		return true
	return ServerVersion.is_instance_available(instance_id)

static func get_instances_for_level(level: int, type = -1, available_only: bool = true) -> Array:
	var suitable_instances = []
	var instances_to_check = get_available_instances() if available_only else get_all_instances()
	
	for id in instances_to_check:
		var instance = instances_to_check[id]
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
		avg_equipment += member.get_total_ilvl()
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

static func get_heroic_dungeons() -> Dictionary:
	"""Retourne les donjons niveau 60 en version héroïque"""
	var heroic_dungeons = {}
	
	# Donjons niveau 60 qui peuvent être faits en héroïque
	var level_60_dungeons = ["stratholme", "scholomance", "blackrock_depths"]
	
	for dungeon_id in level_60_dungeons:
		var base_dungeon = DUNGEONS.get(dungeon_id, {})
		if base_dungeon.is_empty():
			continue
			
		var heroic_id = dungeon_id + "_heroic"
		heroic_dungeons[heroic_id] = base_dungeon.duplicate()
		heroic_dungeons[heroic_id]["name"] = base_dungeon.name + " (Héroïque)"
		heroic_dungeons[heroic_id]["difficulty"] = base_dungeon.difficulty * 1.5  # 50% plus dur
		heroic_dungeons[heroic_id]["equipment_reward_level"] = base_dungeon.equipment_reward_level + 10  # +10 iLvl
		heroic_dungeons[heroic_id]["gold_reward"] = base_dungeon.gold_reward * 2  # Double récompense or
		heroic_dungeons[heroic_id]["is_heroic"] = true
		heroic_dungeons[heroic_id]["requires_level"] = 60  # Niveau max requis
		heroic_dungeons[heroic_id]["description"] = base_dungeon.description + " - Version héroïque avec défis accrus"
	
	return heroic_dungeons

static func is_heroic_dungeon(instance_id: String) -> bool:
	"""Vérifie si un donjon est héroïque"""
	return instance_id.ends_with("_heroic")

static func get_all_dungeons_and_heroic() -> Dictionary:
	"""Retourne tous les donjons normaux et héroïques combinés"""
	var all_dungeons = DUNGEONS.duplicate()
	var heroic_dungeons = get_heroic_dungeons()
	
	for heroic_id in heroic_dungeons:
		all_dungeons[heroic_id] = heroic_dungeons[heroic_id]
	
	return all_dungeons