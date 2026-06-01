extends Resource
class_name DungeonInstance

const DungeonDataScript = preload("res://scripts/data/dungeon_data.gd")
const LootTables = preload("res://scripts/data/loot_tables.gd")
const PveRunReportScript = preload("res://scripts/systems/pve_run_report.gd")

signal boss_reached(boss_index: int, boss_name: String)
signal boss_defeated(boss_index: int, boss_name: String, loot_winner: SimulatedPlayer)
signal boss_failed(boss_index: int, boss_name: String, wipe_count: int)
signal dungeon_completed(total_time: float, gold_reward: int)
signal dungeon_abandoned(reason: String)
signal progress_updated(progress_percent: float)
signal loot_distributed(member, item)

@export var dungeon_id: String = ""
@export var dungeon_data: Dictionary = {}
@export var group_members: Array[SimulatedPlayer] = []
@export var start_time: float = 0.0
@export var current_boss_index: int = 0
@export var is_active: bool = false
@export var wipe_count: int = 0
@export var total_wipes: int = 0
@export var progress_percent: float = 0.0
@export var time_lost_to_wipes: float = 0.0

# Variables pour le timing
var expected_boss_times: Array[float] = []
var boss_times: Array[float] = []  # Temps entre chaque boss
var game_time_node = null  # Référence à GameTime
var current_position: float = 0.0  # Position actuelle sur le chemin (0.0 à 1.0)
var boss_positions: Array[float] = []  # Positions des boss sur le chemin
var time_to_next_boss: float = 0.0
var is_fighting_boss: bool = false
var boss_fight_start_time: float = 0.0
var boss_fight_elapsed: float = 0.0  # temps de JEU écoulé dans le combat en cours

# Configuration
const WIPE_TIME_PENALTY: float = 180.0  # 3 minutes perdues par wipe
const MORALE_LOSS_PER_WIPE: int = 10
const MAX_WIPES_BEFORE_ABANDON: int = 10
const BOSS_BASE_FIGHT_TIME: float = 120.0  # 2 minutes par boss de base
const BOSS_RESOLVE_SECONDS: float = 2.0    # durée (temps de jeu) avant résolution d'un boss

func initialize(p_dungeon_id: String, p_group_members: Array) -> void:
	dungeon_id = p_dungeon_id
	dungeon_data = DungeonDataScript.get_instance_data(dungeon_id)
	
	# Copier les membres du groupe
	group_members.clear()
	for member in p_group_members:
		if member is SimulatedPlayer:
			group_members.append(member)
	
	# Initialiser les temps et positions
	_calculate_boss_times_and_positions()
	
	# Démarrer l'instance
	# Le temps sera récupéré lors du premier update
	start_time = 0.0
	
	is_active = true
	current_boss_index = 0
	current_position = 0.0
	wipe_count = 0
	total_wipes = 0
	progress_percent = 0.0
	is_fighting_boss = false
	
	# Calculer le temps jusqu'au premier boss
	if boss_positions.size() > 0:
		time_to_next_boss = boss_positions[0] * dungeon_data.get("duration_minutes", 60) * 60.0

func _calculate_boss_times_and_positions() -> void:
	expected_boss_times.clear()
	boss_positions.clear()
	boss_times.clear()
	
	if not dungeon_data.has("bosses"):
		return
		
	var bosses = dungeon_data.bosses
	var num_bosses = bosses.size()
	if num_bosses == 0:
		return
		
	var total_duration = dungeon_data.get("duration_minutes", 60) * 60.0
	
	# Répartir les boss uniformément sur le chemin
	# avec un peu plus de temps avant le dernier boss
	for i in range(num_bosses):
		var position: float
		if i == num_bosses - 1:
			# Le dernier boss est à 90% du chemin
			position = 0.9
		else:
			# Les autres boss sont répartis uniformément sur les 80% premiers
			position = (float(i) / float(num_bosses - 1)) * 0.8
		
		boss_positions.append(position)
		expected_boss_times.append(position * total_duration)
		
		# Calculer le temps entre chaque boss
		if i == 0:
			boss_times.append(position * total_duration)
		else:
			var prev_time = expected_boss_times[i-1]
			boss_times.append(position * total_duration - prev_time)

