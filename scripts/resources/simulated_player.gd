extends Resource
class_name SimulatedPlayer

const PlayerTagsScript = preload("res://scripts/data/player_tags.gd")

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
@export var energie: float = 100.0
@export var humeur: float = 75.0
@export var skill: int = 50
@export var integration: float = 0.0
@export var planning: Dictionary = {}

@export var personnage_classe: String = ""
@export var personnage_niveau: int = 1
@export var personnage_equipement: int = 0

@export var connaissance_donjons: Dictionary = {}
@export var connaissance_raids: Dictionary = {}

# État actuel
@export var is_online: bool = false
@export var current_activity = null
@export var last_connection_time: Dictionary = {}

# Propriétés pour la compatibilité

func _init():
	nom = _generate_random_name()
	_generate_random_stats()

func _generate_random_name() -> String:
	var first_names = ["Aragorn", "Legolas", "Gimli", "Frodo", "Gandalf", "Boromir", "Elrond", "Galadriel", "Samwise", "Merry"]
	var last_names = ["Shadowbane", "Stormblade", "Firewalker", "Moonwhisper", "Ironforge", "Goldleaf", "Stargazer", "Dragonheart", "Windrunner", "Frostborn"]
	return first_names[randi() % first_names.size()] + last_names[randi() % last_names.size()]

func _generate_random_stats():
	var classes = ["Guerrier", "Mage", "Prêtre"]
	personnage_classe = classes[randi() % classes.size()]
	
	personnage_niveau = randi_range(1, 60)
	personnage_equipement = personnage_niveau * randi_range(2, 5)
	
	skill = randi_range(20, 90)
	energie = randf_range(50.0, 100.0)
	humeur = randf_range(40.0, 90.0)
	
	# Utilise le nouveau système de tags
	var tag_data = PlayerTagsScript.generate_tags_for_player()
	tags_comportement = tag_data.visible
	tags_caches = tag_data.hidden
	tag_reveal_progress = tag_data.reveal_progress
	
	planning = {
		"lundi": {"soir": randf() > 0.3},
		"mardi": {"soir": randf() > 0.3},
		"mercredi": {"soir": randf() > 0.3},
		"jeudi": {"soir": randf() > 0.3},
		"vendredi": {"soir": randf() > 0.5},
		"samedi": {"apres_midi": randf() > 0.3, "soir": randf() > 0.2},
		"dimanche": {"apres_midi": randf() > 0.3, "soir": randf() > 0.4}
	}

func get_role() -> String:
	match personnage_classe:
		"Guerrier": return "Tank"
		"Mage": return "DPS"
		"Prêtre": return "Healer"
		_: return "DPS"

func update_integration(delta: float):
	integration = clamp(integration + delta, 0.0, 100.0)
	_check_tag_reveals()

func update_energie(delta: float):
	energie = clamp(energie + delta, 0.0, 100.0)

func update_humeur(delta: float):
	humeur = clamp(humeur + delta, 0.0, 100.0)

func is_available_now() -> bool:
	return energie > 20.0

func will_accept_activity(activity_type: String) -> bool:
	if energie < 20.0:
		return false
	
	if humeur < 30.0 and activity_type != "fun":
		return false
	
	if "impatient" in tags_comportement and randf() > 0.7:
		return false
	
	return true

func go_online():
	is_online = true
	energie = max(energie, 50.0)  # Au minimum 50 d'énergie en se connectant
	
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
	if energie <= 10:
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
		print("Tag révélé pour %s: %s" % [nom, tag])

func trigger_loot_conflict():
	loot_conflicts += 1
	_check_tag_reveals()

func trigger_wipe():
	wipes_experienced += 1
	humeur = max(0, humeur - 20)  # Baisse de moral importante
	_check_tag_reveals()

func trigger_raid_success():
	raid_successes += 1
	humeur = min(100, humeur + 15)  # Boost de moral
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

func is_tag_visible(tag: String) -> bool:
	return tag in tags_comportement

# Obtient des infos pour le recrutement (limitées)
func get_recruitment_info() -> Dictionary:
	return {
		"name": nom,
		"class": personnage_classe,
		"level": personnage_niveau,
		"equipment": personnage_equipement,
		"visible_tags": tags_comportement.duplicate(),
		"skill_estimate": _get_skill_estimate()  # Estimation vague
	}

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