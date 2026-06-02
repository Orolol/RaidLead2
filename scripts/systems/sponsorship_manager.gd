extends Node

## Gere les contrats de sponsors pour la guilde.

signal sponsor_acquired(sponsor)
signal sponsor_lost(sponsor, reason)
signal sponsor_offer_available(sponsor)

const MAX_ACTIVE_SPONSORS := 3
const POOL_SIZE := 8
const POOL_REFRESH_WEEKS := 4

var active_sponsors: Array = []
var available_sponsors: Array = []
var weeks_since_refresh: int = 0
var weeks_since_last_scandal: int = 99  # commence sans scandale

# Templates de sponsors
const SPONSOR_TEMPLATES: Array = [
	{name = "ForgeArmor", type = "equipementier", revenue = 80, duration = 8, min_rep = 55.0, min_members = 8},
	{name = "DragonSteel", type = "equipementier", revenue = 150, duration = 12, min_rep = 65.0, min_members = 12},
	{name = "MithrilWorks", type = "equipementier", revenue = 250, duration = 16, min_rep = 75.0, min_members = 15},
	{name = "GamersElite", type = "marque_gaming", revenue = 100, duration = 8, min_rep = 50.0, min_members = 8, min_audience = 500},
	{name = "PixelForge", type = "marque_gaming", revenue = 180, duration = 12, min_rep = 60.0, min_members = 10, min_audience = 2000},
	{name = "EpicGaming Co.", type = "marque_gaming", revenue = 300, duration = 16, min_rep = 70.0, min_members = 12, min_audience = 5000},
	{name = "StreamVault", type = "plateforme", revenue = 120, duration = 10, min_rep = 55.0, min_audience = 1000},
	{name = "BroadcastKing", type = "plateforme", revenue = 220, duration = 14, min_rep = 65.0, min_audience = 3000},
	{name = "ViewerNet", type = "plateforme", revenue = 350, duration = 20, min_rep = 75.0, min_audience = 8000},
	{name = "TavernBrew", type = "marque_gaming", revenue = 60, duration = 6, min_rep = 45.0, min_members = 6},
	{name = "QuestMark", type = "marque_gaming", revenue = 90, duration = 8, min_rep = 50.0, min_members = 8},
	{name = "LegendaryGear", type = "equipementier", revenue = 400, duration = 24, min_rep = 85.0, min_members = 18},
]

func _ready() -> void:
	if GameTime.has_signal("week_changed"):
		GameTime.week_changed.connect(_on_week_changed)
	_refresh_pool()

func _on_week_changed(_week: int, _year: int) -> void:
	# Les sponsors n'existent qu'à partir de la phase Nationale.
	if PhaseManager and PhaseManager.get_current_phase() < PhaseManager.GamePhase.NATIONAL:
		return
	weeks_since_last_scandal += 1
	weeks_since_refresh += 1

	# Tick sponsors actifs
	_tick_active_sponsors()

	# Versement des revenus hebdomadaires a la guilde
	_pay_sponsor_revenue()

	# Refresh du pool periodique
	if weeks_since_refresh >= POOL_REFRESH_WEEKS:
		_refresh_pool()
		weeks_since_refresh = 0

func _pay_sponsor_revenue() -> void:
	"""Verse les revenus hebdomadaires des sponsors actifs a la guilde."""
	var revenue: int = get_weekly_revenue()
	if revenue > 0 and GuildManager.guild:
		GuildManager.guild.add_gold(revenue)

func _tick_active_sponsors() -> void:
	"""Met a jour les sponsors actifs et verifie les obligations."""
	var reputation: float = GuildManager.guild.reputation if GuildManager.guild else 50.0
	var member_count: int = GuildManager.guild_members.size()
	var total_audience: int = 0
	if MediaManager:
		total_audience = MediaManager.get_total_audience()

	var expired: Array = []
	for sponsor in active_sponsors:
		var reqs_met: bool = sponsor.check_requirements(reputation, member_count, total_audience, weeks_since_last_scandal)
		sponsor.tick_week(reqs_met)
		if not sponsor.active:
			expired.append(sponsor)
			var reason: String = "Contrat expire" if sponsor.weeks_remaining <= 0 else "Satisfaction insuffisante"
			sponsor_lost.emit(sponsor, reason)
			if sponsor.satisfaction <= 0.0:
				# Perte reputation si sponsor mecontent
				if GuildManager.guild:
					GuildManager.guild.lose_reputation(5.0, "Sponsor %s mecontent" % sponsor.sponsor_name)

	for s in expired:
		active_sponsors.erase(s)

func _refresh_pool() -> void:
	"""Genere un nouveau pool de sponsors disponibles."""
	available_sponsors.clear()
	var templates := SPONSOR_TEMPLATES.duplicate()
	templates.shuffle()
	var count: int = mini(POOL_SIZE, templates.size())
	for i in range(count):
		var t: Dictionary = templates[i]
		var sponsor := Sponsor.new(t.name, t.type, t.revenue, t.duration)
		sponsor.min_reputation = t.get("min_rep", 50.0)
		sponsor.min_members = t.get("min_members", 8)
		sponsor.min_audience = t.get("min_audience", 0)
		sponsor.no_scandal_weeks = t.get("no_scandal_weeks", 4)
		available_sponsors.append(sponsor)

func try_sign_sponsor(sponsor: Sponsor) -> bool:
	"""Tente de signer un contrat avec un sponsor."""
	if active_sponsors.size() >= MAX_ACTIVE_SPONSORS:
		return false

	var reputation: float = GuildManager.guild.reputation if GuildManager.guild else 50.0
	var member_count: int = GuildManager.guild_members.size()
	var total_audience: int = 0
	if MediaManager:
		total_audience = MediaManager.get_total_audience()

	if not sponsor.check_requirements(reputation, member_count, total_audience, weeks_since_last_scandal):
		return false

	active_sponsors.append(sponsor)
	available_sponsors.erase(sponsor)
	sponsor_acquired.emit(sponsor)
	return true

func on_scandal() -> void:
	"""Appele quand un scandale/drama se produit."""
	weeks_since_last_scandal = 0

func get_weekly_revenue() -> int:
	"""Revenus hebdomadaires totaux des sponsors."""
	var total: int = 0
	for sponsor in active_sponsors:
		if sponsor.active:
			total += sponsor.weekly_revenue
	return total

func serialize() -> Dictionary:
	var active_data: Array = []
	for s in active_sponsors:
		active_data.append(s.serialize())
	return {
		"active_sponsors": active_data,
		"weeks_since_refresh": weeks_since_refresh,
		"weeks_since_last_scandal": weeks_since_last_scandal,
	}

func deserialize(data: Dictionary) -> void:
	weeks_since_refresh = data.get("weeks_since_refresh", 0)
	weeks_since_last_scandal = data.get("weeks_since_last_scandal", 99)
	active_sponsors.clear()
	for s_data in data.get("active_sponsors", []):
		active_sponsors.append(Sponsor.deserialize(s_data))
	_refresh_pool()
