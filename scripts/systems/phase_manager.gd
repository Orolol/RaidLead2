extends Node

# Système de gestion des phases de progression du jeu
# Phase 1: Serveur -> Phase 2: National -> Phase 3: Esport

signal phase_changed(new_phase: GamePhase, old_phase: GamePhase)
signal phase_requirements_met(phase: GamePhase)
signal phase_unlocked(phase: GamePhase)
signal progression_updated(phase: GamePhase, progress: Dictionary)

enum GamePhase {
	LEVELING = 0,
	SERVEUR = 1,
	NATIONAL = 2,
	ESPORT = 3
}

# État actuel
var current_phase: GamePhase = GamePhase.LEVELING
var phase_progress: Dictionary = {}
var phase_unlock_date: Dictionary = {}

# Tracking spécifique des accomplissements
var heroic_dungeons_completed: int = 0
var server_days_at_rank_1: int = 0  # jours consécutifs au rang 1 du classement serveur (phase SERVEUR)
var national_days_at_rank_1: int = 0  # jours consécutifs au rang 1 du classement national (phase NATIONAL)

# Configuration des phases et leurs requirements
const PHASE_CONFIG = {
	GamePhase.LEVELING: {
		"name": "Phase de Leveling",
		"description": "Finir un premier donjon héroïque pour débloquer le vrai jeu",
		"max_duration_days": 30,
		"requirements": {
			"heroic_dungeons_completed": 1  # Au moins un donjon héroïque
		},
		"unlocks": ["server_competition", "basic_guild_features"],
		"next_phase": GamePhase.SERVEUR,
		"connection_bonus": 0.2,  # +20% aux horaires de connexion
		"skill_malus": 0.2,       # -20% au skill des joueurs
		"tag_reveal_rate": 0.2    # Seulement 20% des traits révélés
	},
	
	GamePhase.SERVEUR: {
		"name": "Niveau Serveur",
		"description": "Établir une guilde compétitive sur le serveur local",
		"max_duration_days": 60, # Durée maximale suggérée
		"requirements": {
			"server_rank_position": 1, # TOP 1 serveur
			"server_rank_duration": 14, # pendant 2 semaines
			"active_members_min": 15, # minimum 15 membres actifs
			"integration_threshold": 70.0, # intégration moyenne > 70%
			"content_cleared_percent": 80.0 # 80% du contenu cleared
		},
		"unlocks": ["national_recruitment", "media_attention", "sponsorship_opportunities"],
		"next_phase": GamePhase.NATIONAL
	},
	
	GamePhase.NATIONAL: {
		"name": "Niveau National", 
		"description": "Compétition nationale avec mécaniques de célébrité",
		"max_duration_days": 120,
		"requirements": {
			"national_rank_position": 1, # TOP 1 national
			"national_rank_duration": 30, # pendant 1 mois
			"max_dramas_per_year": 2, # pas plus de 2 dramas majeurs/an
			"active_sponsors": 1, # au moins 1 sponsor actif
			"world_first_count": 3, # au moins 3 world first
			"media_reputation": 75.0 # réputation médiatique > 75%
		},
		"unlocks": ["international_tournaments", "professional_staff", "celebrity_management"],
		"next_phase": GamePhase.ESPORT
	},
	
	GamePhase.ESPORT: {
		"name": "Niveau Esport",
		"description": "Compétition mondiale et professionnalisation complète",
		"max_duration_days": -1, # Pas de limite
		"requirements": {
			# Phase finale - requirements pour maintenir le niveau
			"world_championship_wins": 1,
			"professional_staff_count": 3,
			"international_reputation": 90.0,
			"team_stability": 80.0 # Faible turnover
		},
		"unlocks": ["hall_of_fame", "legacy_building", "mentor_program"],
		"next_phase": null # Phase finale
	}
}

func _ready() -> void:
	# Se connecter aux signaux nécessaires
	if GuildManager:
		GuildManager.connect("guild_level_changed", _on_guild_level_changed)
		GuildManager.connect("member_recruited", _on_member_recruited)
		GuildManager.connect("member_disconnected", _on_member_disconnected)
	
	if GameTime:
		GameTime.connect("day_changed", _on_day_changed)
		GameTime.connect("week_changed", _on_week_changed)
		
	# Initialiser le tracking de progression
	_initialize_phase_progress()
	
	GameLog.d("PhaseManager initialisé - Phase actuelle: %s" % get_phase_name(current_phase))

