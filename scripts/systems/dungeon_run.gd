extends Resource
class_name DungeonRun
const Singletons = preload("res://scripts/utils/singletons.gd")

const DungeonDataScript = preload("res://scripts/data/dungeon_data.gd")
const ActivityScript = preload("res://scripts/resources/activity.gd")
const LootTablesScript = preload("res://scripts/data/loot_tables.gd")

signal boss_defeated(boss_name, loot_dropped)
signal run_completed(success, loot_gained)
signal player_wiped(reason)
signal progress_updated(current_boss, total_bosses)
signal loot_distributed(member, item)

@export var instance_id: String = ""
@export var instance_data: Dictionary = {}
@export var group_members: Array = []
@export var start_time: Dictionary = {}
@export var is_active: bool = false
@export var current_boss_index: int = 0
@export var defeated_bosses: Array = []
@export var loot_collected: Dictionary = {}  # member_name -> equipment_gained
@export var wipe_count: int = 0

# Statistiques de run
@export var total_damage_done: int = 0
@export var total_healing_done: int = 0
@export var deaths_count: int = 0

func start_run(instance: String, members: Array):
	instance_id = instance
	instance_data = DungeonDataScript.get_instance_data(instance)
	group_members = members
	is_active = true
	current_boss_index = 0
	defeated_bosses.clear()
	loot_collected.clear()
	wipe_count = 0
	
	# Marque le début
	var game_time = Singletons.get_autoload("GameTime")
	if game_time:
		start_time = {
			"hour": game_time.current_hour,
			"day": game_time.current_day
		}
	
	# Applique les effets de début de donjon
	for member in group_members:
		member.current_activity = Activity.new(Activity.ActivityType.DUNGEON, instance_data.name)

func simulate_boss_fight(boss_index: int) -> Dictionary:
	if boss_index >= instance_data.bosses.size():
		return {"success": false, "reason": "Boss invalide"}
		
	var boss_name = instance_data.bosses[boss_index]
	var difficulty_score = DungeonDataScript.calculate_difficulty_score(instance_id, group_members)
	
	# Facteurs de succès
	var success_chance = difficulty_score
	
	# Bonus pour la connaissance du donjon
	var avg_knowledge = 0.0
	for member in group_members:
		var knowledge = member.connaissance_donjons.get(instance_id, 0.0)
		avg_knowledge += knowledge
	avg_knowledge /= float(group_members.size())
	success_chance *= (1.0 + avg_knowledge / 200.0)  # Max +50% avec 100 de connaissance
	
	# Malus pour la fatigue
	var avg_energy = 0.0
	for member in group_members:
		avg_energy += member.energy
	avg_energy /= float(group_members.size())
	if avg_energy < 30:
		success_chance *= 0.7
	
	# Malus pour le moral bas
	var avg_mood = 0.0
	for member in group_members:
		avg_mood += member.mood
	avg_mood /= float(group_members.size())
	if avg_mood < 40:
		success_chance *= 0.8
	
	# Vérification de la composition
	var composition = _check_group_composition()
	if not composition.valid:
		success_chance *= 0.5  # Très dur sans la bonne compo
	
	# Jet de dés
	var roll = randf()
	var success = roll < success_chance
	
	# Résultats
	var result = {
		"success": success,
		"boss_name": boss_name,
		"roll": roll,
		"success_chance": success_chance,
		"composition": composition
	}
	
	if success:
		defeated_bosses.append(boss_name)
		_update_member_knowledge(5.0)  # Gain de connaissance
		_handle_loot_drop(boss_name, boss_index)
		current_boss_index += 1
		progress_updated.emit(current_boss_index, instance_data.bosses.size())
	else:
		_handle_wipe()
		result["wipe_reason"] = _generate_wipe_reason(boss_name, composition)
	
	return result

func _check_group_composition() -> Dictionary:
	var required = DungeonDataScript.get_group_composition(instance_id)
	var actual = {"Tank": 0, "Healer": 0, "DPS": 0}
	
	for member in group_members:
		var role = member.get_role()
		if actual.has(role):
			actual[role] += 1
	
	var valid = true
	var missing = []
	
	for role in required:
		if actual[role] < required[role]:
			valid = false
			missing.append("%d %s" % [required[role] - actual[role], role])
	
	return {
		"valid": valid,
		"required": required,
		"actual": actual,
		"missing": missing
	}

