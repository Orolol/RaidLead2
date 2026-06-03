extends Resource
class_name SimulatedPlayer
const Singletons = preload("res://scripts/utils/singletons.gd")

const PlayerTagsScript = preload("res://scripts/data/player_tags.gd")
const EquipmentScript = preload("res://scripts/resources/equipment.gd")
const LootTablesScript = preload("res://scripts/data/loot_tables.gd")
const BehaviorProfileScript = preload("res://scripts/resources/behavior_profile.gd")

const DAY_KEYS: Array[String] = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"]
const CORE_NIGHT_END := 2.0

## Identifiant stable inter-session (get_instance_id() ne survit pas au reload) —
## utilisé pour persister le graphe social. Généré une fois à la création.
static var _id_counter: int = 0
@export var player_id: String = ""

@export var nom: String = ""
@export var tags_comportement: Array = []  # Tags visibles
@export var tags_caches: Array = []  # Tags cachés
@export var tag_reveal_progress: Dictionary = {}  # Progression pour révéler les tags

# Statistiques pour la révélation des tags
@export var days_in_guild: int = 0
@export var raid_successes: int = 0
@export var wipes_experienced: int = 0
@export var loot_conflicts: int = 0
@export var activities_completed: int = 0
@export var energy: float = 100.0
@export var mood: float = 75.0
@export var skill: int = 50
@export var integration: float = 0.0
@export var planning: Dictionary = {}
@export var active_days: Array = []
@export var schedule_archetype: String = "regular"
@export var schedule_reliability: float = 0.75
@export var schedule_spontaneity: float = 0.08
@export var preferred_start_hour: float = 19.5
@export var preferred_session_hours: float = 2.5

# Nouvelles propriétés pour le Dynamic Behavior System
@export var behavior_profile: BehaviorProfileScript = null
@export var relationships: Dictionary = {}  # player_id -> relation_type
@export var fatigue_accumulated: float = 0.0  # 0-100
@export var burnout_level: int = 0  # 0-3
@export var personal_schedule_variance: Vector2 = Vector2(-0.5, 0.5)  # Variance horaire
@export var activity_preferences: Dictionary = {}  # activity_type -> weight
@export var recent_events_memory: Array = []  # Événements marquants récents
@export var circadian_type: String = "flexible"  # "morning", "evening", "flexible"

# Événements personnels
@export var has_urgent_event: bool = false
@export var scheduled_absences: Array = []
@export var bonus_session_active: bool = false
@export var bonus_session_hours: float = 0
@export var daily_event_triggered: bool = false

# Mémorisation des succès/échecs récents
@export var last_raid_success_day: int = -1
@export var last_epic_loot_day: int = -1
@export var last_wipe_day: int = -1

@export var personnage_classe: String = ""
@export var personnage_role: String = ""  # Tank, Healer, DPS
@export var personnage_niveau: int = 1
@export var personnage_xp: int = 0
@export var equipment: EquipmentScript = null
@export var or_actuel: int = 0

@export var connaissance_donjons: Dictionary = {}
@export var connaissance_raids: Dictionary = {}

# État actuel
@export var is_online: bool = false
@export var current_activity = null
@export var last_connection_time: Dictionary = {}

# Système d'effets
@export var active_effects: Array = []  # Array[EffectInstance] - duck typing pour éviter dépendance circulaire

# Phase Nationale - Celebrite et Medias
@export var celebrity_level: float = 0.0  # 0-100
@export var salary_demand: int = 0  # or/semaine pour recrues nationales (0 = pas d'exigence)

# Phase Esport - Stress competitif et burnout
@export var stress_level: float = 0.0  # 0-100, pression competitive (distinct de fatigue_accumulated)

# Propriétés pour la compatibilité

func _init() -> void:
	_id_counter += 1
	player_id = "p%d" % _id_counter
	nom = _generate_random_name()
	_generate_random_stats()
	_initialize_behavior_profile()
	regenerate_play_schedule_from_traits()

func _generate_random_name() -> String:
	var first_names: Array[String] = ["Aragorn", "Legolas", "Gimli", "Frodo", "Gandalf", "Boromir", "Elrond", "Galadriel", "Samwise", "Merry"]
	var last_names: Array[String] = ["Shadowbane", "Stormblade", "Firewalker", "Moonwhisper", "Ironforge", "Goldleaf", "Stargazer", "Dragonheart", "Windrunner", "Frostborn"]
	return first_names[randi() % first_names.size()] + last_names[randi() % last_names.size()]