func _initialize_phase_progress() -> void:
	"""Initialise le tracking de progression pour chaque phase"""
	for phase in GamePhase.values():
		phase_progress[phase] = {
			"started_date": null,
			"requirements_progress": {},
			"achievements": [],
			"milestones_reached": [],
			"days_in_phase": 0
		}
	
	# Marquer la phase leveling comme commencée
	phase_progress[GamePhase.LEVELING]["started_date"] = _get_current_date()

func get_current_phase() -> GamePhase:
	"""Retourne la phase actuelle"""
	return current_phase

func get_phase_name(phase: GamePhase) -> String:
	"""Retourne le nom de la phase"""
	return PHASE_CONFIG[phase]["name"]

func get_phase_description(phase: GamePhase) -> String:
	"""Retourne la description de la phase"""
	return PHASE_CONFIG[phase]["description"]

func get_phase_config(phase: GamePhase) -> Dictionary:
	"""Retourne la configuration complète d'une phase"""
	return PHASE_CONFIG.get(phase, {})

func get_current_phase_config() -> Dictionary:
	"""Retourne la configuration de la phase actuelle"""
	return get_phase_config(current_phase)

func get_phase_requirements(phase: GamePhase) -> Dictionary:
	"""Retourne les requirements d'une phase"""
	var config = get_phase_config(phase)
	return config.get("requirements", {})

func get_current_requirements() -> Dictionary:
	"""Retourne les requirements de la phase actuelle"""
	return get_phase_requirements(current_phase)

func get_phase_progress_info(phase: GamePhase) -> Dictionary:
	"""Retourne les informations de progression d'une phase"""
	return phase_progress.get(phase, {})

func get_current_progress_info() -> Dictionary:
	"""Retourne les informations de progression de la phase actuelle"""
	return get_phase_progress_info(current_phase)

func check_phase_progression() -> bool:
	"""Vérifie si les conditions sont remplies pour passer à la phase suivante"""
	var config = get_current_phase_config()
	var next_phase = config.get("next_phase")
	
	if next_phase == null:
		return false # Phase finale
	
	var requirements = get_current_requirements()
	var all_met = true
	var progress = {}
	
	# Vérifier chaque requirement
	for req_name in requirements:
		var required_value = requirements[req_name]
		var current_value = _get_requirement_current_value(req_name)
		var is_met = _check_requirement_met(req_name, current_value, required_value)
		
		progress[req_name] = {
			"required": required_value,
			"current": current_value,
			"met": is_met,
			"progress_percent": _calculate_requirement_progress(req_name, current_value, required_value)
		}
		
		if not is_met:
			all_met = false
	
	# Mettre à jour le tracking de progression
	phase_progress[current_phase]["requirements_progress"] = progress
	progression_updated.emit(current_phase, progress)
	
	# Si toutes les conditions sont remplies
	if all_met:
		phase_requirements_met.emit(current_phase)
		return true
	
	return false

func can_advance_phase() -> bool:
	"""Indique si la phase courante peut avancer (méthode PURE, sans effet de bord).

	Retourne true si la phase courante possède une next_phase ET que tous ses
	requirements sont remplis. Contrairement à check_phase_progression(), cette
	méthode n'émet aucun signal et n'écrit pas dans phase_progress : elle est sûre
	à appeler depuis l'UI (ex. état disabled d'un bouton) sans risque de récursion."""
	var config: Dictionary = get_current_phase_config()
	var next_phase = config.get("next_phase")
	if next_phase == null:
		return false  # Phase finale

	var requirements: Dictionary = get_current_requirements()
	for req_name in requirements:
		var required_value = requirements[req_name]
		var current_value = _get_requirement_current_value(req_name)
		if not _check_requirement_met(req_name, current_value, required_value):
			return false
	return true

