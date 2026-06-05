extends Node

signal pool_refreshed
signal player_recruited(player)
signal player_lost_to_competition(player, guild_name)

const LootTablesScript = preload("res://scripts/data/loot_tables.gd")
const EquipmentScript = preload("res://scripts/resources/equipment.gd")

var available_players: Array = []
var game_time: Node
var last_refresh_total_day: int = 0

# Configuration du pool (sera ajustée selon la version serveur)
const BASE_MIN_POOL_SIZE = 15
const BASE_MAX_POOL_SIZE = 30
const REFRESH_INTERVAL_DAYS = 3
const DAILY_NEW_PLAYERS = 2  # Nouveaux joueurs par jour
const REJECTION_COOLDOWN_SECONDS = 24 * 60 * 60
const MARKET_MIN_DAYS = 3
const MARKET_MAX_DAYS = 8

const EASY_TRAITS: Array[String] = ["social", "serviable", "casual", "ponctuel", "diurne", "joueur_weekend"]
const DEMANDING_TRAITS: Array[String] = ["ambitieux", "tryhard", "perfectionniste", "hardcore_gamer", "nocturne"]
const RISKY_TRAITS: Array[String] = ["solitaire", "impatient", "greedy", "rage_quitter", "drama_queen", "ninja_looter", "planning_chaotique", "insomniaque"]

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

	# Ajouter le bonus de perks de guilde (variante effective : prend en compte les effets actifs)
	var guild_manager = GuildManager
	if guild_manager and guild_manager.guild:
		var bonus = guild_manager.guild.get_effective_recruitment_pool_bonus()
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
	_initialize_market_candidate(player, false)
	
	return player

func _initialize_market_candidate(player: SimulatedPlayer, is_national_candidate: bool) -> void:
	"""Prepare une recrue pour vivre sur le marche : niveau, stuff, duree et attentes."""
	if not is_national_candidate:
		_assign_recruitment_level(player)
	_equip_candidate_for_level(player)

	var current_day: int = _get_total_days_elapsed()
	player.set_meta("market_entered_day", current_day)
	player.set_meta("market_lifetime_days", randi_range(MARKET_MIN_DAYS, MARKET_MAX_DAYS))
	player.set_meta("recruitment_cooldown_until_ts", -1.0)
	player.set_meta("recruitment_attempts", 0)
	player.set_meta("offers_received", randi_range(0, 2))
	player.set_meta("market_story", _generate_market_story(player))
	player.set_meta("expected_activity", _generate_expected_activity())
	player.set_meta("recruitment_motivation", _generate_motivation())
	_update_recruitment_profile(player)

func _ensure_candidate_meta(player: SimulatedPlayer) -> void:
	if not player.has_meta("market_entered_day"):
		player.set_meta("market_entered_day", _get_total_days_elapsed())
	if not player.has_meta("market_lifetime_days"):
		player.set_meta("market_lifetime_days", randi_range(MARKET_MIN_DAYS, MARKET_MAX_DAYS))
	if not player.has_meta("recruitment_cooldown_until_ts"):
		player.set_meta("recruitment_cooldown_until_ts", -1.0)
	if not player.has_meta("recruitment_attempts"):
		player.set_meta("recruitment_attempts", 0)
	if not player.has_meta("offers_received"):
		player.set_meta("offers_received", 0)
	if not player.has_meta("market_story"):
		player.set_meta("market_story", _generate_market_story(player))
	if not player.has_meta("expected_activity"):
		player.set_meta("expected_activity", _generate_expected_activity())
	if not player.has_meta("recruitment_motivation"):
		player.set_meta("recruitment_motivation", _generate_motivation())