func _generate_random_stats() -> void:
	var classes: Array[String] = ["Guerrier", "Mage", "Prêtre"]
	personnage_classe = classes[randi() % classes.size()]

	personnage_niveau = 1  # Tous commencent niveau 1
	
	# Initialiser l'équipement
	equipment = EquipmentScript.new()
	# Donner équipement de départ basique
	var starting_items = LootTablesScript.create_starting_equipment()
	for item in starting_items:
		equipment.equip_item(item)
	
	skill = randi_range(20, 90)
	energy = randf_range(50.0, 100.0)
	mood = randf_range(40.0, 90.0)
	
	# Utilise le nouveau système de tags
	var tag_data = PlayerTagsScript.generate_tags_for_player()
	tags_comportement = tag_data.visible
	tags_caches = tag_data.hidden
	tag_reveal_progress = tag_data.reveal_progress
	
	planning = {
		"lundi": {"soir": randf() > 0.2},  # 80% chance
		"mardi": {"soir": randf() > 0.2},  # 80% chance
		"mercredi": {"soir": randf() > 0.2},  # 80% chance
		"jeudi": {"soir": randf() > 0.2},  # 80% chance
		"vendredi": {"soir": randf() > 0.1},  # 90% chance
		"samedi": {"apres_midi": randf() > 0.2, "soir": randf() > 0.1},  # 80% and 90% chance
		"dimanche": {"apres_midi": randf() > 0.2, "soir": randf() > 0.15}  # 80% and 85% chance
	}

func regenerate_play_schedule_from_traits() -> void:
	"""Construit un profil de connexion lisible depuis les traits et le profil comportemental."""
	var all_tags: Array = get_all_tags()
	var drive: float = behavior_profile.achievement_drive if behavior_profile != null else 0.5
	var flexibility: float = behavior_profile.flexibility if behavior_profile != null else 0.5
	var routine: float = behavior_profile.routine_preference if behavior_profile != null else 0.5

	var day_target: int = 4
	if drive > 0.75 or "tryhard" in all_tags or "hardcore_gamer" in all_tags:
		day_target += 2
	elif drive > 0.55:
		day_target += 1
	if "casual" in all_tags:
		day_target -= 1
	if "joueur_weekend" in all_tags:
		day_target = maxi(day_target, 3)
	day_target = clampi(day_target, 2, 7)

	active_days = _pick_active_days(day_target, all_tags)
	schedule_archetype = _pick_schedule_archetype(all_tags)
	preferred_start_hour = _pick_preferred_start_hour()
	preferred_session_hours = _pick_preferred_session_hours(all_tags, drive)
	schedule_reliability = clampf(0.58 + routine * 0.20 + drive * 0.12, 0.35, 0.96)
	schedule_spontaneity = clampf(0.04 + flexibility * 0.16 + (0.05 if "social" in all_tags else 0.0), 0.02, 0.28)

	if "ponctuel" in all_tags:
		schedule_reliability += 0.08
	if "retardataire" in all_tags or "planning_chaotique" in all_tags:
		schedule_reliability -= 0.14
		schedule_spontaneity += 0.06
	if "solitaire" in all_tags:
		schedule_spontaneity -= 0.03
	if "insomniaque" in all_tags:
		schedule_spontaneity += 0.05
	schedule_reliability = clampf(schedule_reliability, 0.25, 0.98)
	schedule_spontaneity = clampf(schedule_spontaneity, 0.01, 0.35)

	_sync_legacy_planning()

func ensure_play_schedule() -> void:
	if active_days.is_empty():
		_restore_schedule_from_legacy()
	if active_days.is_empty():
		regenerate_play_schedule_from_traits()

func _pick_active_days(day_target: int, all_tags: Array) -> Array:
	var weighted_days: Array = []
	for day in DAY_KEYS:
		var weight: int = 3
		if day in ["vendredi", "samedi", "dimanche"]:
			weight += 2
		if "joueur_weekend" in all_tags and day in ["samedi", "dimanche"]:
			weight += 4
		if "hardcore_gamer" in all_tags:
			weight += 1
		for i in range(weight):
			weighted_days.append(day)

	var picked: Array = []
	weighted_days.shuffle()
	for day in weighted_days:
		if picked.size() >= day_target:
			break
		if day not in picked:
			picked.append(day)
	picked.sort_custom(func(a, b): return DAY_KEYS.find(a) < DAY_KEYS.find(b))
	return picked

