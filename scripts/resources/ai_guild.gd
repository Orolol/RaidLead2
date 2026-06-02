class_name AIGuild
extends Guild
# Singletons hérité de Guild

# Système de guildes IA concurrentes avec comportements réalistes

enum Strategy {
	AGGRESSIVE,   # Focus sur la progression rapide, prend plus de risques
	BALANCED,     # Équilibré entre progression et stabilité
	DEFENSIVE,    # Focus sur la stabilité et la rétention des membres
	HARDCORE,     # Maximum de performance, turnover élevé acceptable
	CASUAL        # Focus sur la convivialité, progression lente mais stable
}

# Propriétés IA
@export var ai_strategy: Strategy = Strategy.BALANCED
@export var success_rate: float = 0.6  # Taux de succès général
@export var aggressiveness: float = 0.5  # 0-1, tendance à débaucher
@export var stability: float = 0.7  # 0-1, stabilité interne

# État interne de la guilde IA
var members: Array = []  # Array[Dictionary] - Membres simulés simplifiés
var monthly_turnover: float = 0.0
var recent_achievements: Array = []
var current_focus: String = "leveling"  # "leveling", "dungeons", "raids"
var recruitment_attempts: int = 0
var last_major_success_days: int = -1

# Configuration par stratégie
const STRATEGY_CONFIG = {
	Strategy.AGGRESSIVE: {
		"recruitment_frequency": 0.8,
		"poaching_tendency": 0.9,
		"raid_focus": 0.9,
		"member_requirements": 0.8,
		"turnover_tolerance": 0.6,
		"reputation_modifier": -0.1
	},
	Strategy.BALANCED: {
		"recruitment_frequency": 0.6,
		"poaching_tendency": 0.4,
		"raid_focus": 0.6,
		"member_requirements": 0.5,
		"turnover_tolerance": 0.3,
		"reputation_modifier": 0.0
	},
	Strategy.DEFENSIVE: {
		"recruitment_frequency": 0.3,
		"poaching_tendency": 0.1,
		"raid_focus": 0.3,
		"member_requirements": 0.3,
		"turnover_tolerance": 0.1,
		"reputation_modifier": 0.2
	},
	Strategy.HARDCORE: {
		"recruitment_frequency": 1.0,
		"poaching_tendency": 0.8,
		"raid_focus": 1.0,
		"member_requirements": 1.0,
		"turnover_tolerance": 1.0,
		"reputation_modifier": -0.2
	},
	Strategy.CASUAL: {
		"recruitment_frequency": 0.2,
		"poaching_tendency": 0.0,
		"raid_focus": 0.2,
		"member_requirements": 0.2,
		"turnover_tolerance": 0.05,
		"reputation_modifier": 0.3
	}
}

func _init(guild_name: String = "", strategy: Strategy = Strategy.BALANCED, initialize_members: bool = true) -> void:
	super._init()
	if guild_name != "":
		name = guild_name
	ai_strategy = strategy
	if initialize_members:
		_initialize_ai_guild()

func _initialize_ai_guild() -> void:
	"""Initialise la guilde IA avec des membres de départ"""
	var config: Dictionary = STRATEGY_CONFIG[ai_strategy]
	
	# Ajuster les stats de base selon la stratégie
	reputation = 50.0 + (config.reputation_modifier * 20.0)
	success_rate = 0.6 + (config.raid_focus - 0.5) * 0.3
	aggressiveness = config.poaching_tendency
	stability = 1.0 - config.turnover_tolerance
	
	# Générer des membres initiaux
	var member_count: int = randi_range(12, 25)
	_generate_initial_members(member_count)
	
	# XP initiale selon la réputation
	xp = int(reputation * 10) + randi_range(0, 200)
	
	GameLog.d("Guilde IA '%s' créée - Stratégie: %s, Réputation: %.1f" % [name, Strategy.keys()[ai_strategy], reputation])

func _generate_initial_members(count: int) -> void:
	"""Génère des membres initiaux pour la guilde IA"""
	var classes: Array = ["Guerrier", "Prêtre", "Mage", "Voleur", "Chasseur", "Druide"]
	var config: Dictionary = STRATEGY_CONFIG[ai_strategy]

	for i in range(count):
		var member: Dictionary = {
			"name": _generate_member_name(),
			"class": classes.pick_random(),
			"level": _generate_member_level(),
			"equipment": randi_range(5, 50),
			"skill": _generate_member_skill(),
			"loyalty": randf_range(0.3, 0.9),
			"satisfaction": randf_range(0.4, 0.8),
			"days_in_guild": randi_range(1, 90),
			"is_star_player": randf() < 0.15  # 15% de chance d'être un joueur star
		}
		
		# Ajuster selon la stratégie
		if ai_strategy == Strategy.HARDCORE:
			member.skill *= 1.2  # Meilleurs joueurs
			member.level = max(member.level, 45)  # Niveaux plus élevés
		elif ai_strategy == Strategy.CASUAL:
			member.level = min(member.level, 35)  # Niveaux plus bas
			member.satisfaction *= 1.3  # Plus satisfaits
		
		members.append(member)

