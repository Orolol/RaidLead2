extends Resource
class_name Item

enum EquipmentSlot {
	HELMET,
	SHOULDERS, 
	CHEST,
	WEAPON,
	RING
}

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC
}

@export var name: String = ""
@export var slot: EquipmentSlot
@export var ilvl: int = 1
@export var rarity: Rarity = Rarity.COMMON
@export var strength: int = 0
@export var agility: int = 0
@export var intelligence: int = 0

func _init(
	p_name: String = "",
	p_slot: EquipmentSlot = EquipmentSlot.HELMET,
	p_ilvl: int = 1,
	p_rarity: Rarity = Rarity.COMMON,
	p_strength: int = 0,
	p_agility: int = 0,
	p_intelligence: int = 0
) -> void:
	name = p_name
	slot = p_slot
	ilvl = p_ilvl
	rarity = p_rarity
	strength = p_strength
	agility = p_agility
	intelligence = p_intelligence

func get_slot_name() -> String:
	match slot:
		EquipmentSlot.HELMET: return "Casque"
		EquipmentSlot.SHOULDERS: return "Épaulières"
		EquipmentSlot.CHEST: return "Armure"
		EquipmentSlot.WEAPON: return "Arme"
		EquipmentSlot.RING: return "Anneau"
		_: return "Inconnu"

func get_rarity_name() -> String:
	match rarity:
		Rarity.COMMON: return "Commun"
		Rarity.UNCOMMON: return "Peu commun"
		Rarity.RARE: return "Rare"
		Rarity.EPIC: return "Épique"
		_: return "Inconnu"

func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON: return Color.WHITE
		Rarity.UNCOMMON: return Color.GREEN
		Rarity.RARE: return Color.BLUE
		Rarity.EPIC: return Color.PURPLE
		_: return Color.WHITE

func get_display_name() -> String:
	var base: String = "%s (%s, iLvl %d)" % [name, get_slot_name(), ilvl]
	var stat_summary: String = get_stat_summary()
	if stat_summary == "":
		return base
	return "%s - %s" % [base, stat_summary]

func get_stat_summary(show_zero: bool = false) -> String:
	var parts: Array[String] = []
	if show_zero or strength != 0:
		parts.append("FOR %+d" % strength)
	if show_zero or agility != 0:
		parts.append("AGI %+d" % agility)
	if show_zero or intelligence != 0:
		parts.append("INT %+d" % intelligence)
	return ", ".join(parts)

func get_stats() -> Dictionary:
	return {
		"strength": strength,
		"agility": agility,
		"intelligence": intelligence
	}

func has_stats() -> bool:
	return strength != 0 or agility != 0 or intelligence != 0