func _pick_schedule_archetype(all_tags: Array) -> String:
	if "insomniaque" in all_tags:
		return "insomniac"
	if "nocturne" in all_tags or circadian_type == "evening":
		return "late_evening"
	if "diurne" in all_tags or circadian_type == "morning":
		return "early_evening"
	if "joueur_weekend" in all_tags:
		return "weekend"
	if "hardcore_gamer" in all_tags or "tryhard" in all_tags:
		return "hardcore"
	if "casual" in all_tags:
		return "casual"
	return "regular"

func _pick_preferred_start_hour() -> float:
	match schedule_archetype:
		"insomniac":
			return randf_range(21.5, 23.5)
		"late_evening":
			return randf_range(20.5, 22.0)
		"early_evening":
			return randf_range(17.0, 19.0)
		"weekend":
			return randf_range(18.0, 20.0)
		"casual":
			return randf_range(19.0, 20.5)
		"hardcore":
			return randf_range(18.5, 20.5)
	return randf_range(19.0, 21.0)

func _pick_preferred_session_hours(all_tags: Array, drive: float) -> float:
	var base: float = 1.8 + drive * 2.6
	if behavior_profile != null:
		base = (base + behavior_profile.preferred_session_length) * 0.5
	if "hardcore_gamer" in all_tags:
		base += 1.4
	if "tryhard" in all_tags:
		base += 0.7
	if "casual" in all_tags:
		base -= 0.6
	if "insomniaque" in all_tags:
		base += 0.8
	return clampf(base + randf_range(-0.4, 0.6), 1.0, 7.0)

func _sync_legacy_planning() -> void:
	planning = {}
	for day in DAY_KEYS:
		var is_active: bool = day in active_days
		var day_schedule: Dictionary = {"apres_midi": false, "soir": false, "nuit": false}
		if is_active:
			var weekend: bool = day in ["samedi", "dimanche"]
			day_schedule["apres_midi"] = weekend and preferred_start_hour < 18.5
			day_schedule["soir"] = preferred_start_hour < 23.0
			day_schedule["nuit"] = schedule_archetype in ["late_evening", "insomniac"] or preferred_start_hour + preferred_session_hours > 24.0
		planning[day] = day_schedule

func _restore_schedule_from_legacy() -> void:
	var restored: Array = []
	for day in DAY_KEYS:
		if not planning.has(day):
			continue
		var day_schedule: Dictionary = planning[day]
		if day_schedule.get("apres_midi", false) or day_schedule.get("soir", false) or day_schedule.get("nuit", false):
			restored.append(day)
	active_days = restored

func get_connection_score_for_time(game_time: Node) -> float:
	ensure_play_schedule()
	if game_time == null:
		return 0.0

	var day_name: String = game_time.get_day_name().to_lower()
	var hour: float = float(game_time.current_hour) + float(game_time.current_minute) / 60.0
	var all_tags: Array = get_all_tags()
	var active_today: bool = day_name in active_days
	var score: float = schedule_reliability if active_today else schedule_spontaneity * 0.35

	if not _is_reasonable_connection_hour(hour, all_tags):
		return 0.0

	var window_factor: float = _get_window_factor(hour, day_name, active_today, all_tags)
	score *= window_factor

	if active_today and day_name in ["vendredi", "samedi"]:
		score *= 1.08
	if not active_today and day_name in ["samedi", "dimanche"]:
		score *= 1.35
	if "hardcore_gamer" in all_tags:
		score *= 1.20
	if "casual" in all_tags:
		score *= 0.88
	if "ponctuel" in all_tags and absf(_hour_distance(hour, preferred_start_hour)) <= 0.4:
		score *= 1.18
	if "retardataire" in all_tags and hour < preferred_start_hour + 0.5:
		score *= 0.70

	return clampf(score, 0.0, 0.98)

func get_session_end_hour() -> float:
	ensure_play_schedule()
	return fposmod(preferred_start_hour + preferred_session_hours, 24.0)

func get_schedule_summary() -> String:
	ensure_play_schedule()
	var labels: Array[String] = []
	for day in active_days:
		labels.append(str(day).capitalize())
	return "%s, depart %.0fh, %.1fh/session" % [", ".join(labels), preferred_start_hour, preferred_session_hours]

func _is_reasonable_connection_hour(hour: float, all_tags: Array) -> bool:
	if "insomniaque" in all_tags:
		return hour >= 10.0 or hour < 5.0
	if "nocturne" in all_tags or schedule_archetype == "late_evening":
		return hour >= 12.0 or hour < CORE_NIGHT_END
	if "diurne" in all_tags or schedule_archetype == "early_evening":
		return hour >= 7.0 and hour < 23.5
	return hour >= 10.0 or hour < CORE_NIGHT_END