func _generate_member_name() -> String:
	"""Génère un nom de membre aléatoire"""
	var prefixes: Array[String] = ["Dar", "Kor", "Mal", "Thar", "Zen", "Kael", "Mor", "Vel", "Xan", "Jor"]
	var suffixes: Array[String] = ["ion", "ak", "oth", "eus", "in", "el", "an", "ur", "is", "on"]
	return prefixes.pick_random() + suffixes.pick_random()

func _generate_member_level() -> int:
	"""Génère un niveau de membre selon la stratégie"""
	match ai_strategy:
		Strategy.HARDCORE:
			return randi_range(35, 60)
		Strategy.AGGRESSIVE:
			return randi_range(25, 55)
		Strategy.BALANCED:
			return randi_range(15, 45)
		Strategy.DEFENSIVE:
			return randi_range(10, 40)
		Strategy.CASUAL:
			return randi_range(5, 30)
		_:
			return randi_range(10, 40)

func _generate_member_skill() -> float:
	"""Génère un niveau de skill selon la stratégie"""
	var base_skill: float = randf_range(40.0, 80.0)
	
	match ai_strategy:
		Strategy.HARDCORE:
			base_skill = randf_range(70.0, 95.0)
		Strategy.AGGRESSIVE:
			base_skill = randf_range(60.0, 85.0)
		Strategy.CASUAL:
			base_skill = randf_range(30.0, 70.0)
	
	return base_skill

func get_strategy_name() -> String:
	"""Retourne le nom de la stratégie"""
	return Strategy.keys()[ai_strategy]

func get_active_members_count() -> int:
	"""Retourne le nombre de membres actifs"""
	var active: int = 0
	for member in members:
		if member.satisfaction > 0.3:
			active += 1
	return active

func get_average_level() -> float:
	"""Retourne le niveau moyen des membres"""
	if members.is_empty():
		return 1.0
	
	var total = 0
	for member in members:
		total += member.level
	return float(total) / float(members.size())

func get_average_skill() -> float:
	"""Retourne le skill moyen des membres"""
	if members.is_empty():
		return 50.0
	
	var total = 0.0
	for member in members:
		total += member.skill
	return total / float(members.size())

func get_star_players() -> Array:
	"""Retourne les joueurs stars de la guilde"""
	var stars: Array = []
	for member in members:
		if member.is_star_player:
			stars.append(member)
	return stars

func simulate_weekly_progress() -> void:
	"""Simule la progression PvE hebdomadaire (lissée, ~1/4 du rythme mensuel d'origine).

	Découplée du mensuel (recrutement/turnover/réputation) pour que le classement avance
	chaque semaine plutôt que par à-coups tous les 4 weeks."""
	# Progression PvE à amplitude réduite (les tentatives sont divisées par ~4 dans la méthode).
	_simulate_pve_progression(true)

	# Le focus peut évoluer chaque semaine (suit le niveau moyen de la guilde).
	_update_current_focus()

	# XP de niveau lissé : ~1/4 de l'ex-gain mensuel pour conserver le rythme global.
	var config = STRATEGY_CONFIG[ai_strategy]
	var weekly_xp: int = int((120 + reputation * 4.0 + config.raid_focus * 200.0) / 4.0)
	gain_xp(weekly_xp, "Progression hebdomadaire")

func simulate_monthly_progress() -> void:
	"""Simule la progression mensuelle de la guilde IA (recrutement, turnover, réputation).

	La progression PvE et l'XP de niveau sont désormais hebdomadaires
	(voir simulate_weekly_progress)."""
	var config: Dictionary = STRATEGY_CONFIG[ai_strategy]

	# Simulation de recrutement
	if randf() < config.recruitment_frequency:
		_attempt_recruitment()

	# Simulation du turnover
	_simulate_member_turnover()

	# Mise à jour de la réputation
	_update_reputation()

	# Mise à jour du focus
	_update_current_focus()

	# Petit bonus d'XP mensuel passif (réputation/effectif), distinct de la progression PvE
	# hebdomadaire : garde une progression de niveau crédible sur le rythme mensuel.
	var monthly_xp: int = int(40 + reputation * 1.0)
	gain_xp(monthly_xp, "Progression mensuelle")

	GameLog.d("Progression mensuelle simulée pour %s - Membres: %d, Réputation: %.1f" % [name, members.size(), reputation])