func unlock_next_phase() -> bool:
	"""Débloque la phase suivante si les conditions sont remplies.

	Garde via can_advance_phase() (PURE) et non check_phase_progression() : cette
	dernière ré-émet phase_requirements_met(phase_courante) de façon synchrone, ce qui
	rouvrirait un dialog de confirmation « Voulez-vous passer à la phase suivante ? »
	pour la phase qu'on est précisément en train de quitter (dialog fantôme à chaque clic
	sur le bouton d'avance)."""
	if not can_advance_phase():
		return false

	var config = get_current_phase_config()
	var next_phase = config.get("next_phase")
	
	if next_phase == null:
		return false # Phase finale
	
	var old_phase = current_phase
	current_phase = next_phase
	
	# Marquer la nouvelle phase comme commencée
	phase_progress[current_phase]["started_date"] = _get_current_date()
	phase_progress[current_phase]["days_in_phase"] = 0
	phase_unlock_date[current_phase] = _get_current_date()

	# Réinitialiser les compteurs de durée au rang 1 (le suivi recommence par phase)
	server_days_at_rank_1 = 0
	national_days_at_rank_1 = 0

	# Émettre les signaux
	phase_unlocked.emit(current_phase)
	phase_changed.emit(current_phase, old_phase)
	
	# Notification via NotificationManager
	if NotificationManager != null:
		var notification_manager = NotificationManager
		var message = "Passage de %s à %s !" % [get_phase_name(old_phase), get_phase_name(current_phase)]
		notification_manager.show_achievement(message, "Nouvelle Phase")
	
	GameLog.d("Phase débloquée ! Passage de %s à %s" % [get_phase_name(old_phase), get_phase_name(current_phase)])
	
	return true

func is_phase_unlocked(phase: GamePhase) -> bool:
	"""Vérifie si une phase a été débloquée"""
	return phase <= current_phase

func get_unlocked_features() -> Array:
	"""Retourne les fonctionnalités débloquées pour la phase actuelle"""
	var config = get_current_phase_config()
	return config.get("unlocks", [])

func is_feature_unlocked(feature_name: String) -> bool:
	"""Vérifie si une fonctionnalité est débloquée"""
	return feature_name in get_unlocked_features()

func try_advance_phase() -> bool:
	"""Tente de faire progresser vers la phase suivante"""
	return unlock_next_phase()

func complete_heroic_dungeon(dungeon_name: String = "") -> void:
	"""Marque un donjon héroïque comme complété"""
	heroic_dungeons_completed += 1
	
	var achievement_name = "Premier donjon héroïque" if heroic_dungeons_completed == 1 else "Donjon héroïque #%d" % heroic_dungeons_completed
	var description = "Donjon héroïque complété: %s" % dungeon_name if dungeon_name != "" else "Donjon héroïque complété"
	add_achievement(achievement_name, description)
	
	# Notification via NotificationManager
	if NotificationManager != null:
		var notification_manager = NotificationManager
		if heroic_dungeons_completed == 1:
			notification_manager.show_success("Premier donjon héroïque terminé !", "Achievement")
		else:
			notification_manager.show_success("Donjon héroïque #%d complété" % heroic_dungeons_completed, "Victoire")
	
	GameLog.d("Donjon héroïque complété ! Total: %d" % heroic_dungeons_completed)
	
	# Vérifier automatiquement si on peut passer à la phase suivante
	if current_phase == GamePhase.LEVELING:
		try_advance_phase()

func add_achievement(achievement_name: String, description: String = "") -> void:
	"""Ajoute un achievement à la phase actuelle"""
	var achievement = {
		"name": achievement_name,
		"description": description,
		"date": _get_current_date(),
		"phase": current_phase
	}
	
	phase_progress[current_phase]["achievements"].append(achievement)
	GameLog.d("Achievement débloqué: %s" % achievement_name)

func get_achievements_for_phase(phase: GamePhase) -> Array:
	"""Retourne les achievements d'une phase"""
	var progress = get_phase_progress_info(phase)
	return progress.get("achievements", [])

func get_all_achievements() -> Array:
	"""Retourne tous les achievements obtenus"""
	var all_achievements = []
	for phase in GamePhase.values():
		all_achievements.append_array(get_achievements_for_phase(phase))
	return all_achievements

# Méthodes internes pour calculer les requirements