func _get_window_factor(hour: float, day_name: String, active_today: bool, all_tags: Array) -> float:
	var start: float = preferred_start_hour
	if "retardataire" in all_tags:
		start += 0.45
	elif "ponctuel" in all_tags:
		start -= 0.10
	if day_name in ["samedi", "dimanche"] and schedule_archetype == "weekend":
		start -= 1.0

	var hours_from_start: float = _hours_since(start, hour)
	var session_length: float = preferred_session_hours
	if not active_today:
		session_length = maxf(0.8, preferred_session_hours * 0.45)

	if hours_from_start >= 0.0 and hours_from_start <= session_length:
		var middle: float = session_length * 0.45
		var middle_distance: float = absf(hours_from_start - middle)
		return clampf(1.0 - middle_distance / maxf(session_length, 1.0) * 0.35, 0.65, 1.0)

	var before_start: float = _hour_distance(hour, start)
	if before_start <= 1.0:
		return lerpf(0.35, 0.75, 1.0 - before_start)

	var after_end: float = _hours_since(fposmod(start + session_length, 24.0), hour)
	if after_end >= 0.0 and after_end <= 1.5:
		return lerpf(0.45, 0.12, after_end / 1.5)

	return 0.05 if active_today else 0.02

func _hours_since(start_hour: float, current_hour: float) -> float:
	return fposmod(current_hour - start_hour + 24.0, 24.0)

func _hour_distance(a: float, b: float) -> float:
	var raw: float = absf(a - b)
	return minf(raw, 24.0 - raw)

func get_role() -> String:
	# Si le rôle est explicitement défini, l'utiliser
	if personnage_role != "":
		return personnage_role
		
	# Sinon, déterminer le rôle basé sur la classe
	match personnage_classe:
		"Guerrier": return "Tank"
		"Mage": return "DPS"
		"Prêtre": return "Healer"
		"Voleur": return "DPS"
		"Chasseur": return "DPS"
		"Druide": return "DPS"  # Par défaut DPS pour les druides
		"Démoniste": return "DPS"
		"Paladin": return "Tank"  # Par défaut Tank pour les paladins
		"Chaman": return "Healer"  # Par défaut Healer pour les chamans
		_: return "DPS"

func update_integration(delta: float) -> void:
	integration = clamp(integration + delta, 0.0, 100.0)
	_check_tag_reveals()

func update_energy(delta: float) -> void:
	energy = clamp(energy + delta, 0.0, 100.0)

func update_mood(delta: float) -> void:
	mood = clamp(mood + delta, 0.0, 100.0)

func is_available_now() -> bool:
	return energy > 20.0

func will_accept_activity(activity_type: String) -> bool:
	if energy < 20.0:
		return false
	
	if mood < 30.0 and activity_type != "fun":
		return false
	
	if "impatient" in tags_comportement and randf() > 0.7:
		return false
	
	return true

func go_online() -> void:
	is_online = true
	var min_connection_energy: float = 35.0
	if ServerVersion and ServerVersion.has_method("get_server_hype"):
		min_connection_energy += clampf((ServerVersion.get_server_hype() - 35.0) / 65.0, 0.0, 1.0) * 15.0
	energy = maxf(energy, min_connection_energy)

func go_offline() -> void:
	is_online = false
	current_activity = null
	
func should_connect(game_time: Node) -> bool:
	if is_online:
		return false
	return randf() < get_connection_score_for_time(game_time)

func should_disconnect(game_time: Node) -> bool:
	if not is_online:
		return false
		
	# Déconnexion si épuisé
	if energy <= 5:
		return true
		
	# Déconnexion si très tard
	if game_time.current_hour >= 2 and game_time.current_hour < 6:
		return not ("insomniaque" in get_all_tags())
		
	# Vérifie si hors planning
	var presence_score: float = get_connection_score_for_time(game_time)
	return presence_score < 0.08

# Système de révélation des tags
func _check_tag_reveals() -> void:
	var revealed_tags: Array = []

	for tag in tags_caches:
		var player_data: Dictionary = {
			"integration": integration,
			"days_in_guild": days_in_guild,
			"raid_successes": raid_successes,
			"wipes_experienced": wipes_experienced,
			"loot_conflicts": loot_conflicts,
			"reveal_progress": tag_reveal_progress
		}
		
		if PlayerTagsScript.can_reveal_tag(tag, player_data):
			revealed_tags.append(tag)
	
	# Révèle les tags découverts
	for tag in revealed_tags:
		tags_caches.erase(tag)
		tags_comportement.append(tag)
		GameLog.d("Tag révélé pour %s: %s" % [nom, tag])

