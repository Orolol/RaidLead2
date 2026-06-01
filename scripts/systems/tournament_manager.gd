extends Node

## Gere les tournois internationaux (Phase Esport, US 4.2).
## Le joueur peut preparer son equipe (bootcamp) puis participer a des tournois
## simules en bracket. Les victoires rapportent or, prestige international et,
## pour le Championnat du Monde, comptent vers la progression de la phase finale.

signal tournament_available(tournament)
signal tournament_completed(tournament, stage_reached, is_champion, results)
signal bootcamp_started(performance_bonus)

const MAX_OFFERS := 3
const OFFER_INTERVAL_WEEKS := 3
const ROSTER_SIZE := 10
const BOOTCAMP_COST := 2000
const BOOTCAMP_PERF := 0.15
const BOOTCAMP_STRESS := 12.0
const REPUTATION_DECAY := 0.15  # par semaine, oblige a rester actif

const REGIONS := ["Europe", "Amérique", "Asie", "Océanie", "Amérique du Sud"]

var available_tournaments: Array = []   # Array[Tournament]
var world_championship_wins: int = 0
var total_tournaments_won: int = 0
var international_reputation: float = 50.0  # 0-100
var bootcamp_bonus: float = 0.0
var weeks_since_offer: int = 0
var last_results: Dictionary = {}

func _ready() -> void:
	if GameTime and GameTime.has_signal("week_changed"):
		GameTime.week_changed.connect(_on_week_changed)
	_seed_offers()

func _on_week_changed(_week: int, _year: int) -> void:
	weeks_since_offer += 1
	if available_tournaments.size() < MAX_OFFERS and weeks_since_offer >= OFFER_INTERVAL_WEEKS:
		var t: Tournament = _generate_tournament()
		available_tournaments.append(t)
		weeks_since_offer = 0
		tournament_available.emit(t)
	# Le bonus de bootcamp se dissipe lentement s'il n'est pas utilise
	if bootcamp_bonus > 0.0:
		bootcamp_bonus = maxf(0.0, bootcamp_bonus - 0.02)
	# La reputation internationale decroit : il faut continuer a performer
	international_reputation = maxf(0.0, international_reputation - REPUTATION_DECAY)

# --- Generation des offres ---

func _seed_offers() -> void:
	available_tournaments.clear()
	available_tournaments.append(_make_tournament(Tournament.TournamentType.REGIONAL_QUALIFIER))
	available_tournaments.append(_make_tournament(Tournament.TournamentType.INVITATIONAL))

func _generate_tournament() -> Tournament:
	var r: float = randf()
	if r < 0.15:
		return _make_tournament(Tournament.TournamentType.WORLD_CHAMPIONSHIP)
	elif r < 0.5:
		return _make_tournament(Tournament.TournamentType.INVITATIONAL)
	return _make_tournament(Tournament.TournamentType.REGIONAL_QUALIFIER)

func _make_tournament(type: int) -> Tournament:
	var region: String = REGIONS[randi() % REGIONS.size()]
	match type:
		Tournament.TournamentType.WORLD_CHAMPIONSHIP:
			return Tournament.new("Championnat du Monde", type as Tournament.TournamentType,
				85.0, 5, 12000, 30.0, "Mondial")
		Tournament.TournamentType.INVITATIONAL:
			return Tournament.new("Invitational %s" % region, type as Tournament.TournamentType,
				72.0, 4, 4500, 15.0, region)
		_:
			return Tournament.new("Qualifications %s" % region, type as Tournament.TournamentType,
				60.0, 3, 1500, 8.0, region)

# --- Preparation ---

func run_bootcamp() -> bool:
	"""Bootcamp de preparation : ameliore la performance du prochain tournoi mais
	ajoute du stress a l'equipe et coute de l'or."""
	if not GuildManager.guild or not GuildManager.guild.spend_gold(BOOTCAMP_COST):
		return false
	bootcamp_bonus = minf(0.3, bootcamp_bonus + BOOTCAMP_PERF)
	for member in GuildManager.guild_members:
		if member.has_method("add_stress"):
			member.add_stress(BOOTCAMP_STRESS)
	bootcamp_started.emit(bootcamp_bonus)
	return true

# --- Force de l'equipe ---

func get_roster_strength() -> float:
	"""Force de l'equipe : moyenne de puissance des meilleurs joueurs, amplifiee par
	le staff (coach) et le bootcamp, reduite par le stress."""
	var powered: Array = []
	for m in GuildManager.guild_members:
		powered.append(_member_power(m))
	if powered.is_empty():
		return 0.0
	powered.sort_custom(func(a, b): return a > b)
	var n: int = mini(ROSTER_SIZE, powered.size())
	var total: float = 0.0
	for i in range(n):
		total += powered[i]
	var avg: float = total / float(n)
	var staff_perf: float = StaffManager.get_total_performance_bonus() if StaffManager else 0.0
	avg *= (1.0 + staff_perf + bootcamp_bonus)
	return avg

