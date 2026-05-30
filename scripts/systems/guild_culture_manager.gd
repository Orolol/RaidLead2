extends Node

## Mécaniques transversales de culture de guilde (Milestone 5).
## Réveille le système social dormant (SocialDynamics) et ajoute :
## - un moral de guilde global (guild_morale 0-100),
## - la contagion émotionnelle (l'humeur se propage via les relations),
## - les événements de team-building,
## - les rituels & traditions (bonus passifs persistants),
## - la détection et la résolution des tensions/conflits interpersonnels.
##
## Accès au social : GuildManager.behavior_system.social_dynamics

signal morale_changed(new_morale: float, old_morale: float)
signal team_building_done(activity_name: String, morale_gain: float)
signal tradition_established(tradition_name: String)
signal tension_detected(player1_name: String, player2_name: String, reason: String)
signal tension_resolved(player1_name: String, player2_name: String)

const SEED_PAIRS_PER_WEEK := 5
const CONTAGION_RATE := 0.15
const BASE_MORALE := 12.0

# Catalogue des événements de team-building
const TEAM_BUILDING := [
	{"id": "soiree", "name": "Soirée détente", "desc": "Une soirée décontractée entre membres.",
		"gold": 300, "energy": 5, "mood": 8, "morale": 6, "bonding": 3, "cooldown": 3},
	{"id": "challenge", "name": "Challenge interne", "desc": "Une compétition amicale qui soude le groupe.",
		"gold": 500, "energy": 15, "mood": 5, "morale": 8, "bonding": 4, "cooldown": 4},
	{"id": "sortie", "name": "Sortie virtuelle", "desc": "Une sortie de groupe dans un autre jeu.",
		"gold": 800, "energy": 10, "mood": 12, "morale": 10, "bonding": 5, "cooldown": 5},
	{"id": "celebration", "name": "Célébration de guilde", "desc": "Une grande fête pour célébrer les accomplissements.",
		"gold": 1200, "energy": 0, "mood": 15, "morale": 14, "bonding": 6, "cooldown": 6},
]

# Catalogue des traditions (bonus passifs hebdomadaires)
const TRADITIONS := {
	"discours": {"name": "Discours d'avant-raid", "desc": "Un discours rituel avant chaque raid soude l'équipe.",
		"morale_week": 0.8, "cohesion_week": 0.0, "req_members": 6, "cost": 500},
	"celebration_victoire": {"name": "Célébration de victoire", "desc": "Chaque victoire est célébrée ensemble.",
		"morale_week": 1.0, "cohesion_week": 0.02, "req_members": 10, "cost": 800},
	"mentorat": {"name": "Programme de mentorat", "desc": "Les vétérans forment les nouvelles recrues.",
		"morale_week": 0.6, "cohesion_week": 0.03, "req_members": 12, "cost": 1000},
	"anniversaire": {"name": "Anniversaire de guilde", "desc": "Une tradition annuelle qui renforce l'identité.",
		"morale_week": 1.2, "cohesion_week": 0.0, "req_members": 15, "cost": 1500},
}

var guild_morale: float = 65.0
var established_traditions: Array = []  # Array[String] (ids)
var team_building_cooldown: int = 0

func _ready() -> void:
	if GameTime and GameTime.has_signal("week_changed"):
		GameTime.week_changed.connect(_on_week_changed)

func _on_week_changed(_week: int, _year: int) -> void:
	_grow_relationships()
	_maybe_trigger_tension()
	_apply_contagion()
	_apply_tradition_cohesion()
	if team_building_cooldown > 0:
		team_building_cooldown -= 1
	_recompute_morale()

# --- Accès au système social ---

func _get_social():
	if GuildManager and GuildManager.behavior_system:
		return GuildManager.behavior_system.social_dynamics
	return null

func _map_relation_type(type_str: String) -> int:
	match type_str:
		"friend": return SocialDynamics.RelationType.FRIEND
		"rivalry": return SocialDynamics.RelationType.RIVAL
		"mentor": return SocialDynamics.RelationType.MENTOR
		"student": return SocialDynamics.RelationType.STUDENT
		_: return SocialDynamics.RelationType.NEUTRAL

# --- Réveil du graphe social ---