func _get_requirement_current_value(req_name: String) -> Variant:
	"""Retourne la valeur actuelle d'un requirement"""
	match req_name:
		"heroic_dungeons_completed":
			return heroic_dungeons_completed
		
		"server_rank_position":
			if GuildRanking:
				return GuildRanking.get_player_guild_position()
			return 0

		"server_rank_duration":
			return server_days_at_rank_1

		"active_members_min":
			if GuildManager:
				return GuildManager.get_online_members().size()
			return 0
			
		"integration_threshold":
			if GuildManager:
				var members = GuildManager.guild_members
				if members.size() == 0:
					return 0.0
				var total_integration = 0.0
				for member in members:
					total_integration += member.integration
				return total_integration / members.size()
			return 0.0
			
		"content_cleared_percent":
			if GuildRanking and GuildRanking.has_method("get_player_content_cleared_percent"):
				return GuildRanking.get_player_content_cleared_percent()
			return 0.0
			
		"national_rank_position":
			if GuildRanking:
				return GuildRanking.get_player_guild_position()
			return 0

		"national_rank_duration":
			return national_days_at_rank_1

		"max_dramas_per_year":
			if DramaManager and DramaManager.has_method("get_dramas_this_year"):
				return DramaManager.get_dramas_this_year()
			return 0
			
		"active_sponsors":
			if SponsorshipManager:
				return SponsorshipManager.active_sponsors.size()
			return 0
			
		"world_first_count":
			return _count_player_world_firsts()
			
		"media_reputation":
			if MediaManager and MediaManager.has_method("get_media_reputation"):
				return MediaManager.get_media_reputation()
			return 50.0

		"world_championship_wins":
			if TournamentManager and TournamentManager.has_method("get_world_championship_wins"):
				return TournamentManager.get_world_championship_wins()
			return 0

		"professional_staff_count":
			if StaffManager and StaffManager.has_method("get_staff_count"):
				return StaffManager.get_staff_count()
			return 0

		"international_reputation":
			if TournamentManager and TournamentManager.has_method("get_international_reputation"):
				return TournamentManager.get_international_reputation()
			return 0.0

		"team_stability":
			return _compute_team_stability()
			
		_:
			return 0

func _check_requirement_met(req_name: String, current_value, required_value) -> bool:
	"""Vérifie si un requirement est satisfait"""
	match req_name:
		"max_dramas_per_year":
			return current_value <= required_value
		"server_rank_position", "national_rank_position":
			# Rang : plus petit = meilleur. Être classé <= au rang requis (et classé).
			return current_value > 0 and current_value <= required_value
		_:
			return current_value >= required_value

func _calculate_requirement_progress(req_name: String, current_value, required_value) -> float:
	"""Calcule le pourcentage de progression d'un requirement"""
	if required_value == 0:
		return 100.0 if current_value == 0 else 0.0
	
	match req_name:
		"max_dramas_per_year":
			if current_value <= required_value:
				return 100.0
			else:
				return max(0.0, 100.0 - (current_value - required_value) * 25.0)
		"server_rank_position", "national_rank_position":
			return 100.0 if (current_value > 0 and current_value <= required_value) else 0.0
		_:
			return min(100.0, (float(current_value) / float(required_value)) * 100.0)

func _get_current_date() -> Dictionary:
	"""Retourne la date actuelle du jeu"""
	if GameTime:
		return {
			"day": GameTime.current_day,
			"week": GameTime.current_week,
			"year": GameTime.current_year
		}
	return {"day": 1, "week": 1, "year": 1}

# Callbacks des signaux

func _on_day_changed(day: int, _week: int, _year: int) -> void:
	"""Appelé chaque jour pour mettre à jour la progression"""
	# Incrémenter les jours dans la phase actuelle
	phase_progress[current_phase]["days_in_phase"] += 1

	# Suivi de la durée passée au rang 1 (pour server_rank_duration / national_rank_duration)
	_update_rank_duration()

	# Vérifier périodiquement la progression (tous les 7 jours)
	if day % 7 == 0:
		check_phase_progression()

func _update_rank_duration() -> void:
	"""Compte les jours consécutifs au rang 1, séparément pour le serveur et le national.

	Le comptage est gardé par la phase courante : on n'incrémente que le compteur
	pertinent (serveur en phase SERVEUR, national en phase NATIONAL). Aucun comptage
	en LEVELING ou ESPORT. Le compteur est remis à zéro si le rang n'est pas 1.
	"""
	if not GuildRanking:
		return
	var at_rank_1: bool = GuildRanking.get_player_guild_position() == 1
	match current_phase:
		GamePhase.SERVEUR:
			server_days_at_rank_1 = server_days_at_rank_1 + 1 if at_rank_1 else 0
		GamePhase.NATIONAL:
			national_days_at_rank_1 = national_days_at_rank_1 + 1 if at_rank_1 else 0
		_:
			pass