func update(delta: float, game_time_ref = null) -> void:
	if not is_active:
		return
	
	# Stocker la référence à GameTime
	if game_time_ref:
		game_time_node = game_time_ref
	
	# Ne rien faire si le jeu est en pause
	if game_time_node and game_time_node.is_paused:
		return
		
	# Initialiser start_time si nécessaire
	if start_time == 0.0 and game_time_node:
		start_time = game_time_node.get_current_timestamp()
	
	if is_fighting_boss:
		# En combat contre un boss
		_update_boss_fight(delta)
	else:
		# En progression vers le prochain boss
		_update_progression(delta, game_time_node)
		
	# Vérifier si le donjon est terminé
	if current_boss_index >= dungeon_data.bosses.size() and is_active:
		_complete_dungeon()
		return
		
	# Mettre à jour le pourcentage de progression global (monotone : ne recule jamais).
	var boss_progress = float(current_boss_index) / float(dungeon_data.bosses.size())
	var path_progress = current_position * 0.1  # Le chemin compte pour 10%
	progress_percent = maxf(progress_percent, (boss_progress * 0.9 + path_progress) * 100.0)
	progress_updated.emit(progress_percent)

func _update_progression(delta: float, game_time_ref = null) -> void:
	# Utiliser le delta du temps du jeu au lieu du temps réel
	var game_delta = delta
	
	# Ne pas progresser si le jeu est en pause
	if game_time_ref:
		if game_time_ref.is_paused:
			return
		if game_time_ref.time_speed > 0:
			game_delta = delta * game_time_ref.time_speed
	
	time_to_next_boss -= game_delta
	
	if time_to_next_boss <= 0.0 and current_boss_index < boss_positions.size():
		# Arrivé au boss
		_start_boss_fight(game_time_node)
	else:
		# Mettre à jour la position sur le chemin entre les boss
		if current_boss_index < boss_positions.size():
			var current_boss_pos = boss_positions[current_boss_index]
			var prev_boss_pos = boss_positions[current_boss_index - 1] if current_boss_index > 0 else 0.0
			var segment_length = current_boss_pos - prev_boss_pos
			var time_for_segment = boss_times[current_boss_index] if current_boss_index < boss_times.size() else 300.0
			var time_in_segment = time_for_segment - time_to_next_boss
			var segment_progress = clamp(time_in_segment / time_for_segment, 0.0, 1.0)
			current_position = prev_boss_pos + segment_progress * segment_length
		else:
			current_position = 1.0

func _start_boss_fight(game_time_ref = null) -> void:
	is_fighting_boss = true
	boss_fight_elapsed = 0.0
	if game_time_ref:
		boss_fight_start_time = game_time_ref.get_current_timestamp()
	else:
		boss_fight_start_time = 0.0

	var boss_name = dungeon_data.bosses[current_boss_index]
	boss_reached.emit(current_boss_index, boss_name)
	# La résolution se fait en TEMPS DE JEU dans _update_boss_fight (respecte pause/vitesse),
	# et non plus via un timer temps-réel qui se désynchronisait à haute vitesse.

func _simulate_boss_fight() -> void:
	var boss_name = dungeon_data.bosses[current_boss_index]
	var is_final_boss = current_boss_index == dungeon_data.bosses.size() - 1
	
	# Calculer la difficulté du boss
	var boss_difficulty = dungeon_data.get("difficulty", 1.0)
	if is_final_boss:
		boss_difficulty *= dungeon_data.get("boss_difficulty_multiplier", 1.2)
	
	# Calculer les chances de succès du groupe
	var success_chance = _calculate_boss_success_chance(boss_difficulty)
	
	# Appliquer une pénalité basée sur le nombre de wipes
	success_chance *= pow(0.95, wipe_count)  # -5% par wipe

	# Bonus de coordination de guilde (perks Ventrilo / Teamspeak).
	if GuildManager and GuildManager.guild:
		success_chance *= (1.0 + GuildManager.guild.get_raid_success_bonus())
	success_chance = clampf(success_chance, 0.05, 0.98)

	# Résoudre le combat
	if randf() < success_chance:
		_on_boss_defeated()
	else:
		_on_boss_failed()