func _grow_relationships() -> void:
	"""Forme et renforce des relations chaque semaine pour animer le tissu social."""
	var sd = _get_social()
	if not sd:
		return
	var members: Array = GuildManager.guild_members
	if members.size() < 2:
		return
	for i in range(SEED_PAIRS_PER_WEEK):
		var a = members[randi() % members.size()]
		var b = members[randi() % members.size()]
		if a == b:
			continue
		var existing = sd.get_relationship(a, b)
		if existing:
			# Les membres en ligne ensemble se rapprochent
			if a.is_online and b.is_online:
				sd.strengthen_relationship(a, b, 0.1)
		elif a.behavior_profile and b.behavior_profile:
			if a.behavior_profile.should_form_relationship(b.behavior_profile):
				var type_str: String = a.behavior_profile.get_relationship_type(b.behavior_profile)
				sd.form_relationship(a, b, _map_relation_type(type_str), 0.35)

# --- Contagion émotionnelle ---

func _apply_contagion() -> void:
	"""L'humeur de chaque membre dérive vers celle de son cercle social (amis/mentors)."""
	var sd = _get_social()
	if not sd:
		return
	var deltas: Dictionary = {}
	for m in GuildManager.guild_members:
		var circle: Array = sd.get_social_circle(m)
		if circle.is_empty():
			continue
		var influence_sum: float = 0.0
		var weight_sum: float = 0.0
		for other in circle:
			var rel = sd.get_relationship(m, other)
			if not rel or rel.type == SocialDynamics.RelationType.ENEMY:
				continue
			influence_sum += other.mood * rel.strength
			weight_sum += rel.strength
		if weight_sum > 0.0:
			var avg_circle_mood: float = influence_sum / weight_sum
			deltas[m] = (avg_circle_mood - m.mood) * CONTAGION_RATE
	for m in deltas:
		m.update_mood(deltas[m])

# --- Moral de guilde ---

func _recompute_morale() -> void:
	var members: Array = GuildManager.guild_members
	if members.is_empty():
		return
	var mood_sum: float = 0.0
	for m in members:
		mood_sum += m.mood
	var avg_mood: float = mood_sum / members.size()
	var target: float = clampf(avg_mood * 0.7 + BASE_MORALE + _social_health_score() + _tradition_morale_bonus(), 0.0, 100.0)
	var old: float = guild_morale
	guild_morale = clampf(lerpf(guild_morale, target, 0.3), 0.0, 100.0)
	if absf(guild_morale - old) > 0.4:
		morale_changed.emit(guild_morale, old)

func _social_health_score() -> float:
	"""Score -15..+15 : les amitiés montent le moral, les rivalités/inimitiés le baissent."""
	var sd = _get_social()
	if not sd:
		return 0.0
	var friends: int = 0
	var rivals: int = 0
	var enemies: int = 0
	for key in sd.relationships:
		var rel = sd.relationships[key]
		match rel.type:
			SocialDynamics.RelationType.FRIEND, SocialDynamics.RelationType.MENTOR:
				friends += 1
			SocialDynamics.RelationType.RIVAL:
				rivals += 1
			SocialDynamics.RelationType.ENEMY:
				enemies += 1
	return clampf(friends * 1.5 - rivals * 1.0 - enemies * 3.0, -15.0, 15.0)

func get_guild_morale() -> float:
	return guild_morale

func get_morale_tier() -> String:
	if guild_morale >= 85.0:
		return "Excellente"
	elif guild_morale >= 70.0:
		return "Bonne"
	elif guild_morale >= 50.0:
		return "Correcte"
	elif guild_morale >= 30.0:
		return "Tendue"
	else:
		return "Toxique"

# --- Team-building ---

func get_team_building_catalog() -> Array:
	return TEAM_BUILDING

func can_team_build() -> bool:
	return team_building_cooldown <= 0