func trigger_loot_conflict() -> void:
	loot_conflicts += 1
	if behavior_profile:
		behavior_profile.adjust_from_experience("social_conflict", "negative")
	_check_tag_reveals()

func trigger_wipe() -> void:
	wipes_experienced += 1
	mood = max(0, mood - 20)  # Baisse de moral importante
	add_stress(4.0)  # La pression des wipes alimente le stress competitif
	last_wipe_day = _get_current_day()
	
	# Réaction selon le profil comportemental + mémoire émotionnelle (le profil évolue).
	if behavior_profile:
		var stress_response = behavior_profile.get_stress_response(fatigue_accumulated)
		mood += stress_response.get("mood_impact", 0)
		energy += stress_response.get("energy_impact", 0)
		behavior_profile.adjust_from_experience("raid_wipe", "repeated")

	_check_tag_reveals()

func trigger_raid_success() -> void:
	raid_successes += 1
	mood = min(100, mood + 15)  # Boost de moral
	last_raid_success_day = _get_current_day()

	# Réduction de fatigue et de stress après succès
	fatigue_accumulated = max(0, fatigue_accumulated - 10)
	reduce_stress(5.0)
	if behavior_profile:
		behavior_profile.adjust_from_experience("raid_success", "positive")
	
	_check_tag_reveals()

func complete_activity() -> void:
	activities_completed += 1
	_check_tag_reveals()

func increment_days_in_guild() -> void:
	days_in_guild += 1
	_check_tag_reveals()

func get_visible_tags() -> Array:
	return tags_comportement

func get_all_tags() -> Array:
	return tags_comportement + tags_caches

func has_tag(tag: String) -> bool:
	return tag in tags_comportement or tag in tags_caches

func get_revealed_tags_count() -> int:
	"""Retourne le nombre de tags révélés selon la phase actuelle"""
	var total_tags: int = tags_comportement.size() + tags_caches.size()
	if total_tags == 0:
		return 0
	
	# En phase leveling, seulement 20% des tags sont révélés
	# Note: PhaseManager sera accessible depuis les autoloads quand implémenté
	# Pour l'instant, on retourne tous les tags visibles
	# if phase_manager and phase_manager.get_current_phase() == phase_manager.GamePhase.LEVELING:
	#	var config = phase_manager.get_current_phase_config()
	#	var reveal_rate = config.get("tag_reveal_rate", 1.0)
	#	return max(1, int(total_tags * reveal_rate))
	
	return tags_comportement.size()

func is_tag_visible(tag: String) -> bool:
	return tag in tags_comportement

# Obtient des infos pour le recrutement (limitées)
func get_recruitment_info() -> Dictionary:
	return {
		"name": nom,
		"class": personnage_classe,
		"level": personnage_niveau,
		"equipment": get_total_ilvl(),
		"visible_tags": tags_comportement.duplicate(),
		"skill_estimate": _get_skill_estimate()  # Estimation vague
	}

func get_total_ilvl() -> int:
	"""Retourne l'iLvl total de l'équipement"""
	if equipment:
		return equipment.get_total_ilvl()
	return 0

func get_equipment_summary() -> String:
	"""Retourne un résumé de l'équipement"""
	if equipment:
		return equipment.get_equipment_summary()
	return "Aucun équipement"

func get_equipment_stats() -> Dictionary:
	"""Retourne les statistiques d'équipement agrégées"""
	if equipment:
		return equipment.get_total_stats()
	return {
		"strength": 0,
		"agility": 0,
		"intelligence": 0
	}

func get_equipment_stats_summary() -> String:
	"""Retourne un résumé formaté des statistiques d'équipement"""
	if equipment:
		var summary: String = equipment.get_stats_summary()
		if summary != "":
			return summary
	return "Aucune statistique d'équipement"

const STAT_PREFERENCES: Dictionary = {
	"Guerrier": "strength", "Paladin": "strength",
	"Voleur": "agility", "Chasseur": "agility",
	"Mage": "intelligence", "Prêtre": "intelligence",
	"Démoniste": "intelligence", "Chaman": "intelligence",
	"Druide": "intelligence",
}

func get_preferred_stat() -> String:
	"""Retourne la stat préférée selon la classe"""
	return STAT_PREFERENCES.get(personnage_classe, "strength")

func calculate_item_score(item: Item) -> float:
	"""Calcule le score d'un item selon les préférences de classe"""
	var preferred: String = get_preferred_stat()
	var stat_value: int = 0
	match preferred:
		"strength":
			stat_value = item.strength
		"agility":
			stat_value = item.agility
		"intelligence":
			stat_value = item.intelligence
	return item.ilvl * 1.0 + stat_value * 0.3

