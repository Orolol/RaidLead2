extends Node

# Système de classement des guildes
# Gère la compétition entre la guilde du joueur et les guildes IA

const AIGuild = preload("res://scripts/resources/ai_guild.gd")
const DungeonDataScript = preload("res://scripts/data/dungeon_data.gd")

signal ranking_updated(rankings: Array)
signal guild_position_changed(guild_name: String, old_position: int, new_position: int)
signal new_server_first(guild_name: String, achievement_name: String)

# Types de scores pour le classement
enum ScoreType {
	OVERALL,        # Score global
	PVE_PROGRESS,   # Progression PvE
	GUILD_LEVEL,    # Niveau de guilde
	MEMBER_COUNT,   # Nombre de membres actifs
	REPUTATION      # Réputation
}

# Classements par phase
var server_rankings: Array = []
var national_rankings: Array = []  # Pour Phase 2
var world_rankings: Array = []     # Pour Phase 3

# Historique des positions
var ranking_history: Dictionary = {}
var last_ranking_update: Dictionary = {}

# Configuration du système de scores
const SCORE_WEIGHTS = {
	"pve_progress": 0.4,      # 40% - Progression dans les donjons/raids
	"guild_level": 0.2,       # 20% - Niveau de la guilde
	"member_activity": 0.15,  # 15% - Activité des membres
	"reputation": 0.15,       # 15% - Réputation de la guilde
	"stability": 0.1          # 10% - Stabilité de l'équipe (faible turnover)
}

# Données des achievements de contenu
var content_achievements: Dictionary = {}
var server_firsts: Dictionary = {}  # Qui a fait le premier clear de chaque contenu
var player_cleared_content: Dictionary = {}
var player_recent_clears: Array = []

func _ready():
	# Se connecter aux signaux nécessaires
	if GuildManager:
		GuildManager.connect("member_recruited", _on_member_recruited)
		GuildManager.connect("guild_level_changed", _on_guild_level_changed)
		
	if ActivityManager:
		ActivityManager.connect("activity_completed", _on_activity_completed)
		
	if GameTime:
		GameTime.connect("week_changed", _on_week_changed)
		
	# Se connecter au PhaseManager s'il existe
	if PhaseManager:
		PhaseManager.connect("phase_changed", _on_phase_changed)
	
	# Se connecter au AIGuildManager
	if AIGuildManager:
		AIGuildManager.connect("monthly_simulation_completed", _on_ai_simulation_completed)
		AIGuildManager.connect("ai_guild_created", _on_ai_guild_created)
	
	# Initialiser les rankings
	_initialize_rankings()
	
	print("GuildRanking initialisé")

func _initialize_rankings():
	"""Initialise les systèmes de classement"""
	# Les guildes IA seront ajoutées par le système IA
	ranking_history = {}
	last_ranking_update = _get_current_date()
	
	# Initialiser l'historique pour la guilde du joueur
	if GuildManager and GuildManager.guild:
		ranking_history[GuildManager.guild.name] = []

func register_guild(guild_name: String, is_player_guild: bool = false):
	"""Enregistre une guilde dans le système de classement"""
	if not ranking_history.has(guild_name):
		ranking_history[guild_name] = []
		
	print("Guilde enregistrée dans le classement: %s" % guild_name)

func calculate_guild_score(guild_name: String, guild_data: Dictionary) -> float:
	"""Calcule le score d'une guilde pour le classement"""
	var score = 0.0
	
	# Score de progression PvE
	var pve_score = _calculate_pve_score(guild_name, guild_data)
	score += pve_score * SCORE_WEIGHTS["pve_progress"]
	
	# Score de niveau de guilde
	var level_score = _calculate_level_score(guild_data)
	score += level_score * SCORE_WEIGHTS["guild_level"]
	
	# Score d'activité des membres
	var activity_score = _calculate_activity_score(guild_data)
	score += activity_score * SCORE_WEIGHTS["member_activity"]
	
	# Score de réputation
	var reputation_score = _calculate_reputation_score(guild_name, guild_data)
	score += reputation_score * SCORE_WEIGHTS["reputation"]
	
	# Score de stabilité
	var stability_score = _calculate_stability_score(guild_data)
	score += stability_score * SCORE_WEIGHTS["stability"]
	
	return score

