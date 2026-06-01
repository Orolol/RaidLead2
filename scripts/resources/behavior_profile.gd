extends Resource
class_name BehaviorProfile

# Traits psychologiques de base (0.0 à 1.0)
@export var stress_tolerance: float = 0.5  # Résistance au stress et à la pression
@export var flexibility: float = 0.5  # Adaptabilité aux changements d'horaires
@export var social_needs: float = 0.5  # Besoin d'interactions sociales
@export var achievement_drive: float = 0.5  # Motivation par les accomplissements
@export var routine_preference: float = 0.5  # Préférence pour la routine vs spontanéité
@export var conflict_avoidance: float = 0.5  # Tendance à éviter les conflits

# Type circadien
@export var circadian_type: String = "flexible"  # "morning", "evening", "flexible"

# Seuils personnalisés
@export var burnout_threshold: float = 70.0  # Seuil de fatigue pour burnout
@export var mood_recovery_rate: float = 5.0  # Vitesse de récupération du moral
@export var fatigue_accumulation_rate: float = 1.0  # Vitesse d'accumulation de fatigue

# Préférences temporelles
@export var preferred_session_length: float = 3.0  # Heures de jeu préférées
@export var schedule_variance: Vector2 = Vector2(-0.5, 0.5)  # Variance horaire min/max

# Patterns comportementaux
@export var reaction_patterns: Dictionary = {}  # event_type -> reaction_type
@export var social_preferences: Dictionary = {}  # Préférences de groupes/activités

func _init():
	_randomize_profile()

func serialize() -> Dictionary:
	"""Sérialise les traits du profil (pour que la personnalité survive au reload)."""
	return {
		"stress_tolerance": stress_tolerance,
		"flexibility": flexibility,
		"social_needs": social_needs,
		"achievement_drive": achievement_drive,
		"routine_preference": routine_preference,
		"conflict_avoidance": conflict_avoidance,
		"circadian_type": circadian_type,
		"burnout_threshold": burnout_threshold,
		"mood_recovery_rate": mood_recovery_rate,
		"fatigue_accumulation_rate": fatigue_accumulation_rate,
		"preferred_session_length": preferred_session_length,
	}

func deserialize(data: Dictionary) -> void:
	stress_tolerance = data.get("stress_tolerance", stress_tolerance)
	flexibility = data.get("flexibility", flexibility)
	social_needs = data.get("social_needs", social_needs)
	achievement_drive = data.get("achievement_drive", achievement_drive)
	routine_preference = data.get("routine_preference", routine_preference)
	conflict_avoidance = data.get("conflict_avoidance", conflict_avoidance)
	circadian_type = data.get("circadian_type", circadian_type)
	burnout_threshold = data.get("burnout_threshold", burnout_threshold)
	mood_recovery_rate = data.get("mood_recovery_rate", mood_recovery_rate)
	fatigue_accumulation_rate = data.get("fatigue_accumulation_rate", fatigue_accumulation_rate)
	preferred_session_length = data.get("preferred_session_length", preferred_session_length)

func _randomize_profile():
	"""Génère un profil aléatoire mais cohérent"""
	
	# Générer les traits de base
	stress_tolerance = randf()
	flexibility = randf()
	social_needs = randf()
	achievement_drive = randf()
	routine_preference = randf()
	conflict_avoidance = randf()
	
	# Type circadien avec distribution réaliste
	var circadian_roll = randf()
	if circadian_roll < 0.25:
		circadian_type = "morning"
	elif circadian_roll < 0.5:
		circadian_type = "evening"
	else:
		circadian_type = "flexible"
	
	# Ajuster les seuils selon les traits
	burnout_threshold = 50.0 + (stress_tolerance * 40.0)  # 50-90
	mood_recovery_rate = 3.0 + (flexibility * 4.0)  # 3-7
	fatigue_accumulation_rate = 1.5 - (stress_tolerance * 1.0)  # 0.5-1.5
	
	# Session préférée selon achievement drive
	preferred_session_length = 2.0 + (achievement_drive * 4.0)  # 2-6 heures
	
	# Variance selon flexibilité
	var variance_amount = 0.25 + (flexibility * 0.75)  # 0.25-1.0
	schedule_variance = Vector2(-variance_amount, variance_amount)
	
	# Patterns de réaction cohérents avec la personnalité
	_generate_reaction_patterns()
	_generate_social_preferences()

