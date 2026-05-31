extends Node

# Gestionnaire des guildes IA concurrentes
# Orchestre la simulation et la compétition entre guildes

signal ai_guild_created(ai_guild: AIGuild)
signal monthly_simulation_completed(guilds_data: Array)
signal poaching_attempt(target_member, source_guild: AIGuild, success: bool)

var ai_guilds: Array[AIGuild] = []
var simulation_timer: Timer
var daily_check_timer: Timer

# Configuration par phase
const GUILD_COUNT_BY_PHASE = {
	PhaseManager.GamePhase.SERVEUR: 9,    # 9 guildes concurrentes + 1 joueur
	PhaseManager.GamePhase.NATIONAL: 49,  # 49 guildes + 1 joueur pour top 50
	PhaseManager.GamePhase.ESPORT: 99     # 99 guildes + 1 joueur pour top 100
}

# Noms de guildes prédéfinis
const GUILD_NAMES = [
	"Les Vengeurs d'Azeroth", "Légion Noire", "Les Gardiens du Crépuscule",
	"Fraternité du Loup", "Les Chevaliers de l'Aube", "Horde Sauvage",
	"Les Élus de la Lumière", "Compagnie du Dragon", "Les Forgerons de Guerre",
	"Ordre du Phénix", "Clan des Ombres", "Les Maîtres du Temps",
	"Garde Impériale", "Les Chasseurs d'Elite", "Confrérie du Fer",
	"Les Sentinelles", "Bataillon d'Acier", "Les Conquérants",
	"Escouade Fantôme", "Les Prédateurs", "Alliance des Braves",
	"Les Immortels", "Régiment Noir", "Compagnie d'Elite",
	"Les Dominateurs", "Cercle des Sages", "Les Invaincus",
	"Garde Sacrée", "Les Libérateurs", "Division Alpha",
	"Les Stratèges", "Corps d'Elite", "Les Perfectionnistes",
	"Unité Spéciale", "Les Champions", "Escadron d'Or",
	"Les Légendaires", "Force Suprême", "Les Virtuoses",
	"Élite Mondiale", "Les Maîtres", "Conseil des Experts",
	"Les Phénomènes", "Avant-Garde", "Les Souverains",
	"Empire Global", "Les Titans", "Suprématie Internationale",
	"Les Conquérants Mondiaux", "Hégémonie Esport"
]

# Stratégies prédéfinies avec distribution réaliste
const STRATEGY_DISTRIBUTION = [
	AIGuild.Strategy.AGGRESSIVE,   # 20%
	AIGuild.Strategy.AGGRESSIVE,
	AIGuild.Strategy.BALANCED,     # 40%
	AIGuild.Strategy.BALANCED,
	AIGuild.Strategy.BALANCED,
	AIGuild.Strategy.BALANCED,
	AIGuild.Strategy.DEFENSIVE,    # 20%
	AIGuild.Strategy.DEFENSIVE,
	AIGuild.Strategy.HARDCORE,     # 10%
	AIGuild.Strategy.CASUAL        # 10%
]

func _ready():
	# Se connecter aux signaux nécessaires
	if PhaseManager:
		PhaseManager.connect("phase_changed", _on_phase_changed)
	
	if GameTime:
		GameTime.connect("day_changed", _on_day_changed)
		GameTime.connect("week_changed", _on_week_changed)
	
	# Créer les timers de simulation
	_setup_simulation_timers()
	
	# Initialiser les guildes pour la phase actuelle
	_initialize_guilds_for_current_phase()
	
	print("AIGuildManager initialisé avec %d guildes" % ai_guilds.size())

func _setup_simulation_timers():
	"""Configure les timers de simulation"""
	# Timer pour simulation mensuelle
	simulation_timer = Timer.new()
	simulation_timer.wait_time = 300.0  # 5 minutes = 1 mois de jeu
	simulation_timer.timeout.connect(_run_monthly_simulation)
	simulation_timer.autostart = true
	add_child(simulation_timer)
	
	# Timer pour vérifications quotidiennes
	daily_check_timer = Timer.new()
	daily_check_timer.wait_time = 10.0  # 10 secondes = 1 jour de jeu
	daily_check_timer.timeout.connect(_run_daily_checks)
	daily_check_timer.autostart = true
	add_child(daily_check_timer)

