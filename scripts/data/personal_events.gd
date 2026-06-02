extends Resource
class_name PersonalEvents

# Base de données des événements personnels
static var EVENTS_DATABASE = {
	# Urgences (déconnexion immédiate)
	"urgent_family": {
		"name": "Urgence familiale",
		"description": "Un membre de la famille a besoin d'aide immédiatement",
		"probability": 0.02,  # 2% par jour
		"effect_type": "immediate_disconnect",
		"duration_hours": 0,
		"message": "{player} a dû partir pour une urgence familiale",
		"mood_impact": -10,
		"can_prevent": false
	},
	"technical_problem": {
		"name": "Problème technique",
		"description": "Crash PC, coupure internet, problème matériel",
		"probability": 0.015,
		"effect_type": "immediate_disconnect",
		"duration_hours": 0,
		"message": "{player} a été déconnecté (problème technique)",
		"mood_impact": -15,
		"can_prevent": false
	},
	"doorbell": {
		"name": "Visite imprévue",
		"description": "Quelqu'un sonne à la porte",
		"probability": 0.01,
		"effect_type": "immediate_disconnect",
		"duration_hours": 0,
		"message": "{player} doit répondre à la porte",
		"mood_impact": -5,
		"can_prevent": false
	},
	"pet_emergency": {
		"name": "Urgence animale",
		"description": "L'animal de compagnie a un problème",
		"probability": 0.005,
		"effect_type": "immediate_disconnect", 
		"duration_hours": 0,
		"message": "{player} doit s'occuper de son animal",
		"mood_impact": -8,
		"can_prevent": false
	},
	
	# Obligations planifiées
	"work_overtime": {
		"name": "Heures supplémentaires",
		"description": "Doit travailler plus tard que prévu",
		"probability": 0.05,
		"effect_type": "schedule_absence",
		"delay_days": 1,
		"duration_days": 1,
		"message": "{player} doit faire des heures sup demain",
		"mood_impact": -20,
		"can_prevent": true
	},
	"family_dinner": {
		"name": "Dîner de famille",
		"description": "Repas de famille obligatoire",
		"probability": 0.03,
		"effect_type": "schedule_absence",
		"delay_days": 2,
		"duration_days": 1,
		"message": "{player} a un dîner de famille prévu",
		"mood_impact": 0,
		"can_prevent": true
	},
	"medical_appointment": {
		"name": "Rendez-vous médical",
		"description": "Consultation médicale prévue",
		"probability": 0.02,
		"effect_type": "schedule_absence",
		"delay_days": 3,
		"duration_days": 1,
		"message": "{player} a un rendez-vous médical",
		"mood_impact": -5,
		"can_prevent": false
	},
	"social_obligation": {
		"name": "Obligation sociale",
		"description": "Événement social impossible à éviter",
		"probability": 0.025,
		"effect_type": "schedule_absence",
		"delay_days": 1,
		"duration_days": 1,
		"message": "{player} a une obligation sociale",
		"mood_impact": -10,
		"can_prevent": true
	},
	"home_maintenance": {
		"name": "Travaux maison",
		"description": "Réparations ou entretien nécessaire",
		"probability": 0.015,
		"effect_type": "schedule_absence",
		"delay_days": 1,
		"duration_days": 1,
		"message": "{player} doit s'occuper de travaux",
		"mood_impact": -15,
		"can_prevent": true
	},
	
	# Temps bonus
	"free_evening": {
		"name": "Soirée libre",
		"description": "Rien de prévu, peut jouer plus longtemps",
		"probability": 0.04,
		"effect_type": "bonus_time",
		"bonus_hours": 3,
		"message": "{player} a la soirée libre !",
		"mood_impact": 15,
		"energy_boost": 20
	},
	"day_off": {
		"name": "Jour de congé",
		"description": "Congé inattendu ou jour férié",
		"probability": 0.01,
		"effect_type": "bonus_time",
		"bonus_hours": 8,
		"message": "{player} est en congé aujourd'hui !",
		"mood_impact": 25,
		"energy_boost": 30
	},
	"cancelled_plans": {
		"name": "Plans annulés",
		"description": "Les plans prévus sont annulés",
		"probability": 0.03,
		"effect_type": "bonus_time",
		"bonus_hours": 4,
		"message": "Les plans de {player} sont annulés, plus de temps pour jouer !",
		"mood_impact": 10,
		"energy_boost": 10
	},
	"insomnia": {
		"name": "Insomnie",
		"description": "Ne peut pas dormir, joue tard",
		"probability": 0.02,
		"effect_type": "bonus_time",
		"bonus_hours": 2,
		"message": "{player} n'arrive pas à dormir",
		"mood_impact": -5,
		"energy_boost": -10  # Négatif car fatigué
	},
	
	# Événements récurrents
	"weekly_commitment": {
		"name": "Engagement hebdomadaire",
		"description": "Activité récurrente chaque semaine",
		"probability": 0.0,  # Géré différemment
		"effect_type": "recurring",
		"recurrence": "weekly",
		"day_of_week": "tuesday",  # Variable selon le joueur
		"message": "{player} a son engagement hebdomadaire",
		"mood_impact": 0
	},
	"study_night": {
		"name": "Soirée études",
		"description": "Doit étudier ou travailler sur un projet",
		"probability": 0.03,
		"effect_type": "schedule_absence",
		"delay_days": 0,
		"duration_days": 1,
		"message": "{player} doit étudier ce soir",
		"mood_impact": -10,
		"can_prevent": false
	},
	
	# Événements liés à l'humeur
	"bad_day": {
		"name": "Mauvaise journée",
		"description": "Journée difficile IRL",
		"probability": 0.04,
		"effect_type": "mood_modifier",
		"mood_change": -30,
		"message": "{player} a passé une mauvaise journée",
		"affects_performance": true
	},
	"great_news": {
		"name": "Excellente nouvelle",
		"description": "Quelque chose de positif est arrivé",
		"probability": 0.02,
		"effect_type": "mood_modifier",
		"mood_change": 40,
		"message": "{player} a reçu d'excellentes nouvelles !",
		"affects_performance": true
	},
	"tired_from_work": {
		"name": "Fatigue du travail",
		"description": "Journée de travail épuisante",
		"probability": 0.05,
		"effect_type": "energy_modifier",
		"energy_change": -30,
		"message": "{player} est épuisé après le travail",
		"affects_performance": true
	}
}