func _calculate_pve_score(guild_name: String, guild_data: Dictionary) -> float:
	"""Calcule le score de progression PvE"""
	var score = 0.0
	
	# Server firsts (bonus majeur)
	for content_id in server_firsts:
		if server_firsts[content_id] == guild_name:
			if _is_raid_content(content_id):
				score += 500.0  # Gros bonus pour les raids
			else:
				score += 200.0  # Bonus moindre pour les donjons
	
	# Contenu cleared
	var cleared_content = guild_data.get("cleared_content", [])
	for content_id in cleared_content:
		if _is_raid_content(content_id):
			score += 100.0
		else:
			score += 40.0
	
	# Progression récente (boost temporaire)
	var recent_clears = guild_data.get("recent_clears", [])
	score += recent_clears.size() * 50.0
	
	return score

func _calculate_level_score(guild_data: Dictionary) -> float:
	"""Calcule le score basé sur le niveau de guilde"""
	var guild_level = guild_data.get("guild_level", 1)
	return guild_level * 20.0  # 20 points par niveau

func _calculate_activity_score(guild_data: Dictionary) -> float:
	"""Calcule le score d'activité des membres"""
	var active_members = guild_data.get("active_members_count", 0)
	var total_members = guild_data.get("total_members_count", 1)
	var activity_ratio = float(active_members) / float(total_members)
	
	return activity_ratio * 300.0 + active_members * 10.0

func _calculate_reputation_score(guild_name: String, guild_data: Dictionary) -> float:
	"""Calcule le score de réputation"""
	var reputation = guild_data.get("reputation", 50.0)
	
	# Bonus/malus selon la réputation
	var base_score = (reputation - 50.0) * 4.0  # -200 à +200
	
	# Bonus pour événements spéciaux
	var special_events = guild_data.get("special_achievements", [])
	base_score += special_events.size() * 30.0
	
	return max(0.0, base_score)

func _calculate_stability_score(guild_data: Dictionary) -> float:
	"""Calcule le score de stabilité de l'équipe"""
	var turnover_rate = guild_data.get("monthly_turnover", 0.2)  # Taux de rotation mensuel
	var stability = 1.0 - turnover_rate
	
	return stability * 150.0

func update_rankings():
	"""Met à jour les classements de toutes les guildes"""
	var current_phase = PhaseManager.get_current_phase() if PhaseManager else PhaseManager.GamePhase.SERVEUR
	
	match current_phase:
		PhaseManager.GamePhase.LEVELING, PhaseManager.GamePhase.SERVEUR:
			# Le classement serveur est calculé dès la phase Leveling pour rester
			# cohérent avec la fenêtre Monde et alimenter get_player_guild_position().
			_update_server_rankings()
		PhaseManager.GamePhase.NATIONAL:
			_update_national_rankings()
		PhaseManager.GamePhase.ESPORT:
			_update_world_rankings()

func _update_server_rankings():
	"""Met à jour le classement serveur"""
	var guilds_data = []
	
	# Ajouter la guilde du joueur
	if GuildManager and GuildManager.guild:
		var player_guild_data = _get_player_guild_data()
		player_guild_data["is_player"] = true
		guilds_data.append(player_guild_data)
	
	# Ajouter les guildes IA
	if AIGuildManager:
		var ai_guilds = AIGuildManager.get_all_guilds()
		for ai_guild in ai_guilds:
			var ai_guild_data = ai_guild.get_guild_data_for_ranking()
			ai_guild_data["is_player"] = false
			guilds_data.append(ai_guild_data)
	
	# Calculer les scores et trier
	for guild_data in guilds_data:
		guild_data["score"] = calculate_guild_score(guild_data["name"], guild_data)
	
	# Trier par score décroissant
	guilds_data.sort_custom(func(a, b): return a["score"] > b["score"])
	
	# Assigner les positions
	for i in range(guilds_data.size()):
		guilds_data[i]["position"] = i + 1
		guilds_data[i]["rank_change"] = _calculate_rank_change(guilds_data[i]["name"], i + 1)
	
	# Mettre à jour l'historique
	_update_ranking_history(guilds_data)
	
	var old_server_rankings = server_rankings.duplicate()
	server_rankings = guilds_data
	
	# Émettre le signal de mise à jour
	ranking_updated.emit(server_rankings)
	
	# Vérifier les changements de position
	_check_position_changes(old_server_rankings, server_rankings)
	
	last_ranking_update = _get_current_date()
	print("Classement serveur mis à jour - %d guildes" % server_rankings.size())