func _initialize_guilds_for_current_phase():
	"""Initialise les guildes pour la phase actuelle"""
	var current_phase = PhaseManager.get_current_phase() if PhaseManager else PhaseManager.GamePhase.SERVEUR
	var guild_count = GUILD_COUNT_BY_PHASE.get(current_phase, 9)
	
	# Nettoyer les guildes existantes
	ai_guilds.clear()
	
	# Créer les nouvelles guildes
	for i in range(guild_count):
		var guild_name = GUILD_NAMES[i % GUILD_NAMES.size()]
		var strategy = STRATEGY_DISTRIBUTION[i % STRATEGY_DISTRIBUTION.size()]
		
		var ai_guild = AIGuild.new(guild_name, strategy)
		ai_guilds.append(ai_guild)
		
		ai_guild_created.emit(ai_guild)
	
	print("Créé %d guildes IA pour la phase %s" % [guild_count, PhaseManager.get_phase_name(current_phase) if PhaseManager else "Serveur"])

func get_all_guilds() -> Array[AIGuild]:
	"""Retourne toutes les guildes IA"""
	return ai_guilds

func get_guild_by_name(guild_name: String) -> AIGuild:
	"""Trouve une guilde par son nom"""
	for guild in ai_guilds:
		if guild.name == guild_name:
			return guild
	return null

func get_guilds_by_strategy(strategy: AIGuild.Strategy) -> Array[AIGuild]:
	"""Retourne les guildes d'une stratégie donnée"""
	var filtered: Array[AIGuild] = []
	for guild in ai_guilds:
		if guild.ai_strategy == strategy:
			filtered.append(guild)
	return filtered

func get_top_guilds(count: int = 5) -> Array[AIGuild]:
	"""Retourne les meilleures guildes triées par réputation/succès"""
	var sorted_guilds: Array[AIGuild] = ai_guilds.duplicate()
	sorted_guilds.sort_custom(func(a, b): return a.reputation > b.reputation)
	return sorted_guilds.slice(0, min(count, sorted_guilds.size()))

func _run_monthly_simulation():
	"""Exécute la simulation mensuelle de toutes les guildes"""
	print("🎯 Début de la simulation mensuelle des guildes IA")
	
	var guilds_data = []
	
	# Simuler la progression de chaque guilde
	for guild in ai_guilds:
		guild.simulate_monthly_progress()
		guilds_data.append(guild.get_guild_data_for_ranking())
	
	# Simuler les interactions entre guildes
	_simulate_inter_guild_interactions()
	
	# Mettre à jour le système de classement
	if GuildRanking:
		call_deferred("_update_guild_rankings", guilds_data)
	
	monthly_simulation_completed.emit(guilds_data)
	print("✅ Simulation mensuelle terminée")

func _simulate_inter_guild_interactions():
	"""Simule les interactions entre guildes (débauchage, etc.)"""
	var aggressive_guilds = get_guilds_by_strategy(AIGuild.Strategy.AGGRESSIVE)
	aggressive_guilds.append_array(get_guilds_by_strategy(AIGuild.Strategy.HARDCORE))
	
	# Les guildes agressives tentent de débaucher
	for aggressive_guild in aggressive_guilds:
		if randf() < 0.4:  # 40% de chance par mois
			_attempt_poaching_by_guild(aggressive_guild)

func _attempt_poaching_by_guild(source_guild: AIGuild):
	"""Une guilde tente de débaucher des membres"""
	# Choisir une guilde cible (pas forcément la guilde du joueur)
	var potential_targets = ai_guilds.duplicate()
	potential_targets.erase(source_guild)
	
	# Inclure la guilde du joueur dans les cibles potentielles
	var player_guild_members = []
	if GuildManager and GuildManager.guild_members:
		player_guild_members = GuildManager.guild_members.duplicate()
		# Ne pas inclure le personnage du joueur lui-même
		for member in player_guild_members:
			if member.get_meta("is_player", false):
				player_guild_members.erase(member)
				break
	
	# Tentative de débauchage de la guilde du joueur (plus intéressant)
	if not player_guild_members.is_empty() and randf() < 0.6:
		var result = source_guild.attempt_poaching(player_guild_members)
		if result.success:
			_process_successful_poaching_from_player(result, source_guild)
			return
	
	# Sinon, débaucher entre guildes IA
	if not potential_targets.is_empty():
		var target_guild = potential_targets.pick_random()
		var result = source_guild.attempt_poaching(target_guild.members)
		if result.success:
			_process_successful_poaching_between_ai(result, source_guild, target_guild)

func _process_successful_poaching_from_player(result: Dictionary, source_guild: AIGuild):
	"""Traite un débauchage réussi depuis la guilde du joueur"""
	var target_member = result.target
	var offer = result.offer
	
	# Calculer la probabilité que le membre accepte vraiment de partir
	var leave_probability = _calculate_member_leave_probability(target_member, offer)
	
	if randf() < leave_probability:
		# Le membre part réellement
		if GuildManager:
			GuildManager.remove_member(target_member)
		
		# Ajouter un membre similaire à la guilde IA
		_add_recruited_member_to_ai_guild(source_guild, target_member)
		
		print("🔄 %s a débauché %s de notre guilde !" % [source_guild.name, target_member.nom])
		poaching_attempt.emit(target_member, source_guild, true)
	else:
		print("🛡️ %s a tenté de débaucher %s, mais il a refusé" % [source_guild.name, target_member.nom])
		poaching_attempt.emit(target_member, source_guild, false)
		
		# Le membre gagne en loyauté après avoir refusé
		target_member.integration = min(100.0, target_member.integration + 5.0)

