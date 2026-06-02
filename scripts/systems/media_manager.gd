extends Node

## Gere le systeme de streaming et medias de la guilde.
## Les membres celebres peuvent devenir streamers, generant revenus et conflits.

signal streamer_started(member_name: String)
signal streamer_stopped(member_name: String)
signal media_incident(member_name: String, incident_type: String, description: String)

const STREAMER_CELEBRITY_THRESHOLD := 40.0
const STREAMER_CHANCE := 0.10  # 10% chance par semaine si eligible
const STREAMING_VS_RAID_CHANCE := 0.05
const STRATEGY_LEAK_CHANCE := 0.03
const LIVE_INCIDENT_CHANCE := 0.02
const AUDIENCE_GROWTH_RATE := 500  # par semaine si actif
const AUDIENCE_DECAY_RATE := 200  # par semaine si inactif
const REVENUE_PER_AUDIENCE := 0.01  # or par audience par semaine

func _ready() -> void:
	if GameTime.has_signal("week_changed"):
		GameTime.week_changed.connect(_on_week_changed)

func _on_week_changed(_week: int, _year: int) -> void:
	# Les médias/célébrité ne s'activent qu'à partir de la phase Nationale.
	if PhaseManager and PhaseManager.get_current_phase() < PhaseManager.GamePhase.NATIONAL:
		return
	_update_celebrity()
	_update_streamers()
	_check_media_events()
	_pay_guild_revenue_cut()

func _update_celebrity() -> void:
	"""Fait evoluer la celebrite des membres selon leurs performances et leur exposition."""
	for member in GuildManager.guild_members:
		var growth: float = 0.0
		# Le talent attire l'attention
		if member.skill >= 85:
			growth += 1.5
		elif member.skill >= 70:
			growth += 0.7
		# Le streaming amplifie fortement la celebrite
		if member.get_meta("is_streamer", false):
			var audience: int = member.get_meta("audience_size", 0)
			growth += clampf(float(audience) / 1500.0, 0.0, 3.0)
		# Decroissance naturelle si rien ne se passe
		growth -= 0.6
		member.update_celebrity(growth)

func _pay_guild_revenue_cut() -> void:
	"""La guilde percoit une part des revenus de streaming de ses membres."""
	var guild_cut: int = int(get_total_weekly_revenue() * 0.3)
	if guild_cut > 0 and GuildManager.guild:
		GuildManager.guild.add_gold(guild_cut)

func _update_streamers() -> void:
	"""Met a jour le statut des streamers et leur audience."""
	for member in GuildManager.guild_members:
		if not member.has_meta("is_streamer"):
			member.set_meta("is_streamer", false)
			member.set_meta("audience_size", 0)
			member.set_meta("stream_revenue", 0.0)

		var is_streamer: bool = member.get_meta("is_streamer")
		var celebrity: float = member.celebrity_level

		if not is_streamer:
			# Chance de devenir streamer
			if celebrity >= STREAMER_CELEBRITY_THRESHOLD and _has_social_tag(member):
				if randf() < STREAMER_CHANCE:
					member.set_meta("is_streamer", true)
					member.set_meta("audience_size", randi_range(100, 1000))
					streamer_started.emit(member.nom)
		else:
			# Croissance/decroissance audience — PLAFONNÉE par la célébrité pour éviter
			# une boucle audience↔célébrité→revenus non bornée.
			var audience: int = member.get_meta("audience_size")
			if member.is_online:
				var growth: int = randi_range(0, AUDIENCE_GROWTH_RATE) + int(celebrity * 10)
				var max_audience: int = 2000 + int(celebrity * 800)  # plafond fonction de la célébrité
				audience = mini(audience + growth, max_audience)
			else:
				audience = maxi(0, audience - AUDIENCE_DECAY_RATE)
			member.set_meta("audience_size", audience)

			# Revenus
			var revenue: float = float(audience) * REVENUE_PER_AUDIENCE
			member.set_meta("stream_revenue", revenue)

func _check_media_events() -> void:
	"""Verifie les evenements mediatiques potentiels."""
	for member in GuildManager.guild_members:
		if not member.get_meta("is_streamer", false):
			continue

		# Streaming vs Raid
		if randf() < STREAMING_VS_RAID_CHANCE:
			media_incident.emit(member.nom, "streaming_vs_raid",
				"%s a rate un raid pour streamer" % member.nom)

		# Fuite de strategie
		if randf() < STRATEGY_LEAK_CHANCE:
			media_incident.emit(member.nom, "strategy_leak",
				"%s a divulgue une strategie en live" % member.nom)

		# Incident en live
		if randf() < LIVE_INCIDENT_CHANCE:
			media_incident.emit(member.nom, "live_incident",
				"%s a provoque un incident en live" % member.nom)

func _has_social_tag(member) -> bool:
	"""Verifie si le membre a un tag social."""
	if member.has_method("has_tag"):
		return member.has_tag("social") or member.has_tag("drama_queen")
	if "tags_comportement" in member:
		return "social" in member.tags_comportement or "drama_queen" in member.tags_comportement
	return randf() < 0.3  # fallback

func get_total_audience() -> int:
	"""Retourne l'audience totale de tous les streamers."""
	var total: int = 0
	for member in GuildManager.guild_members:
		if member.get_meta("is_streamer", false):
			total += member.get_meta("audience_size", 0)
	return total

func get_total_weekly_revenue() -> float:
	"""Retourne les revenus hebdomadaires totaux du streaming."""
	var total: float = 0.0
	for member in GuildManager.guild_members:
		if member.get_meta("is_streamer", false):
			total += member.get_meta("stream_revenue", 0.0)
	return total

func get_media_reputation() -> float:
	"""Réputation médiatique (0-100) : réputation de guilde + exposition (audience, célébrité)."""
	var base: float = GuildManager.guild.reputation if GuildManager.guild else 50.0
	var audience_bonus: float = clampf(float(get_total_audience()) / 1000.0, 0.0, 15.0)
	var celeb_total: float = 0.0
	var count: int = 0
	for member in GuildManager.guild_members:
		celeb_total += member.celebrity_level
		count += 1
	var avg_celeb: float = (celeb_total / count) if count > 0 else 0.0
	var celeb_bonus: float = clampf(avg_celeb / 5.0, 0.0, 15.0)
	return clampf(base + audience_bonus + celeb_bonus, 0.0, 100.0)

func get_streamers() -> Array:
	"""Retourne la liste des streamers actifs."""
	var streamers: Array = []
	for member in GuildManager.guild_members:
		if member.get_meta("is_streamer", false):
			streamers.append(member)
	return streamers

func serialize() -> Dictionary:
	var streamers_data: Array = []
	for member in GuildManager.guild_members:
		if member.get_meta("is_streamer", false):
			streamers_data.append({
				"nom": member.nom,
				"audience_size": member.get_meta("audience_size", 0),
				"stream_revenue": member.get_meta("stream_revenue", 0.0),
			})
	return {"streamers": streamers_data}

func deserialize(data: Dictionary) -> void:
	var streamers_data: Array = data.get("streamers", [])
	for s in streamers_data:
		for member in GuildManager.guild_members:
			if member.nom == s.get("nom", ""):
				member.set_meta("is_streamer", true)
				member.set_meta("audience_size", s.get("audience_size", 0))
				member.set_meta("stream_revenue", s.get("stream_revenue", 0.0))
				break
