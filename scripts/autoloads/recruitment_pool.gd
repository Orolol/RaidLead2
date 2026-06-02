extends Node

signal pool_refreshed
signal player_recruited(player)
signal player_lost_to_competition(player, guild_name)

var available_players: Array = []
var game_time: Node
var last_refresh_total_day: int = 0

# Configuration du pool (sera ajustée selon la version serveur)
const BASE_MIN_POOL_SIZE = 15
const BASE_MAX_POOL_SIZE = 30
const REFRESH_INTERVAL_DAYS = 3
const DAILY_NEW_PLAYERS = 2  # Nouveaux joueurs par jour

# Générateur de noms de guilde pour la compétition
var competitor_guilds = [
	"Les Vengeurs d'Azeroth",
	"Légion Noire",
	"Les Gardiens du Crépuscule",
	"Fraternité du Loup",
	"Les Chevaliers de l'Aube",
	"Horde Sauvage",
	"Les Élus de la Lumière",
	"Compagnie du Dragon",
	"Les Forgerons de Guerre"
]

func _ready() -> void:
	game_time = GameTime
	if game_time:
		last_refresh_total_day = _get_total_days_elapsed()
		game_time.day_changed.connect(_on_day_changed)
		game_time.hour_changed.connect(_on_hour_changed)
	
	# Se connecter aux mises à jour de version serveur
	if ServerVersion:
		ServerVersion.version_updated.connect(_on_server_version_updated)
	
	# Génère le pool initial
	_generate_initial_pool()

func _generate_initial_pool() -> void:
	available_players.clear()
	
	var pool_limits: Dictionary = _get_current_pool_limits()
	var pool_size: int = randi_range(pool_limits.min_size, pool_limits.max_size)
	for i in pool_size:
		var player: SimulatedPlayer = _spawn_player()
		available_players.append(player)

	pool_refreshed.emit()

func _get_current_pool_limits() -> Dictionary:
	var base_min = BASE_MIN_POOL_SIZE
	var base_max = BASE_MAX_POOL_SIZE

	if ServerVersion:
		var pool_size = ServerVersion.get_recruitment_pool_size()
		base_min = pool_size
		base_max = min(pool_size + 10, BASE_MAX_POOL_SIZE)

	# Ajouter le bonus de perks de guilde
	var guild_manager = GuildManager
	if guild_manager and guild_manager.guild:
		var bonus = guild_manager.guild.get_recruitment_pool_bonus()
		base_min += bonus
		base_max += bonus

	# Phase nationale : pool élargi (50-100 joueurs)
	if is_national_phase():
		base_min = maxi(base_min, 50)
		base_max = maxi(base_max, 100)

	return {
		"min_size": base_min,
		"max_size": base_max
	}

func _spawn_player() -> SimulatedPlayer:
	"""Génère une recrue : en phase nationale, ~40% sont des semi-pros (avec salaire)."""
	if is_national_phase() and randf() < 0.4:
		return _create_national_player()
	return _create_random_player()

func _create_random_player() -> SimulatedPlayer:
	var player := SimulatedPlayer.new()

	# Ajoute des infos supplémentaires pour le recrutement
	player.set_meta("recruitment_motivation", _generate_motivation())
	player.set_meta("expected_activity", _generate_expected_activity())
	player.set_meta("recruitment_difficulty", _calculate_recruitment_difficulty(player))
	
	return player

func _generate_motivation() -> String:
	var motivations: Array[String] = [
		"Cherche une guilde active pour progresser",
		"Veut participer à des raids réguliers",
		"Recherche une ambiance familiale",
		"Ambitionne de voir tout le contenu",
		"Souhaite améliorer son équipement",
		"Cherche des partenaires de donjon",
		"Veut rejoindre une guilde compétitive",
		"Préfère une guilde casual",
		"Recherche une guilde francophone"
	]
	return motivations[randi() % motivations.size()]

func _generate_expected_activity() -> Dictionary:
	return {
		"raids_per_week": randi_range(0, 4),
		"dungeons_per_week": randi_range(2, 10),
		"preferred_time": ["soir", "après-midi", "matin"][randi() % 3],
		"hardcore": randf() > 0.7
	}

func _calculate_recruitment_difficulty(player: SimulatedPlayer) -> float:
	var difficulty: float = 0.5  # Base
	
	# Plus difficile si haut niveau/skill
	if player.personnage_niveau >= 55:
		difficulty += 0.2
	if player.skill >= 70:
		difficulty += 0.2
	
	# Plus facile si tags sociaux
	if player.has_tag("social") or player.has_tag("serviable"):
		difficulty -= 0.1
	
	# Plus difficile si tags problématiques visibles
	if player.has_tag("impatient") or player.has_tag("solitaire"):
		difficulty += 0.1
	
	return clamp(difficulty, 0.1, 0.9)