func _calculate_member_leave_probability(member, offer: Dictionary) -> float:
	"""Calcule la probabilité qu'un membre accepte une offre de débauchage"""
	var base_probability = 0.1
	
	# Facteurs de risque
	if member.integration < 30.0:
		base_probability += 0.4
	elif member.integration < 50.0:
		base_probability += 0.2
	
	if member.mood < 40.0:
		base_probability += 0.3
	elif member.mood < 60.0:
		base_probability += 0.1
	
	# Attractivité de l'offre
	if offer.get("equipment_bonus", 0) > 20:
		base_probability += 0.2
	if offer.get("guaranteed_raid_spot", false):
		base_probability += 0.15
	if offer.get("leadership_role", false):
		base_probability += 0.1
	
	return clamp(base_probability, 0.05, 0.8)

func _add_recruited_member_to_ai_guild(guild: AIGuild, recruited_member):
	"""Ajoute un membre recruté à une guilde IA"""
	var new_ai_member = {
		"name": recruited_member.nom,
		"class": recruited_member.personnage_classe,
		"level": recruited_member.personnage_niveau,
		"equipment": recruited_member.get_total_ilvl(),
		"skill": recruited_member.skill,
		"loyalty": 0.9,  # Très loyal initialement après débauchage réussi
		"satisfaction": 0.8,
		"days_in_guild": 0,
		"is_star_player": recruited_member.skill > 80
	}
	
	guild.members.append(new_ai_member)

func _process_successful_poaching_between_ai(result: Dictionary, source_guild: AIGuild, target_guild: AIGuild):
	"""Traite un débauchage réussi entre guildes IA"""
	var target_member = result.target
	
	# Supprimer de la guilde cible
	target_guild.members.erase(target_member)
	
	# Ajouter à la guilde source avec satisfaction élevée
	target_member.satisfaction = 0.8
	target_member.loyalty = 0.9
	target_member.days_in_guild = 0
	source_guild.members.append(target_member)
	
	print("🔄 %s a débauché %s de %s" % [source_guild.name, target_member.name, target_guild.name])

func _run_daily_checks():
	"""Exécute des vérifications quotidiennes plus légères"""
	# Vérifier les débauchages spontanés occasionnels
	if randf() < 0.05:  # 5% par jour
		var aggressive_guilds = get_guilds_by_strategy(AIGuild.Strategy.AGGRESSIVE)
		if not aggressive_guilds.is_empty():
			_attempt_poaching_by_guild(aggressive_guilds.pick_random())

func _update_guild_rankings(_guilds_data: Array):
	"""Met à jour le système de classement avec les données des guildes IA"""
	if not GuildRanking:
		return
	
	# Forcer une mise à jour du classement
	GuildRanking.update_rankings()

# Callbacks des signaux

func _on_phase_changed(new_phase, old_phase):
	"""Réagit aux changements de phase"""
	print("Changement de phase détecté: adaptation des guildes IA")
	
	# Réinitialiser les guildes pour la nouvelle phase
	call_deferred("_initialize_guilds_for_current_phase")

func _on_day_changed(day: int, week: int, year: int):
	"""Réagit aux changements de jour"""
	# Les vérifications quotidiennes sont gérées par le timer
	pass

func _on_week_changed(week: int, year: int):
	"""Réagit aux changements de semaine"""
	# Simulation plus légère chaque semaine
	if week % 4 == 0:  # Tous les mois
		# Le timer mensuel s'en charge déjà
		pass

# API publique pour interactions

func get_guild_attempting_poaching(member) -> AIGuild:
	"""Retourne la guilde qui tente de débaucher un membre (si applicable)"""
	# Cette fonction sera utilisée par l'UI pour afficher les tentatives
	var aggressive_guilds = get_guilds_by_strategy(AIGuild.Strategy.AGGRESSIVE)
	aggressive_guilds.append_array(get_guilds_by_strategy(AIGuild.Strategy.HARDCORE))
	
	if not aggressive_guilds.is_empty():
		return aggressive_guilds.pick_random()
	
	return null