func _assign_recruitment_level(player: SimulatedPlayer) -> void:
	var max_level: int = _get_current_max_player_level()
	var roll: float = randf()
	var min_level: int = 1
	var max_roll_level: int = max_level

	if roll < 0.20:
		min_level = 1
		max_roll_level = maxi(2, mini(max_level, 8))
	elif roll < 0.65:
		min_level = maxi(2, int(max_level * 0.20))
		max_roll_level = maxi(min_level, int(max_level * 0.55))
	elif roll < 0.90:
		min_level = maxi(3, int(max_level * 0.55))
		max_roll_level = maxi(min_level, int(max_level * 0.85))
	else:
		min_level = maxi(4, int(max_level * 0.85))
		max_roll_level = max_level

	player.personnage_niveau = clampi(randi_range(min_level, max_roll_level), 1, max_level)
	var xp_for_next: int = player._calculate_xp_for_level(player.personnage_niveau)
	player.personnage_xp = randi_range(0, maxi(0, xp_for_next - 1))

func _equip_candidate_for_level(player: SimulatedPlayer) -> void:
	if not player.equipment:
		player.equipment = EquipmentScript.new()

	var item_count: int = clampi(2 + int(player.personnage_niveau / 15), 2, 5)
	for i in range(item_count):
		var item = LootTablesScript.generate_item_for_level(player.personnage_niveau)
		player.try_auto_equip(item)

func _get_current_max_player_level() -> int:
	if ServerVersion:
		return maxi(1, ServerVersion.get_max_player_level())
	return 60

func _get_current_timestamp() -> float:
	if game_time and game_time.has_method("get_current_timestamp"):
		return game_time.get_current_timestamp()
	return float(_get_total_days_elapsed() * 24 * 60 * 60)

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

func _generate_market_story(player: SimulatedPlayer) -> String:
	var stories: Array[String] = [
		"Vu sur le canal RechercheGuilde depuis peu.",
		"Surveille plusieurs offres en meme temps.",
		"A poste un long message de candidature tres motive.",
		"Discret, mais ses runs de donjon commencent a circuler.",
		"Compare les guildes comme un tableur vivant."
	]
	if player.has_tag("ambitieux") or player.has_tag("tryhard"):
		stories.append("Cherche clairement une guilde qui avance vite.")
	if player.has_tag("social") or player.has_tag("serviable"):
		stories.append("A deja aide des inconnus en donjon cette semaine.")
	if player.has_tag("impatient") or player.has_tag("greedy"):
		stories.append("Son profil attire, mais quelques rumeurs rendent prudent.")
	return stories[randi() % stories.size()]

func _generate_expected_activity() -> Dictionary:
	return {
		"raids_per_week": randi_range(0, 4),
		"dungeons_per_week": randi_range(2, 10),
		"preferred_time": ["soir", "après-midi", "matin"][randi() % 3],
		"hardcore": randf() > 0.7
	}

func _calculate_recruitment_difficulty(player: SimulatedPlayer) -> float:
	return _calculate_candidate_difficulty(player)

func _calculate_candidate_difficulty(player: SimulatedPlayer) -> float:
	_ensure_candidate_meta(player)
	var max_level: int = _get_current_max_player_level()
	var difficulty: float = 0.18

	var level_factor: float = float(player.personnage_niveau) / float(maxi(1, max_level))
	var skill_factor: float = clampf((float(player.skill) - 20.0) / 80.0, 0.0, 1.0)
	var equipment_factor: float = clampf(float(player.get_total_ilvl()) / maxf(20.0, float(max_level) * 4.5), 0.0, 1.0)

	difficulty += level_factor * 0.25
	difficulty += skill_factor * 0.20
	difficulty += equipment_factor * 0.16

	for tag in EASY_TRAITS:
		if player.has_tag(tag):
			difficulty -= 0.04
	for tag in DEMANDING_TRAITS:
		if player.has_tag(tag):
			difficulty += 0.06
	for tag in RISKY_TRAITS:
		if player.has_tag(tag):
			difficulty += 0.04

	if player.get_meta("is_national", false):
		difficulty += 0.10

	var offers_received: int = int(player.get_meta("offers_received", 0))
	difficulty += minf(0.12, float(offers_received) * 0.03)

	if get_candidate_days_remaining(player) <= 1:
		difficulty += 0.08

	return clampf(difficulty, 0.05, 0.92)

