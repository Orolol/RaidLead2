extends Node

signal version_updated(new_version: float, update_name: String)
signal content_unlocked(content_type: String, content_ids: Array)

# Configuration des mises à jour serveur
const VERSION_DATA = {
	1.0: {
		"name": "Launch",
		"description": "Lancement du serveur",
		"days_to_unlock": 0,
		"max_player_level": 40,
		"max_guild_count": 5,
		"recruitment_pool_size": 15,
		"available_dungeons": ["ragefire_chasm", "deadmines", "wailing_caverns", "gnomeregan"],
		"available_raids": [],
		"features": ["basic_guild_management", "dungeon_running", "recruitment"]
	},
	1.1: {
		"name": "First Expansion",
		"description": "Premiers donjons de haut niveau",
		"days_to_unlock": 15,
		"max_player_level": 50,
		"max_guild_count": 7,
		"recruitment_pool_size": 20,
		"available_dungeons": ["ragefire_chasm", "deadmines", "wailing_caverns", "gnomeregan", "scarlet_monastery", "uldaman"],
		"available_raids": [],
		"features": ["basic_guild_management", "dungeon_running", "recruitment", "advanced_dungeons"]
	},
	1.2: {
		"name": "End Game Content",
		"description": "Contenu de fin de jeu",
		"days_to_unlock": 30,
		"max_player_level": 60,
		"max_guild_count": 10,
		"recruitment_pool_size": 25,
		"available_dungeons": ["ragefire_chasm", "deadmines", "wailing_caverns", "gnomeregan", "scarlet_monastery", "uldaman", "zul_farrak", "blackrock_depths"],
		"available_raids": ["molten_core", "onyxias_lair"],
		"features": ["basic_guild_management", "dungeon_running", "recruitment", "advanced_dungeons", "raid_content"]
	},
	1.3: {
		"name": "High End Dungeons",
		"description": "Donjons de très haut niveau",
		"days_to_unlock": 45,
		"max_player_level": 60,
		"max_guild_count": 12,
		"recruitment_pool_size": 30,
		"available_dungeons": ["ragefire_chasm", "deadmines", "wailing_caverns", "gnomeregan", "scarlet_monastery", "uldaman", "zul_farrak", "blackrock_depths", "stratholme", "scholomance"],
		"available_raids": ["molten_core", "onyxias_lair"],
		"features": ["basic_guild_management", "dungeon_running", "recruitment", "advanced_dungeons", "raid_content", "elite_dungeons"]
	},
	1.4: {
		"name": "Raid Progression",
		"description": "Progression des raids",
		"days_to_unlock": 60,
		"max_player_level": 60,
		"max_guild_count": 15,
		"recruitment_pool_size": 30,
		"available_dungeons": ["ragefire_chasm", "deadmines", "wailing_caverns", "gnomeregan", "scarlet_monastery", "uldaman", "zul_farrak", "blackrock_depths", "stratholme", "scholomance"],
		"available_raids": ["molten_core", "onyxias_lair", "blackwing_lair", "zul_gurub"],
		"features": ["basic_guild_management", "dungeon_running", "recruitment", "advanced_dungeons", "raid_content", "elite_dungeons", "full_raid_progression"]
	}
}

# État actuel du serveur
var current_version: float = 1.0
var server_start_date: Dictionary = {}
var days_since_launch: int = 0

func _ready() -> void:
	# Se connecter au signal de changement de jour de GameTime
	if GameTime:
		GameTime.day_changed.connect(_on_day_changed)

	# Initialiser la date de lancement du serveur
	_initialize_server_launch_date()

	# Vérifier la version actuelle
	_check_version_update()

func _initialize_server_launch_date() -> void:
	"""Initialise la date de lancement du serveur avec la date actuelle de GameTime"""
	if GameTime:
		server_start_date = {
			"day": GameTime.current_day,
			"week": GameTime.current_week,
			"year": GameTime.current_year
		}
		days_since_launch = 0

func _on_day_changed(_day: int, _week: int, _year: int) -> void:
	"""Appelé à chaque changement de jour pour calculer la progression"""
	_calculate_days_since_launch()
	_check_version_update()

func _calculate_days_since_launch() -> void:
	"""Calcule le nombre de jours écoulés depuis le lancement du serveur"""
	if not GameTime:
		return

	var current_total_days: int = _get_total_days(GameTime.current_day, GameTime.current_week, GameTime.current_year)
	var launch_total_days: int = _get_total_days(server_start_date.day, server_start_date.week, server_start_date.year)

	days_since_launch = current_total_days - launch_total_days

func _get_total_days(day: int, week: int, year: int) -> int:
	"""Convertit une date en nombre total de jours depuis l'année 1"""
	return (year - 1) * GameTime.WEEKS_PER_YEAR * GameTime.DAYS_PER_WEEK + (week - 1) * GameTime.DAYS_PER_WEEK + (day - 1)

func _check_version_update() -> void:
	"""Vérifie si une mise à jour de version doit être déclenchée"""
	var target_version: float = _get_target_version_for_days(days_since_launch)

	if target_version > current_version:
		var old_version: float = current_version
		current_version = target_version

		var version_info: Dictionary = VERSION_DATA[current_version]
		version_updated.emit(current_version, version_info.name)

		# Émettre les signaux de contenu débloqué
		_emit_content_unlocked_signals(old_version, current_version)

		GameLog.d("Serveur mis à jour vers la version %s: %s" % [current_version, version_info.name])