func _handle_loot_drop(boss_name: String, boss_index: int):
	# Chance de loot dépend du boss (dernier boss = meilleur loot)
	var loot_chance = 0.3 + (float(boss_index) / float(instance_data.bosses.size())) * 0.4
	
	if randf() < loot_chance:
		# Générer un objet selon le système de loot
		var is_heroic = DungeonDataScript.is_heroic_dungeon(instance_id)
		var looted_item = LootTablesScript.generate_item_for_level(instance_data.equipment_reward_level, is_heroic)
		
		# Détermine qui reçoit le loot (les joueurs avec moins d'équipement sont prioritaires)
		var eligible_members = []
		for member in group_members:
			if member.get_total_ilvl() < instance_data.equipment_reward_level:
				eligible_members.append(member)
		
		if eligible_members.is_empty():
			eligible_members = group_members
		
		# Attribution du loot
		var chosen_member = eligible_members[randi() % eligible_members.size()]

		# Vérifier les comportements spéciaux
		if chosen_member.has_tag("ninja_looter") and randf() < 0.3:
			# 30% de chance qu'un ninja looter vole un loot supplémentaire
			# Créer un conflit
			for other_member in group_members:
				if other_member != chosen_member:
					other_member.trigger_loot_conflict()

		# Équiper l'objet avec auto-equip
		chosen_member.try_auto_equip(looted_item)

		# Ajouter à l'historique de loot
		var guild_manager_node = Engine.get_main_loop().root.get_node_or_null("/root/GuildManager") if Engine.get_main_loop() else null
		if guild_manager_node:
			guild_manager_node.add_loot_entry(looted_item, chosen_member.nom, instance_data.get("name", ""), boss_name)
		
		if not loot_collected.has(chosen_member.nom):
			loot_collected[chosen_member.nom] = []
		loot_collected[chosen_member.nom].append(looted_item)
		
		# Émettre le signal de distribution de loot
		loot_distributed.emit(chosen_member, looted_item)
		
		boss_defeated.emit(boss_name, true)
		
		# Réactions au loot
		for member in group_members:
			if member == chosen_member:
				member.mood = min(100, member.mood + 10)
			elif member.has_tag("greedy"):
				member.mood = max(0, member.mood - 5)  # Jaloux
	else:
		boss_defeated.emit(boss_name, false)

func _handle_wipe():
	wipe_count += 1
	
	# Effets du wipe
	for member in group_members:
		member.trigger_wipe()
		member.energy = max(0, member.energy - 20)
		
		# Les joueurs avec certains tags réagissent différemment
		if member.has_tag("rage_quitter") and wipe_count >= 2:
			# Risque de quitter le groupe
			if randf() < 0.4:
				print("%s rage quit le groupe !" % member.nom)
	
	player_wiped.emit(_generate_wipe_reason("", {"valid": true}))

func _generate_wipe_reason(boss_name: String, composition: Dictionary) -> String:
	var reasons = []
	
	if not composition.valid:
		reasons.append("Composition inadéquate: manque " + ", ".join(composition.missing))
	
	if boss_name != "":
		reasons.append("%s était trop puissant" % boss_name)
	
	# Raisons aléatoires basées sur les tags
	for member in group_members:
		if member.has_tag("impatient") and randf() < 0.2:
			reasons.append("%s a pull trop tôt" % member.nom)
		if member.skill < 30 and randf() < 0.3:
			reasons.append("%s ne connaissait pas la stratégie" % member.nom)
	
	if reasons.is_empty():
		reasons.append("Manque de coordination")
	
	return reasons[randi() % reasons.size()]

func _update_member_knowledge(gain: float):
	for member in group_members:
		if not member.connaissance_donjons.has(instance_id):
			member.connaissance_donjons[instance_id] = 0.0
		member.connaissance_donjons[instance_id] = min(100.0, member.connaissance_donjons[instance_id] + gain)

func complete_run(success: bool):
	is_active = false
	
	# Mise à jour finale des membres
	for member in group_members:
		if success:
			member.trigger_raid_success()
			_update_member_knowledge(10.0)  # Bonus pour complétion
		
		member.complete_activity()
		member.energy = max(0, member.energy - 30)  # Fatigue après le donjon
	
	# Donner de l'XP à la guilde si succès
	if success:
		var guild_manager = Singletons.get_autoload("GuildManager")
		if guild_manager and guild_manager.guild:
			guild_manager.guild.gain_xp(100, "Donjon complété: " + instance_data.name)
		
		# Vérifier si c'était un donjon héroïque et notifier PhaseManager
		var is_heroic = DungeonDataScript.is_heroic_dungeon(instance_id)
		if is_heroic:
			var phase_manager = Singletons.get_autoload("PhaseManager")
			if phase_manager:
				phase_manager.complete_heroic_dungeon(instance_data.name)
	
	run_completed.emit(success, loot_collected)

func can_continue() -> bool:
	# Vérifie si le groupe peut continuer
	if wipe_count >= 3:
		return false
		
	var avg_energy = 0.0
	var avg_mood = 0.0
	
	for member in group_members:
		avg_energy += member.energy
		avg_mood += member.mood
		
	avg_energy /= float(group_members.size())
	avg_mood /= float(group_members.size())
	
	return avg_energy > 20 and avg_mood > 20

func get_progress_percentage() -> float:
	if instance_data.bosses.is_empty():
		return 0.0
	return float(defeated_bosses.size()) / float(instance_data.bosses.size()) * 100.0