func _count_player_world_firsts() -> int:
	"""Nombre de premiers clears réalisés par la guilde du joueur (= world firsts ici)."""
	if not GuildRanking or not GuildManager or not GuildManager.guild:
		return 0
	var count: int = 0
	var firsts: Dictionary = GuildRanking.get_server_firsts()
	for content_id in firsts:
		if firsts[content_id] == GuildManager.guild.name:
			count += 1
	return count

func get_requirements_progress(phase: GamePhase) -> Dictionary:
	"""Progression des requirements d'une phase. Utilisable pour la phase finale Esport,
	dont check_phase_progression() sort tot faute de phase suivante."""
	var requirements: Dictionary = get_phase_requirements(phase)
	var progress: Dictionary = {}
	for req_name in requirements:
		var required_value = requirements[req_name]
		var current_value = _get_requirement_current_value(req_name)
		progress[req_name] = {
			"required": required_value,
			"current": current_value,
			"met": _check_requirement_met(req_name, current_value, required_value),
			"progress_percent": _calculate_requirement_progress(req_name, current_value, required_value),
		}
	return progress

func _compute_team_stability() -> float:
	"""Stabilité d'équipe (0-100) : bien-être moyen (moral + intégration) pénalisé par le
	stress et le burnout, augmenté du bonus de stabilité du staff (manager)."""
	if not GuildManager or GuildManager.guild_members.is_empty():
		return 0.0
	var members: Array = GuildManager.guild_members
	var total: float = 0.0
	for m in members:
		var wellbeing: float = (m.mood + m.integration) / 2.0
		var stress_pen: float = m.stress_level * 0.3
		var burnout_pen: float = float(m.burnout_level) * 8.0
		total += clampf(wellbeing - stress_pen - burnout_pen, 0.0, 100.0)
	var staff_bonus: float = StaffManager.get_total_stability_bonus() if StaffManager else 0.0
	return clampf(total / float(members.size()) + staff_bonus, 0.0, 100.0)

func _on_week_changed(_week: int, _year: int) -> void:
	"""Appelé chaque semaine"""
	# Check automatique de progression chaque semaine
	check_phase_progression()

func _on_guild_level_changed(new_level: int) -> void:
	"""Réagit aux changements de niveau de guilde"""
	add_achievement("Niveau de guilde %d" % new_level, "La guilde a atteint le niveau %d" % new_level)

func _on_member_recruited(_player) -> void:
	"""Réagit au recrutement de nouveaux membres"""
	if GuildManager.guild_members.size() >= 15:
		add_achievement("Guilde établie", "La guilde compte maintenant 15 membres actifs")

func _on_member_disconnected(_player) -> void:
	"""Réagit à la déconnexion de membres"""
	# Vérifier si on maintient le minimum requis
	pass

# Méthodes utilitaires pour le debug et les tests

func force_phase_change(target_phase: GamePhase) -> bool:
	"""Force le changement vers une phase spécifique (debug uniquement)"""
	if target_phase == current_phase:
		return false
		
	var old_phase = current_phase
	current_phase = target_phase
	
	# Marquer la nouvelle phase comme commencée
	phase_progress[current_phase]["started_date"] = _get_current_date()
	phase_progress[current_phase]["days_in_phase"] = 0
	phase_unlock_date[current_phase] = _get_current_date()

	# Réinitialiser les compteurs de durée au rang 1 (le suivi recommence par phase)
	server_days_at_rank_1 = 0
	national_days_at_rank_1 = 0

	# Émettre les signaux
	phase_changed.emit(current_phase, old_phase)

	GameLog.d("Phase forcée vers: %s" % get_phase_name(current_phase))
	return true

func get_debug_info() -> Dictionary:
	"""Retourne des informations de debug sur l'état actuel"""
	return {
		"current_phase": get_phase_name(current_phase),
		"days_in_current_phase": phase_progress[current_phase]["days_in_phase"],
		"requirements_progress": phase_progress[current_phase]["requirements_progress"],
		"unlocked_features": get_unlocked_features(),
		"total_achievements": get_all_achievements().size()
	}

