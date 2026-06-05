extends Node

# Gestionnaire des guildes IA concurrentes
# Orchestre la simulation et la compétition entre guildes

signal ai_guild_created(ai_guild: AIGuild)
signal monthly_simulation_completed(guilds_data: Array)
signal poaching_attempt(target_member, source_guild: AIGuild, success: bool)

var ai_guilds: Array[AIGuild] = []

# Configuration par phase
# Échelle volontairement resserrée : un top 10 reste crédible avec ~10-15 concurrents,
# sans le coût/bruit de dizaines de guildes simulées (ex-49/99). On garde les 9 de la
# Phase 0/Serveur et on monte légèrement en National/Esport pour densifier la compétition.
const GUILD_COUNT_BY_PHASE = {
	PhaseManager.GamePhase.SERVEUR: 9,     # 9 guildes concurrentes + 1 joueur
	PhaseManager.GamePhase.NATIONAL: 13,   # 13 guildes + 1 joueur (top 10 disputé)
	PhaseManager.GamePhase.ESPORT: 15      # 15 guildes + 1 joueur (élite resserrée)
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

func _ready() -> void:
	# Se connecter aux signaux nécessaires
	if PhaseManager:
		PhaseManager.connect("phase_changed", _on_phase_changed)
	
	if GameTime:
		GameTime.connect("day_changed", _on_day_changed)
		GameTime.connect("week_changed", _on_week_changed)
	
	# La simulation IA est pilotée par GameTime (_on_day_changed / _on_week_changed),
	# synchronisée avec la vitesse de jeu (plus de timers temps-réel désynchronisés).

	# Initialiser les guildes pour la phase actuelle
	_initialize_guilds_for_current_phase()
	
	GameLog.d("AIGuildManager initialisé avec %d guildes" % ai_guilds.size())

func _setup_simulation_timers() -> void:
	# Obsolète : la simulation IA est désormais pilotée par GameTime
	# (_on_day_changed / _on_week_changed). Conservée vide pour compat d'appel éventuel.
	pass

func _initialize_guilds_for_current_phase() -> void:
	"""Initialise les guildes pour la phase actuelle"""
	var current_phase = PhaseManager.get_current_phase() if PhaseManager else PhaseManager.GamePhase.SERVEUR
	var guild_count = GUILD_COUNT_BY_PHASE.get(current_phase, 9)

	# Nettoyer les guildes existantes
	ai_guilds.clear()

	# Créer les nouvelles guildes
	for i in range(guild_count):
		var guild_name: String = GUILD_NAMES[i % GUILD_NAMES.size()]
		var strategy = STRATEGY_DISTRIBUTION[i % STRATEGY_DISTRIBUTION.size()]

		var ai_guild: AIGuild = AIGuild.new(guild_name, strategy)
		ai_guilds.append(ai_guild)

		ai_guild_created.emit(ai_guild)
	
	GameLog.d("Créé %d guildes IA pour la phase %s" % [guild_count, PhaseManager.get_phase_name(current_phase) if PhaseManager else "Serveur"])

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

func _run_weekly_progression() -> void:
	"""Progression PvE hebdomadaire lissée des guildes IA (cadence découplée du mensuel).

	Fait avancer les IA chaque semaine avec une amplitude réduite (~1/4 de l'ancien
	rythme mensuel), pour un classement fluide plutôt qu'en marches d'escalier."""
	for guild in ai_guilds:
		guild.simulate_weekly_progress()

	# Recalcul différé du classement (consommé une fois par semaine côté GuildRanking).
	if GuildRanking:
		var guilds_data: Array = []
		for guild in ai_guilds:
			guilds_data.append(guild.get_guild_data_for_ranking())
		call_deferred("_update_guild_rankings", guilds_data)

func _run_monthly_simulation() -> void:
	"""Exécute la simulation mensuelle de toutes les guildes (turnover/recrutement/réputation)."""
	GameLog.d("🎯 Début de la simulation mensuelle des guildes IA")

	var guilds_data: Array = []

	# Simuler les aspects réellement mensuels de chaque guilde (recrutement, turnover, etc.)
	for guild in ai_guilds:
		guild.simulate_monthly_progress()
		guilds_data.append(guild.get_guild_data_for_ranking())

	# Simuler les interactions entre guildes
	_simulate_inter_guild_interactions()

	# Mettre à jour le système de classement
	if GuildRanking:
		call_deferred("_update_guild_rankings", guilds_data)

	monthly_simulation_completed.emit(guilds_data)
	GameLog.d("✅ Simulation mensuelle terminée")

func _simulate_inter_guild_interactions() -> void:
	"""Simule les interactions entre guildes (débauchage, etc.)"""
	var aggressive_guilds: Array[AIGuild] = get_guilds_by_strategy(AIGuild.Strategy.AGGRESSIVE)
	aggressive_guilds.append_array(get_guilds_by_strategy(AIGuild.Strategy.HARDCORE))

	# Les guildes agressives tentent de débaucher
	for aggressive_guild in aggressive_guilds:
		if randf() < 0.4:  # 40% de chance par mois
			_attempt_poaching_by_guild(aggressive_guild)

func _attempt_poaching_by_guild(source_guild: AIGuild) -> void:
	"""Une guilde tente de débaucher des membres"""
	# Choisir une guilde cible (pas forcément la guilde du joueur)
	var potential_targets: Array[AIGuild] = ai_guilds.duplicate()
	potential_targets.erase(source_guild)

	# Inclure la guilde du joueur dans les cibles potentielles
	var player_guild_members: Array = []
	if GuildManager and GuildManager.guild_members:
		player_guild_members = GuildManager.guild_members.duplicate()
		# Ne pas inclure le personnage du joueur lui-même
		for member in player_guild_members:
			if member.get_meta("is_player", false):
				player_guild_members.erase(member)
				break

	# Tentative de débauchage de la guilde du joueur (plus intéressant)
	if not player_guild_members.is_empty() and randf() < 0.6:
		var result: Dictionary = source_guild.attempt_poaching(player_guild_members)
		if result.success:
			_process_successful_poaching_from_player(result, source_guild)
			return

	# Sinon, débaucher entre guildes IA
	if not potential_targets.is_empty():
		var target_guild = potential_targets.pick_random()
		var result: Dictionary = source_guild.attempt_poaching(target_guild.members)
		if result.success:
			_process_successful_poaching_between_ai(result, source_guild, target_guild)

func _process_successful_poaching_from_player(result: Dictionary, source_guild: AIGuild) -> void:
	"""Signale une tentative de débauchage visant la guilde du joueur.

	La décision (laisser partir / contre-offre / ignorer) appartient au joueur :
	on émet `poaching_attempt(..., true)` AVANT toute mutation. Le membre reste
	dans la guilde jusqu'à ce que le PoachingHandler/popup résolve le sort réel
	(retrait + ajout IA uniquement si le membre part vraiment). Le calcul final
	de la probabilité de départ se fait donc en aval de la décision joueur."""
	var target_member = result.target

	GameLog.d("⚠️ %s tente de débaucher %s — décision du joueur attendue" % [source_guild.name, target_member.nom])
	# Aucune mutation ici : pas de remove_member, pas d'ajout à la guilde IA.
	poaching_attempt.emit(target_member, source_guild, true)

func finalize_poaching_departure(target_member, source_guild: AIGuild) -> void:
	"""Effectue le départ RÉEL d'un membre débauché (appelé par PoachingHandler).

	N'agit que si le membre est encore dans la guilde du joueur : retrait via
	GuildManager (départ involontaire) puis ajout d'un clone à la guilde IA source.
	Idempotent : un membre déjà parti (fantôme) n'est pas retraité."""
	if target_member == null or source_guild == null:
		return
	if not GuildManager or target_member not in GuildManager.guild_members:
		return

	GuildManager.remove_member(target_member, false)
	_add_recruited_member_to_ai_guild(source_guild, target_member)
	GameLog.d("🔄 %s a débauché %s de notre guilde !" % [source_guild.name, target_member.nom])

func get_member_leave_probability(member, offer: Dictionary) -> float:
	"""Expose le calcul de probabilité de départ côté IA pour la décision différée."""
	return _calculate_member_leave_probability(member, offer)

func _calculate_member_leave_probability(member, offer: Dictionary) -> float:
	"""Calcule la probabilité qu'un membre accepte une offre de débauchage"""
	var base_probability: float = 0.1
	
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

	# La célébrité rend un membre plus convoité : risque de départ accru.
	if target_member_has_celebrity_risk(member):
		base_probability += member.get_celebrity_poaching_risk()

	return clamp(base_probability, 0.05, 0.85)

func target_member_has_celebrity_risk(member) -> bool:
	return member != null and member.has_method("get_celebrity_poaching_risk")

func _add_recruited_member_to_ai_guild(guild: AIGuild, recruited_member) -> void:
	"""Ajoute un membre recruté à une guilde IA"""
	var new_ai_member: Dictionary = {
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

func _process_successful_poaching_between_ai(result: Dictionary, source_guild: AIGuild, target_guild: AIGuild) -> void:
	"""Traite un débauchage réussi entre guildes IA"""
	var target_member = result.target
	
	# Supprimer de la guilde cible
	target_guild.members.erase(target_member)
	
	# Ajouter à la guilde source avec satisfaction élevée
	target_member.satisfaction = 0.8
	target_member.loyalty = 0.9
	target_member.days_in_guild = 0
	source_guild.members.append(target_member)
	
	GameLog.d("🔄 %s a débauché %s de %s" % [source_guild.name, target_member.name, target_guild.name])

func _run_daily_checks() -> void:
	"""Exécute des vérifications quotidiennes plus légères"""
	# Vérifier les débauchages spontanés occasionnels
	if randf() < 0.05:  # 5% par jour
		var aggressive_guilds: Array[AIGuild] = get_guilds_by_strategy(AIGuild.Strategy.AGGRESSIVE)
		if not aggressive_guilds.is_empty():
			_attempt_poaching_by_guild(aggressive_guilds.pick_random())

func _update_guild_rankings(_guilds_data: Array):
	"""Met à jour le système de classement avec les données des guildes IA"""
	if not GuildRanking:
		return
	
	# Forcer une mise à jour du classement
	GuildRanking.update_rankings()

# Callbacks des signaux

func _on_phase_changed(_new_phase, _old_phase) -> void:
	"""Réagit aux changements de phase"""
	GameLog.d("Changement de phase détecté: adaptation des guildes IA")

	# Réinitialiser les guildes pour la nouvelle phase
	call_deferred("_initialize_guilds_for_current_phase")

func _on_day_changed(_day: int, _week: int, _year: int) -> void:
	"""Vérifications quotidiennes (pilotées par GameTime, synchronisées à la vitesse de jeu)."""
	_run_daily_checks()

func _on_week_changed(week: int, _year: int) -> void:
	"""Cadence IA : progression PvE chaque semaine (lissée), logique mensuelle toutes les 4 semaines.

	Découpler les deux évite le classement « en marches d'escalier » à haute vitesse tout en
	gardant le turnover/recrutement/réputation sur un rythme mensuel crédible."""
	_run_weekly_progression()
	if week % 4 == 0:
		_run_monthly_simulation()

# API publique pour interactions

func get_guild_attempting_poaching(_member) -> AIGuild:
	"""Retourne la guilde qui tente de débaucher un membre (si applicable)"""
	# Cette fonction sera utilisée par l'UI pour afficher les tentatives
	var aggressive_guilds = get_guilds_by_strategy(AIGuild.Strategy.AGGRESSIVE)
	aggressive_guilds.append_array(get_guilds_by_strategy(AIGuild.Strategy.HARDCORE))
	
	if not aggressive_guilds.is_empty():
		return aggressive_guilds.pick_random()
	
	return null

func simulate_counter_offer_response(source_guild: AIGuild, _member, counter_offer: Dictionary) -> bool:
	"""Simule la réponse d'une guilde IA à une contre-offre"""
	var guild_persistence: float = 0.5
	
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
	var counter_offer_strength: float = 0.0
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
	var total_members: int = 0
	var avg_reputation: float = 0.0
	var strategy_counts: Dictionary = {}

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
	var top_guilds: Array[AIGuild] = get_top_guilds(3)
	var top_guilds_info: Array = []

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
		"driven_by": "GameTime"
	}

# Méthodes de sauvegarde/chargement

func save_ai_guilds_data() -> Dictionary:
	"""Sauvegarde les données des guildes IA"""
	var guilds_data: Array = []

	for guild in ai_guilds:
		var guild_data: Dictionary = {
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
		"ai_guilds": guilds_data
	}

func load_ai_guilds_data(data: Dictionary) -> void:
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
	
	
	GameLog.d("Données des guildes IA chargées: %d guildes" % ai_guilds.size())