# Patterns récurrents (détectés après plusieurs occurrences)
static var RECURRING_PATTERNS = {
	"always_late_monday": {
		"name": "Toujours en retard le lundi",
		"detection_threshold": 3,  # Après 3 lundis
		"confidence": 0.0
	},
	"weekend_warrior": {
		"name": "Guerrier du weekend",
		"detection_threshold": 4,  # 4 weekends consécutifs actifs
		"confidence": 0.0
	},
	"midweek_absence": {
		"name": "Absent en milieu de semaine",
		"detection_threshold": 3,
		"confidence": 0.0
	},
	"marathon_fridays": {
		"name": "Sessions marathon le vendredi",
		"detection_threshold": 3,
		"confidence": 0.0
	}
}

static func get_event(event_id: String) -> Dictionary:
	"""Retourne les données d'un événement"""
	if EVENTS_DATABASE.has(event_id):
		return EVENTS_DATABASE[event_id].duplicate()
	return {}

static func get_random_event() -> Dictionary:
	"""Retourne un événement aléatoire selon les probabilités"""
	var total_prob = 0.0
	var probabilities = []
	
	# Calculer les probabilités cumulées
	for event_id in EVENTS_DATABASE:
		var event = EVENTS_DATABASE[event_id]
		if event.probability > 0:
			total_prob += event.probability
			probabilities.append({
				"id": event_id,
				"cumulative": total_prob
			})
	
	# Sélectionner un événement
	var roll = randf() * total_prob
	
	for prob_data in probabilities:
		if roll <= prob_data.cumulative:
			var event = get_event(prob_data.id)
			event["id"] = prob_data.id
			return event
	
	return {}

static func should_trigger_event(player) -> bool:
	"""Détermine si un événement devrait se déclencher pour un joueur"""
	
	# Facteurs influençant la probabilité d'événements
	var base_chance = 0.15  # 15% de base par jour
	
	# Modificateurs selon le profil comportemental
	# (player est une Resource : pas de .has() — on teste la propriété directement)
	if player.behavior_profile != null:
		var profile = player.behavior_profile

		# Les flexibles ont plus d'événements imprévus
		base_chance *= (1.0 + profile.flexibility * 0.3)

		# Les routiniers ont moins d'événements
		base_chance *= (1.0 - profile.routine_preference * 0.2)

	# Modificateur selon le burnout (plus d'événements si burnout)
	var burnout: int = player.burnout_level if player.burnout_level != null else 0
	base_chance *= (1.0 + burnout * 0.1)

	return randf() < base_chance

static func get_event_for_player(player) -> Dictionary:
	"""Sélectionne un événement approprié pour un joueur"""
	
	var suitable_events = []
	
	for event_id in EVENTS_DATABASE:
		var event = EVENTS_DATABASE[event_id]
		
		# Filtrer selon l'état du joueur
		if event.effect_type == "immediate_disconnect" and not player.is_online:
			continue
		
		if event.effect_type == "bonus_time" and player.is_online:
			# Moins probable si déjà en ligne
			event = event.duplicate()
			event.probability *= 0.3
		
		# Ajuster selon l'humeur
		if event.get("mood_impact", 0) < 0 and player.mood < 30:
			# Éviter les événements négatifs si déjà mal
			event = event.duplicate()
			event.probability *= 0.5
		
		if event.probability > 0:
			suitable_events.append(event)
	
	# Sélectionner parmi les événements appropriés
	if suitable_events.is_empty():
		return {}
	
	var total_prob = 0.0
	for event in suitable_events:
		total_prob += event.probability
	
	var roll = randf() * total_prob
	var cumulative = 0.0
	
	for event in suitable_events:
		cumulative += event.probability
		if roll <= cumulative:
			# Trouver l'ID de l'événement
			for event_id in EVENTS_DATABASE:
				if EVENTS_DATABASE[event_id].name == event.name:
					event["id"] = event_id
					break
			return event
	
	return {}

