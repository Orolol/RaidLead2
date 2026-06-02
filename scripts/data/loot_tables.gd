extends Resource
class_name LootTables

const ItemScript = preload("res://scripts/resources/item.gd")

# Modulateurs pour la génération des statistiques
const SLOT_STAT_MULTIPLIERS = {
	ItemScript.EquipmentSlot.HELMET: 0.45,
	ItemScript.EquipmentSlot.SHOULDERS: 0.4,
	ItemScript.EquipmentSlot.CHEST: 0.55,
	ItemScript.EquipmentSlot.WEAPON: 0.7,
	ItemScript.EquipmentSlot.RING: 0.25
}

const RARITY_STAT_MULTIPLIERS = {
	ItemScript.Rarity.COMMON: 1.0,
	ItemScript.Rarity.UNCOMMON: 1.15,
	ItemScript.Rarity.RARE: 1.35,
	ItemScript.Rarity.EPIC: 1.75
}

const RARITY_FLAT_BONUS = {
	ItemScript.Rarity.COMMON: 0,
	ItemScript.Rarity.UNCOMMON: 1,
	ItemScript.Rarity.RARE: 3,
	ItemScript.Rarity.EPIC: 6
}

# Noms d'objets par slot et rareté
const ITEM_NAMES = {
	ItemScript.EquipmentSlot.HELMET: {
		ItemScript.Rarity.COMMON: ["Casque de Cuir Usé", "Coiffe Simple", "Bandeau de Tissu"],
		ItemScript.Rarity.UNCOMMON: ["Casque de Mailles Renforcé", "Heaume de Garde", "Coiffe de Mage Novice"],
		ItemScript.Rarity.RARE: ["Couronne de Bataille", "Casque du Protecteur", "Diadème Mystique"],
		ItemScript.Rarity.EPIC: ["Couronne des Héros", "Heaume Légendaire", "Tiare Arcanique"]
	},
	ItemScript.EquipmentSlot.SHOULDERS: {
		ItemScript.Rarity.COMMON: ["Épaulières de Cuir", "Protège-Épaules Basiques", "Manteau Simple"],
		ItemScript.Rarity.UNCOMMON: ["Épaulières Renforcées", "Manteau de Garde", "Cape de Mage"],
		ItemScript.Rarity.RARE: ["Épaulières de Bataille", "Manteau du Champion", "Cape Mystique"],
		ItemScript.Rarity.EPIC: ["Épaulières Légendaires", "Manteau des Héros", "Cape Arcane"]
	},
	ItemScript.EquipmentSlot.CHEST: {
		ItemScript.Rarity.COMMON: ["Tunique de Cuir", "Plastron Basique", "Robe Simple"],
		ItemScript.Rarity.UNCOMMON: ["Plastron Renforcé", "Armure de Garde", "Robe de Mage"],
		ItemScript.Rarity.RARE: ["Plastron de Bataille", "Armure du Champion", "Robe Mystique"],
		ItemScript.Rarity.EPIC: ["Plastron Légendaire", "Armure des Héros", "Robe Arcane"]
	},
	ItemScript.EquipmentSlot.WEAPON: {
		ItemScript.Rarity.COMMON: ["Épée Rouillée", "Bâton de Bois", "Masse Simple"],
		ItemScript.Rarity.UNCOMMON: ["Épée d'Acier", "Bâton Renforcé", "Masse de Guerre"],
		ItemScript.Rarity.RARE: ["Lame Enchantée", "Sceptre Mystique", "Marteau de Bataille"],
		ItemScript.Rarity.EPIC: ["Lame Légendaire", "Sceptre Arcane", "Marteau des Héros"]
	},
	ItemScript.EquipmentSlot.RING: {
		ItemScript.Rarity.COMMON: ["Anneau de Bronze", "Bague Simple", "Anneau Terni"],
		ItemScript.Rarity.UNCOMMON: ["Anneau d'Argent", "Bague Ornée", "Anneau de Protection"],
		ItemScript.Rarity.RARE: ["Anneau d'Or", "Bague Enchantée", "Anneau de Pouvoir"],
		ItemScript.Rarity.EPIC: ["Anneau Légendaire", "Bague des Héros", "Anneau Arcane"]
	}
}