func run_team_building(activity: Dictionary) -> bool:
	"""Organise un événement de team-building : coûte de l'or, monte moral/humeur, soude le groupe."""
	if team_building_cooldown > 0:
		return false
	if not GuildManager.guild or not GuildManager.guild.spend_gold(activity.get("gold", 0)):
		return false

	for m in GuildManager.guild_members:
		m.update_mood(activity.get("mood", 0))
		m.update_energy(-activity.get("energy", 0))

	var sd = _get_social()
	if sd:
		var members: Array = GuildManager.guild_members
		for i in range(activity.get("bonding", 0)):
			if members.size() < 2:
				break
			var a = members[randi() % members.size()]
			var b = members[randi() % members.size()]
			if a == b:
				continue
			if sd.get_relationship(a, b):
				sd.strengthen_relationship(a, b, 0.15)
			else:
				sd.form_relationship(a, b, SocialDynamics.RelationType.FRIEND, 0.35)
		for c in sd.cliques:
			sd.update_clique_cohesion(c, 0.1)

	guild_morale = clampf(guild_morale + activity.get("morale", 0), 0.0, 100.0)
	team_building_cooldown = activity.get("cooldown", 3)
	team_building_done.emit(activity.get("name", ""), activity.get("morale", 0))
	return true

# --- Traditions ---

func get_traditions_status() -> Array:
	"""Retourne le catalogue des traditions avec leur état (établie / disponible / verrouillée)."""
	var member_count: int = GuildManager.guild_members.size() if GuildManager else 0
	var gold: int = GuildManager.guild.gold if (GuildManager and GuildManager.guild) else 0
	var out: Array = []
	for id in TRADITIONS:
		var t: Dictionary = TRADITIONS[id]
		var established: bool = id in established_traditions
		var req_met: bool = member_count >= t.get("req_members", 0)
		out.append({
			"id": id,
			"name": t.get("name", ""),
			"desc": t.get("desc", ""),
			"morale_week": t.get("morale_week", 0.0),
			"cohesion_week": t.get("cohesion_week", 0.0),
			"req_members": t.get("req_members", 0),
			"cost": t.get("cost", 0),
			"established": established,
			"can_establish": (not established) and req_met and gold >= t.get("cost", 0),
		})
	return out

func establish_tradition(id: String) -> bool:
	if id in established_traditions or not TRADITIONS.has(id):
		return false
	var t: Dictionary = TRADITIONS[id]
	if GuildManager.guild_members.size() < t.get("req_members", 0):
		return false
	if not GuildManager.guild or not GuildManager.guild.spend_gold(t.get("cost", 0)):
		return false
	established_traditions.append(id)
	guild_morale = clampf(guild_morale + 5.0, 0.0, 100.0)  # élan initial
	tradition_established.emit(t.get("name", ""))
	return true

func _tradition_morale_bonus() -> float:
	var bonus: float = 0.0
	for id in established_traditions:
		if TRADITIONS.has(id):
			bonus += TRADITIONS[id].get("morale_week", 0.0) * 3.0
	return bonus

func _apply_tradition_cohesion() -> void:
	var sd = _get_social()
	if not sd:
		return
	var total_cohesion: float = 0.0
	for id in established_traditions:
		if TRADITIONS.has(id):
			total_cohesion += TRADITIONS[id].get("cohesion_week", 0.0)
	if total_cohesion > 0.0:
		for c in sd.cliques:
			sd.update_clique_cohesion(c, total_cohesion)

# --- Tensions / conflits ---

func _maybe_trigger_tension() -> void:
	"""Plus le moral est bas, plus des tensions risquent d'éclater."""
	var sd = _get_social()
	if not sd:
		return
	var members: Array = GuildManager.guild_members
	if members.size() < 2:
		return
	var chance: float = 0.08 + (1.0 - guild_morale / 100.0) * 0.18
	if randf() < chance:
		var a = members[randi() % members.size()]
		var b = members[randi() % members.size()]
		if a == b:
			return
		sd.trigger_social_conflict(a, b, "Tension d'équipe")
		tension_detected.emit(a.nom, b.nom, "Tension d'équipe")

func get_tensions() -> Array:
	"""Retourne les relations conflictuelles (rivalités et inimitiés)."""
	var sd = _get_social()
	var out: Array = []
	if not sd:
		return out
	for key in sd.relationships:
		var rel = sd.relationships[key]
		if rel.type == SocialDynamics.RelationType.RIVAL or rel.type == SocialDynamics.RelationType.ENEMY:
			var ids: PackedStringArray = key.split(":")
			var p1 = _player_by_id(int(ids[0]))
			var p2 = _player_by_id(int(ids[1]))
			if p1 and p2:
				out.append({
					"p1": p1, "p2": p2,
					"is_enemy": rel.type == SocialDynamics.RelationType.ENEMY,
					"strength": rel.strength,
				})
	return out