func _update_national_rankings():
	"""Met à jour le classement national (Phase 2)"""
	# TODO: Implémenter pour Phase 2
	pass

func _update_world_rankings():
	"""Met à jour le classement mondial (Phase 3)"""
	# TODO: Implémenter pour Phase 3
	pass

func _get_player_guild_data() -> Dictionary:
	"""Récupère les données de la guilde du joueur pour le classement"""
	if not GuildManager or not GuildManager.guild:
		return {}
	
	var guild = GuildManager.guild
	var members = GuildManager.guild_members
	
	# Calculer les données nécessaires
	var active_members = GuildManager.get_online_members().size()
	var total_members = members.size()
	
	var cleared_content = _get_player_guild_cleared_content()
	var recent_clears = _get_recent_clears("player_guild")
	
	# Calculer le taux de rotation (simplified)
	var turnover = _calculate_turnover_rate(members)
	
	return {
		"name": guild.name,
		"guild_level": guild.get_level(),
		"active_members_count": active_members,
		"total_members_count": total_members,
		"cleared_content": cleared_content,
		"recent_clears": recent_clears,
		"reputation": guild.reputation,
		"monthly_turnover": turnover,
		"special_achievements": []
	}

func _get_player_guild_cleared_content() -> Array:
	"""Retourne le contenu cleared par la guilde du joueur"""
	return get_player_cleared_content()

func _get_recent_clears(guild_name: String) -> Array:
	"""Retourne les clears récents d'une guilde (7 derniers jours)"""
	if guild_name == "player_guild" or (GuildManager and GuildManager.guild and guild_name == GuildManager.guild.name):
		return get_player_recent_clears()
	return []

func _calculate_turnover_rate(members: Array) -> float:
	"""Calcule le taux de rotation des membres"""
	# Simplified - basé sur l'intégration moyenne
	if members.size() == 0:
		return 0.0
	
	var low_integration_count = 0
	for member in members:
		if member.integration < 30.0:
			low_integration_count += 1
	
	return float(low_integration_count) / float(members.size()) * 0.3

func _calculate_rank_change(guild_name: String, new_position: int) -> int:
	"""Calcule le changement de position depuis le dernier ranking"""
	var history = ranking_history.get(guild_name, [])
	if history.size() == 0:
		return 0
	
	var last_entry = history[-1]
	var old_position = last_entry.get("position", new_position)
	
	return old_position - new_position  # Positif si montée, négatif si descente

func _update_ranking_history(guilds_data: Array):
	"""Met à jour l'historique des classements"""
	var current_date = _get_current_date()
	
	for guild_data in guilds_data:
		var guild_name = guild_data["name"]
		if not ranking_history.has(guild_name):
			ranking_history[guild_name] = []
		
		ranking_history[guild_name].append({
			"date": current_date,
			"position": guild_data["position"],
			"score": guild_data["score"]
		})
		
		# Garder seulement les 50 dernières entrées
		if ranking_history[guild_name].size() > 50:
			ranking_history[guild_name] = ranking_history[guild_name].slice(-50)

func _check_position_changes(old_rankings: Array, new_rankings: Array):
	"""Vérifie les changements de position et émet les signaux appropriés"""
	# Créer un mapping des anciennes positions
	var old_positions = {}
	for guild_data in old_rankings:
		old_positions[guild_data["name"]] = guild_data["position"]
	
	# Vérifier les changements
	for guild_data in new_rankings:
		var guild_name = guild_data["name"]
		var new_position = guild_data["position"]
		var old_position = old_positions.get(guild_name, new_position)
		
		if old_position != new_position:
			guild_position_changed.emit(guild_name, old_position, new_position)
			
			if guild_name == GuildManager.guild.name if GuildManager and GuildManager.guild else "":
				if new_position < old_position:
					print("🎉 Notre guilde monte au classement ! Position %d -> %d" % [old_position, new_position])
				else:
					print("📉 Notre guilde descend au classement. Position %d -> %d" % [old_position, new_position])

