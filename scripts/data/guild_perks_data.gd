class_name GuildPerksData
extends Resource

static var PERKS = {
	2: {
		"name": "Forum de la guilde",
		"description": "Permet de recruter de nouveaux membres",
		"effects": {
			"can_recruit": true
		}
	},
	3: {
		"name": "Banque de guilde",
		"description": "Débloque l'activité Farming pour générer de l'or et des potions",
		"effects": {
			"unlock_farming": true,
			"gold_storage": 1000
		}
	},
	4: {
		"name": "Tabard de guilde",
		"description": "Augmente l'intégration des membres de 10%",
		"effects": {
			"integration_bonus": 0.1
		}
	},
	5: {
		"name": "Extension de la guilde",
		"description": "Permet d'accueillir plus de membres (limite portée à 20) et agrandit la trésorerie",
		"effects": {
			"max_members": 20,
			"gold_storage": 9000
		}
	},
	6: {
		"name": "Ventrilo de guilde",
		"description": "Améliore la coordination en raid (+5% de réussite)",
		"effects": {
			"raid_success_bonus": 0.05
		}
	},
	7: {
		"name": "DKP System",
		"description": "Réduit les conflits de loot de 20%",
		"effects": {
			"loot_conflict_reduction": 0.2
		}
	},
	8: {
		"name": "Site web de guilde",
		"description": "Augmente la visibilité (+2 candidats dans le pool de recrutement) et la trésorerie",
		"effects": {
			"recruitment_pool_bonus": 2,
			"gold_storage": 40000
		}
	},
	9: {
		"name": "Teamspeak Premium",
		"description": "Améliore encore la coordination (+5% supplémentaire en raid)",
		"effects": {
			"raid_success_bonus": 0.05
		}
	},
	10: {
		"name": "Réputation de serveur",
		"description": "Attire les meilleurs joueurs (+20% qualité du pool de recrutement), améliore la planification et débloque une grande trésorerie",
		"effects": {
			"recruitment_quality_bonus": 0.2,
			"availability_bonus": 0.15,
			"gold_storage": 200000
		}
	}
}

static func get_xp_for_level(level: int) -> int:
	if level <= 1:
		return 0
	return (level - 1) * 200 + get_xp_for_level(level - 1)

static func get_level_from_xp(xp: int) -> int:
	var level = 1
	while get_xp_for_level(level + 1) <= xp and level < 10:
		level += 1
	return level

static func get_xp_progress(xp: int) -> Dictionary:
	var level = get_level_from_xp(xp)
	var current_level_xp = get_xp_for_level(level)
	var next_level_xp = get_xp_for_level(level + 1)
	
	return {
		"level": level,
		"current_xp": xp,
		"current_level_total": current_level_xp,
		"next_level_total": next_level_xp,
		"progress": xp - current_level_xp,
		"needed": next_level_xp - xp
	}

static func get_active_perks(level: int) -> Array:
	var active_perks = []
	for perk_level in PERKS.keys():
		if perk_level <= level:
			var perk_data = PERKS[perk_level].duplicate()
			perk_data["level"] = perk_level
			active_perks.append(perk_data)
	return active_perks

static func get_combined_effects(level: int) -> Dictionary:
	var effects = {
		"max_members": 10,  # Commence avec 10 membres au niveau 1
		"can_recruit": false,
		"unlock_farming": false,
		"gold_storage": 0,
		"integration_bonus": 0.0,
		"raid_success_bonus": 0.0,
		"loot_conflict_reduction": 0.0,
		"recruitment_pool_bonus": 0,
		"availability_bonus": 0.0,
		"recruitment_quality_bonus": 0.0
	}
	
	for perk_level in PERKS.keys():
		if perk_level <= level:
			var perk_effects = PERKS[perk_level]["effects"]
			for effect_key in perk_effects:
				if effect_key in effects:
					if typeof(effects[effect_key]) == TYPE_FLOAT or typeof(effects[effect_key]) == TYPE_INT:
						effects[effect_key] += perk_effects[effect_key]
					else:
						effects[effect_key] = perk_effects[effect_key]
	
	return effects