func _member_power(member) -> float:
	var base: float = float(member.skill)
	var ilvl_bonus: float = float(member.get_total_ilvl()) * 0.2
	var perf: float = 1.0
	if member.has_method("get_esport_performance_factor"):
		perf = member.get_esport_performance_factor()
	return (base + ilvl_bonus) * perf

# --- Participation ---

func participate(tournament) -> Dictionary:
	"""Simule la participation a un tournoi en bracket et applique les recompenses."""
	# Garde-fous : réservé à la phase Esport, avec un roster minimum (sinon victoire
	# par chance sur un effectif vide, et tournois spammables sans enjeu).
	if PhaseManager and PhaseManager.get_current_phase() < PhaseManager.GamePhase.ESPORT:
		_notify_tournament_blocked("Les tournois ne sont disponibles qu'en phase Esport.")
		return {"success": false, "reason": "phase"}
	if not GuildManager or GuildManager.guild_members.size() < 5:
		_notify_tournament_blocked("Roster insuffisant : 5 membres minimum pour participer.")
		return {"success": false, "reason": "roster"}

	var strength: float = get_roster_strength()
	var strategy: float = StaffManager.get_total_strategy_bonus() if StaffManager else 0.0
	var stage_reached: int = 0
	var round_logs: Array = []

	for r in range(tournament.rounds):
		var opp: float = tournament.difficulty + r * 4.0  # adversaires plus forts a chaque tour
		var win_prob: float = clampf(strength / (strength + opp) + strategy, 0.05, 0.95)
		var won: bool = randf() < win_prob
		round_logs.append({"round": r + 1, "win_prob": win_prob, "won": won})
		if won:
			stage_reached += 1
		else:
			break

	var is_champion: bool = stage_reached >= tournament.rounds
	var gold: int = tournament.get_reward_gold(stage_reached)
	var prestige: float = tournament.get_prestige_reward(stage_reached)

	if GuildManager.guild and gold > 0:
		GuildManager.guild.add_gold(gold)
	international_reputation = clampf(international_reputation + prestige, 0.0, 100.0)
	# Échec précoce (éliminé au 1er tour) : vraie pénalité, pour créer un enjeu de préparation.
	if stage_reached == 0:
		international_reputation = clampf(international_reputation - 3.0, 0.0, 100.0)

	if is_champion:
		total_tournaments_won += 1
		if tournament.is_world_championship():
			world_championship_wins += 1
			if GuildManager.guild:
				GuildManager.guild.on_world_first(tournament.tournament_name)

	# Stress de competition : perdre stresse davantage que triompher
	for member in GuildManager.guild_members:
		if member.has_method("add_stress"):
			member.add_stress(6.0 if is_champion else 12.0)

	bootcamp_bonus = 0.0  # consomme
	available_tournaments.erase(tournament)

	var results: Dictionary = {
		"tournament": tournament.tournament_name,
		"type": tournament.get_type_name(),
		"stage_reached": stage_reached,
		"rounds": tournament.rounds,
		"is_champion": is_champion,
		"gold": gold,
		"prestige": prestige,
		"rounds_log": round_logs,
	}
	last_results = results
	tournament_completed.emit(tournament, stage_reached, is_champion, results)
	return results

# --- Accesseurs ---

func _notify_tournament_blocked(msg: String) -> void:
	var nm = get_node_or_null("/root/NotificationManager")
	if nm and nm.has_method("show_warning"):
		nm.show_warning(msg, "Tournoi")

func get_international_reputation() -> float:
	return international_reputation

func get_world_championship_wins() -> int:
	return world_championship_wins

# --- Sauvegarde ---

func serialize() -> Dictionary:
	var offers: Array = []
	for t in available_tournaments:
		offers.append(t.serialize())
	return {
		"world_championship_wins": world_championship_wins,
		"total_tournaments_won": total_tournaments_won,
		"international_reputation": international_reputation,
		"bootcamp_bonus": bootcamp_bonus,
		"weeks_since_offer": weeks_since_offer,
		"available_tournaments": offers,
		"last_results": last_results,
	}

func deserialize(data: Dictionary) -> void:
	world_championship_wins = data.get("world_championship_wins", 0)
	total_tournaments_won = data.get("total_tournaments_won", 0)
	international_reputation = data.get("international_reputation", 50.0)
	bootcamp_bonus = data.get("bootcamp_bonus", 0.0)
	weeks_since_offer = data.get("weeks_since_offer", 0)
	last_results = data.get("last_results", {})
	available_tournaments.clear()
	for td in data.get("available_tournaments", []):
		available_tournaments.append(Tournament.deserialize(td))
	if available_tournaments.is_empty():
		_seed_offers()