func _generate_reaction_patterns():
	"""Génère des patterns de réaction cohérents"""
	
	reaction_patterns = {
		"raid_wipe": _get_wipe_reaction(),
		"loot_conflict": _get_loot_reaction(),
		"guild_drama": _get_drama_reaction(),
		"raid_success": _get_success_reaction(),
		"new_member": _get_new_member_reaction()
	}

func _get_wipe_reaction() -> String:
	if stress_tolerance > 0.7 and achievement_drive > 0.6:
		return "motivated"  # Motivé pour réessayer
	elif stress_tolerance < 0.3:
		if conflict_avoidance > 0.6:
			return "quiet_frustrated"  # Frustré mais ne dit rien
		else:
			return "vocal_frustrated"  # Exprime sa frustration
	elif flexibility > 0.7:
		return "analytical"  # Cherche à comprendre et s'adapter
	else:
		return "neutral"  # Réaction neutre

func _get_loot_reaction() -> String:
	if achievement_drive > 0.8 and social_needs < 0.3:
		return "competitive"  # Veut le meilleur loot
	elif social_needs > 0.7 and conflict_avoidance > 0.6:
		return "generous"  # Laisse aux autres
	elif flexibility > 0.6:
		return "pragmatic"  # Décision rationnelle
	else:
		return "neutral"

func _get_drama_reaction() -> String:
	if conflict_avoidance > 0.8:
		return "withdraw"  # Se retire du conflit
	elif social_needs > 0.7 and stress_tolerance > 0.6:
		return "mediate"  # Tente de médiatiser
	elif conflict_avoidance < 0.3:
		return "participate"  # Participe au drama
	else:
		return "observe"  # Observe sans intervenir

func _get_success_reaction() -> String:
	if social_needs > 0.7 and achievement_drive > 0.6:
		return "celebrate_together"  # Célèbre avec l'équipe
	elif achievement_drive > 0.8:
		return "push_for_more"  # Veut enchaîner
	elif routine_preference < 0.3:
		return "try_something_new"  # Propose nouvelle activité
	else:
		return "satisfied"  # Satisfait, normal

func _get_new_member_reaction() -> String:
	if social_needs > 0.8 and conflict_avoidance > 0.5:
		return "welcoming"  # Accueillant
	elif social_needs < 0.3:
		return "indifferent"  # Indifférent
	elif achievement_drive > 0.7 and stress_tolerance > 0.6:
		return "evaluative"  # Évalue les compétences
	else:
		return "neutral"

func _generate_social_preferences():
	"""Génère les préférences sociales"""
	
	social_preferences = {
		"preferred_group_size": _get_preferred_group_size(),
		"leadership_style": _get_leadership_style(),
		"communication_preference": _get_communication_preference(),
		"mentor_potential": social_needs > 0.6 and stress_tolerance > 0.5,
		"clique_tendency": social_needs > 0.5 and routine_preference > 0.6
	}

func _get_preferred_group_size() -> String:
	if social_needs < 0.3:
		return "solo"  # Préfère jouer seul
	elif social_needs > 0.7 and stress_tolerance > 0.6:
		return "large"  # Aime les grands groupes
	elif routine_preference > 0.7:
		return "consistent"  # Même groupe régulier
	else:
		return "small"  # Petits groupes

func _get_leadership_style() -> String:
	if achievement_drive > 0.7 and stress_tolerance > 0.6:
		if social_needs > 0.5:
			return "democratic"  # Leader démocratique
		else:
			return "authoritative"  # Leader autoritaire
	elif social_needs > 0.7 and conflict_avoidance < 0.4:
		return "supportive"  # Leader supportif
	else:
		return "follower"  # Préfère suivre

func _get_communication_preference() -> String:
	if social_needs > 0.7:
		return "chatty"  # Bavard
	elif social_needs < 0.3:
		return "minimal"  # Communication minimale
	elif achievement_drive > 0.7:
		return "strategic"  # Communication stratégique
	else:
		return "moderate"  # Communication modérée