func simulate_counter_offer_response(source_guild: AIGuild, member, counter_offer: Dictionary) -> bool:
	"""Simule la réponse d'une guilde IA à une contre-offre"""
	var guild_persistence = 0.5
	
	match source_guild.ai_strategy:
		AIGuild.Strategy.AGGRESSIVE:
			guild_persistence = 0.8
		AIGuild.Strategy.HARDCORE:
			guild_persistence = 0.9
		AIGuild.Strategy.BALANCED:
			guild_persistence = 0.4
		AIGuild.Strategy.DEFENSIVE:
			guild_persistence = 0.2
		AIGuild.Strategy.CASUAL:
			guild_persistence = 0.1
	
	# La guilde IA abandon​ne si notre contre-offre est suffisamment attractive
	var counter_offer_strength = 0.0
	if counter_offer.get("equipment_bonus", 0) > 0:
		counter_offer_strength += 0.3
	if counter_offer.get("salary_increase", 0) > 0:
		counter_offer_strength += 0.3
	if counter_offer.get("promotion", false):
		counter_offer_strength += 0.4
	
	return randf() > (guild_persistence - counter_offer_strength)

# Méthodes utilitaires et debug

func get_simulation_stats() -> Dictionary:
	"""Retourne les statistiques de simulation"""
	var total_members = 0
	var avg_reputation = 0.0
	var strategy_counts = {}
	
	for guild in ai_guilds:
		total_members += guild.members.size()
		avg_reputation += guild.reputation
		
		var strategy_name = guild.get_strategy_name()
		strategy_counts[strategy_name] = strategy_counts.get(strategy_name, 0) + 1
	
	if ai_guilds.size() > 0:
		avg_reputation /= ai_guilds.size()
	
	return {
		"guild_count": ai_guilds.size(),
		"total_members": total_members,
		"avg_members_per_guild": float(total_members) / max(1, ai_guilds.size()),
		"avg_reputation": avg_reputation,
		"strategy_distribution": strategy_counts
	}

func get_debug_info() -> Dictionary:
	"""Retourne des informations de debug"""
	var top_guilds = get_top_guilds(3)
	var top_guilds_info = []
	
	for guild in top_guilds:
		top_guilds_info.append({
			"name": guild.name,
			"reputation": guild.reputation,
			"members": guild.members.size(),
			"strategy": guild.get_strategy_name()
		})
	
	return {
		"simulation_stats": get_simulation_stats(),
		"top_guilds": top_guilds_info,
		"timers_active": simulation_timer.is_stopped() == false
	}

# Méthodes de sauvegarde/chargement

func save_ai_guilds_data() -> Dictionary:
	"""Sauvegarde les données des guildes IA"""
	var guilds_data = []
	
	for guild in ai_guilds:
		var guild_data = {
			"name": guild.name,
			"ai_strategy": guild.ai_strategy,
			"reputation": guild.reputation,
			"success_rate": guild.success_rate,
			"aggressiveness": guild.aggressiveness,
			"stability": guild.stability,
			"xp": guild.xp,
			"gold": guild.gold,
			"members": guild.members.duplicate(),
			"monthly_turnover": guild.monthly_turnover,
			"recent_achievements": guild.recent_achievements.duplicate(),
			"current_focus": guild.current_focus,
			"last_major_success_days": guild.last_major_success_days
		}
		guilds_data.append(guild_data)
	
	return {
		"ai_guilds": guilds_data,
		"simulation_timer_time_left": simulation_timer.time_left if simulation_timer else 0.0
	}

func load_ai_guilds_data(data: Dictionary):
	"""Charge les données des guildes IA"""
	ai_guilds.clear()
	
	var guilds_data = data.get("ai_guilds", [])
	
	for guild_data in guilds_data:
		var guild_name: String = guild_data.get("name", "Guilde IA")
		var strategy: AIGuild.Strategy = guild_data.get("ai_strategy", AIGuild.Strategy.BALANCED)
		var ai_guild: AIGuild = AIGuild.new(guild_name, strategy, false)
		ai_guild.reputation = guild_data.get("reputation", 50.0)
		ai_guild.success_rate = guild_data.get("success_rate", 0.6)
		ai_guild.aggressiveness = guild_data.get("aggressiveness", 0.5)
		ai_guild.stability = guild_data.get("stability", 0.7)
		ai_guild.xp = guild_data.get("xp", 0)
		ai_guild.gold = guild_data.get("gold", 0)
		ai_guild.members = guild_data.get("members", [])
		ai_guild.monthly_turnover = guild_data.get("monthly_turnover", 0.0)
		ai_guild.recent_achievements = guild_data.get("recent_achievements", [])
		ai_guild.current_focus = guild_data.get("current_focus", "leveling")
		ai_guild.last_major_success_days = guild_data.get("last_major_success_days", -1)
		
		ai_guilds.append(ai_guild)
		
		# Réenregistrer dans le système de classement
		if GuildRanking:
			GuildRanking.register_guild(ai_guild.name, false)
	
	
	print("Données des guildes IA chargées: %d guildes" % ai_guilds.size())