static func detect_pattern(player_history: Array) -> Dictionary:
	"""Détecte des patterns récurrents dans l'historique d'un joueur"""
	
	var detected_patterns = {}
	
	# Analyser les connexions par jour de la semaine
	var weekday_stats = {
		"monday": {"late": 0, "absent": 0, "total": 0},
		"tuesday": {"late": 0, "absent": 0, "total": 0},
		"wednesday": {"late": 0, "absent": 0, "total": 0},
		"thursday": {"late": 0, "absent": 0, "total": 0},
		"friday": {"late": 0, "absent": 0, "marathon": 0, "total": 0},
		"saturday": {"active": 0, "total": 0},
		"sunday": {"active": 0, "total": 0}
	}
	
	for entry in player_history:
		if entry.has("weekday") and entry.has("behavior"):
			var day = entry.weekday
			if weekday_stats.has(day):
				weekday_stats[day].total += 1
				
				match entry.behavior:
					"late":
						if weekday_stats[day].has("late"):
							weekday_stats[day].late += 1
					"absent":
						if weekday_stats[day].has("absent"):
							weekday_stats[day].absent += 1
					"marathon":
						if weekday_stats[day].has("marathon"):
							weekday_stats[day].marathon += 1
					"active":
						if weekday_stats[day].has("active"):
							weekday_stats[day].active += 1
	
	# Détecter "always_late_monday"
	if weekday_stats.monday.total >= 3:
		var late_ratio = float(weekday_stats.monday.late) / float(weekday_stats.monday.total)
		if late_ratio > 0.6:
			detected_patterns["always_late_monday"] = {
				"confidence": late_ratio,
				"occurrences": weekday_stats.monday.late
			}
	
	# Détecter "weekend_warrior"
	var weekend_total = weekday_stats.saturday.total + weekday_stats.sunday.total
	var weekend_active = weekday_stats.saturday.active + weekday_stats.sunday.active
	if weekend_total >= 8:  # Au moins 4 weekends
		var active_ratio = float(weekend_active) / float(weekend_total)
		if active_ratio > 0.75:
			detected_patterns["weekend_warrior"] = {
				"confidence": active_ratio,
				"occurrences": weekend_active
			}
	
	# Détecter "midweek_absence"
	var midweek_total = weekday_stats.tuesday.total + weekday_stats.wednesday.total + weekday_stats.thursday.total
	var midweek_absent = weekday_stats.tuesday.absent + weekday_stats.wednesday.absent + weekday_stats.thursday.absent
	if midweek_total >= 9:  # Au moins 3 semaines
		var absent_ratio = float(midweek_absent) / float(midweek_total)
		if absent_ratio > 0.5:
			detected_patterns["midweek_absence"] = {
				"confidence": absent_ratio,
				"occurrences": midweek_absent
			}
	
	# Détecter "marathon_fridays"
	if weekday_stats.friday.total >= 3:
		var marathon_ratio = float(weekday_stats.friday.marathon) / float(weekday_stats.friday.total)
		if marathon_ratio > 0.6:
			detected_patterns["marathon_fridays"] = {
				"confidence": marathon_ratio,
				"occurrences": weekday_stats.friday.marathon
			}
	
	return detected_patterns

static func apply_event_effects(player, event: Dictionary):
	"""Applique les effets d'un événement sur un joueur"""
	
	# Impact sur l'humeur
	if event.has("mood_impact"):
		player.mood = clamp(player.mood + event.mood_impact, 0, 100)
	
	# Impact sur l'énergie
	if event.has("energy_boost"):
		player.energy = clamp(player.energy + event.energy_boost, 0, 100)
	
	# Effets spéciaux selon le type
	match event.get("effect_type", ""):
		"immediate_disconnect":
			player.has_urgent_event = true
		
		"schedule_absence":
			if player.scheduled_absences == null:
				player.scheduled_absences = []
			player.scheduled_absences.append({
				"event": event.get("id", "unknown"),
				"start_day": event.get("delay_days", 0),
				"duration_days": event.get("duration_days", 1)
			})
		
		"bonus_time":
			player.bonus_session_active = true
			player.bonus_session_hours = event.get("bonus_hours", 2)
		
		"mood_modifier":
			player.mood = clamp(player.mood + event.get("mood_change", 0), 0, 100)
		
		"energy_modifier":
			player.energy = clamp(player.energy + event.get("energy_change", 0), 0, 100)