extends Resource
class_name Equipment

const ItemScript = preload("res://scripts/resources/item.gd")

const STAT_KEYS := ["strength", "agility", "intelligence"]
const STAT_LABELS := {
	"strength": "FOR",
	"agility": "AGI",
	"intelligence": "INT"
}

@export var helmet: ItemScript = null
@export var shoulders: ItemScript = null  
@export var chest: ItemScript = null
@export var weapon: ItemScript = null
@export var ring: ItemScript = null

func _init():
	helmet = null
	shoulders = null
	chest = null
	weapon = null
	ring = null

func equip_item(item: ItemScript) -> ItemScript:
	"""Équipe un objet et retourne l'ancien objet équipé (null si aucun)"""
	if not item:
		return null
		
	var old_item = null
	
	match item.slot:
		ItemScript.EquipmentSlot.HELMET:
			old_item = helmet
			helmet = item
		ItemScript.EquipmentSlot.SHOULDERS:
			old_item = shoulders
			shoulders = item
		ItemScript.EquipmentSlot.CHEST:
			old_item = chest
			chest = item
		ItemScript.EquipmentSlot.WEAPON:
			old_item = weapon
			weapon = item
		ItemScript.EquipmentSlot.RING:
			old_item = ring
			ring = item
	
	return old_item

func get_item_in_slot(slot: ItemScript.EquipmentSlot) -> ItemScript:
	"""Retourne l'objet équipé dans un slot spécifique"""
	match slot:
		ItemScript.EquipmentSlot.HELMET: return helmet
		ItemScript.EquipmentSlot.SHOULDERS: return shoulders
		ItemScript.EquipmentSlot.CHEST: return chest
		ItemScript.EquipmentSlot.WEAPON: return weapon
		ItemScript.EquipmentSlot.RING: return ring
		_: return null

func remove_item(slot: ItemScript.EquipmentSlot) -> ItemScript:
	"""Retire un objet d'un slot et le retourne"""
	var item = get_item_in_slot(slot)
	
	match slot:
		ItemScript.EquipmentSlot.HELMET: helmet = null
		ItemScript.EquipmentSlot.SHOULDERS: shoulders = null
		ItemScript.EquipmentSlot.CHEST: chest = null
		ItemScript.EquipmentSlot.WEAPON: weapon = null
		ItemScript.EquipmentSlot.RING: ring = null
	
	return item

func get_total_ilvl() -> int:
	"""Calcule l'iLvl total de tout l'équipement"""
	var total = 0
	
	if helmet: total += helmet.ilvl
	if shoulders: total += shoulders.ilvl
	if chest: total += chest.ilvl
	if weapon: total += weapon.ilvl
	if ring: total += ring.ilvl
	
	return total

func get_equipped_items() -> Array[ItemScript]:
	"""Retourne tous les objets équipés"""
	var items: Array[ItemScript] = []
	
	if helmet: items.append(helmet)
	if shoulders: items.append(shoulders)
	if chest: items.append(chest)
	if weapon: items.append(weapon)
	if ring: items.append(ring)
	
	return items

func get_slot_count() -> int:
	"""Retourne le nombre de slots équipés"""
	var count = 0
	
	if helmet: count += 1
	if shoulders: count += 1
	if chest: count += 1
	if weapon: count += 1
	if ring: count += 1
	
	return count

func get_average_ilvl() -> float:
	"""Retourne l'iLvl moyen des objets équipés"""
	var equipped_count = get_slot_count()
	if equipped_count == 0:
		return 0.0
	return float(get_total_ilvl()) / float(equipped_count)

func is_slot_equipped(slot: ItemScript.EquipmentSlot) -> bool:
	"""Vérifie si un slot est équipé"""
	return get_item_in_slot(slot) != null

func get_equipment_summary() -> String:
	"""Retourne un résumé de l'équipement"""
	var stat_summary = get_stats_summary()
	var base_summary = "iLvl Total: %d (Moy: %.1f) - %d/%d slots" % [
		get_total_ilvl(),
		get_average_ilvl(), 
		get_slot_count(),
		5
	]
	if stat_summary == "":
		return base_summary
	return "%s | %s" % [base_summary, stat_summary]

func get_total_stats() -> Dictionary:
	"""Retourne la somme des statistiques de l'équipement"""
	var totals = {
		"strength": 0,
		"agility": 0,
		"intelligence": 0
	}
	for item in get_equipped_items():
		if not item:
			continue
		totals["strength"] += item.strength
		totals["agility"] += item.agility
		totals["intelligence"] += item.intelligence
	return totals

func get_stat_total(stat_name: String) -> int:
	"""Retourne la valeur totale d'une statistique donnée"""
	var totals = get_total_stats()
	return totals.get(stat_name, 0)

func get_stats_summary() -> String:
	"""Retourne un résumé formaté des statistiques cumulées"""
	var totals = get_total_stats()
	var parts: Array[String] = []
	for key in STAT_KEYS:
		var value = totals.get(key, 0)
		if value != 0:
			parts.append("%s %d" % [STAT_LABELS.get(key, key), value])
	return " / ".join(parts)