func _calculate_boss_success_chance(boss_difficulty: float) -> float:
	var base_score = 0.0
	var total_members = group_members.size()
	
	if total_members == 0:
		return 0.0
		
	# Calculer le score moyen du groupe
	for member in group_members:
		var member_score = 0.0
		
		# Niveau par rapport au donjon
		var level_diff = member.personnage_niveau - dungeon_data.level_recommended
		member_score += 0.3 * (1.0 + level_diff / 10.0)
		
		# Skill
		member_score += 0.3 * (member.skill / 100.0)
		
		# Équipement
		var expected_equipment = dungeon_data.level_recommended * 3
		member_score += 0.2 * (member.get_total_ilvl() / expected_equipment)
		
		# Moral
		member_score += 0.1 * (member.mood / 100.0)
		
		# Énergie
		member_score += 0.1 * (member.energy / 100.0)
		
		base_score += member_score
		
	base_score /= total_members
	
	# Vérifier la composition du groupe
	var composition = DungeonDataScript.get_group_composition(dungeon_id)
	var composition_penalty = _check_group_composition(composition)
	base_score *= composition_penalty

	# Familiarité avec le contenu : la connaissance du donjon (0-100) ajoute jusqu'à +50%.
	var avg_knowledge: float = 0.0
	for member in group_members:
		avg_knowledge += float(member.connaissance_donjons.get(dungeon_id, 0.0))
	avg_knowledge /= float(total_members)
	base_score *= (1.0 + avg_knowledge / 200.0)

	# Bonus du staff professionnel (coach/analyste) — rend l'investissement staff visible en PvE.
	if StaffManager:
		base_score *= (1.0 + minf(StaffManager.get_total_performance_bonus(), 0.3))

	# Modificateur circadien moyen : les types matin/soir performent mieux/moins selon l'heure.
	if GuildManager and GuildManager.behavior_system and game_time_node:
		var bs = GuildManager.behavior_system
		if bs.has_method("apply_circadian_modifier"):
			var circ_sum: float = 0.0
			for member in group_members:
				circ_sum += bs.apply_circadian_modifier(member, game_time_node.current_hour)
			base_score *= circ_sum / float(total_members)

	# Appliquer la difficulté
	var success_chance = base_score / boss_difficulty

	return clamp(success_chance, 0.1, 0.95)

func _check_group_composition(required_comp: Dictionary) -> float:
	var actual_comp = {"Tank": 0, "Healer": 0, "DPS": 0}
	
	for member in group_members:
		var role = member.personnage_role
		if actual_comp.has(role):
			actual_comp[role] += 1
			
	var penalty = 1.0
	
	# Pénalités pour composition incorrecte
	if actual_comp["Tank"] < required_comp.get("Tank", 1):
		penalty *= 0.5  # Grosse pénalité sans tank
	if actual_comp["Healer"] < required_comp.get("Healer", 1):
		penalty *= 0.6  # Grosse pénalité sans healer
	if actual_comp["DPS"] < required_comp.get("DPS", 3):
		penalty *= 0.9  # Pénalité moindre pour manque de DPS
		
	return penalty

