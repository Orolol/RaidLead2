extends Resource
class_name SimulatedPlayer
const Singletons = preload("res://scripts/utils/singletons.gd")

const PlayerTagsScript = preload("res://scripts/data/player_tags.gd")
const EquipmentScript = preload("res://scripts/resources/equipment.gd")
const LootTablesScript = preload("res://scripts/data/loot_tables.gd")
const BehaviorProfileScript = preload("res://scripts/resources/behavior_profile.gd")

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

func _init():
	_id_counter += 1
	player_id = "p%d" % _id_counter
	nom = _generate_random_name()
	_generate_random_stats()
	_initialize_behavior_profile()

func _generate_random_name() -> String:
	var first_names = ["Aragorn", "Legolas", "Gimli", "Frodo", "Gandalf", "Boromir", "Elrond", "Galadriel", "Samwise", "Merry"]
	var last_names = ["Shadowbane", "Stormblade", "Firewalker", "Moonwhisper", "Ironforge", "Goldleaf", "Stargazer", "Dragonheart", "Windrunner", "Frostborn"]
	return first_names[randi() % first_names.size()] + last_names[randi() % last_names.size()]

func _generate_random_stats():
	var classes = ["Guerrier", "Mage", "Prêtre"]
	personnage_classe = classes[randi() % classes.size()]
	
	# Respecter le niveau maximum selon la version serveur
	var max_level = 60
	if ServerVersion:
		max_level = ServerVersion.get_max_player_level()
	
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

func update_integration(delta: float):
	integration = clamp(integration + delta, 0.0, 100.0)
	_check_tag_reveals()

func update_energy(delta: float):
	energy = clamp(energy + delta, 0.0, 100.0)

func update_mood(delta: float):
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

func go_online():
	is_online = true
	energy = max(energy, 70.0)  # Au minimum 70 d'énergie en se connectant
	
func go_offline():
	is_online = false
	current_activity = null
	
func should_connect(game_time: Node) -> bool:
	if is_online:
		return false
		
	# Vérifie le planning
	var day_name = game_time.get_day_name().to_lower()
	if not planning.has(day_name):
		return false
		
	var day_schedule = planning[day_name]
	
	# Vérifie les créneaux horaires
	if game_time.is_evening() and day_schedule.get("soir", false):
		return true
	elif game_time.is_afternoon() and day_schedule.get("apres_midi", false):
		return true
		
	return false

func should_disconnect(game_time: Node) -> bool:
	if not is_online:
		return false
		
	# Déconnexion si épuisé
	if energy <= 5:
		return true
		
	# Déconnexion si très tard
	if game_time.current_hour >= 2 and game_time.current_hour < 6:
		return true
		
	# Vérifie si hors planning
	var day_name = game_time.get_day_name().to_lower()
	if planning.has(day_name):
		var day_schedule = planning[day_name]
		var in_schedule = false
		
		if game_time.is_evening() and day_schedule.get("soir", false):
			in_schedule = true
		elif game_time.is_afternoon() and day_schedule.get("apres_midi", false):
			in_schedule = true
			
		if not in_schedule:
			return true
			
	return false

# Système de révélation des tags
func _check_tag_reveals():
	var revealed_tags = []
	
	for tag in tags_caches:
		var player_data = {
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

func trigger_loot_conflict():
	loot_conflicts += 1
	if behavior_profile:
		behavior_profile.adjust_from_experience("social_conflict", "negative")
	_check_tag_reveals()

func trigger_wipe():
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

func trigger_raid_success():
	raid_successes += 1
	mood = min(100, mood + 15)  # Boost de moral
	last_raid_success_day = _get_current_day()

	# Réduction de fatigue et de stress après succès
	fatigue_accumulated = max(0, fatigue_accumulated - 10)
	reduce_stress(5.0)
	if behavior_profile:
		behavior_profile.adjust_from_experience("raid_success", "positive")
	
	_check_tag_reveals()

func complete_activity():
	activities_completed += 1
	_check_tag_reveals()

func increment_days_in_guild():
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
	var total_tags = tags_comportement.size() + tags_caches.size()
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
		var summary = equipment.get_stats_summary()
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
	var base_skill = float(skill)
	
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
	var _max_level = 60 if server_version else 60
	
	# Formule d'XP plus progressive et réaliste
	var xp_for_next_level = _calculate_xp_for_level(personnage_niveau)
	
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
	var xp_for_next = _calculate_xp_for_level(personnage_niveau)
	
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

func _initialize_behavior_profile():
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

func _initialize_activity_preferences():
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

func equip_epic_item(item):
	"""Équipe un objet épique et mémorise l'événement"""
	var result = equip_item(item)
	if result and item.rarity >= 3:  # Epic ou mieux
		last_epic_loot_day = _get_current_day()
		# Boost de moral pour loot épique
		mood = min(100, mood + 20)
		# Réduction de fatigue par excitation
		fatigue_accumulated = max(0, fatigue_accumulated - 5)
	return result