func _update_recruitment_profile(player: SimulatedPlayer) -> void:
	player.set_meta("recruitment_difficulty", _calculate_candidate_difficulty(player))
	player.set_meta("recruitment_value", _calculate_candidate_value(player))

func _calculate_candidate_value(player: SimulatedPlayer) -> float:
	var max_level: int = _get_current_max_player_level()
	var level_score: float = float(player.personnage_niveau) / float(maxi(1, max_level))
	var skill_score: float = float(player.skill) / 100.0
	var equipment_score: float = clampf(float(player.get_total_ilvl()) / maxf(20.0, float(max_level) * 4.5), 0.0, 1.0)
	return clampf(level_score * 0.35 + skill_score * 0.40 + equipment_score * 0.25, 0.0, 1.0)

func get_candidate_days_remaining(player: SimulatedPlayer) -> int:
	_ensure_candidate_meta(player)
	var entered_day: int = int(player.get_meta("market_entered_day", _get_total_days_elapsed()))
	var lifetime_days: int = int(player.get_meta("market_lifetime_days", MARKET_MIN_DAYS))
	return maxi(0, entered_day + lifetime_days - _get_total_days_elapsed())

func is_player_on_recruitment_cooldown(player: SimulatedPlayer) -> bool:
	if not player:
		return false
	var until_ts: float = float(player.get_meta("recruitment_cooldown_until_ts", -1.0))
	return until_ts > _get_current_timestamp()

func get_recruitment_cooldown_remaining_hours(player: SimulatedPlayer) -> int:
	var until_ts: float = float(player.get_meta("recruitment_cooldown_until_ts", -1.0))
	var remaining_seconds: float = maxf(0.0, until_ts - _get_current_timestamp())
	return int(ceil(remaining_seconds / 3600.0))

func get_candidate_status_text(player: SimulatedPlayer) -> String:
	if is_player_on_recruitment_cooldown(player):
		return "A relancer dans %dh" % get_recruitment_cooldown_remaining_hours(player)
	var days_left: int = get_candidate_days_remaining(player)
	if days_left <= 0:
		return "Signe ailleurs aujourd'hui"
	return "Dispo encore %dj" % days_left

func _on_day_changed(_day: int, _week: int, _year: int) -> void:
	var pool_limits: Dictionary = _get_current_pool_limits()
	_process_candidate_lifecycle()

	# Ajoute quelques nouveaux joueurs chaque jour
	for i in randi_range(1, DAILY_NEW_PLAYERS):
		if available_players.size() < pool_limits.max_size:
			var new_player: SimulatedPlayer = _spawn_player()
			available_players.append(new_player)
	
	# Refresh complet périodiquement
	_ensure_minimum_pool_size(pool_limits)

	if _get_total_days_elapsed() - last_refresh_total_day >= REFRESH_INTERVAL_DAYS:
		last_refresh_total_day = _get_total_days_elapsed()

	pool_refreshed.emit()

func _on_hour_changed(_hour: int) -> void:
	# Simule la compétition - des joueurs peuvent être recrutés par d'autres guildes
	if randf() < 0.05:  # 5% de chance par heure
		_simulate_competition()

func _refresh_pool() -> void:
	last_refresh_total_day = _get_total_days_elapsed()
	var pool_limits: Dictionary = _get_current_pool_limits()
	_process_candidate_lifecycle()
	_ensure_minimum_pool_size(pool_limits)
	pool_refreshed.emit()

func _ensure_minimum_pool_size(pool_limits: Dictionary) -> void:
	while available_players.size() < int(pool_limits.min_size):
		available_players.append(_spawn_player())