func try_auto_equip(item: Item) -> Dictionary:
	"""Tente d'équiper automatiquement un item s'il est meilleur que l'actuel.
	Retourne {equipped: bool, old_item: Item ou null}"""
	if not equipment:
		equipment = EquipmentScript.new()

	var current_item: Item = equipment.get_item_in_slot(item.slot)

	if current_item == null:
		# Slot vide, toujours équiper
		equipment.equip_item(item)
		GameLog.d("%s a équipé %s (slot vide)" % [nom, item.get_display_name()])
		return {"equipped": true, "old_item": null}

	var new_score: float = calculate_item_score(item)
	var current_score: float = calculate_item_score(current_item)

	if new_score > current_score:
		var old_item: Item = equipment.equip_item(item)
		GameLog.d("%s a remplacé %s par %s" % [nom, old_item.get_display_name(), item.get_display_name()])
		return {"equipped": true, "old_item": old_item}
	else:
		return {"equipped": false, "old_item": null}

func would_be_upgrade(item: Item) -> bool:
	"""Vérifie si un item serait une amélioration sans l'équiper"""
	if not equipment:
		return true

	var current_item: Item = equipment.get_item_in_slot(item.slot)
	if current_item == null:
		return true

	return calculate_item_score(item) > calculate_item_score(current_item)

# --- Celebrite ---

func update_celebrity(delta: float) -> void:
	"""Modifie le niveau de celebrite."""
	celebrity_level = clampf(celebrity_level + delta, 0.0, 100.0)

func get_celebrity_bonus_recruitment() -> float:
	"""Bonus de recrutement lie a la celebrite."""
	if celebrity_level > 30.0:
		return 0.1
	return 0.0

func get_celebrity_poaching_risk() -> float:
	"""Risque supplementaire de debauchage."""
	if celebrity_level > 60.0:
		return 0.2
	return 0.0

# (tick_celebrity_weekly supprimé : la célébrité est gérée par MediaManager._update_celebrity,
#  cette version était du code mort qui doublonnait la logique.)

# --- Stress competitif & Burnout (Phase Esport) ---

const ESPORT_BASELINE_STRESS := 3.0

func add_stress(delta: float) -> void:
	"""Augmente le stress competitif (0-100)."""
	stress_level = clampf(stress_level + delta, 0.0, 100.0)

func reduce_stress(delta: float) -> void:
	"""Reduit le stress competitif (0-100)."""
	stress_level = clampf(stress_level - delta, 0.0, 100.0)

func get_burnout_risk() -> float:
	"""Risque de burnout (0-1) combinant stress competitif et fatigue accumulee,
	module par la tolerance au stress du profil comportemental."""
	var tolerance: float = behavior_profile.stress_tolerance if behavior_profile else 0.5
	var raw: float = (stress_level * 0.6 + fatigue_accumulated * 0.4) / 100.0
	raw *= (1.3 - tolerance * 0.6)  # tolerance 0 -> x1.3, tolerance 1 -> x0.7
	return clampf(raw, 0.0, 1.0)

func get_stress_tier() -> String:
	if stress_level >= 80.0:
		return "Critique"
	elif stress_level >= 60.0:
		return "Élevé"
	elif stress_level >= 35.0:
		return "Modéré"
	else:
		return "Maîtrisé"

func get_esport_performance_factor() -> float:
	"""Facteur multiplicatif de performance en competition selon le stress (0.7-1.0)."""
	if stress_level <= 40.0:
		return 1.0
	return clampf(1.0 - (stress_level - 40.0) * 0.005, 0.7, 1.0)  # 40 -> 1.0, 100 -> 0.7

func tick_wellbeing_weekly(stress_relief: float, morale_bonus: float, in_esport: bool) -> void:
	"""Mise a jour hebdomadaire du bien-etre, orchestree par StaffManager.
	En phase Esport, une pression de base s'accumule ; le psychologue et le repos la reduisent.
	Un stress severe degrade le moral et alimente la fatigue (qui pilote le burnout existant)."""
	if in_esport:
		var tolerance: float = behavior_profile.stress_tolerance if behavior_profile else 0.5
		add_stress(ESPORT_BASELINE_STRESS * (1.2 - tolerance * 0.6))
	if stress_relief > 0.0:
		reduce_stress(stress_relief)
	if morale_bonus != 0.0:
		update_mood(morale_bonus)
	if stress_level >= 60.0:
		update_mood(-(stress_level - 60.0) * 0.1)
	if stress_level >= 75.0:
		fatigue_accumulated = clampf(fatigue_accumulated + 4.0, 0.0, 100.0)

