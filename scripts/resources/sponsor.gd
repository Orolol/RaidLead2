extends Resource
class_name Sponsor

## Represente un contrat de sponsor pour la guilde.

@export var sponsor_name: String = ""
@export var sponsor_type: String = "marque_gaming"  # "equipementier" | "marque_gaming" | "plateforme"
@export var weekly_revenue: int = 100
@export var duration_weeks: int = 12
@export var weeks_remaining: int = 12
@export var satisfaction: float = 100.0

# Exigences du sponsor
@export var min_reputation: float = 60.0
@export var min_members: int = 10
@export var min_audience: int = 0  # audience totale des streamers
@export var no_scandal_weeks: int = 2  # semaines sans scandale requises (assoupli : était 4)

var active: bool = true

func _init(p_name: String = "", p_type: String = "marque_gaming", p_revenue: int = 100, p_duration: int = 12) -> void:
	sponsor_name = p_name
	sponsor_type = p_type
	weekly_revenue = p_revenue
	duration_weeks = p_duration
	weeks_remaining = p_duration

func check_requirements(reputation: float, member_count: int, total_audience: int, weeks_since_scandal: int) -> bool:
	"""Verifie si les exigences du sponsor sont remplies."""
	return reputation >= min_reputation and member_count >= min_members and total_audience >= min_audience and weeks_since_scandal >= no_scandal_weeks

func tick_week(requirements_met: bool) -> void:
	"""Mise a jour hebdomadaire du contrat."""
	weeks_remaining -= 1
	if requirements_met:
		satisfaction = minf(100.0, satisfaction + 4.0)   # récupération plus rapide
	else:
		satisfaction -= 6.0                              # pénalité adoucie (était -10), un scandale reste rattrapable

	if weeks_remaining <= 0 or satisfaction <= 0.0:
		active = false

func get_status_text() -> String:
	if not active:
		return "Expire"
	return "%s sem. restantes (Satisfaction: %d%%)" % [weeks_remaining, int(satisfaction)]

func serialize() -> Dictionary:
	return {
		"sponsor_name": sponsor_name,
		"sponsor_type": sponsor_type,
		"weekly_revenue": weekly_revenue,
		"duration_weeks": duration_weeks,
		"weeks_remaining": weeks_remaining,
		"satisfaction": satisfaction,
		"min_reputation": min_reputation,
		"min_members": min_members,
		"min_audience": min_audience,
		"no_scandal_weeks": no_scandal_weeks,
		"active": active,
	}

static func deserialize(data: Dictionary) -> Sponsor:
	var s := Sponsor.new(
		data.get("sponsor_name", ""),
		data.get("sponsor_type", "marque_gaming"),
		data.get("weekly_revenue", 100),
		data.get("duration_weeks", 12),
	)
	s.weeks_remaining = data.get("weeks_remaining", 12)
	s.satisfaction = data.get("satisfaction", 100.0)
	s.min_reputation = data.get("min_reputation", 60.0)
	s.min_members = data.get("min_members", 10)
	s.min_audience = data.get("min_audience", 0)
	s.no_scandal_weeks = data.get("no_scandal_weeks", 2)
	s.active = data.get("active", true)
	return s