func _on_boss_defeated() -> void:
	var boss_name: String = dungeon_data.bosses[current_boss_index]

	# Familiarité progressive avec le donjon (lue par le calcul de réussite).
	_grant_knowledge(5.0)

	# Vérifier si le boss drop du loot
	var is_heroic: bool = DungeonDataScript.is_heroic_dungeon(dungeon_id)
	var loot_chance: float = LootTables.get_boss_loot_chance(current_boss_index, dungeon_data.bosses.size(), is_heroic)

	var loot_winner: SimulatedPlayer = null
	var looted_item: Item = null

	if randf() < loot_chance:
		# Générer un objet
		looted_item = LootTables.generate_item_for_level(dungeon_data.equipment_reward_level, is_heroic)

		if looted_item and group_members.size() > 0:
			var d_name: String = dungeon_data.get("name", "")

			# Vérifier les conflits de loot pour les items rares+
			if looted_item.rarity >= Item.Rarity.RARE:
				var eligible_members: Array[SimulatedPlayer] = []
				for member in group_members:
					if member.would_be_upgrade(looted_item):
						eligible_members.append(member)

				if eligible_members.size() >= 2 and randf() >= (GuildManager.guild.get_loot_conflict_reduction() if (GuildManager and GuildManager.guild) else 0.0):
					# Conflit de loot - laisser le joueur décider
					var conflict: Dictionary = {
						"item": looted_item,
						"candidates": eligible_members,
						"dungeon_name": d_name,
						"boss_name": boss_name,
					}
					GuildManager.loot_conflict_occurred.emit(conflict)
					# Ne pas distribuer maintenant, le signal gère la suite
					boss_defeated.emit(current_boss_index, boss_name, null)

					# Continuer la progression normalement
					wipe_count = 0
					current_boss_index += 1
					is_fighting_boss = false
					if current_boss_index > 0 and current_boss_index - 1 < boss_positions.size():
						current_position = boss_positions[current_boss_index - 1]
					if current_boss_index >= dungeon_data.bosses.size():
						_complete_dungeon()
					else:
						var current_time: float = get_elapsed_time(game_time_node) - time_lost_to_wipes
						var next_boss_time: float = expected_boss_times[current_boss_index]
						time_to_next_boss = max(30.0, next_boss_time - current_time)
					return

			# Distribution équitable : priorité au membre éligible le moins équipé (pas d'aléatoire pur).
			loot_winner = _pick_loot_winner(looted_item)

			if loot_winner and looted_item:
				loot_winner.try_auto_equip(looted_item)
				GuildManager.add_loot_entry(looted_item, loot_winner.nom, d_name, boss_name)
				# Émettre le signal de distribution de loot pour le chat
				loot_distributed.emit(loot_winner, looted_item)

	# Le signal boss_defeated ne déclare que 3 paramètres (boss_index, boss_name, loot_winner)
	boss_defeated.emit(current_boss_index, boss_name, loot_winner)
	
	# Réinitialiser le compteur de wipes pour ce boss
	wipe_count = 0
	
	# Passer au boss suivant
	current_boss_index += 1
	is_fighting_boss = false
	
	# Mettre à jour la position après avoir vaincu le boss
	if current_boss_index > 0 and current_boss_index - 1 < boss_positions.size():
		current_position = boss_positions[current_boss_index - 1]
	
	if current_boss_index >= dungeon_data.bosses.size():
		# Donjon terminé !
		_complete_dungeon()
	else:
		# Calculer le temps jusqu'au prochain boss
		var current_time = get_elapsed_time(game_time_node) - time_lost_to_wipes
		var next_boss_time = expected_boss_times[current_boss_index]
		time_to_next_boss = max(30.0, next_boss_time - current_time)  # Au moins 30 secondes

func _on_boss_failed() -> void:
	wipe_count += 1
	total_wipes += 1
	
	var boss_name = dungeon_data.bosses[current_boss_index]
	boss_failed.emit(current_boss_index, boss_name, wipe_count)
	
	# Ajouter la pénalité de temps
	time_lost_to_wipes += WIPE_TIME_PENALTY
	
	# Réduire le moral du groupe
	for member in group_members:
		member.mood = max(0, member.mood - MORALE_LOSS_PER_WIPE)
		member.energy = max(0, member.energy - 5)
	
	# Vérifier si on abandonne
	if total_wipes >= MAX_WIPES_BEFORE_ABANDON:
		_abandon_dungeon("Trop de wipes (%d)" % total_wipes)
		return
		
	# Vérifier le moral du groupe
	var avg_morale = 0
	for member in group_members:
		avg_morale += member.mood
	avg_morale /= group_members.size()
	
	if avg_morale < 20:
		_abandon_dungeon("Moral trop bas")
		return
		
	# Sinon, on retente le boss après un délai
	is_fighting_boss = false
	time_to_next_boss = 30.0  # 30 secondes avant de retenter

func _update_boss_fight(delta: float) -> void:
	# Résout le combat après un court laps de TEMPS DE JEU (respecte pause et vitesse).
	var gdelta: float = delta
	if game_time_node:
		if game_time_node.is_paused:
			return
		if game_time_node.time_speed > 0:
			gdelta = delta * game_time_node.time_speed
	boss_fight_elapsed += gdelta
	if boss_fight_elapsed >= BOSS_RESOLVE_SECONDS:
		boss_fight_elapsed = 0.0
		if is_active and current_boss_index < dungeon_data.bosses.size():
			_simulate_boss_fight()