func equip_item(item) -> bool:
	"""Fait équiper un objet au joueur"""
	if not equipment:
		equipment = EquipmentScript.new()

	var old_item = equipment.equip_item(item)
	if old_item:
		GameLog.d("%s a remplacé %s par %s" % [nom, old_item.get_display_name(), item.get_display_name()])
	else:
		GameLog.d("%s a équipé %s" % [nom, item.get_display_name()])
	
	return true

func get_effective_skill() -> float:
	"""Retourne le skill effectif avec les modificateurs de phase"""
	var base_skill: float = float(skill)
	
	# Appliquer malus de phase leveling
	# Note: PhaseManager sera accessible depuis les autoloads quand implémenté
	# Pour l'instant, on retourne le skill sans modification
	# if phase_manager and phase_manager.get_current_phase() == phase_manager.GamePhase.LEVELING:
	#	var config = phase_manager.get_current_phase_config()
	#	var skill_malus = config.get("skill_malus", 0.0)
	#	base_skill *= (1.0 - skill_malus)
	
	return base_skill

func _get_skill_estimate() -> String:
	# Donne une estimation vague du skill
	if skill >= 80:
		return "Très expérimenté"
	elif skill >= 60:
		return "Expérimenté"
	elif skill >= 40:
		return "Moyen"
	else:
		return "Débutant"

func gain_experience(amount: int) -> void:
	personnage_xp += amount
	
	# Vérifier si on monte de niveau
	var server_version = Singletons.get_autoload("ServerVersion")
	var _max_level: int = 60 if server_version else 60

	# Formule d'XP plus progressive et réaliste
	var xp_for_next_level: int = _calculate_xp_for_level(personnage_niveau)
	
	while personnage_xp >= xp_for_next_level and personnage_niveau < _max_level:
		personnage_xp -= xp_for_next_level
		personnage_niveau += 1
		
		# Donner de l'XP à la guilde pour chaque niveau gagné
		var guild_manager = Singletons.get_autoload("GuildManager")
		if not guild_manager:
			# Repli sur l'identifiant global de l'autoload
			guild_manager = GuildManager

		if guild_manager:
			if guild_manager.guild:
				guild_manager.guild.gain_xp(personnage_niveau, nom + " a atteint le niveau " + str(personnage_niveau))
			# Émettre le signal de level up
			guild_manager.member_leveled_up.emit(self, personnage_niveau)
		
		# Améliorer légèrement les stats
		skill = min(100, skill + randi_range(1, 3))
		
		# Recalculer l'XP pour le prochain niveau
		xp_for_next_level = _calculate_xp_for_level(personnage_niveau)

func get_xp_progress() -> Dictionary:
	var xp_for_next: int = _calculate_xp_for_level(personnage_niveau)
	
	return {
		"current_xp": personnage_xp,
		"xp_for_next": xp_for_next,
		"progress_percent": float(personnage_xp) / float(xp_for_next) * 100.0 if xp_for_next > 0 else 0.0
	}

func _calculate_xp_for_level(level: int) -> int:
	"""Calcule l'XP requise pour passer au niveau suivant avec une courbe plus réaliste"""
	if level < 10:
		return 200 + (level * 50)  # 250-700 XP pour niveaux 1-9
	elif level < 20:
		return 500 + (level * 80)  # 1300-2100 XP pour niveaux 10-19
	elif level < 30:
		return 1000 + (level * 120)  # 3400-4600 XP pour niveaux 20-29
	elif level < 40:
		return 2000 + (level * 150)  # 6500-7850 XP pour niveaux 30-39
	elif level < 50:
		return 3000 + (level * 200)  # 11000-13000 XP pour niveaux 40-49
	else:
		return 5000 + (level * 300)  # 20000-23000 XP pour niveaux 50-59

# Méthodes pour le système d'effets
func get_modified_stat(stat_name: String, base_value: float) -> float:
	var effect_system = Singletons.get_autoload("EffectSystem")
	if not effect_system:
		return base_value
	
	var flat_modifier = effect_system.get_stat_modifier(self, stat_name)
	var percentage_modifier = effect_system.get_percentage_modifier(self, stat_name)
	
	var modified_value = base_value + flat_modifier
	modified_value *= (1.0 + percentage_modifier / 100.0)
	
	return modified_value

func get_modified_energy() -> float:
	return get_modified_stat("energy", energy)

func get_modified_mood() -> float:
	return get_modified_stat("mood", mood)

func get_modified_skill() -> int:
	return int(get_modified_stat("skill", float(skill)))

