extends Node

## Équilibrage adaptatif de la difficulté (Milestone 6, US 6.4).
## - Presets de difficulté : Détendu / Normal / Difficile.
## - Catch-up : aide douce (or + moral) quand le joueur est à la traîne (rang, trésorerie, moral).
## - Rubber-band : les guildes IA progressent un peu plus vite quand le joueur domine durablement.
## - Modificateurs lus par RecruitmentPool (chance de recrutement) et AIGuild (progression PvE).
##
## Le réglage de difficulté est sauvegardé (SaveManager). Tout le reste est recalculé en direct.

signal difficulty_changed(new_difficulty: int)
signal catchup_applied(gold: int)

enum Difficulty { RELAXED, NORMAL, HARD }

const DIFFICULTY_PRESETS := {
	Difficulty.RELAXED: {
		"name": "Détendu",
		"desc": "Aide renforcée, IA plus lentes. Idéal pour découvrir le jeu sans pression.",
		"catchup": 1.6, "recruit": 1.25, "ai_progression": 0.8, "weekly_stipend": 150,
	},
	Difficulty.NORMAL: {
		"name": "Normal",
		"desc": "Équilibre standard avec un catch-up modéré quand vous décrochez.",
		"catchup": 1.0, "recruit": 1.0, "ai_progression": 1.0, "weekly_stipend": 0,
	},
	Difficulty.HARD: {
		"name": "Difficile",
		"desc": "Peu d'aide, IA tenaces qui reviennent vite. Pour les vétérans.",
		"catchup": 0.4, "recruit": 0.85, "ai_progression": 1.15, "weekly_stipend": 0,
	},
}

const STRUGGLE_THRESHOLD := 0.4
const DOMINANCE_THRESHOLD := 0.5
const TOTAL_GUILDS := 10  # joueur + 9 IA

## Façade centrale des constantes d'équilibrage (audit Priorité 12).
## Regroupe les nombres « magiques » les plus susceptibles d'être ajustés, pour
## équilibrer sans éditer 15 scripts. Les systèmes lisent via BalanceManager.tunable("clé", défaut) ;
## la valeur par défaut au point d'appel documente la valeur historique. Étendre ce dictionnaire
## plutôt que de réintroduire des constantes éparpillées.
const BALANCE := {
	# Recrutement
	"recruitment.base_chance": 0.5,          # chance de base d'acceptation (attempt_recruitment)
	"recruitment.reputation_weight": 0.01,   # poids de (réputation-50) sur la chance
	# Salaires (non-paiement)
	"salary.unpaid_mood_penalty": 15.0,      # moral perdu par salarié impayé
	"salary.unpaid_reputation_loss": 3.0,    # réputation perdue si salaires impayés
	# Réputation
	"reputation.scout_cost": 2.0,            # coût en réputation d'un scouting
	# PvE — récompenses & malus appliqués en combat / aperçu de run
	"pve.gold_reward_mult": 1.0,        # multiplicateur d'or versé à la guilde par clear
	"pve.low_energy_threshold": 30.0,
	"pve.low_energy_penalty": 0.7,
	"pve.low_morale_threshold": 40.0,
	"pve.low_morale_penalty": 0.8,
	# Classement (poids de score, miroir de GuildRanking.SCORE_WEIGHTS pour référence)
	"ranking.weight.pve_progress": 0.4,
	"ranking.weight.guild_level": 0.2,
	"ranking.weight.member_activity": 0.15,
	"ranking.weight.reputation": 0.15,
	"ranking.weight.stability": 0.1,
}

func tunable(key: String, fallback = null) -> Variant:
	"""Lit une constante d'équilibrage centralisée (BALANCE), avec repli explicite."""
	return BALANCE.get(key, fallback)

func tunable_float(key: String, fallback: float) -> float:
	return float(BALANCE.get(key, fallback))

var current_difficulty: int = Difficulty.NORMAL

# Derniers calculs (exposés à l'UI / debug)
var last_struggle: float = 0.0   # 0..1
var last_dominance: float = 0.0  # 0..1
var last_rank: int = 0
var last_catchup_gold: int = 0
var total_catchup_gold: int = 0
var weeks_dominating: int = 0

func _ready() -> void:
	if GameTime and GameTime.has_signal("week_changed"):
		GameTime.week_changed.connect(_on_week_changed)

# --- Réglage de difficulté ---

func set_difficulty(d: int) -> void:
	var nd: int = clampi(d, 0, 2)
	if nd == current_difficulty:
		return
	current_difficulty = nd
	difficulty_changed.emit(current_difficulty)

func get_difficulty() -> int:
	return current_difficulty

func _preset() -> Dictionary:
	return DIFFICULTY_PRESETS[current_difficulty]

func get_difficulty_name() -> String:
	return _preset().get("name", "Normal")

func get_difficulty_desc() -> String:
	return _preset().get("desc", "")

# --- Évaluation du standing (galère vs domination) ---