func _simulate_pve_progression(weekly: bool = false) -> void:
	"""Simule la progression PvE de la guilde.

	weekly=true lisse l'amplitude (~1/4 des tentatives) pour une cadence hebdomadaire."""
	var config: Dictionary = STRATEGY_CONFIG[ai_strategy]
	var success_chance = success_rate * config.raid_focus

	# Équilibrage adaptatif : rubber-band — les IA progressent plus vite si le joueur domine (US 6.4)
	var balance_manager = Singletons.get_autoload("BalanceManager")
	if balance_manager:
		success_chance *= balance_manager.get_ai_progression_mult()

	# Tentatives de progression selon le focus actuel
	var progression_attempts: int = 1
	if current_focus == "raids":
		progression_attempts = 3
	elif current_focus == "dungeons":
		progression_attempts = 2

	# Cadence hebdomadaire lissée : on réduit l'amplitude (~1/4) via une probabilité d'essai.
	# 1 tentative -> ~25% de chance d'avoir 1 essai cette semaine ; 2/3 -> proportionnel.
	if weekly:
		var expected_attempts: float = progression_attempts / 4.0
		progression_attempts = int(expected_attempts)
		if randf() < (expected_attempts - float(progression_attempts)):
			progression_attempts += 1

	for i in range(progression_attempts):
		if randf() < success_chance:
			_achieve_pve_success()

func _achieve_pve_success() -> void:
	"""La guilde réalise un succès PvE"""
	var available_content: Array = _get_available_content_for_level()
	if available_content.is_empty():
		return

	var content: Dictionary = available_content.pick_random()
	recent_achievements.append({
		"type": "pve_clear",
		"content": content,
		"date": _get_current_date(),
		"is_server_first": randf() < 0.1  # 10% de chance de server first
	})
	
	# Gain XP pour la guilde
	var xp_gain: int = 50
	if content.has("raid") and content.raid:
		xp_gain = 150
	
	gain_xp(xp_gain, "Clear de " + content.name)
	
	# Si c'est un server first, le notifier
	if recent_achievements[-1].is_server_first:
		var guild_ranking = Singletons.get_autoload("GuildRanking")
		if guild_ranking:
			guild_ranking.register_server_first(name, content.id)
	
	last_major_success_days = 0
	reputation = min(100.0, reputation + 2.0)

func _get_available_content_for_level() -> Array:
	"""Retourne le contenu disponible pour le niveau moyen de la guilde"""
	var avg_level: float = get_average_level()
	var available: Array = []

	# Contenu de base toujours disponible
	if avg_level >= 15:
		available.append({"id": "deadmines", "name": "Mines de la Mort", "raid": false})
	if avg_level >= 25:
		available.append({"id": "scarlet_monastery", "name": "Monastère Écarlate", "raid": false})
	if avg_level >= 35:
		available.append({"id": "uldaman", "name": "Uldaman", "raid": false})
	if avg_level >= 50:
		available.append({"id": "blackrock_depths", "name": "Profondeurs de Blackrock", "raid": false})
	
	# Raids de haut niveau
	if avg_level >= 55 and get_active_members_count() >= 20:
		available.append({"id": "molten_core", "name": "Cœur du Magma", "raid": true})
	if avg_level >= 58 and reputation >= 70:
		available.append({"id": "onyxias_lair", "name": "Repaire d'Onyxia", "raid": true})
	
	return available

func _attempt_recruitment() -> void:
	"""Tente de recruter de nouveaux membres"""
	var config: Dictionary = STRATEGY_CONFIG[ai_strategy]
	recruitment_attempts += 1

	# Chances de succès selon la réputation et la stratégie
	var success_chance: float = (reputation / 100.0) * 0.7 + 0.2

	if randf() < success_chance:
		var new_member: Dictionary = {
			"name": _generate_member_name(),
			"class": ["Guerrier", "Prêtre", "Mage", "Voleur", "Chasseur"].pick_random(),
			"level": _generate_member_level(),
			"equipment": randi_range(5, 30),
			"skill": _generate_member_skill(),
			"loyalty": randf_range(0.5, 0.9),
			"satisfaction": randf_range(0.6, 0.9),
			"days_in_guild": 0,
			"is_star_player": randf() < 0.1
		}
		
		members.append(new_member)
		GameLog.d("Guilde IA %s a recruté %s" % [name, new_member.name])