func get_modified_integration() -> float:
	return get_modified_stat("integration", integration)

func has_effect(effect_id: String) -> bool:
	var effect_system = Singletons.get_autoload("EffectSystem")
	if not effect_system:
		return false
	return effect_system.has_effect(self, effect_id)

func get_effects() -> Array:
	var effect_system = Singletons.get_autoload("EffectSystem")
	if not effect_system:
		return []
	return effect_system.get_effects(self)

func can_perform_action(action: String) -> bool:
	var effect_system = Singletons.get_autoload("EffectSystem")
	if not effect_system:
		return true
	
	for effect_instance in effect_system.get_effects(self):
		if action in effect_instance.effect.blocks_actions:
			return false
	
	return true

func get_available_actions() -> Array[String]:
	var base_actions: Array[String] = ["leveling", "farming", "fun", "dungeon", "raid"]
	var available_actions: Array[String] = base_actions.duplicate()
	
	var effect_system = Singletons.get_autoload("EffectSystem")
	if not effect_system:
		return available_actions
	
	# Supprimer les actions bloquées et ajouter les actions activées
	for effect_instance in effect_system.get_effects(self):
		for blocked_action in effect_instance.effect.blocks_actions:
			available_actions.erase(blocked_action)
		
		for enabled_action in effect_instance.effect.enables_actions:
			if enabled_action not in available_actions:
				available_actions.append(enabled_action)
	
	return available_actions

func _initialize_behavior_profile() -> void:
	"""Initialise le profil comportemental du joueur"""
	behavior_profile = BehaviorProfileScript.new()
	
	# Ajuster le profil selon les tags existants
	if "tryhard" in tags_comportement:
		behavior_profile.achievement_drive = randf_range(0.7, 1.0)
		behavior_profile.stress_tolerance = randf_range(0.6, 0.9)
	elif "casual" in tags_comportement:
		behavior_profile.achievement_drive = randf_range(0.2, 0.5)
		behavior_profile.routine_preference = randf_range(0.2, 0.5)
	
	if "social" in tags_comportement:
		behavior_profile.social_needs = randf_range(0.6, 0.9)
		behavior_profile.conflict_avoidance = randf_range(0.4, 0.7)
	elif "solitaire" in tags_comportement:
		behavior_profile.social_needs = randf_range(0.1, 0.4)
	
	# Définir le type circadien
	circadian_type = behavior_profile.circadian_type
	personal_schedule_variance = behavior_profile.schedule_variance
	
	# Initialiser les préférences d'activité
	_initialize_activity_preferences()

func _initialize_activity_preferences() -> void:
	"""Initialise les préférences d'activité selon le profil"""
	activity_preferences = {
		"LEVELING": 0.5,
		"FARMING": 0.5,
		"FUN": 0.5,
		"DUNGEON": 0.5,
		"RAID": 0.5,
		"OFFLINE": 1.0
	}
	
	# Ajuster selon le profil comportemental
	if behavior_profile:
		if behavior_profile.achievement_drive > 0.7:
			activity_preferences["RAID"] = 0.8
			activity_preferences["DUNGEON"] = 0.7
			activity_preferences["FUN"] = 0.3
		elif behavior_profile.achievement_drive < 0.3:
			activity_preferences["FUN"] = 0.7
			activity_preferences["RAID"] = 0.3
		
		if behavior_profile.social_needs > 0.7:
			activity_preferences["FUN"] *= 1.2
			activity_preferences["DUNGEON"] *= 1.1
			activity_preferences["RAID"] *= 1.1
		elif behavior_profile.social_needs < 0.3:
			activity_preferences["LEVELING"] *= 1.3
			activity_preferences["FARMING"] *= 1.2

func _get_current_day() -> int:
	"""Jour ABSOLU écoulé (et non current_day 1-7 qui se réinitialise chaque semaine,
	ce qui faussait les calculs "jours depuis le dernier wipe/succès/loot")."""
	var game_time = Singletons.get_autoload("GameTime")
	if game_time and game_time.has_method("get_total_days_elapsed"):
		return game_time.get_total_days_elapsed()
	return 0

func equip_epic_item(item) -> bool:
	"""Équipe un objet épique et mémorise l'événement"""
	var result: bool = equip_item(item)
	if result and item.rarity >= 3:  # Epic ou mieux
		last_epic_loot_day = _get_current_day()
		# Boost de moral pour loot épique
		mood = min(100, mood + 20)
		# Réduction de fatigue par excitation
		fatigue_accumulated = max(0, fatigue_accumulated - 5)
	return result
