extends Node

## Gere le staff professionnel de la guilde (Phase Esport, US 4.1).
## Coachs, analystes, psychologues et managers apportent des bonus a l'equipe.
## Orchestre aussi le bien-etre hebdomadaire des joueurs (relief de stress, moral).

signal staff_hired(staff)
signal staff_fired(staff)
signal staff_pool_refreshed()

const MAX_STAFF := 6
const POOL_SIZE := 5
const POOL_REFRESH_WEEKS := 6
const SIGNING_FEE_MULTIPLIER := 2  # frais d'embauche = 2 semaines de salaire
const REST_COOLDOWN := 4

var hired_staff: Array = []       # Array[StaffMember]
var available_staff: Array = []   # Array[StaffMember]
var weeks_since_refresh: int = 0
var rest_cooldown_weeks: int = 0

const FIRST_NAMES := ["Lars", "Mika", "Yuki", "Chen", "Diego", "Sven", "Aria", "Noor",
	"Kai", "Elena", "Tomas", "Ravi", "Lena", "Hugo", "Sora", "Nadia"]
const LAST_NAMES := ["Berg", "Kovac", "Tanaka", "Wei", "Moreau", "Larsson", "Petrov",
	"Khan", "Silva", "Dubois", "Novak", "Reyes", "Haas", "Ito", "Vidal", "Okafor"]

func _ready() -> void:
	if GameTime and GameTime.has_signal("week_changed"):
		GameTime.week_changed.connect(_on_week_changed)
	_refresh_pool()

func _on_week_changed(_week: int, _year: int) -> void:
	_pay_staff_salaries()
	_process_wellbeing()
	if rest_cooldown_weeks > 0:
		rest_cooldown_weeks -= 1
	weeks_since_refresh += 1
	if weeks_since_refresh >= POOL_REFRESH_WEEKS:
		_refresh_pool()

# --- Pool / generation ---

func _refresh_pool() -> void:
	available_staff.clear()
	for i in range(POOL_SIZE):
		available_staff.append(_generate_staff())
	weeks_since_refresh = 0
	staff_pool_refreshed.emit()

func _generate_staff() -> StaffMember:
	var role: int = randi() % 4
	var skill: int = randi_range(40, 95)
	var salary: int = _salary_for(role, skill)
	return StaffMember.new(_random_name(), role as StaffMember.StaffRole, skill, salary)

func _salary_for(role: int, skill: int) -> int:
	var base: int = 200
	match role:
		StaffMember.StaffRole.COACH: base = 350
		StaffMember.StaffRole.ANALYST: base = 280
		StaffMember.StaffRole.PSYCHOLOGIST: base = 300
		StaffMember.StaffRole.MANAGER: base = 320
	return base + skill * 4  # 40 -> +160, 95 -> +380

func _random_name() -> String:
	return "%s %s" % [FIRST_NAMES[randi() % FIRST_NAMES.size()], LAST_NAMES[randi() % LAST_NAMES.size()]]

# --- Embauche / renvoi ---

func hire_staff(staff) -> bool:
	"""Embauche un membre du staff (frais d'embauche initiaux). Retourne false si impossible."""
	if hired_staff.size() >= MAX_STAFF:
		return false
	if not GuildManager.guild:
		return false
	var signing_fee: int = staff.weekly_salary * SIGNING_FEE_MULTIPLIER
	if not GuildManager.guild.spend_gold(signing_fee):
		return false
	staff.hired = true
	hired_staff.append(staff)
	available_staff.erase(staff)
	staff_hired.emit(staff)
	return true

func fire_staff(staff) -> void:
	if staff in hired_staff:
		staff.hired = false
		hired_staff.erase(staff)
		staff_fired.emit(staff)

# --- Salaires & bien-etre ---