func _process_candidate_lifecycle() -> void:
	var current_day: int = _get_total_days_elapsed()
	var departures: Array[Dictionary] = []

	for player in available_players:
		if not player:
			continue
		_ensure_candidate_meta(player)
		_progress_candidate_daily(player)
		var entered_day: int = int(player.get_meta("market_entered_day", current_day))
		var lifetime_days: int = int(player.get_meta("market_lifetime_days", MARKET_MIN_DAYS))
		if current_day - entered_day >= lifetime_days:
			departures.append({
				"player": player,
				"guild": competitor_guilds[randi() % competitor_guilds.size()]
			})
		else:
			_update_recruitment_profile(player)

	for departure in departures:
		var leaving_player: SimulatedPlayer = departure.get("player", null) as SimulatedPlayer
		if leaving_player in available_players:
			available_players.erase(leaving_player)
			player_lost_to_competition.emit(leaving_player, String(departure.get("guild", "")))

func _progress_candidate_daily(player: SimulatedPlayer) -> void:
	var max_level: int = _get_current_max_player_level()
	if player.personnage_niveau < max_level:
		var level_chance: float = 0.55
		if player.personnage_niveau > int(float(max_level) * 0.75):
			level_chance = 0.25
		if player.has_tag("tryhard") or player.has_tag("ambitieux"):
			level_chance += 0.12
		if player.has_tag("casual"):
			level_chance -= 0.12

		if randf() < clampf(level_chance, 0.10, 0.75):
			player.personnage_niveau += 1
			player.personnage_xp = 0
			player.skill = mini(100, player.skill + randi_range(0, 2))
			if randf() < 0.65:
				player.try_auto_equip(LootTablesScript.generate_item_for_level(player.personnage_niveau))

	if randf() < _get_competition_interest(player) * 0.35:
		var offers_received: int = int(player.get_meta("offers_received", 0))
		player.set_meta("offers_received", offers_received + 1)

func _get_competition_interest(player: SimulatedPlayer) -> float:
	var value: float = float(player.get_meta("recruitment_value", _calculate_candidate_value(player)))
	var interest: float = 0.04 + value * 0.22
	if player.has_tag("social") or player.has_tag("serviable"):
		interest += 0.03
	if player.has_tag("ninja_looter") or player.has_tag("drama_queen"):
		interest -= 0.04
	return clampf(interest, 0.01, 0.30)

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
	var candidates: Array[SimulatedPlayer] = []
	for candidate in available_players:
		if candidate:
			_ensure_candidate_meta(candidate)
			candidates.append(candidate)
	if candidates.is_empty():
		return
	candidates.sort_custom(func(a: SimulatedPlayer, b: SimulatedPlayer) -> bool:
		return _get_competition_interest(a) > _get_competition_interest(b)
	)
	var candidate_index: int = mini(candidates.size() - 1, randi_range(0, mini(4, candidates.size() - 1)))
	var target: SimulatedPlayer = candidates[candidate_index]
	if randf() < _get_competition_interest(target):
		available_players.erase(target)
		var guild_name: String = competitor_guilds[randi() % competitor_guilds.size()]
		player_lost_to_competition.emit(target, guild_name)
		pool_refreshed.emit()

func get_filtered_players(filters: Dictionary) -> Array:
	var filtered: Array = []

	for player in available_players:
		_ensure_candidate_meta(player)
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
	_ensure_candidate_meta(player)
	if is_player_on_recruitment_cooldown(player):
		return {
			"success": false,
			"step": "cooldown",
			"reason": "%s veut souffler avant de reparler recrutement." % player.nom,
			"cooldown_hours": get_recruitment_cooldown_remaining_hours(player),
		}
	var validation_v2: Dictionary = _can_finalize_recruitment(player)
	if not bool(validation_v2.get("ok", false)):
		return {
			"success": false,
			"step": "error",
			"reason": String(validation_v2.get("reason", "")),
			"player": player,
		}

	var preview_v2: Dictionary = get_recruitment_preview(player, guild_data)
	var final_chance_v2: float = float(preview_v2.get("chance", 0.0))
	if randf() < final_chance_v2:
		return _finalize_recruitment(player, {
			"step": "accepted",
			"chance": final_chance_v2,
			"message": _generate_acceptance_message(player, final_chance_v2),
		})

	var reasons_v2: Array = _generate_rejection_reasons(player, guild_data)
	var reason_v2: String = reasons_v2[randi() % reasons_v2.size()]
	return _mark_recruitment_refused(player, reason_v2, final_chance_v2)