func _complete_dungeon() -> void:
	is_active = false
	_grant_knowledge(10.0)  # bonus de familiarité pour avoir terminé le contenu
	var total_time = get_elapsed_time(game_time_node)
	var gold_reward: int = int(dungeon_data.get("gold_reward", 100))
	if BalanceManager:
		gold_reward = int(gold_reward * BalanceManager.tunable_float("pve.gold_reward_mult", 1.0))

	# Récompense d'or → trésorerie de guilde : c'est le revenu principal de la boucle PvE.
	if GuildManager and GuildManager.guild:
		GuildManager.guild.add_gold(gold_reward)
		# XP de guilde (fait progresser le niveau, 20% du score de classement).
		var is_raid_clear: bool = int(dungeon_data.get("type", -1)) == DungeonDataScript.InstanceType.RAID
		var guild_xp: int = 250 if is_raid_clear else 100
		if DungeonDataScript.is_heroic_dungeon(dungeon_id):
			guild_xp += 100
		GuildManager.guild.gain_xp(guild_xp, "Contenu complété : " + str(dungeon_data.get("name", "")))

	# Part personnelle (flavor) + bonus de moral pour les participants.
	var member_count: int = max(1, group_members.size())
	var gold_per_member: int = int(gold_reward * 0.2) / member_count
	for member in group_members:
		member.or_actuel += gold_per_member
		# Bonus de moral pour avoir terminé
		member.mood = min(100, member.mood + 20)

	dungeon_completed.emit(total_time, gold_reward)
	
	if GuildRanking:
		var participant_names: Array = []
		for member in group_members:
			participant_names.append(member.nom)
		var total_bosses: int = dungeon_data.get("bosses", []).size()
		var expected_duration_seconds: float = float(dungeon_data.get("duration_minutes", 60)) * 60.0
		var run_details: Dictionary = {
			"duration_seconds": total_time,
			"gold_reward": gold_reward,
			"wipes": total_wipes,
			"bosses_defeated": total_bosses,
			"total_bosses": total_bosses,
			"expected_duration_seconds": expected_duration_seconds
		}
		run_details["performance_score"] = PveRunReportScript.calculate_performance_score(true, total_time, gold_reward, 0, run_details)
		GuildRanking.register_player_content_clear(
			dungeon_id,
			dungeon_data.get("name", ""),
			dungeon_data.get("type", -1),
			DungeonDataScript.is_heroic_dungeon(dungeon_id),
			participant_names,
			run_details
		)

	# Progression de phase : compléter un donjon héroïque fait avancer la Phase 0 -> Serveur
	if DungeonDataScript.is_heroic_dungeon(dungeon_id) and PhaseManager:
		PhaseManager.complete_heroic_dungeon(dungeon_data.get("name", ""))

func _abandon_dungeon(reason: String) -> void:
	is_active = false
	
	# Pénalité de moral pour abandon
	for member in group_members:
		member.mood = max(0, member.mood - 20)
		
	dungeon_abandoned.emit(reason)

func get_current_boss_name() -> String:
	if current_boss_index < dungeon_data.bosses.size():
		return dungeon_data.bosses[current_boss_index]
	return ""

func get_remaining_bosses() -> int:
	return dungeon_data.bosses.size() - current_boss_index

func get_elapsed_time(game_time_ref = null) -> float:
	if game_time_ref:
		return game_time_ref.get_current_timestamp() - start_time
	else:
		return 0.0

func get_estimated_remaining_time() -> float:
	var total_duration = dungeon_data.get("duration_minutes", 60) * 60.0
	var elapsed = get_elapsed_time(game_time_node)
	return max(0.0, total_duration - elapsed + time_lost_to_wipes)

func _grant_knowledge(amount: float) -> void:
	"""Augmente la familiarité de chaque membre avec ce donjon (0-100)."""
	for member in group_members:
		var k: float = float(member.connaissance_donjons.get(dungeon_id, 0.0))
		member.connaissance_donjons[dungeon_id] = minf(100.0, k + amount)

func _pick_loot_winner(item: Item) -> SimulatedPlayer:
	"""Attribue le loot au membre éligible (upgrade) le moins équipé ; à défaut au plus bas iLvl."""
	if group_members.is_empty():
		return null
	var upgraders: Array = []
	for m in group_members:
		if m.would_be_upgrade(item):
			upgraders.append(m)
	var pool: Array = upgraders if not upgraders.is_empty() else group_members
	var best = pool[0]
	for m in pool:
		if m.get_total_ilvl() < best.get_total_ilvl():
			best = m
	return best