func register_server_first(guild_name: String, content_id: String):
	"""Enregistre un server first pour une guilde"""
	server_firsts[content_id] = guild_name
	
	new_server_first.emit(guild_name, "Server First: %s" % content_id)
	
	if guild_name == GuildManager.guild.name if GuildManager and GuildManager.guild else "":
		print("🏆 SERVER FIRST! Nous avons fait le premier clear de %s!" % content_id)
	else:
		print("📢 %s a fait le server first de %s" % [guild_name, content_id])
	
	# Mettre à jour les rankings immédiatement après un server first
	call_deferred("update_rankings")

func _is_raid_content(content_id: String) -> bool:
	"""Détermine si un contenu est un raid ou un donjon"""
	var raid_contents = ["molten_core", "onyxias_lair", "blackwing_lair", "zul_gurub", "aq20", "aq40", "naxxramas"]
	return content_id in raid_contents

func get_current_rankings() -> Array:
	"""Retourne les classements actuels selon la phase"""
	var current_phase = PhaseManager.get_current_phase() if PhaseManager else PhaseManager.GamePhase.SERVEUR
	
	match current_phase:
		PhaseManager.GamePhase.SERVEUR:
			return server_rankings
		PhaseManager.GamePhase.NATIONAL:
			return national_rankings
		PhaseManager.GamePhase.ESPORT:
			return world_rankings
		_:
			return server_rankings

func get_guild_position(guild_name: String) -> int:
	"""Retourne la position actuelle d'une guilde"""
	var rankings = get_current_rankings()
	
	for guild_data in rankings:
		if guild_data["name"] == guild_name:
			return guild_data["position"]
	
	return -1  # Non trouvé

func get_player_guild_position() -> int:
	"""Retourne la position de la guilde du joueur"""
	if GuildManager and GuildManager.guild:
		return get_guild_position(GuildManager.guild.name)
	return -1

func get_guild_ranking_info(guild_name: String) -> Dictionary:
	"""Retourne les informations détaillées de classement d'une guilde"""
	var rankings = get_current_rankings()
	
	for guild_data in rankings:
		if guild_data["name"] == guild_name:
			return guild_data
	
	return {}

func get_ranking_history(guild_name: String) -> Array:
	"""Retourne l'historique de classement d'une guilde"""
	return ranking_history.get(guild_name, [])

func get_server_firsts() -> Dictionary:
	"""Retourne tous les server firsts enregistrés"""
	return server_firsts.duplicate()

func register_player_content_clear(content_id: String, content_name: String = "", instance_type: int = -1, is_heroic: bool = false, participants: Array = []) -> void:
	"""Enregistre un clear PvE réel de la guilde du joueur."""
	if content_id.strip_edges() == "":
		return
	
	var clear_data: Dictionary = {
		"content_id": content_id,
		"name": content_name if content_name != "" else content_id,
		"type": instance_type,
		"is_heroic": is_heroic,
		"participants": participants.duplicate(),
		"date": _get_current_date(),
		"total_day": GameTime.get_total_days_elapsed() if GameTime and GameTime.has_method("get_total_days_elapsed") else 0
	}
	
	player_cleared_content[content_id] = clear_data
	player_recent_clears.append(clear_data)
	_prune_player_recent_clears()
	
	if GuildManager and GuildManager.guild and not server_firsts.has(content_id):
		register_server_first(GuildManager.guild.name, content_id)
	else:
		call_deferred("update_rankings")

func get_player_cleared_content() -> Array:
	"""Retourne les IDs de contenu déjà clear par la guilde du joueur."""
	return player_cleared_content.keys()

func get_player_recent_clears(days: int = 7) -> Array:
	"""Retourne les clears du joueur dans la fenêtre récente demandée."""
	var current_total_day: int = GameTime.get_total_days_elapsed() if GameTime and GameTime.has_method("get_total_days_elapsed") else 0
	var cutoff_day: int = current_total_day - days
	var recent: Array = []
	for clear_data in player_recent_clears:
		if int(clear_data.get("total_day", 0)) >= cutoff_day:
			recent.append(clear_data)
	return recent