func compute_standing() -> Dictionary:
	"""Évalue à quel point le joueur galère (struggle) ou domine (dominance), 0..1 chacun."""
	var struggle: float = 0.0
	var dominance: float = 0.0

	var rank: int = 0
	if GuildRanking and GuildRanking.has_method("get_player_guild_position"):
		rank = GuildRanking.get_player_guild_position()
	if rank > 0:
		var frac: float = float(rank - 1) / float(max(1, TOTAL_GUILDS - 1))  # 0 = 1er, 1 = dernier
		struggle += frac * 0.5
		if rank == 1:
			dominance += 0.5

	if GuildManager and GuildManager.guild:
		var salaries: int = GuildManager.get_total_weekly_salaries()
		var gold: int = GuildManager.guild.gold
		if salaries > 0 and gold < salaries:
			struggle += 0.3
		elif gold > maxi(5000, salaries * 8):
			dominance += 0.25

	var morale: float = _get_morale()
	if morale < 40.0:
		struggle += 0.2
	elif morale > 80.0:
		dominance += 0.25

	last_struggle = clampf(struggle, 0.0, 1.0)
	last_dominance = clampf(dominance, 0.0, 1.0)
	last_rank = rank
	return {"struggle": last_struggle, "dominance": last_dominance, "rank": rank}

func _get_morale() -> float:
	var gcm: Node = get_node_or_null("/root/GuildCultureManager")
	if gcm and gcm.has_method("get_guild_morale"):
		return gcm.get_guild_morale()
	return 65.0

# --- Application hebdomadaire ---

func _on_week_changed(_week: int, _year: int) -> void:
	var st: Dictionary = compute_standing()
	if st.get("dominance", 0.0) >= DOMINANCE_THRESHOLD:
		weeks_dominating += 1
	else:
		weeks_dominating = 0
	_apply_catchup(st)
	_apply_stipend()

func _apply_catchup(st: Dictionary) -> void:
	last_catchup_gold = 0
	var struggle: float = st.get("struggle", 0.0)
	if struggle < STRUGGLE_THRESHOLD:
		return
	var strength: float = _preset().get("catchup", 1.0)
	if strength <= 0.0 or not GuildManager or not GuildManager.guild:
		return

	var gold_aid: int = int(struggle * 300.0 * strength)
	if gold_aid > 0:
		GuildManager.guild.add_gold(gold_aid)
		last_catchup_gold = gold_aid
		total_catchup_gold += gold_aid
		catchup_applied.emit(gold_aid)

	# Soutien de moral : plancher doux pour éviter la spirale
	var gcm: Node = get_node_or_null("/root/GuildCultureManager")
	if gcm and gcm.has_method("get_guild_morale") and gcm.get_guild_morale() < 45.0:
		gcm.guild_morale = minf(50.0, gcm.guild_morale + 3.0 * strength)

func _apply_stipend() -> void:
	var stipend: int = _preset().get("weekly_stipend", 0)
	if stipend > 0 and GuildManager and GuildManager.guild:
		GuildManager.guild.add_gold(stipend)

# --- Modificateurs lus par les autres systèmes ---

func get_recruit_chance_mult() -> float:
	"""Chance de recrutement du joueur : preset × bonus catch-up si à la traîne. Recalcule le standing."""
	compute_standing()
	var m: float = _preset().get("recruit", 1.0)
	m *= 1.0 + last_struggle * 0.3 * _preset().get("catchup", 1.0)
	return clampf(m, 0.5, 1.8)

func get_ai_progression_mult() -> float:
	"""Vitesse de progression PvE des IA : preset × rubber-band si le joueur domine durablement."""
	var m: float = _preset().get("ai_progression", 1.0)
	if weeks_dominating >= 2:
		m *= 1.0 + minf(0.25, (weeks_dominating - 1) * 0.05) * last_dominance
	return m

func get_status() -> Dictionary:
	"""État courant pour l'UI."""
	compute_standing()
	return {
		"difficulty": current_difficulty,
		"difficulty_name": get_difficulty_name(),
		"struggle": last_struggle,
		"dominance": last_dominance,
		"rank": last_rank,
		"weeks_dominating": weeks_dominating,
		"last_catchup_gold": last_catchup_gold,
		"total_catchup_gold": total_catchup_gold,
		"recruit_mult": get_recruit_chance_mult(),
		"ai_progression_mult": get_ai_progression_mult(),
	}

# --- Sauvegarde ---

func serialize() -> Dictionary:
	return {
		"difficulty": current_difficulty,
		"total_catchup_gold": total_catchup_gold,
		"weeks_dominating": weeks_dominating,
	}

func deserialize(data: Dictionary) -> void:
	current_difficulty = clampi(int(data.get("difficulty", Difficulty.NORMAL)), 0, 2)
	total_catchup_gold = int(data.get("total_catchup_gold", 0))
	weeks_dominating = int(data.get("weeks_dominating", 0))