func _on_day_changed(_day: int, _week: int, _year: int) -> void:
	var pool_limits: Dictionary = _get_current_pool_limits()

	# Ajoute quelques nouveaux joueurs chaque jour
	for i in randi_range(1, DAILY_NEW_PLAYERS):
		if available_players.size() < pool_limits.max_size:
			var new_player: SimulatedPlayer = _spawn_player()
			available_players.append(new_player)
	
	# Refresh complet périodiquement
	if _get_total_days_elapsed() - last_refresh_total_day >= REFRESH_INTERVAL_DAYS:
		_refresh_pool()

func _on_hour_changed(_hour: int) -> void:
	# Simule la compétition - des joueurs peuvent être recrutés par d'autres guildes
	if randf() < 0.05:  # 5% de chance par heure
		_simulate_competition()

func _refresh_pool() -> void:
	last_refresh_total_day = _get_total_days_elapsed()
	var pool_limits: Dictionary = _get_current_pool_limits()

	# Retire certains joueurs (recrutés ailleurs, ont arrêté, etc.)
	var players_to_remove: Array = []
	for player in available_players:
		if randf() < 0.3:  # 30% de chance de partir
			players_to_remove.append(player)

	for player in players_to_remove:
		available_players.erase(player)
		if randf() < 0.5:  # 50% de chance que ce soit une autre guilde
			var guild = competitor_guilds[randi() % competitor_guilds.size()]
			player_lost_to_competition.emit(player, guild)
	
	# Ajoute de nouveaux joueurs
	while available_players.size() < pool_limits.min_size:
		available_players.append(_spawn_player())
	
	pool_refreshed.emit()

func _get_total_days_elapsed() -> int:
	if game_time and game_time.has_method("get_total_days_elapsed"):
		return game_time.get_total_days_elapsed()
	if not game_time:
		return 0
	return (
		(game_time.current_year - 1) * game_time.WEEKS_PER_YEAR * game_time.DAYS_PER_WEEK
		+ (game_time.current_week - 1) * game_time.DAYS_PER_WEEK
		+ (game_time.current_day - 1)
	)

func _simulate_competition() -> void:
	if available_players.is_empty():
		return
	
	# Un joueur aléatoire peut être recruté par une guilde concurrente
	var player = available_players[randi() % available_players.size()]
	
	# Les bons joueurs sont plus susceptibles d'être recrutés
	var recruit_chance: float = 0.1
	if player.skill > 70:
		recruit_chance += 0.2
	if player.personnage_niveau == 60:
		recruit_chance += 0.1
	
	if randf() < recruit_chance:
		available_players.erase(player)
		var guild = competitor_guilds[randi() % competitor_guilds.size()]
		player_lost_to_competition.emit(player, guild)

func get_filtered_players(filters: Dictionary) -> Array:
	var filtered: Array = []

	for player in available_players:
		var matches: bool = true
		
		# Filtre par classe
		if filters.has("class") and filters.class != "":
			if player.personnage_classe != filters.class:
				matches = false
		
		# Filtre par niveau
		if filters.has("min_level"):
			if player.personnage_niveau < filters.min_level:
				matches = false
		if filters.has("max_level"):
			if player.personnage_niveau > filters.max_level:
				matches = false
		
		# Filtre par rôle
		if filters.has("role") and filters.role != "":
			if player.get_role() != filters.role:
				matches = false
		
		if matches:
			filtered.append(player)
	
	return filtered