# Chances de drop par rareté (sur 100)
const RARITY_CHANCES = {
	ItemScript.Rarity.COMMON: 60,
	ItemScript.Rarity.UNCOMMON: 30,
	ItemScript.Rarity.RARE: 8,
	ItemScript.Rarity.EPIC: 2
}

static func generate_item_for_level(base_level: int, is_heroic: bool = false) -> ItemScript:
	"""Génère un objet aléatoirement pour un niveau donné"""
	
	# Calculer l'iLvl selon le niveau (nouvelle balance)
	var item_ilvl: int = _calculate_ilvl_for_level(base_level)
	
	# Ajouter variation aléatoire (-2 à +3 iLvl)
	item_ilvl += randi_range(-2, 3)
	
	# Ajuster l'iLvl pour héroïque (+10 à +15 iLvl)
	if is_heroic:
		item_ilvl += randi_range(10, 15)
	
	# Déterminer la rareté
	var rarity: ItemScript.Rarity = _roll_rarity(is_heroic)
	
	# Bonus d'iLvl selon la rareté
	match rarity:
		ItemScript.Rarity.UNCOMMON: item_ilvl += 3
		ItemScript.Rarity.RARE: item_ilvl += 7
		ItemScript.Rarity.EPIC: item_ilvl += 12
	
	# S'assurer que l'iLvl minimum est de 1
	item_ilvl = max(1, item_ilvl)
	
	# Choisir un slot aléatoire
	var slots: Array = [
		ItemScript.EquipmentSlot.HELMET,
		ItemScript.EquipmentSlot.SHOULDERS,
		ItemScript.EquipmentSlot.CHEST,
		ItemScript.EquipmentSlot.WEAPON,
		ItemScript.EquipmentSlot.RING
	]
	var slot = slots[randi() % slots.size()]

	# Générer le nom
	var possible_names = ITEM_NAMES[slot][rarity]
	var item_name = possible_names[randi() % possible_names.size()]

	# Créer l'objet et lui attribuer des statistiques
	var item: ItemScript = ItemScript.new(item_name, slot, item_ilvl, rarity)
	_apply_stats_to_item(item)
	return item

static func generate_loot_for_dungeon(dungeon_name: String, is_heroic: bool = false) -> Array[ItemScript]:
	"""Génère une table de loot pour un donjon spécifique"""
	var items: Array[ItemScript] = []
	
	# Obtenir les données du donjon pour l'iLvl de base
	var dungeon_data = DungeonData.DUNGEONS.get(dungeon_name, {})
	var base_ilvl = dungeon_data.get("equipment_reward_level", 10)
	
	# Générer 3-6 objets pour la table de loot du donjon
	var item_count: int = randi_range(3, 6)

	for i in range(item_count):
		var item: ItemScript = generate_item_for_level(base_ilvl, is_heroic)
		items.append(item)
	
	return items

static func get_boss_loot_chance(boss_index: int, total_bosses: int, is_heroic: bool = false) -> float:
	"""Retourne la chance qu'un boss drop du loot"""
	var base_chance: float = 0.3  # 30% de chance de base
	
	# Le dernier boss a plus de chance de dropper
	if boss_index == total_bosses - 1:
		base_chance = 0.8  # 80% pour le boss final
	
	# Bonus pour héroïque
	if is_heroic:
		base_chance += 0.2
	
	return min(1.0, base_chance)

static func _roll_rarity(is_heroic: bool = false) -> ItemScript.Rarity:
	"""Détermine la rareté d'un objet selon les chances"""
	var roll: int = randi() % 100
	var cumulative_chance: int = 0

	# Ajuster les chances pour héroïque
	var chances: Dictionary = RARITY_CHANCES.duplicate()
	if is_heroic:
		# Réduire les chances de commun, augmenter rare et épique
		chances[ItemScript.Rarity.COMMON] = 40
		chances[ItemScript.Rarity.UNCOMMON] = 35
		chances[ItemScript.Rarity.RARE] = 20
		chances[ItemScript.Rarity.EPIC] = 5
	
	# Rouler pour la rareté (dans l'ordre inverse pour commencer par épique)
	var rarities: Array = [
		ItemScript.Rarity.EPIC,
		ItemScript.Rarity.RARE, 
		ItemScript.Rarity.UNCOMMON,
		ItemScript.Rarity.COMMON
	]
	
	for rarity in rarities:
		cumulative_chance += chances[rarity]
		if roll < cumulative_chance:
			return rarity
	
	return ItemScript.Rarity.COMMON

