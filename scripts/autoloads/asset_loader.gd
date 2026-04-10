extends Node

## Chargeur centralisé d'assets pixel art avec cache et fallback.

const ASSET_BASE := "res://assets/generated/"

var _cache: Dictionary = {}

# --- Lookup tables ---

var _class_portraits: Dictionary = {
	"Guerrier": "classes/guerrier.png",
	"Mage": "classes/mage.png",
	"Prêtre": "classes/pretre.png",
	"Voleur": "classes/voleur.png",
	"Chasseur": "classes/chasseur.png",
	"Druide": "classes/druide.png",
	"Démoniste": "classes/demoniste.png",
	"Paladin": "classes/paladin.png",
	"Chaman": "classes/chaman.png",
}

var _role_icons: Dictionary = {
	"Tank": "roles/tank.png",
	"Healer": "roles/healer.png",
	"DPS": "roles/dps.png",
}

var _stat_icons: Dictionary = {
	"Énergie": "stats/energy.png",
	"Humeur": "stats/mood.png",
	"Intégration": "stats/integration.png",
	"Skill": "stats/skill.png",
	"XP": "stats/xp.png",
	"iLvl": "stats/ilvl.png",
}

var _slot_icons: Dictionary = {
	0: "equipment/helmet.png",    # Item.Slot.HELMET
	1: "equipment/shoulders.png", # Item.Slot.SHOULDERS
	2: "equipment/chest.png",     # Item.Slot.CHEST
	3: "equipment/weapon.png",    # Item.Slot.WEAPON
	4: "equipment/ring.png",      # Item.Slot.RING
}

var _activity_icons: Dictionary = {
	0: "activities/leveling.png",  # Activity.Type.LEVELING
	1: "activities/farming.png",   # Activity.Type.FARMING
	2: "activities/fun.png",       # Activity.Type.FUN
	3: "activities/dungeon.png",   # Activity.Type.DUNGEON
	4: "activities/raid.png",      # Activity.Type.RAID
	5: "activities/offline.png",   # Activity.Type.OFFLINE
	6: "activities/none.png",      # Activity.Type.NONE
}

var _menu_icons: Dictionary = {
	"Personnage": "menu/personnage.png",
	"Guilde": "menu/guilde.png",
	"Monde": "menu/monde.png",
	"Organisation": "menu/organisation.png",
}

var _rarity_frames: Dictionary = {
	0: "equipment/frame_common.png",
	1: "equipment/frame_uncommon.png",
	2: "equipment/frame_rare.png",
	3: "equipment/frame_epic.png",
}

# --- Public API ---

func get_class_portrait(classe: String) -> Texture2D:
	var path: String = _class_portraits.get(classe, "")
	if path.is_empty():
		return null
	return _load_cached(ASSET_BASE + path)

func get_role_icon(role: String) -> Texture2D:
	var path: String = _role_icons.get(role, "")
	if path.is_empty():
		return null
	return _load_cached(ASSET_BASE + path)

func get_stat_icon(stat_name: String) -> Texture2D:
	var path: String = _stat_icons.get(stat_name, "")
	if path.is_empty():
		return null
	return _load_cached(ASSET_BASE + path)

func get_slot_icon(slot: int) -> Texture2D:
	var path: String = _slot_icons.get(slot, "")
	if path.is_empty():
		return null
	return _load_cached(ASSET_BASE + path)

func get_activity_icon(activity_type: int) -> Texture2D:
	var path: String = _activity_icons.get(activity_type, "")
	if path.is_empty():
		return null
	return _load_cached(ASSET_BASE + path)

func get_menu_icon(menu_name: String) -> Texture2D:
	var path: String = _menu_icons.get(menu_name, "")
	if path.is_empty():
		return null
	return _load_cached(ASSET_BASE + path)

func get_rarity_frame(rarity: int) -> Texture2D:
	var path: String = _rarity_frames.get(rarity, "")
	if path.is_empty():
		return null
	return _load_cached(ASSET_BASE + path)

func get_background() -> Texture2D:
	return _load_cached(ASSET_BASE + "backgrounds/bg_main.png")

func get_menu_bar_bg() -> Texture2D:
	return _load_cached(ASSET_BASE + "ui/menu_bar_bg.png")

func get_dungeon_banner(dungeon_id: String) -> Texture2D:
	var path := ASSET_BASE + "dungeons/" + dungeon_id + ".png"
	return _load_cached(path)

# --- Cache interne ---

func _load_cached(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		_cache[path] = null
		return null
	var tex: Texture2D = load(path)
	_cache[path] = tex
	return tex
