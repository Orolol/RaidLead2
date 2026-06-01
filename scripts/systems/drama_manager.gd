extends Node

## Gere les dramas et crises au sein de la guilde.
## Les dramas sont declenchees par la celebrite, les conflits de loot, les streamers, etc.

signal drama_occurred(drama)
signal drama_resolved(drama)
signal drama_response_needed(drama)

var active_dramas: Array = []
var resolved_dramas: Array = []
var dramas_this_year: int = 0  # dramas majeurs (severité >= MEDIUM) sur l'année courante

const MAX_ACTIVE_DRAMAS := 3

func _ready() -> void:
	if GameTime.has_signal("week_changed"):
		GameTime.week_changed.connect(_on_week_changed)
	if GameTime.has_signal("year_changed"):
		GameTime.year_changed.connect(_on_year_changed)

	# Connecter aux incidents media (MediaManager est un autoload toujours présent)
	if MediaManager and MediaManager.has_signal("media_incident"):
		MediaManager.media_incident.connect(_on_media_incident)

func _on_week_changed(_week: int, _year: int) -> void:
	_tick_dramas()  # résout les dramas actifs (y compris ceux de loot, valides en toute phase)
	# Les dramas médiatiques aléatoires ne se déclenchent qu'à partir de la phase Nationale.
	if PhaseManager and PhaseManager.get_current_phase() >= PhaseManager.GamePhase.NATIONAL:
		_check_drama_triggers()

func _tick_dramas() -> void:
	"""Met a jour les dramas actifs."""
	var newly_resolved: Array = []
	for drama in active_dramas:
		drama.tick_week()
		if not drama.active:
			newly_resolved.append(drama)
			drama_resolved.emit(drama)

	for d in newly_resolved:
		active_dramas.erase(d)
		resolved_dramas.append(d)
		# Limiter historique
		if resolved_dramas.size() > 50:
			resolved_dramas.pop_front()

func _check_drama_triggers() -> void:
	"""Verifie les conditions de declenchement de dramas."""
	if active_dramas.size() >= MAX_ACTIVE_DRAMAS:
		return

	for member in GuildManager.guild_members:
		var celebrity: float = member.celebrity_level

		# Celebrity elevee -> scandale
		if celebrity > 80.0 and randf() < 0.15:
			_create_drama(Drama.DramaType.SCANDAL, Drama.Severity.MEDIUM, member.nom,
				"%s fait parler de lui dans les medias" % member.nom)
			return

		# Drama queens
		if _has_revealed_tag(member, "drama_queen") and randf() < 0.10:
			_create_drama(Drama.DramaType.INTERNAL_CONFLICT, Drama.Severity.LOW, member.nom,
				"%s cree des tensions au sein de la guilde" % member.nom)
			return

	# Conflit entre 2 drama queens
	var drama_queens: Array = []
	for member in GuildManager.guild_members:
		if _has_revealed_tag(member, "drama_queen"):
			drama_queens.append(member)
	if drama_queens.size() >= 2 and randf() < 0.10:
		var m1 = drama_queens[0]
		var m2 = drama_queens[1]
		_create_drama(Drama.DramaType.INTERNAL_CONFLICT, Drama.Severity.MEDIUM, m1.nom,
			"Conflit ouvert entre %s et %s" % [m1.nom, m2.nom])

func _create_drama(type: Drama.DramaType, severity: Drama.Severity, source: String, desc: String) -> Drama:
	"""Cree et enregistre un nouveau drama."""
	# Verifier qu'il n'y a pas deja un drama similaire du meme membre
	for d in active_dramas:
		if d.source_member == source and d.drama_type == type:
			return d

	var drama := Drama.new(type, severity, source, desc)
	active_dramas.append(drama)
	if severity >= Drama.Severity.MEDIUM:
		dramas_this_year += 1
	drama_occurred.emit(drama)
	drama_response_needed.emit(drama)

	# Impact immediat sur reputation et moral
	if GuildManager.guild:
		GuildManager.guild.lose_reputation(absf(drama.get_reputation_impact()),
			"Drama: %s" % drama.get_type_name())

	# Notifier les sponsors (SponsorshipManager est un autoload toujours présent)
	if SponsorshipManager:
		SponsorshipManager.on_scandal()

	return drama