func attempt_recruitment(player: SimulatedPlayer, guild_data: Dictionary) -> Dictionary:
	if player not in available_players:
		return {"success": false, "reason": "Joueur non disponible"}
	
	var base_chance: float = BalanceManager.tunable_float("recruitment.base_chance", 0.5)
	var recruitment_difficulty = player.get_meta("recruitment_difficulty", 0.5)

	# Bonus de célébrité : des membres connus rendent la guilde plus attractive (max +0.2).
	var celeb_bonus: float = 0.0
	for m in GuildManager.guild_members:
		celeb_bonus += m.get_celebrity_bonus_recruitment()
	base_chance += minf(celeb_bonus, 0.2)
	
	# Facteurs positifs
	if guild_data.has("recent_raid_success") and guild_data.recent_raid_success:
		base_chance += 0.2
	
	if guild_data.has("guild_size") and guild_data.guild_size < 20:
		if player.has_tag("solitaire"):
			base_chance += 0.1
	elif guild_data.guild_size > 30:
		if player.has_tag("social"):
			base_chance += 0.1
	
	# Vérifie les attentes du joueur
	var expectations = player.get_meta("expected_activity", {})
	if expectations.get("hardcore", false) and guild_data.get("hardcore", false):
		base_chance += 0.15
	elif not expectations.get("hardcore", false) and not guild_data.get("hardcore", false):
		base_chance += 0.15
	
	# Bonus de réputation de guilde
	if guild_data.has("reputation"):
		var reputation_bonus = (guild_data.reputation - 50.0) * BalanceManager.tunable_float("recruitment.reputation_weight", 0.01)  # -50% à +50%
		base_chance += reputation_bonus
		base_chance = clamp(base_chance, 0.0, 1.0)
	
	# Ajuste selon la difficulté
	var final_chance: float = base_chance * (1.0 - recruitment_difficulty)

	# Équilibrage adaptatif : bonus de recrutement si le joueur est à la traîne (US 6.4)
	var balance_manager = BalanceManager
	if balance_manager:
		final_chance *= balance_manager.get_recruit_chance_mult()
	final_chance = clamp(final_chance, 0.0, 1.0)

	var success: bool = randf() < final_chance

	if success:
		available_players.erase(player)
		player_recruited.emit(player)
		return {"success": true, "player": player}
	else:
		# Génère une raison de refus
		var reasons: Array = _generate_rejection_reasons(player, guild_data)
		return {"success": false, "reason": reasons[randi() % reasons.size()]}

func _generate_rejection_reasons(player: SimulatedPlayer, guild_data: Dictionary) -> Array:
	var reasons: Array = []

	var expectations = player.get_meta("expected_activity", {})
	
	if expectations.get("hardcore", false) and not guild_data.get("hardcore", false):
		reasons.append("Cherche une guilde plus compétitive")
	elif not expectations.get("hardcore", false) and guild_data.get("hardcore", false):
		reasons.append("Préfère une guilde plus casual")
	
	if guild_data.guild_size < 10:
		reasons.append("La guilde semble trop petite")
	
	if player.has_tag("ambitieux"):
		reasons.append("Veut rejoindre une guilde plus prestigieuse")
	
	# Raisons génériques
	reasons.append("A déjà reçu une meilleure offre")
	reasons.append("Préfère attendre d'autres opportunités")
	reasons.append("Les horaires ne correspondent pas")
	
	return reasons

func _on_server_version_updated(new_version: float, _update_name: String) -> void:
	GameLog.d("Pool de recrutement : mise à jour vers version %s" % new_version)
	
	# Augmenter la taille du pool si nécessaire
	var pool_limits: Dictionary = _get_current_pool_limits()
	while available_players.size() < pool_limits.min_size:
		available_players.append(_spawn_player())

	# Permettre à certains joueurs existants de progresser en niveau
	var max_level = ServerVersion.get_max_player_level()
	for player in available_players:
		# 30% de chance qu'un joueur gagne quelques niveaux lors d'une mise à jour
		if randf() < 0.3 and player.personnage_niveau < max_level:
			var level_gain: int = randi_range(1, min(5, max_level - player.personnage_niveau))
			player.personnage_niveau += level_gain
			# L'équipement ne suit plus automatiquement le niveau avec le nouveau système
	
	pool_refreshed.emit()

func get_player_info(player: SimulatedPlayer) -> Dictionary:
	return {
		"recruitment_info": player.get_recruitment_info(),
		"motivation": player.get_meta("recruitment_motivation", ""),
		"expected_activity": player.get_meta("expected_activity", {}),
		"difficulty": player.get_meta("recruitment_difficulty", 0.5)
	}

# --- Phase Nationale : Recrutement etendu ---

func is_national_phase() -> bool:
	"""Verifie si on est en phase nationale ou superieure."""
	if PhaseManager and PhaseManager.has_method("get_current_phase"):
		return PhaseManager.get_current_phase() >= 2  # NATIONAL = 2
	return false

