extends Resource
class_name Tournament

## Represente un tournoi esport (Phase Esport, US 4.2).
## Un tournoi se joue en plusieurs tours (bracket) ; le nombre de tours remportes
## determine les recompenses (or et prestige international).

enum TournamentType { REGIONAL_QUALIFIER, INVITATIONAL, WORLD_CHAMPIONSHIP }

@export var tournament_name: String = ""
@export var tournament_type: TournamentType = TournamentType.REGIONAL_QUALIFIER
@export var difficulty: float = 60.0   # force moyenne des adversaires (0-100)
@export var rounds: int = 3            # nombre de tours dans le bracket
@export var base_prize: int = 1500     # or pour le vainqueur
@export var prestige: float = 8.0      # reputation internationale pour le vainqueur
@export var region: String = "International"

func _init(p_name: String = "", p_type: TournamentType = TournamentType.REGIONAL_QUALIFIER,
		p_difficulty: float = 60.0, p_rounds: int = 3, p_prize: int = 1500,
		p_prestige: float = 8.0, p_region: String = "International") -> void:
	tournament_name = p_name
	tournament_type = p_type
	difficulty = p_difficulty
	rounds = p_rounds
	base_prize = p_prize
	prestige = p_prestige
	region = p_region

func get_type_name() -> String:
	match tournament_type:
		TournamentType.REGIONAL_QUALIFIER: return "Qualifications régionales"
		TournamentType.INVITATIONAL: return "Invitational"
		TournamentType.WORLD_CHAMPIONSHIP: return "Championnat du Monde"
		_: return "Tournoi"

func is_world_championship() -> bool:
	return tournament_type == TournamentType.WORLD_CHAMPIONSHIP

func get_reward_gold(stage_reached: int) -> int:
	"""Or gagne selon le nombre de tours remportes (champion = prix complet)."""
	if stage_reached >= rounds:
		return base_prize
	return int(base_prize * 0.15 * stage_reached)

func get_prestige_reward(stage_reached: int) -> float:
	"""Prestige international gagne selon le parcours (champion = prestige complet)."""
	if stage_reached >= rounds:
		return prestige
	return prestige * 0.4 * (float(stage_reached) / float(maxi(1, rounds)))

func serialize() -> Dictionary:
	return {
		"tournament_name": tournament_name,
		"tournament_type": tournament_type,
		"difficulty": difficulty,
		"rounds": rounds,
		"base_prize": base_prize,
		"prestige": prestige,
		"region": region,
	}

static func deserialize(data: Dictionary) -> Tournament:
	return Tournament.new(
		data.get("tournament_name", ""),
		data.get("tournament_type", 0) as TournamentType,
		data.get("difficulty", 60.0),
		data.get("rounds", 3),
		data.get("base_prize", 1500),
		data.get("prestige", 8.0),
		data.get("region", "International"),
	)