# Méthodes de sauvegarde/chargement

func save_phase_data() -> Dictionary:
	"""Sauvegarde les données de progression des phases"""
	return {
		"current_phase": current_phase,
		"phase_progress": phase_progress,
		"phase_unlock_date": phase_unlock_date,
		"heroic_dungeons_completed": heroic_dungeons_completed,
		"server_days_at_rank_1": server_days_at_rank_1,
		"national_days_at_rank_1": national_days_at_rank_1
	}

func load_phase_data(data: Dictionary) -> void:
	"""Charge les données de progression des phases (MERGE NON DESTRUCTIF).

	Le JSON convertit les clés de dictionnaire (les valeurs de l'enum GamePhase) en
	String et les nombres en float. On normalise donc les clés en int et on FUSIONNE
	la progression chargée avec les défauts, sans jamais écraser les achievements,
	milestones, requirements_progress ni days_in_phase déjà sauvegardés."""
	# current_phase peut arriver en float depuis le JSON : on le ramène à un int d'enum.
	current_phase = int(data.get("current_phase", GamePhase.LEVELING)) as GamePhase
	heroic_dungeons_completed = int(data.get("heroic_dungeons_completed", 0))
	# Compat best-effort : les anciennes saves n'avaient qu'un compteur unique
	# "days_at_rank_1" partagé. On l'utilise comme valeur de repli pour amorcer
	# les nouveaux compteurs séparés sans planter.
	var legacy_days_at_rank_1: int = int(data.get("days_at_rank_1", 0))
	server_days_at_rank_1 = int(data.get("server_days_at_rank_1", legacy_days_at_rank_1))
	national_days_at_rank_1 = int(data.get("national_days_at_rank_1", legacy_days_at_rank_1))

	# phase_unlock_date : clés normalisées en int (GamePhase) après le JSON.
	phase_unlock_date = _normalize_phase_keys(data.get("phase_unlock_date", {}))

	# Fusion non destructive de la progression chargée par-dessus les défauts.
	_merge_phase_progress(data.get("phase_progress", {}))

	GameLog.d("Données de phases chargées - Phase actuelle: %s" % get_phase_name(current_phase))

func _normalize_phase_keys(raw: Dictionary) -> Dictionary:
	"""Reconvertit les clés de phase (String issues du JSON) en int d'enum GamePhase.
	Les clés non numériques sont conservées telles quelles (robustesse)."""
	var out: Dictionary = {}
	for key in raw.keys():
		var normalized_key = key
		if key is float:
			normalized_key = int(key)
		elif key is String and key.is_valid_int():
			normalized_key = key.to_int()
		out[normalized_key] = raw[key]
	return out

func _default_phase_entry() -> Dictionary:
	"""Structure par défaut d'une entrée de progression de phase."""
	return {
		"started_date": null,
		"requirements_progress": {},
		"achievements": [],
		"milestones_reached": [],
		"days_in_phase": 0,
	}

func _merge_phase_progress(loaded_raw: Dictionary) -> void:
	"""Fusionne la progression chargée par-dessus les défauts SANS rien écraser.

	- Garantit que chaque phase de l'enum possède une entrée complète.
	- Pour les entrées chargées, on conserve toutes les valeurs sauvegardées
	  (achievements, milestones_reached, requirements_progress, days_in_phase,
	  started_date) ; on n'ajoute QUE les sous-clés manquantes avec leur défaut."""
	var loaded: Dictionary = _normalize_phase_keys(loaded_raw)
	phase_progress = {}
	for phase in GamePhase.values():
		var entry: Dictionary = _default_phase_entry()
		if loaded.has(phase) and loaded[phase] is Dictionary:
			var saved: Dictionary = loaded[phase]
			# Conserver toutes les sous-clés sauvegardées (non destructif).
			for sub_key in saved.keys():
				entry[sub_key] = saved[sub_key]
			# Normaliser days_in_phase en int (peut arriver en float depuis le JSON).
			if entry.has("days_in_phase"):
				entry["days_in_phase"] = int(entry["days_in_phase"])
		phase_progress[phase] = entry

	# La phase de leveling doit avoir une date de début même pour une save minimale.
	if phase_progress[GamePhase.LEVELING].get("started_date", null) == null:
		phase_progress[GamePhase.LEVELING]["started_date"] = _get_current_date()