func _simulate_member_turnover() -> void:
	"""Simule les départs de membres"""
	var config: Dictionary = STRATEGY_CONFIG[ai_strategy]
	var members_to_remove: Array = []

	for i in range(members.size()):
		var member: Dictionary = members[i]
		member.days_in_guild += 30  # Un mois
		
		# Probabilité de départ selon satisfaction et loyauté
		var leave_chance = (1.0 - member.satisfaction) * (1.0 - member.loyalty) * config.turnover_tolerance
		
		# Facteurs additionnels
		if member.days_in_guild > 180:  # Plus de 6 mois
			leave_chance *= 0.8  # Moins susceptible de partir
		if member.is_star_player:
			leave_chance *= 0.5  # Joueurs stars moins susceptibles de partir
		
		if randf() < leave_chance:
			members_to_remove.append(i)
	
	# Supprimer les membres qui partent (en ordre inverse pour préserver les indices)
	members_to_remove.reverse()
	for index in members_to_remove:
		var leaving_member: Dictionary = members[index]
		GameLog.d("Membre %s quitte la guilde %s" % [leaving_member.name, name])
		members.remove_at(index)
	
	# Calculer le taux de turnover
	monthly_turnover = float(members_to_remove.size()) / float(max(1, members.size() + members_to_remove.size()))

func _update_reputation() -> void:
	"""Met à jour la réputation de la guilde"""
	var change: float = 0.0
	
	# Bonus pour succès récents
	if last_major_success_days >= 0:
		if last_major_success_days < 30:
			change += 1.0
		last_major_success_days += 30
	
	# Malus pour turnover élevé
	if monthly_turnover > 0.3:
		change -= 2.0
	
	# Bonus pour stabilité
	if monthly_turnover < 0.1:
		change += 0.5
	
	# Dérive naturelle vers 50
	var drift: float = (50.0 - reputation) * 0.05
	change += drift
	
	reputation = clamp(reputation + change, 0.0, 100.0)

func _update_current_focus() -> void:
	"""Met à jour le focus actuel de la guilde"""
	var avg_level: float = get_average_level()
	var config: Dictionary = STRATEGY_CONFIG[ai_strategy]
	
	if avg_level < 30:
		current_focus = "leveling"
	elif avg_level < 50:
		if randf() < config.raid_focus:
			current_focus = "dungeons"
		else:
			current_focus = "leveling"
	else:
		if randf() < config.raid_focus:
			current_focus = "raids"
		else:
			current_focus = "dungeons"

func attempt_poaching(target_guild_members: Array) -> Dictionary:
	"""Tente de débaucher des membres d'une autre guilde"""
	var config: Dictionary = STRATEGY_CONFIG[ai_strategy]

	if randf() > config.poaching_tendency:
		return {"success": false, "reason": "Guilde pas intéressée par le débauchage"}

	# Filtrer les cibles intéressantes
	var potential_targets: Array = []
	for member in target_guild_members:
		if _is_attractive_target(member):
			potential_targets.append(member)
	
	if potential_targets.is_empty():
		return {"success": false, "reason": "Aucune cible attractive"}
	
	# Sélectionner une cible
	var target = potential_targets.pick_random()
	
	# Calculer les chances de succès
	var success_chance: float = _calculate_poaching_success_chance(target)

	if randf() < success_chance:
		return {
			"success": true,
			"target": target,
			"offer": _generate_poaching_offer(target)
		}
	else:
		return {
			"success": false,
			"reason": "Le joueur a refusé l'offre",
			"target": target
		}

func _is_attractive_target(member) -> bool:
	"""Détermine si un membre est une cible attractive pour le débauchage"""
	var config: Dictionary = STRATEGY_CONFIG[ai_strategy]

	# Vérifier les critères minimums selon la stratégie
	var min_level: int = 30 if ai_strategy == Strategy.HARDCORE else 20
	var min_skill: int = 70 if ai_strategy == Strategy.HARDCORE else 50
	
	# Gérer les deux types : SimulatedPlayer et Dictionary
	var level: int
	var skill: float
	var integration: float
	var mood: float
	
	if member is Dictionary:
		# Pour les membres de guildes IA (Dictionary)
		level = member.get("level", 1)
		skill = member.get("skill", 50.0)
		integration = member.get("loyalty", 0.5) * 100.0  # loyalty est 0-1, integration 0-100
		mood = member.get("satisfaction", 0.5) * 100.0    # satisfaction est 0-1, mood 0-100
	else:
		# Pour les membres de la guilde joueur (SimulatedPlayer)
		level = member.personnage_niveau
		skill = member.skill
		integration = member.integration
		mood = member.mood
	
	if level < min_level:
		return false
	if skill < min_skill:
		return false
	
	# Préférer les membres moins intégrés ou insatisfaits
	if integration < 50 or mood < 60:
		return true
	
	# Toujours intéressé par les très bons joueurs
	if skill > 85 and level >= 50:
		return true
	
	return false