func _get_target_version_for_days(days: int) -> float:
	"""Retourne la version du serveur correspondant au nombre de jours écoulés"""
	var target_version: float = 1.0

	for version in VERSION_DATA:
		var version_info: Dictionary = VERSION_DATA[version]
		if days >= version_info.days_to_unlock:
			target_version = version

	return target_version

func _emit_content_unlocked_signals(old_version: float, new_version: float) -> void:
	"""Émet les signaux pour le nouveau contenu débloqué"""
	var old_data: Dictionary = VERSION_DATA.get(old_version, {})
	var new_data: Dictionary = VERSION_DATA[new_version]

	# Nouveaux donjons
	var old_dungeons: Array = old_data.get("available_dungeons", [])
	var new_dungeons: Array = new_data.get("available_dungeons", [])
	var unlocked_dungeons: Array = []
	for dungeon in new_dungeons:
		if not dungeon in old_dungeons:
			unlocked_dungeons.append(dungeon)

	if unlocked_dungeons.size() > 0:
		content_unlocked.emit("dungeons", unlocked_dungeons)

	# Nouveaux raids
	var old_raids: Array = old_data.get("available_raids", [])
	var new_raids: Array = new_data.get("available_raids", [])
	var unlocked_raids: Array = []
	for raid in new_raids:
		if not raid in old_raids:
			unlocked_raids.append(raid)

	if unlocked_raids.size() > 0:
		content_unlocked.emit("raids", unlocked_raids)

# Fonctions publiques pour interroger l'état du serveur

func get_current_version() -> float:
	"""Retourne la version actuelle du serveur"""
	return current_version

func get_current_version_info() -> Dictionary:
	"""Retourne les informations de la version actuelle"""
	return VERSION_DATA.get(current_version, {})

func get_max_player_level() -> int:
	"""Retourne le niveau maximum des joueurs pour la version actuelle"""
	return get_current_version_info().get("max_player_level", 1)

func get_max_guild_count() -> int:
	"""Retourne le nombre maximum de guildes pour la version actuelle"""
	return get_current_version_info().get("max_guild_count", 1)

func get_recruitment_pool_size() -> int:
	"""Retourne la taille du pool de recrutement pour la version actuelle"""
	return get_current_version_info().get("recruitment_pool_size", 10)

func get_available_dungeons() -> Array:
	"""Retourne la liste des donjons disponibles"""
	return get_current_version_info().get("available_dungeons", [])

func get_available_raids() -> Array:
	"""Retourne la liste des raids disponibles"""
	return get_current_version_info().get("available_raids", [])

func is_feature_available(feature: String) -> bool:
	"""Vérifie si une fonctionnalité est disponible dans la version actuelle"""
	var features: Array = get_current_version_info().get("features", [])
	return feature in features

func is_instance_available(instance_id: String) -> bool:
	"""Vérifie si un donjon/raid est disponible dans la version actuelle"""
	return instance_id in get_available_dungeons() or instance_id in get_available_raids()

func get_days_until_next_version() -> int:
	"""Retourne le nombre de jours avant la prochaine mise à jour (-1 si aucune)"""
	var next_version = null
	var next_days: int = -1

	for version in VERSION_DATA:
		var version_info: Dictionary = VERSION_DATA[version]
		if version > current_version:
			if next_version == null or version < next_version:
				next_version = version
				next_days = version_info.days_to_unlock
	
	if next_days == -1:
		return -1
	
	return max(0, next_days - days_since_launch)

func get_next_version_info() -> Dictionary:
	"""Retourne les informations de la prochaine version (ou vide si aucune)"""
	var next_version = null
	
	for version in VERSION_DATA:
		if version > current_version:
			if next_version == null or version < next_version:
				next_version = version
	
	if next_version == null:
		return {}
	
	return VERSION_DATA[next_version]

# Fonctions de sauvegarde/chargement

func save_server_data() -> Dictionary:
	"""Sauvegarde l'état du serveur"""
	return {
		"current_version": current_version,
		"server_start_date": server_start_date,
		"days_since_launch": days_since_launch
	}

func load_server_data(data: Dictionary) -> void:
	"""Charge l'état du serveur"""
	current_version = data.get("current_version", 1.0)
	server_start_date = data.get("server_start_date", {})
	days_since_launch = data.get("days_since_launch", 0)
	
	# Si pas de date de lancement sauvegardée, l'initialiser
	if server_start_date.is_empty():
		_initialize_server_launch_date()

# Fonctions utilitaires pour le debug

func force_version_update(target_version: float) -> void:
	"""Force une mise à jour vers une version spécifique (debug uniquement)"""
	if target_version in VERSION_DATA and target_version != current_version:
		var old_version: float = current_version
		current_version = target_version

		var version_info: Dictionary = VERSION_DATA[current_version]
		version_updated.emit(current_version, version_info.name)
		_emit_content_unlocked_signals(old_version, current_version)

		GameLog.d("Version forcée vers %s: %s" % [current_version, version_info.name])

func get_all_versions() -> Array:
	"""Retourne toutes les versions disponibles (debug)"""
	var versions: Array = VERSION_DATA.keys()
	versions.sort()
	return versions
