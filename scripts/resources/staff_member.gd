extends Resource
class_name StaffMember

## Represente un membre du staff professionnel (Phase Esport).
## Chaque role apporte des bonus differents, mis a l'echelle par le skill (1-100).

enum StaffRole { COACH, ANALYST, PSYCHOLOGIST, MANAGER }

@export var staff_name: String = ""
@export var role: StaffRole = StaffRole.COACH
@export var skill_level: int = 50  # 1-100
@export var weekly_salary: int = 300
@export var hired: bool = false

func _init(p_name: String = "", p_role: StaffRole = StaffRole.COACH, p_skill: int = 50, p_salary: int = 300) -> void:
	staff_name = p_name
	role = p_role
	skill_level = p_skill
	weekly_salary = p_salary

func get_role_name() -> String:
	match role:
		StaffRole.COACH: return "Coach stratégique"
		StaffRole.ANALYST: return "Analyste"
		StaffRole.PSYCHOLOGIST: return "Psychologue"
		StaffRole.MANAGER: return "Manager"
		_: return "Inconnu"

func get_role_short() -> String:
	match role:
		StaffRole.COACH: return "Coach"
		StaffRole.ANALYST: return "Analyste"
		StaffRole.PSYCHOLOGIST: return "Psy"
		StaffRole.MANAGER: return "Manager"
		_: return "?"

func get_role_description() -> String:
	match role:
		StaffRole.COACH: return "Améliore la performance et la stratégie de l'équipe en compétition."
		StaffRole.ANALYST: return "Augmente fortement les probabilités de victoire en tournoi."
		StaffRole.PSYCHOLOGIST: return "Réduit le stress des joueurs et prévient le burnout."
		StaffRole.MANAGER: return "Stabilise l'équipe et optimise la masse salariale du staff."
		_: return ""

func _skill_factor() -> float:
	return clampf(float(skill_level) / 100.0, 0.0, 1.0)

func get_performance_bonus() -> float:
	"""Bonus multiplicatif de force de l'equipe en competition (0-1)."""
	if role == StaffRole.COACH:
		return 0.15 * _skill_factor()
	return 0.0

func get_strategy_bonus() -> float:
	"""Bonus a la probabilite de victoire en tournoi (0-1)."""
	match role:
		StaffRole.ANALYST:
			return 0.20 * _skill_factor()
		StaffRole.COACH:
			return 0.10 * _skill_factor()
		_:
			return 0.0

func get_stress_relief() -> float:
	"""Reduction de stress hebdomadaire apportee aux joueurs."""
	if role == StaffRole.PSYCHOLOGIST:
		return 8.0 * _skill_factor()
	return 0.0

func get_morale_bonus() -> float:
	"""Bonus de moral hebdomadaire apporte a l'equipe."""
	match role:
		StaffRole.PSYCHOLOGIST:
			return 4.0 * _skill_factor()
		StaffRole.MANAGER:
			return 2.0 * _skill_factor()
		_:
			return 0.0

func get_stability_bonus() -> float:
	"""Contribution a la stabilite d'equipe (0-100)."""
	if role == StaffRole.MANAGER:
		return 10.0 * _skill_factor()
	return 0.0

func get_salary_efficiency() -> float:
	"""Reduction fractionnaire de la masse salariale du staff (0-1)."""
	if role == StaffRole.MANAGER:
		return 0.15 * _skill_factor()
	return 0.0

func get_quality_tier() -> String:
	if skill_level >= 85:
		return "Élite"
	elif skill_level >= 70:
		return "Confirmé"
	elif skill_level >= 50:
		return "Compétent"
	else:
		return "Débutant"

func serialize() -> Dictionary:
	return {
		"staff_name": staff_name,
		"role": role,
		"skill_level": skill_level,
		"weekly_salary": weekly_salary,
		"hired": hired,
	}

static func deserialize(data: Dictionary) -> StaffMember:
	var s := StaffMember.new(
		data.get("staff_name", ""),
		data.get("role", 0) as StaffRole,
		data.get("skill_level", 50),
		data.get("weekly_salary", 300),
	)
	s.hired = data.get("hired", false)
	return s
