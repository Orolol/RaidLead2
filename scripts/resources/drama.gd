extends Resource
class_name Drama

## Represente un drama/crise affectant la guilde.

enum DramaType { SCANDAL, INTERNAL_CONFLICT, PUBLIC_CONTROVERSY, LOOT_RAGE }
enum Severity { LOW = 1, MEDIUM = 2, HIGH = 3 }

@export var drama_type: DramaType = DramaType.INTERNAL_CONFLICT
@export var severity: Severity = Severity.LOW
@export var source_member: String = ""
@export var description: String = ""
@export var active: bool = true
@export var resolution_weeks: int = 2
@export var weeks_elapsed: int = 0

func _init(p_type: DramaType = DramaType.INTERNAL_CONFLICT, p_severity: Severity = Severity.LOW, p_source: String = "", p_desc: String = "") -> void:
	drama_type = p_type
	severity = p_severity
	source_member = p_source
	description = p_desc

func get_type_name() -> String:
	match drama_type:
		DramaType.SCANDAL: return "Scandale"
		DramaType.INTERNAL_CONFLICT: return "Conflit interne"
		DramaType.PUBLIC_CONTROVERSY: return "Controverse publique"
		DramaType.LOOT_RAGE: return "Rage du loot"
		_: return "Inconnu"

func get_severity_name() -> String:
	match severity:
		Severity.LOW: return "Mineur"
		Severity.MEDIUM: return "Moyen"
		Severity.HIGH: return "Grave"
		_: return "Inconnu"

func get_reputation_impact() -> float:
	return -float(severity) * 5.0

func get_moral_impact() -> float:
	return -float(severity) * 3.0

func get_sponsor_impact() -> float:
	return -float(severity) * 8.0

func apply_resolution(resolution_type: String) -> void:
	"""Applique une resolution au drama."""
	match resolution_type:
		"silence":
			resolution_weeks = 4
		"communication":
			resolution_weeks = 2
		"sanctions":
			resolution_weeks = 1
		"exclusion":
			resolution_weeks = 0
			active = false

func tick_week() -> void:
	"""Mise a jour hebdomadaire."""
	weeks_elapsed += 1
	if weeks_elapsed >= resolution_weeks:
		active = false

func serialize() -> Dictionary:
	return {
		"drama_type": drama_type,
		"severity": severity,
		"source_member": source_member,
		"description": description,
		"active": active,
		"resolution_weeks": resolution_weeks,
		"weeks_elapsed": weeks_elapsed,
	}

static func deserialize(data: Dictionary) -> Drama:
	var d := Drama.new(
		data.get("drama_type", 0) as DramaType,
		data.get("severity", 1) as Severity,
		data.get("source_member", ""),
		data.get("description", ""),
	)
	d.active = data.get("active", true)
	d.resolution_weeks = data.get("resolution_weeks", 2)
	d.weeks_elapsed = data.get("weeks_elapsed", 0)
	return d