func _calculate_poaching_success_chance(member) -> float:
	"""Calcule les chances de succès d'un débauchage"""
	var base_chance: float = 0.2
	
	# Gérer les deux types : SimulatedPlayer et Dictionary
	var integration: float
	var mood: float
	
	if member is Dictionary:
		# Pour les membres de guildes IA (Dictionary)
		integration = member.get("loyalty", 0.5) * 100.0  # loyalty est 0-1, integration 0-100
		mood = member.get("satisfaction", 0.5) * 100.0    # satisfaction est 0-1, mood 0-100
	else:
		# Pour les membres de la guilde joueur (SimulatedPlayer)
		integration = member.integration
		mood = member.mood
	
	# Facteurs favorables
	if integration < 30:
		base_chance += 0.3
	if mood < 50:
		base_chance += 0.2
	
	# Notre réputation vs leur satisfaction
	var reputation_factor: float = reputation / 100.0
	base_chance += reputation_factor * 0.3
	
	# Facteurs défavorables
	if integration > 70:
		base_chance -= 0.3
	if mood > 80:
		base_chance -= 0.2
	
	return clamp(base_chance, 0.05, 0.8)

func _generate_poaching_offer(member) -> Dictionary:
	"""Génère une offre de débauchage"""
	# Gérer les deux types : SimulatedPlayer et Dictionary
	var skill: float
	if member is Dictionary:
		skill = member.get("skill", 50.0)
	else:
		skill = member.skill
	
	return {
		"equipment_bonus": randi_range(10, 50),
		"guaranteed_raid_spot": ai_strategy in [Strategy.HARDCORE, Strategy.AGGRESSIVE],
		"leadership_role": skill > 85 and randf() < 0.3,
		"message": "Rejoignez une guilde qui valorise le talent !"
	}

func get_guild_data_for_ranking() -> Dictionary:
	"""Retourne les données de la guilde pour le système de classement"""
	return {
		"name": name,
		"guild_level": get_level(),
		"active_members_count": get_active_members_count(),
		"total_members_count": members.size(),
		"cleared_content": _get_cleared_content_ids(),
		"recent_clears": _get_recent_clears(),
		"reputation": reputation,
		"monthly_turnover": monthly_turnover,
		"special_achievements": recent_achievements
	}

func _get_cleared_content_ids() -> Array:
	"""Retourne les IDs UNIQUES du contenu cleared (dédupliqués, comme côté joueur)."""
	var cleared: Dictionary = {}
	for achievement in recent_achievements:
		if achievement.type == "pve_clear":
			cleared[achievement.content.id] = true
	return cleared.keys()

func _get_recent_clears() -> Array:
	"""Retourne les IDs uniques des clears récents (5 derniers achievements, dédupliqués)."""
	var recent: Dictionary = {}
	for i in range(maxi(0, recent_achievements.size() - 5), recent_achievements.size()):
		var achievement = recent_achievements[i]
		if achievement.type == "pve_clear":
			recent[achievement.content.id] = true
	return recent.keys()

# Méthodes utilitaires

func _get_current_date() -> Dictionary:
	"""Retourne la date actuelle du jeu"""
	var game_time = Singletons.get_autoload("GameTime")
	if game_time:
		return {
			"day": game_time.current_day,
			"week": game_time.current_week,
			"year": game_time.current_year
		}
	return {"day": 1, "week": 1, "year": 1}

func get_debug_info() -> Dictionary:
	"""Retourne des informations de debug"""
	return {
		"strategy": get_strategy_name(),
		"reputation": reputation,
		"members_count": members.size(),
		"active_members": get_active_members_count(),
		"average_level": get_average_level(),
		"average_skill": get_average_skill(),
		"monthly_turnover": monthly_turnover,
		"current_focus": current_focus,
		"recent_achievements": recent_achievements.size()
	}