func get_recruitment_preview(player: SimulatedPlayer, guild_data: Dictionary = {}) -> Dictionary:
	if not player:
		return {"chance": 0.0, "difficulty": 1.0, "fit": 0.0, "label": "Inconnu", "reasons": []}
	_ensure_candidate_meta(player)
	if guild_data.is_empty():
		guild_data = _get_guild_data()

	var base_chance: float = BalanceManager.tunable_float("recruitment.base_chance", 0.5)
	var difficulty: float = float(player.get_meta("recruitment_difficulty", _calculate_candidate_difficulty(player)))
	var fit_bonus: float = _calculate_guild_fit_bonus(player, guild_data)

	var celeb_bonus: float = 0.0
	if GuildManager:
		for member in GuildManager.guild_members:
			celeb_bonus += member.get_celebrity_bonus_recruitment()
	celeb_bonus = minf(celeb_bonus, 0.2)

	var reputation_bonus: float = 0.0
	if guild_data.has("reputation"):
		reputation_bonus = (float(guild_data.reputation) - 50.0) * BalanceManager.tunable_float("recruitment.reputation_weight", 0.01)

	var quality_bonus: float = 0.0
	if GuildManager and GuildManager.guild:
		quality_bonus = GuildManager.guild.get_recruitment_quality_bonus()

	var chance: float = base_chance + fit_bonus + celeb_bonus + reputation_bonus + quality_bonus - difficulty * 0.55
	if BalanceManager:
		chance *= BalanceManager.get_recruit_chance_mult()
	chance = clampf(chance, 0.02, 0.95)
	if is_player_on_recruitment_cooldown(player):
		chance = 0.0

	return {
		"chance": chance,
		"difficulty": difficulty,
		"fit": fit_bonus,
		"label": _get_chance_label(chance),
		"reasons": _get_recruitment_breakdown(player, guild_data, difficulty, fit_bonus, celeb_bonus, reputation_bonus, quality_bonus),
	}

func _calculate_guild_fit_bonus(player: SimulatedPlayer, guild_data: Dictionary) -> float:
	var fit: float = 0.0
	var expectations: Dictionary = player.get_meta("expected_activity", {})

	var expects_hardcore: bool = bool(expectations.get("hardcore", false))
	var guild_hardcore: bool = bool(guild_data.get("hardcore", false))
	if expects_hardcore == guild_hardcore:
		fit += 0.12
	else:
		fit -= 0.08

	var guild_size: int = int(guild_data.get("guild_size", 0))
	if player.has_tag("solitaire") and guild_size <= 12:
		fit += 0.06
	if player.has_tag("social") and guild_size >= 8:
		fit += 0.06
	if player.has_tag("ambitieux") and bool(guild_data.get("recent_raid_success", false)):
		fit += 0.10
	if player.has_tag("casual") and not guild_hardcore:
		fit += 0.05
	if player.has_tag("tryhard") and not guild_hardcore:
		fit -= 0.05

	return clampf(fit, -0.18, 0.24)

func _get_recruitment_breakdown(
	player: SimulatedPlayer,
	_guild_data: Dictionary,
	difficulty: float,
	fit_bonus: float,
	celeb_bonus: float,
	reputation_bonus: float,
	quality_bonus: float
) -> Array[String]:
	var reasons: Array[String] = []
	reasons.append("Profil %.0f%% difficile" % (difficulty * 100.0))
	if fit_bonus >= 0.08:
		reasons.append("bon fit avec la guilde")
	elif fit_bonus <= -0.05:
		reasons.append("attentes mal alignees")
	if celeb_bonus > 0.0:
		reasons.append("membres connus attractifs")
	if reputation_bonus > 0.0:
		reasons.append("bonne reputation")
	elif reputation_bonus < 0.0:
		reasons.append("reputation a ameliorer")
	if quality_bonus > 0.0:
		reasons.append("perks de recrutement")
	if int(player.get_meta("offers_received", 0)) > 0:
		reasons.append("%d offre(s) concurrentes" % int(player.get_meta("offers_received", 0)))
	return reasons