func create_loot_rage_drama(member_name: String, item_name: String) -> Drama:
	"""Cree un drama de type rage du loot (appele depuis l'exterieur)."""
	return _create_drama(Drama.DramaType.LOOT_RAGE, Drama.Severity.LOW, member_name,
		"%s est furieux de ne pas avoir obtenu %s" % [member_name, item_name])

func resolve_drama(drama: Drama, resolution: String) -> void:
	"""Applique une resolution a un drama."""
	drama.apply_resolution(resolution)

	# Effets selon la resolution
	match resolution:
		"silence":
			pass  # Pas d'effet immediat, resolution lente
		"communication":
			if GuildManager.guild:
				GuildManager.guild.gain_reputation(2.0, "Communication de crise")
		"sanctions":
			# Baisser le moral de tous
			for member in GuildManager.guild_members:
				member.mood = maxf(0.0, member.mood - 15.0)
			if GuildManager.guild:
				GuildManager.guild.gain_reputation(5.0, "Sanctions disciplinaires")
		"exclusion":
			# Trouver et retirer le membre source
			for member in GuildManager.guild_members:
				if member.nom == drama.source_member:
					GuildManager.remove_member(member, false)
					break
			# Gros impact moral mais bonne reputation
			for member in GuildManager.guild_members:
				member.mood = maxf(0.0, member.mood - 25.0)
			if GuildManager.guild:
				GuildManager.guild.gain_reputation(10.0, "Exclusion disciplinaire")

	if not drama.active:
		active_dramas.erase(drama)
		resolved_dramas.append(drama)
		drama_resolved.emit(drama)

func _on_media_incident(member_name: String, incident_type: String, _description: String) -> void:
	"""Reagit a un incident media."""
	match incident_type:
		"live_incident":
			_create_drama(Drama.DramaType.PUBLIC_CONTROVERSY, Drama.Severity.MEDIUM, member_name,
				"%s a provoque un incident en direct" % member_name)
		"strategy_leak":
			_create_drama(Drama.DramaType.PUBLIC_CONTROVERSY, Drama.Severity.LOW, member_name,
				"%s a divulgue des strategies en stream" % member_name)

func _has_revealed_tag(member, tag_name: String) -> bool:
	"""Ne considère que les tags RÉVÉLÉS (visibles) — un trait caché ne doit pas agir
	avant que le joueur ne l'ait découvert (respecte la révélation progressive)."""
	if "tags_comportement" in member:
		return tag_name in member.tags_comportement
	return false

func _has_tag(member, tag_name: String) -> bool:
	if member.has_method("has_tag"):
		return member.has_tag(tag_name)
	if "tags_comportement" in member:
		return tag_name in member.tags_comportement
	return false

func _on_year_changed(_year: int) -> void:
	"""Réinitialise le compteur de dramas annuel."""
	dramas_this_year = 0

func get_dramas_this_year() -> int:
	return dramas_this_year

func get_active_dramas_count() -> int:
	return active_dramas.size()

func has_active_drama() -> bool:
	return not active_dramas.is_empty()

func serialize() -> Dictionary:
	var active_data: Array = []
	for d in active_dramas:
		active_data.append(d.serialize())
	var resolved_data: Array = []
	for d in resolved_dramas:
		resolved_data.append(d.serialize())
	return {
		"active_dramas": active_data,
		"resolved_dramas": resolved_data,
		"dramas_this_year": dramas_this_year,
	}

func deserialize(data: Dictionary) -> void:
	dramas_this_year = data.get("dramas_this_year", 0)
	active_dramas.clear()
	for d_data in data.get("active_dramas", []):
		active_dramas.append(Drama.deserialize(d_data))
	resolved_dramas.clear()
	for d_data in data.get("resolved_dramas", []):
		resolved_dramas.append(Drama.deserialize(d_data))