static func _calculate_ilvl_for_level(level: int) -> int:
	"""Calcule l'iLvl de base selon le niveau (nouvelle balance)"""
	# Niveau 1-20: iLvl 1-15
	if level <= 20:
		return 1 + int(float(level - 1) / 19.0 * 14.0)
	# Niveau 21-40: iLvl 15-35
	elif level <= 40:
		return 15 + int(float(level - 20) / 20.0 * 20.0)
	# Niveau 41-50: iLvl 35-50
	elif level <= 50:
		return 35 + int(float(level - 40) / 10.0 * 15.0)
	# Niveau 51-60: iLvl 50-65
	elif level <= 60:
		return 50 + int(float(level - 50) / 10.0 * 15.0)
	# Niveau 60+: iLvl 65+
	else:
		return 65 + (level - 60)

static func get_recommended_ilvl_for_dungeon(dungeon_level: int, is_heroic: bool = false) -> int:
	"""Retourne l'iLvl recommandé pour un donjon"""
	var base_ilvl = _calculate_ilvl_for_level(dungeon_level)
	
	if is_heroic:
		return base_ilvl + 10
	
	return base_ilvl

static func create_starting_equipment() -> Array[ItemScript]:
	"""Crée l'équipement de départ basique"""
	var starter_items: Array[ItemScript] = [
		ItemScript.new("Casque de Novice", ItemScript.EquipmentSlot.HELMET, 1, ItemScript.Rarity.COMMON),
		ItemScript.new("Épée de Fer", ItemScript.EquipmentSlot.WEAPON, 2, ItemScript.Rarity.COMMON)
	]
	_apply_stats_to_item(starter_items[0], "strength")
	_apply_stats_to_item(starter_items[1], "strength")
	return starter_items

static func _apply_stats_to_item(item: ItemScript, preferred_primary: String = "") -> void:
	if not item:
		return
	var stats: Dictionary = _generate_stats_for_item(item.ilvl, item.slot, item.rarity, preferred_primary)
	item.strength = stats.get("strength", 0)
	item.agility = stats.get("agility", 0)
	item.intelligence = stats.get("intelligence", 0)

static func _generate_stats_for_item(item_ilvl: int, slot: ItemScript.EquipmentSlot, rarity: ItemScript.Rarity, preferred_primary: String = "") -> Dictionary:
	var stat_budget: int = max(1, int(round(float(item_ilvl) * SLOT_STAT_MULTIPLIERS.get(slot, 0.4))))
	stat_budget = max(1, int(round(float(stat_budget) * RARITY_STAT_MULTIPLIERS.get(rarity, 1.0))))

	var stats: Dictionary = {
		"strength": 0,
		"agility": 0,
		"intelligence": 0
	}

	var available_primary: Array = ["strength", "agility", "intelligence"]
	var primary_stat = preferred_primary if preferred_primary in available_primary else available_primary[randi() % available_primary.size()]

	var secondary_stats: Array = available_primary.duplicate()
	secondary_stats.erase(primary_stat)

	var primary_ratio: float = randf_range(0.6, 0.75)
	var primary_value: int = max(1, int(round(float(stat_budget) * primary_ratio)))
	primary_value = min(primary_value, stat_budget)
	stats[primary_stat] = primary_value

	var remaining: int = max(0, stat_budget - primary_value)
	if remaining > 0:
		var secondary_ratio: float = randf_range(0.4, 0.65)
		var first_secondary_value: int = int(round(float(remaining) * secondary_ratio))
		first_secondary_value = clamp(first_secondary_value, 0, remaining)
		var second_secondary_value: int = remaining - first_secondary_value
		stats[secondary_stats[0]] += first_secondary_value
		stats[secondary_stats[1]] += second_secondary_value

	var bonus_points = RARITY_FLAT_BONUS.get(rarity, 0)
	while bonus_points > 0:
		var bonus_target = available_primary[randi() % available_primary.size()]
		stats[bonus_target] += 1
		bonus_points -= 1

	return stats