func _get_chance_label(chance: float) -> String:
	if chance >= 0.75:
		return "Tres favorable"
	if chance >= 0.55:
		return "Favorable"
	if chance >= 0.35:
		return "Incertain"
	if chance >= 0.18:
		return "Difficile"
	return "Tres difficile"

func _can_finalize_recruitment(player: SimulatedPlayer) -> Dictionary:
	if not GuildManager or not GuildManager.guild:
		return {"ok": false, "reason": "Aucune guilde active"}
	if player not in available_players:
		return {"ok": false, "reason": "Joueur non disponible"}
	if not GuildManager.guild.can_recruit():
		return {"ok": false, "reason": "Votre guilde doit atteindre le niveau 2 pour recruter"}
	var max_members: int = GuildManager.guild.get_effective_max_members()
	if GuildManager.guild_members.size() >= max_members:
		return {"ok": false, "reason": "La guilde est pleine (%d/%d)" % [GuildManager.guild_members.size(), max_members]}
	if player in GuildManager.guild_members:
		return {"ok": false, "reason": "Joueur deja membre de la guilde"}
	return {"ok": true, "reason": ""}

func _finalize_recruitment(player: SimulatedPlayer, extra: Dictionary = {}) -> Dictionary:
	var validation: Dictionary = _can_finalize_recruitment(player)
	if not bool(validation.get("ok", false)):
		return {
			"success": false,
			"step": "error",
			"reason": String(validation.get("reason", "")),
			"player": player,
		}

	var added: bool = GuildManager.add_member(player)
	if not added:
		return {
			"success": false,
			"step": "error",
			"reason": "Acceptation annulee : impossible d'ajouter %s a la guilde" % player.nom,
			"player": player,
		}

	available_players.erase(player)
	player.set_meta("recruited_day", _get_total_days_elapsed())
	player_recruited.emit(player)
	pool_refreshed.emit()

	var result: Dictionary = {
		"success": true,
		"player": player,
		"step": extra.get("step", "accepted"),
		"reason": extra.get("message", "%s rejoint la guilde." % player.nom),
	}
	for key in extra.keys():
		result[key] = extra[key]
	return result

func _mark_recruitment_refused(player: SimulatedPlayer, reason: String, chance: float) -> Dictionary:
	var attempts: int = int(player.get_meta("recruitment_attempts", 0)) + 1
	player.set_meta("recruitment_attempts", attempts)
	player.set_meta("last_rejection_reason", reason)
	player.set_meta("recruitment_cooldown_until_ts", _get_current_timestamp() + float(REJECTION_COOLDOWN_SECONDS))
	player.set_meta("offers_received", int(player.get_meta("offers_received", 0)) + 1)
	_update_recruitment_profile(player)
	pool_refreshed.emit()
	return {
		"success": false,
		"step": "rejected",
		"reason": "%s\nVous pourrez le relancer dans 24h." % reason,
		"cooldown_hours": get_recruitment_cooldown_remaining_hours(player),
		"chance": chance,
		"player": player,
	}

func _generate_acceptance_message(player: SimulatedPlayer, chance: float) -> String:
	var lines: Array[String] = [
		"%s accepte l'invitation et rejoint la guilde." % player.nom,
		"%s signe apres un bon echange. Le roster gagne une vraie option." % player.nom,
		"%s rejoint la guilde. Il veut etre teste rapidement en donjon." % player.nom,
	]
	if chance < 0.30:
		lines.append("%s accepte contre toute attente. Joli coup de recrutement." % player.nom)
	if player.has_tag("social"):
		lines.append("%s rejoint et demande deja qui est dispo ce soir." % player.nom)
	if player.has_tag("ambitieux"):
		lines.append("%s rejoint, mais il faudra lui montrer que la guilde avance." % player.nom)
	return lines[randi() % lines.size()]