func resolve_tension(p1, p2, method: String) -> Dictionary:
	"""Tente de résoudre une tension. method : 'mediation' ou 'team_building'."""
	var sd = _get_social()
	if not sd:
		return {"success": false, "reason": "Système social indisponible"}

	if method == "mediation":
		var mediator = _find_mediator(p1, p2)
		if not mediator:
			return {"success": false, "reason": "Aucun médiateur (ami des deux) disponible"}
		var ok: bool = sd.mediate_conflict(mediator, p1, p2)
		if ok:
			tension_resolved.emit(p1.nom, p2.nom)
			return {"success": true, "mediator": mediator.nom}
		return {"success": false, "reason": "La médiation de %s a échoué" % mediator.nom}

	elif method == "team_building":
		# Apaisement direct au prix d'un peu de moral d'équipe
		var rel = sd.get_relationship(p1, p2)
		if rel and rel.type == SocialDynamics.RelationType.ENEMY:
			sd.transform_relationship(p1, p2, SocialDynamics.RelationType.RIVAL)
		elif rel:
			sd.weaken_relationship(p1, p2, 0.3)
		p1.update_mood(4.0)
		p2.update_mood(4.0)
		tension_resolved.emit(p1.nom, p2.nom)
		return {"success": true}

	return {"success": false, "reason": "Méthode inconnue"}

func _find_mediator(p1, p2):
	"""Trouve un membre ami des deux parties, avec la meilleure influence."""
	var sd = _get_social()
	if not sd:
		return null
	var best = null
	var best_influence: float = -1.0
	for m in GuildManager.guild_members:
		if m == p1 or m == p2:
			continue
		if sd.are_friends(m, p1) and sd.are_friends(m, p2):
			var inf: float = sd.get_influence_on_player(m)
			if inf > best_influence:
				best_influence = inf
				best = m
	return best

# --- Helpers sociaux pour l'UI ---

func get_relationship_counts() -> Dictionary:
	var sd = _get_social()
	var counts: Dictionary = {"friend": 0, "rival": 0, "enemy": 0, "mentor": 0, "neutral": 0}
	if not sd:
		return counts
	for key in sd.relationships:
		var rel = sd.relationships[key]
		match rel.type:
			SocialDynamics.RelationType.FRIEND: counts["friend"] += 1
			SocialDynamics.RelationType.RIVAL: counts["rival"] += 1
			SocialDynamics.RelationType.ENEMY: counts["enemy"] += 1
			SocialDynamics.RelationType.MENTOR, SocialDynamics.RelationType.STUDENT: counts["mentor"] += 1
			_: counts["neutral"] += 1
	return counts

func get_cliques() -> Array:
	var sd = _get_social()
	if sd:
		return sd.cliques
	return []

func get_member_social(member) -> Dictionary:
	"""Détaille le cercle social d'un membre pour l'UI."""
	var sd = _get_social()
	var info: Dictionary = {"friends": [], "rivals": [], "enemies": [], "mentors": []}
	if not sd:
		return info
	for other in sd.get_social_circle(member):
		var rel = sd.get_relationship(member, other)
		if not rel:
			continue
		match rel.type:
			SocialDynamics.RelationType.FRIEND: info["friends"].append(other.nom)
			SocialDynamics.RelationType.RIVAL: info["rivals"].append(other.nom)
			SocialDynamics.RelationType.ENEMY: info["enemies"].append(other.nom)
			SocialDynamics.RelationType.MENTOR, SocialDynamics.RelationType.STUDENT: info["mentors"].append(other.nom)
	return info

func _player_by_id(id: int):
	if not GuildManager:
		return null
	for m in GuildManager.guild_members:
		if m.get_instance_id() == id:
			return m
	return null

# --- Sauvegarde ---

func serialize() -> Dictionary:
	return {
		"guild_morale": guild_morale,
		"established_traditions": established_traditions,
		"team_building_cooldown": team_building_cooldown,
	}

func deserialize(data: Dictionary) -> void:
	guild_morale = data.get("guild_morale", 65.0)
	established_traditions = data.get("established_traditions", [])
	team_building_cooldown = data.get("team_building_cooldown", 0)