func _create_national_player() -> SimulatedPlayer:
	"""Cree un joueur de niveau national (haute qualite)."""
	var player := SimulatedPlayer.new()

	# Forcer niveau 55-60
	player.personnage_niveau = randi_range(55, 60)

	# Skill eleve
	player.skill = randi_range(60, 90)

	# Exigences salariales
	player.salary_demand = randi_range(10, 100)

	# Agent (20% de chance)
	if randf() < 0.2:
		player.set_meta("has_agent", true)
		player.set_meta("agent_commission", player.salary_demand * 2)
	else:
		player.set_meta("has_agent", false)
		player.set_meta("agent_commission", 0)

	# Motivations nationales
	var national_motivations: Array[String] = [
		"Cherche une guilde top serveur",
		"Veut progresser au niveau national",
		"Ambitionne l'esport a terme",
		"Recherche un environnement semi-pro",
		"Veut rejoindre une guilde avec sponsors",
	]
	player.set_meta("recruitment_motivation", national_motivations[randi() % national_motivations.size()])
	player.set_meta("expected_activity", _generate_expected_activity())
	player.set_meta("recruitment_difficulty", _calculate_recruitment_difficulty(player))
	player.set_meta("is_national", true)

	return player

func attempt_national_recruitment(player: SimulatedPlayer, offered_salary: int) -> Dictionary:
	"""Tente de recruter un joueur national avec negociation salariale."""
	if player not in available_players:
		return {"success": false, "reason": "Joueur non disponible", "step": "error"}

	var demand: int = player.salary_demand
	if demand <= 0:
		# Pas d'exigence salariale, recrutement normal
		return attempt_recruitment(player, _get_guild_data())

	# Etape 1 : Verifier si l'offre est acceptable
	var ratio: float = float(offered_salary) / float(demand)

	if ratio >= 1.0:
		# Offre >= demande : acceptation directe
		return _finalize_national_recruit(player, offered_salary)
	elif ratio >= 0.7:
		# Contre-proposition
		var counter: int = int(demand * randf_range(0.85, 1.1))
		return {"success": false, "reason": "Contre-proposition", "counter_offer": counter, "step": "counter"}
	else:
		# Offre trop basse
		return {"success": false, "reason": "Offre insuffisante (%d/%d or)" % [offered_salary, demand], "step": "rejected"}

func accept_counter_offer(player: SimulatedPlayer, salary: int) -> Dictionary:
	"""Accepte la contre-proposition d'un joueur national."""
	if player not in available_players:
		return {"success": false, "reason": "Joueur non disponible", "step": "error"}
	return _finalize_national_recruit(player, salary)

func _finalize_national_recruit(player: SimulatedPlayer, salary: int) -> Dictionary:
	"""Finalise un recrutement national en dépensant la commission d'agent (one-shot).

	Centralise la dépense d'or pour TOUS les chemins d'acceptation (offre directe ET
	contre-proposition), avec vérification de solvabilité, à l'image de
	TransferManager._try_finalize(). Le salaire hebdomadaire reste prélevé par
	GuildManager._pay_salaries().
	"""
	var agent_cost: int = 0
	if player.get_meta("has_agent", false):
		agent_cost = int(player.get_meta("agent_commission", 0))

	# La commission d'agent est un coût ponctuel à la signature : on vérifie la solvabilité.
	if agent_cost > 0:
		if not GuildManager.guild or GuildManager.guild.gold < agent_cost:
			return {
				"success": false,
				"step": "error",
				"reason": "Commission d'agent inabordable (%d or requis)" % agent_cost,
			}
		GuildManager.guild.spend_gold(agent_cost)

	player.set_meta("salary", salary)
	available_players.erase(player)
	player_recruited.emit(player)
	return {
		"success": true,
		"player": player,
		"salary": salary,
		"agent_cost": agent_cost,
		"step": "accepted",
	}

func scout_player(player: SimulatedPlayer) -> Dictionary:
	"""Scoute un joueur pour reveler ses stats cachees. Coute de la reputation."""
	if GuildManager.guild:
		GuildManager.guild.lose_reputation(BalanceManager.tunable_float("reputation.scout_cost", 2.0), "Scouting de %s" % player.nom)

	# Reveler quelques tags caches
	var revealed_tags: Array = []
	for tag in player.tags_caches:
		if randf() < 0.5:
			revealed_tags.append(tag)
			if tag not in player.tags_comportement:
				player.tags_comportement.append(tag)

	return {
		"skill": player.skill,
		"revealed_tags": revealed_tags,
		"salary_demand": player.salary_demand,
		"has_agent": player.get_meta("has_agent", false),
	}

func _get_guild_data() -> Dictionary:
	"""Retourne les donnees de guilde pour le recrutement."""
	var data: Dictionary = {"guild_size": GuildManager.guild_members.size()}
	if GuildManager.guild:
		data["reputation"] = GuildManager.guild.reputation
		data["recent_raid_success"] = false
		data["hardcore"] = false
	return data