func get_player_content_cleared_percent() -> float:
	"""Pourcentage du contenu actuellement disponible clear par la guilde du joueur."""
	var available_content: Dictionary = DungeonDataScript.get_available_instances()
	if available_content.is_empty():
		return 0.0
	
	var cleared_count: int = 0
	for content_id in available_content:
		if player_cleared_content.has(content_id):
			cleared_count += 1
	
	return (float(cleared_count) / float(available_content.size())) * 100.0

func _prune_player_recent_clears(days: int = 14) -> void:
	var current_total_day: int = GameTime.get_total_days_elapsed() if GameTime and GameTime.has_method("get_total_days_elapsed") else 0
	var cutoff_day: int = current_total_day - days
	var pruned: Array = []
	for clear_data in player_recent_clears:
		if int(clear_data.get("total_day", 0)) >= cutoff_day:
			pruned.append(clear_data)
	player_recent_clears = pruned

# Callbacks des signaux

func _on_week_changed(week: int, year: int):
	"""Met à jour les rankings chaque semaine"""
	update_rankings()

func _on_member_recruited(player):
	"""Réagit au recrutement de nouveaux membres"""
	# Attendre un peu avant de mettre à jour (laisser le temps à l'intégration)
	get_tree().create_timer(1.0).timeout.connect(update_rankings)

func _on_guild_level_changed(new_level: int):
	"""Réagit aux changements de niveau de guilde"""
	# Mettre à jour immédiatement car c'est important pour le score
	update_rankings()

func _on_activity_completed(player, activity):
	"""Réagit aux activités terminées"""
	# Si c'est une activité de donjon/raid, ça peut affecter le ranking
	if activity and activity.type in [activity.ActivityType.DUNGEON, activity.ActivityType.RAID]:
		get_tree().create_timer(2.0).timeout.connect(update_rankings)

func _on_phase_changed(new_phase, old_phase):
	"""Réagit aux changements de phase"""
	print("Changement de phase détecté : mise à jour du système de classement")
	update_rankings()

func _on_ai_simulation_completed(guilds_data: Array):
	"""Appelé quand la simulation mensuelle des guildes IA est terminée"""
	# Les données sont déjà intégrées dans les guildes IA
	# On met juste à jour les rankings
	update_rankings()

func _on_ai_guild_created(ai_guild: AIGuild):
	"""Appelé quand une nouvelle guilde IA est créée"""
	register_guild(ai_guild.name, false)

# Méthodes utilitaires

func _get_current_date() -> Dictionary:
	"""Retourne la date actuelle du jeu"""
	if GameTime:
		return {
			"day": GameTime.current_day,
			"week": GameTime.current_week,
			"year": GameTime.current_year
		}
	return {"day": 1, "week": 1, "year": 1}

func get_debug_info() -> Dictionary:
	"""Retourne des informations de debug"""
	return {
		"current_rankings_count": get_current_rankings().size(),
		"player_position": get_player_guild_position(),
		"server_firsts_count": server_firsts.size(),
		"last_update": last_ranking_update,
		"tracked_guilds": ranking_history.keys()
	}

# Méthodes de sauvegarde/chargement

func save_ranking_data() -> Dictionary:
	"""Sauvegarde les données de classement"""
	return {
		"server_rankings": server_rankings,
		"national_rankings": national_rankings,
		"world_rankings": world_rankings,
		"ranking_history": ranking_history,
		"server_firsts": server_firsts,
		"player_cleared_content": player_cleared_content,
		"player_recent_clears": player_recent_clears,
		"last_ranking_update": last_ranking_update
	}

func load_ranking_data(data: Dictionary):
	"""Charge les données de classement"""
	server_rankings = data.get("server_rankings", [])
	national_rankings = data.get("national_rankings", [])
	world_rankings = data.get("world_rankings", [])
	ranking_history = data.get("ranking_history", {})
	server_firsts = data.get("server_firsts", {})
	player_cleared_content = data.get("player_cleared_content", {})
	player_recent_clears = data.get("player_recent_clears", [])
	last_ranking_update = data.get("last_ranking_update", _get_current_date())
	
	print("Données de classement chargées - %d server firsts, %d guildes trackées" % [server_firsts.size(), ranking_history.size()])