func _pay_staff_salaries() -> void:
	var total: int = get_total_weekly_salary()
	if total <= 0:
		return
	var nm: Node = NotificationManager
	if GuildManager.guild and GuildManager.guild.gold >= total:
		GuildManager.guild.spend_gold(total)
	else:
		if GuildManager.guild:
			GuildManager.guild.lose_reputation(2.0, "Salaires staff impayés")
		if nm:
			nm.show_warning("Salaires du staff impayés !", "Budget staff")
		# Un membre du staff peut partir faute de paiement
		if not hired_staff.is_empty() and randf() < 0.25:
			var leaving = hired_staff[randi() % hired_staff.size()]
			fire_staff(leaving)
			if nm:
				nm.show_warning("%s (%s) quitte le staff." % [leaving.staff_name, leaving.get_role_short()], "Staff")

func _process_wellbeing() -> void:
	"""Applique le relief de stress et le bonus de moral du staff a chaque joueur."""
	var relief: float = get_total_stress_relief()
	var morale: float = get_total_morale_bonus()
	var in_esport: bool = PhaseManager and PhaseManager.get_current_phase() >= PhaseManager.GamePhase.ESPORT
	if not in_esport and relief <= 0.0 and morale <= 0.0:
		return
	for member in GuildManager.guild_members:
		if member.has_method("tick_wellbeing_weekly"):
			member.tick_wellbeing_weekly(relief, morale, in_esport)

func grant_team_rest() -> bool:
	"""Repos/rotation (US 4.3) : reduit fortement le stress et la fatigue de toute l'equipe.
	Soumis a un cooldown pour eviter l'abus."""
	if rest_cooldown_weeks > 0:
		return false
	for member in GuildManager.guild_members:
		if member.has_method("reduce_stress"):
			member.reduce_stress(25.0)
		member.fatigue_accumulated = maxf(0.0, member.fatigue_accumulated - 15.0)
		member.update_mood(5.0)
	rest_cooldown_weeks = REST_COOLDOWN
	return true

func can_grant_rest() -> bool:
	return rest_cooldown_weeks <= 0

# --- Agregats de bonus ---

func get_staff_count() -> int:
	return hired_staff.size()

func has_role(role: int) -> bool:
	for s in hired_staff:
		if s.role == role:
			return true
	return false

func get_total_weekly_salary() -> int:
	var total: int = 0
	var efficiency: float = 0.0
	for s in hired_staff:
		total += s.weekly_salary
		efficiency += s.get_salary_efficiency()
	efficiency = clampf(efficiency, 0.0, 0.4)
	return int(total * (1.0 - efficiency))

func get_synergy_multiplier() -> float:
	"""+5% de bonus par role distinct present au-dela du premier (max +15%)."""
	var roles_present: Dictionary = {}
	for s in hired_staff:
		roles_present[s.role] = true
	return 1.0 + maxi(0, roles_present.size() - 1) * 0.05

func get_total_performance_bonus() -> float:
	var b: float = 0.0
	for s in hired_staff:
		b += s.get_performance_bonus()
	return b * get_synergy_multiplier()

func get_total_strategy_bonus() -> float:
	var b: float = 0.0
	for s in hired_staff:
		b += s.get_strategy_bonus()
	return b * get_synergy_multiplier()

func get_total_stress_relief() -> float:
	var b: float = 0.0
	for s in hired_staff:
		b += s.get_stress_relief()
	return b

func get_total_morale_bonus() -> float:
	var b: float = 0.0
	for s in hired_staff:
		b += s.get_morale_bonus()
	return b

func get_total_stability_bonus() -> float:
	var b: float = 0.0
	for s in hired_staff:
		b += s.get_stability_bonus()
	return b

# --- Sauvegarde ---

func serialize() -> Dictionary:
	var staff_data: Array = []
	for s in hired_staff:
		staff_data.append(s.serialize())
	return {
		"hired_staff": staff_data,
		"weeks_since_refresh": weeks_since_refresh,
		"rest_cooldown_weeks": rest_cooldown_weeks,
	}

func deserialize(data: Dictionary) -> void:
	hired_staff.clear()
	for sd in data.get("hired_staff", []):
		hired_staff.append(StaffMember.deserialize(sd))
	weeks_since_refresh = data.get("weeks_since_refresh", 0)
	rest_cooldown_weeks = data.get("rest_cooldown_weeks", 0)
