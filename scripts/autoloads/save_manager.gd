extends Node

## SaveManager — Coordonne la sauvegarde et le chargement de toute la progression.
## Sauvegarde en JSON dans user://savegame.json.

const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 1

signal save_completed(success: bool)
signal load_completed(success: bool)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()

func save_game() -> bool:
	"""Sauvegarde l'ensemble de la progression dans un fichier JSON."""
	var data: Dictionary = {
		"save_version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"game_time": GameTime.save_time_data(),
		"server_version": ServerVersion.save_server_data(),
		"phase": PhaseManager.save_phase_data(),
		"ranking": GuildRanking.save_ranking_data(),
		"ai_guilds": AIGuildManager.save_ai_guilds_data(),
		"guild": _serialize_guild(),
		"members": _serialize_members(),
		"loot_history": _serialize_loot_history(),
		"media": MediaManager.serialize(),
		"sponsors": SponsorshipManager.serialize(),
		"dramas": DramaManager.serialize(),
	}

	var json_string: String = JSON.stringify(data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("SaveManager: impossible d'ouvrir %s en écriture" % SAVE_PATH)
		save_completed.emit(false)
		return false

	file.store_string(json_string)
	file.close()
	print("SaveManager: sauvegarde réussie (%d octets)" % json_string.length())
	save_completed.emit(true)
	return true

func load_game() -> bool:
	"""Charge la progression depuis le fichier JSON."""
	if not FileAccess.file_exists(SAVE_PATH):
		print("SaveManager: pas de sauvegarde trouvée, nouvelle partie")
		load_completed.emit(false)
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("SaveManager: impossible d'ouvrir %s en lecture" % SAVE_PATH)
		load_completed.emit(false)
		return false

	var json_string: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var error: int = json.parse(json_string)
	if error != OK:
		push_error("SaveManager: erreur de parsing JSON ligne %d" % json.get_error_line())
		load_completed.emit(false)
		return false

	var data: Dictionary = json.data
	if not data.has("save_version"):
		push_error("SaveManager: format de sauvegarde invalide")
		load_completed.emit(false)
		return false

	# Charger chaque système
	if data.has("game_time"):
		GameTime.load_time_data(data.game_time)
	if data.has("server_version"):
		ServerVersion.load_server_data(data.server_version)
	if data.has("phase"):
		PhaseManager.load_phase_data(data.phase)
	if data.has("ranking"):
		GuildRanking.load_ranking_data(data.ranking)
	if data.has("ai_guilds"):
		AIGuildManager.load_ai_guilds_data(data.ai_guilds)
	if data.has("guild"):
		_deserialize_guild(data.guild)
	if data.has("members"):
		_deserialize_members(data.members)
	if data.has("loot_history"):
		_deserialize_loot_history(data.loot_history)
	# Systemes National (apres les membres car ils y font reference)
	if data.has("media"):
		MediaManager.deserialize(data.media)
	if data.has("sponsors"):
		SponsorshipManager.deserialize(data.sponsors)
	if data.has("dramas"):
		DramaManager.deserialize(data.dramas)

	print("SaveManager: chargement réussi (version %d)" % data.save_version)
	load_completed.emit(true)
	return true

func has_save() -> bool:
	"""Vérifie si une sauvegarde existe."""
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	"""Supprime la sauvegarde."""
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		print("SaveManager: sauvegarde supprimée")

# --- Sérialisation Guild ---

func _serialize_guild() -> Dictionary:
	var g: Guild = GuildManager.guild
	if not g:
		return {}
	return {
		"name": g.name,
		"xp": g.xp,
		"gold": g.gold,
		"reputation": g.reputation,
		"reputation_history": g.reputation_history,
	}

func _deserialize_guild(data: Dictionary) -> void:
	var g: Guild = GuildManager.guild
	if not g:
		return
	g.name = data.get("name", "Ma Guilde")
	g.xp = data.get("xp", 0)
	g.gold = data.get("gold", 0)
	g.reputation = data.get("reputation", 50.0)
	g.reputation_history = data.get("reputation_history", [])

# --- Sérialisation Membres ---

func _serialize_members() -> Array:
	var members_data: Array = []
	for member in GuildManager.guild_members:
		members_data.append(_serialize_player(member))
	return members_data

func _deserialize_members(data: Array) -> void:
	# Supprimer les membres existants
	GuildManager.guild_members.clear()

	for member_data in data:
		var is_player: bool = member_data.get("is_player", false)
		var member: SimulatedPlayer
		if is_player:
			var PlayerCharacterScript = load("res://scripts/resources/player_character.gd")
			member = PlayerCharacterScript.new()
			_deserialize_player_character(member, member_data)
			member.set_meta("is_player", true)
			GuildManager.player_character = member
		else:
			member = SimulatedPlayer.new()

		_deserialize_player(member, member_data)
		GuildManager.guild_members.append(member)

func _serialize_player(player: SimulatedPlayer) -> Dictionary:
	var data: Dictionary = {
		"nom": player.nom,
		"is_player": player.get_meta("is_player", false),
		"personnage_classe": player.personnage_classe,
		"personnage_role": player.personnage_role,
		"personnage_niveau": player.personnage_niveau,
		"personnage_xp": player.personnage_xp,
		"or_actuel": player.or_actuel,
		"skill": player.skill,
		"energy": player.energy,
		"mood": player.mood,
		"integration": player.integration,
		"days_in_guild": player.days_in_guild,
		"raid_successes": player.raid_successes,
		"wipes_experienced": player.wipes_experienced,
		"loot_conflicts": player.loot_conflicts,
		"activities_completed": player.activities_completed,
		"tags_comportement": player.tags_comportement,
		"tags_caches": player.tags_caches,
		"planning": player.planning,
		"is_online": player.is_online,
		"connaissance_donjons": player.connaissance_donjons,
		"connaissance_raids": player.connaissance_raids,
		"fatigue_accumulated": player.fatigue_accumulated,
		"burnout_level": player.burnout_level,
		"circadian_type": player.circadian_type,
		"activity_preferences": player.activity_preferences,
		"last_raid_success_day": player.last_raid_success_day,
		"last_epic_loot_day": player.last_epic_loot_day,
		"last_wipe_day": player.last_wipe_day,
		"equipment": _serialize_equipment(player.equipment),
	}

	# Propriétés PlayerCharacter
	if player.get_meta("is_player", false) and player.has_method("get"):
		var pc = player
		data["player_energy_pool"] = pc.get("player_energy_pool") if pc.get("player_energy_pool") != null else 100.0
		data["max_energy_pool"] = pc.get("max_energy_pool") if pc.get("max_energy_pool") != null else 100.0
		data["session_xp_gained"] = pc.get("session_xp_gained") if pc.get("session_xp_gained") != null else 0
		data["session_gold_gained"] = pc.get("session_gold_gained") if pc.get("session_gold_gained") != null else 0

	return data

func _deserialize_player(player: SimulatedPlayer, data: Dictionary) -> void:
	player.nom = data.get("nom", "")
	player.personnage_classe = data.get("personnage_classe", "")
	player.personnage_role = data.get("personnage_role", "")
	player.personnage_niveau = data.get("personnage_niveau", 1)
	player.personnage_xp = data.get("personnage_xp", 0)
	player.or_actuel = data.get("or_actuel", 0)
	player.skill = data.get("skill", 50)
	player.energy = data.get("energy", 100.0)
	player.mood = data.get("mood", 75.0)
	player.integration = data.get("integration", 0.0)
	player.days_in_guild = data.get("days_in_guild", 0)
	player.raid_successes = data.get("raid_successes", 0)
	player.wipes_experienced = data.get("wipes_experienced", 0)
	player.loot_conflicts = data.get("loot_conflicts", 0)
	player.activities_completed = data.get("activities_completed", 0)
	player.tags_comportement = data.get("tags_comportement", [])
	player.tags_caches = data.get("tags_caches", [])
	player.planning = data.get("planning", {})
	player.is_online = data.get("is_online", false)
	player.connaissance_donjons = data.get("connaissance_donjons", {})
	player.connaissance_raids = data.get("connaissance_raids", {})
	player.fatigue_accumulated = data.get("fatigue_accumulated", 0.0)
	player.burnout_level = data.get("burnout_level", 0)
	player.circadian_type = data.get("circadian_type", "flexible")
	player.activity_preferences = data.get("activity_preferences", {})
	player.last_raid_success_day = data.get("last_raid_success_day", -1)
	player.last_epic_loot_day = data.get("last_epic_loot_day", -1)
	player.last_wipe_day = data.get("last_wipe_day", -1)

	# Équipement
	if data.has("equipment"):
		player.equipment = _deserialize_equipment(data.equipment)

func _deserialize_player_character(player, data: Dictionary) -> void:
	"""Charge les propriétés spécifiques au PlayerCharacter."""
	player.player_energy_pool = data.get("player_energy_pool", 100.0)
	player.max_energy_pool = data.get("max_energy_pool", 100.0)
	player.session_xp_gained = data.get("session_xp_gained", 0)
	player.session_gold_gained = data.get("session_gold_gained", 0)
	player.is_player_controlled = true
	player.manual_control_enabled = true

# --- Sérialisation Equipment ---

func _serialize_equipment(eq: Equipment) -> Dictionary:
	if not eq:
		return {}
	var data: Dictionary = {}
	for slot_name in ["helmet", "shoulders", "chest", "weapon", "ring"]:
		var item: Item = eq.get(slot_name)
		if item:
			data[slot_name] = _serialize_item(item)
	return data

func _deserialize_equipment(data: Dictionary) -> Equipment:
	var eq := Equipment.new()
	for slot_name in ["helmet", "shoulders", "chest", "weapon", "ring"]:
		if data.has(slot_name) and data[slot_name] is Dictionary:
			var item: Item = _deserialize_item(data[slot_name])
			eq.set(slot_name, item)
	return eq

func _serialize_item(item: Item) -> Dictionary:
	return {
		"name": item.name,
		"slot": item.slot,
		"ilvl": item.ilvl,
		"rarity": item.rarity,
		"strength": item.strength,
		"agility": item.agility,
		"intelligence": item.intelligence,
	}

func _deserialize_item(data: Dictionary) -> Item:
	return Item.new(
		data.get("name", ""),
		data.get("slot", 0),
		data.get("ilvl", 1),
		data.get("rarity", 0),
		data.get("strength", 0),
		data.get("agility", 0),
		data.get("intelligence", 0),
	)

# --- Sérialisation Loot History ---

func _serialize_loot_history() -> Array:
	var entries: Array = []
	for entry in GuildManager.loot_history:
		var serialized: Dictionary = {
			"member_name": entry.get("member_name", ""),
			"dungeon_name": entry.get("dungeon_name", ""),
			"boss_name": entry.get("boss_name", ""),
			"timestamp": entry.get("timestamp", {}),
		}
		var item = entry.get("item", null)
		if item:
			serialized["item"] = _serialize_item(item)
		entries.append(serialized)
	return entries

func _deserialize_loot_history(data: Array) -> void:
	GuildManager.loot_history.clear()
	for entry_data in data:
		var entry: Dictionary = {
			"member_name": entry_data.get("member_name", ""),
			"dungeon_name": entry_data.get("dungeon_name", ""),
			"boss_name": entry_data.get("boss_name", ""),
			"timestamp": entry_data.get("timestamp", {}),
		}
		if entry_data.has("item") and entry_data.item is Dictionary:
			entry["item"] = _deserialize_item(entry_data.item)
		GuildManager.loot_history.append(entry)