func _generate_rejection_reasons(player: SimulatedPlayer, guild_data: Dictionary) -> Array:
	var reasons: Array = []

	var expectations = player.get_meta("expected_activity", {})
	
	if bool(expectations.get("hardcore", false)) and not bool(guild_data.get("hardcore", false)):
		reasons.append("Cherche une guilde plus compétitive")
	elif not bool(expectations.get("hardcore", false)) and bool(guild_data.get("hardcore", false)):
		reasons.append("Préfère une guilde plus casual")
	
	if int(guild_data.get("guild_size", 0)) < 10:
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
			var level_gain: int = randi_range(1, mini(5, max_level - player.personnage_niveau))
			player.personnage_niveau += level_gain
			if randf() < 0.7:
				player.try_auto_equip(LootTablesScript.generate_item_for_level(player.personnage_niveau))
			_update_recruitment_profile(player)
			# L'équipement ne suit plus automatiquement le niveau avec le nouveau système
	
	pool_refreshed.emit()

func get_player_info(player: SimulatedPlayer) -> Dictionary:
	return {
		"recruitment_info": player.get_recruitment_info(),
		"motivation": player.get_meta("recruitment_motivation", ""),
		"expected_activity": player.get_meta("expected_activity", {}),
		"difficulty": player.get_meta("recruitment_difficulty", 0.5),
		"days_remaining": get_candidate_days_remaining(player),
		"cooldown_hours": get_recruitment_cooldown_remaining_hours(player),
		"market_story": player.get_meta("market_story", "")
	}

func get_current_guild_recruitment_data() -> Dictionary:
	return _get_guild_data()

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
	player.set_meta("is_national", true)
	_initialize_market_candidate(player, true)
	player.set_meta("recruitment_motivation", national_motivations[randi() % national_motivations.size()])
	_update_recruitment_profile(player)

	return player

func attempt_national_recruitment(player: SimulatedPlayer, offered_salary: int) -> Dictionary:
	"""Tente de recruter un joueur national avec negociation salariale."""
	if player not in available_players:
		return {"success": false, "reason": "Joueur non disponible", "step": "error"}
	_ensure_candidate_meta(player)
	if is_player_on_recruitment_cooldown(player):
		return {
			"success": false,
			"reason": "%s ne veut pas renegocier tout de suite." % player.nom,
			"step": "cooldown",
			"cooldown_hours": get_recruitment_cooldown_remaining_hours(player),
		}

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
		return _mark_recruitment_refused(player, "Offre insuffisante (%d/%d or)" % [offered_salary, demand], 0.0)

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

	var validation: Dictionary = _can_finalize_recruitment(player)
	if not bool(validation.get("ok", false)):
		return {
			"success": false,
			"step": "error",
			"reason": String(validation.get("reason", "")),
		}

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
	var result: Dictionary = _finalize_recruitment(player, {
		"salary": salary,
		"agent_cost": agent_cost,
		"step": "accepted",
		"message": "%s rejoint la guilde pour %d or/semaine." % [player.nom, salary],
	})
	if not result.get("success", false) and agent_cost > 0 and GuildManager.guild:
		GuildManager.guild.add_gold(agent_cost)
	return result

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
		# Variante effective : la réputation tient compte des effets actifs (sinon = valeur de base).
		data["reputation"] = GuildManager.guild.get_effective_reputation()
		data["recent_raid_success"] = false
		if GuildRanking:
			data["recent_raid_success"] = GuildRanking.get_player_recent_clears(7).size() > 0
		data["hardcore"] = _estimate_guild_hardcore_profile()
	return data

func _estimate_guild_hardcore_profile() -> bool:
	if not GuildManager or GuildManager.guild_members.is_empty():
		return false
	var total_level: int = 0
	var total_skill: int = 0
	for member in GuildManager.guild_members:
		total_level += member.personnage_niveau
		total_skill += member.skill
	var avg_level: float = float(total_level) / float(GuildManager.guild_members.size())
	var avg_skill: float = float(total_skill) / float(GuildManager.guild_members.size())
	return avg_level >= float(_get_current_max_player_level()) * 0.75 or avg_skill >= 65.0