# Méthodes publiques pour accéder aux comportements

func get_schedule_variance() -> float:
	"""Retourne la variance d'horaire en heures"""
	return randf_range(schedule_variance.x, schedule_variance.y)

func get_stress_response(stress_level: float) -> Dictionary:
	"""Retourne la réponse au stress"""
	var response = {}
	
	if stress_level > (1.0 - stress_tolerance) * 100:
		response["mood_impact"] = -20.0 * (1.0 - stress_tolerance)
		response["energy_impact"] = -15.0 * (1.0 - stress_tolerance)
		response["disconnect_probability"] = 0.3 * (1.0 - stress_tolerance)
	else:
		response["mood_impact"] = -5.0
		response["energy_impact"] = -5.0
		response["disconnect_probability"] = 0.05
	
	return response

func get_social_influence_factor() -> float:
	"""Retourne le facteur d'influence sociale"""
	return social_needs

func get_activity_duration_preference() -> float:
	"""Retourne la durée d'activité préférée en heures"""
	return preferred_session_length + randf_range(-0.5, 0.5)

func should_form_relationship(other_profile: BehaviorProfile) -> bool:
	"""Détermine si devrait former une relation avec un autre profil"""
	
	# Calcul de compatibilité
	var compatibility = 0.0
	
	# Les sociaux s'entendent bien ensemble
	if abs(social_needs - other_profile.social_needs) < 0.3:
		compatibility += 0.3
	
	# Les achievement drivers s'entendent ou rivalisent
	if abs(achievement_drive - other_profile.achievement_drive) < 0.2:
		compatibility += 0.2
	elif achievement_drive > 0.7 and other_profile.achievement_drive > 0.7:
		compatibility -= 0.1  # Petite rivalité
	
	# Routine preference similaire
	if abs(routine_preference - other_profile.routine_preference) < 0.3:
		compatibility += 0.2
	
	# Circadian compatibility
	if circadian_type == other_profile.circadian_type:
		compatibility += 0.2
	elif circadian_type == "flexible" or other_profile.circadian_type == "flexible":
		compatibility += 0.1
	
	return compatibility > 0.4 and randf() < (0.3 + social_needs * 0.4)

func get_relationship_type(other_profile: BehaviorProfile) -> String:
	"""Détermine le type de relation avec un autre profil"""
	
	# Rivalité si les deux sont très achievement driven
	if achievement_drive > 0.8 and other_profile.achievement_drive > 0.8:
		if randf() < 0.4:
			return "rivalry"
	
	# Mentor/Élève si différence de stress tolerance significative
	if abs(stress_tolerance - other_profile.stress_tolerance) > 0.5:
		if stress_tolerance > other_profile.stress_tolerance:
			return "mentor"
		else:
			return "student"
	
	# Amitié si bonne compatibilité sociale
	if abs(social_needs - other_profile.social_needs) < 0.3 and social_needs > 0.5:
		return "friend"
	
	return "neutral"

func adjust_from_experience(event_type: String, outcome: String):
	"""Ajuste le profil selon les expériences vécues"""
	
	match event_type:
		"raid_success":
			if outcome == "positive":
				achievement_drive = min(1.0, achievement_drive + 0.02)
				stress_tolerance = min(1.0, stress_tolerance + 0.01)
		
		"raid_wipe":
			if outcome == "repeated":
				stress_tolerance = max(0.0, stress_tolerance - 0.02)
				if stress_tolerance < 0.3:
					conflict_avoidance = min(1.0, conflict_avoidance + 0.01)
		
		"social_conflict":
			if outcome == "negative":
				conflict_avoidance = min(1.0, conflict_avoidance + 0.03)
				social_needs = max(0.0, social_needs - 0.02)
		
		"good_loot":
			achievement_drive = min(1.0, achievement_drive + 0.01)
		
		"burnout_recovery":
			stress_tolerance = min(1.0, stress_tolerance + 0.05)
			routine_preference = min(1.0, routine_preference + 0.03)