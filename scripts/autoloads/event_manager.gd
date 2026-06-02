extends Node

# Gestionnaire central des événements aléatoires avec système MTTH

const EventsDataResource = preload("res://scripts/data/events_data.gd")
const RandomEventResource = preload("res://scripts/resources/random_event.gd")
const EventChoiceResource = preload("res://scripts/resources/event_choice.gd")
const EffectResource = preload("res://scripts/resources/effect.gd")

var event_pool: Array = []  # Array[RandomEventResource]
var event_history: Dictionary = {}  # event_id -> {last_triggered, occurrence_count}
var active_chains: Dictionary = {}  # chain_id -> {current_event_id, progress}
var pending_event = null  # RandomEventResource

# Configuration du système
var check_interval: float = 3600.0  # Vérification toutes les heures (en secondes de jeu)
var last_check: float = 0.0
var daily_event_target: float = 1.0  # Objectif d'événements par jour
var events_today: int = 0
var last_day_count: int = 0
# var events_paused: bool = false  # Supprimé - utilise process_mode

# Signaux
signal event_triggered(event: RandomEventResource)
signal event_resolved(event: RandomEventResource, choice: EventChoiceResource)
signal chain_started(chain_id: String, event: RandomEventResource)
signal chain_continued(chain_id: String, event: RandomEventResource)
signal chain_ended(chain_id: String)

func _ready():
	GameLog.d("EventManager démarré")
	# S'arrête automatiquement avec get_tree().paused
	process_mode = PROCESS_MODE_PAUSABLE
	_load_events()
	_connect_time_signals()
	_initialize_system()

func _load_events():
	event_pool = EventsDataResource.get_all_events()
	GameLog.d("Événements chargés: %d" % event_pool.size())

func _connect_time_signals():
	var game_time = GameTime
	if game_time:
		game_time.hour_changed.connect(_on_hour_changed)
		game_time.day_changed.connect(_on_day_changed)

func _initialize_system():
	var game_time = GameTime
	if game_time:
		last_check = game_time.get_current_timestamp()
		last_day_count = game_time.current_day

func _on_hour_changed(hour: int):
	if OS.is_debug_build(): print("EventManager: Vérification horaire (heure %d)" % hour)
	_check_for_events()

func _on_day_changed(day: int, week: int, year: int):
	GameLog.d("EventManager: Nouveau jour, réinitialisation du compteur d'événements")
	events_today = 0
	last_day_count = day

func _check_for_events():
	# Le process_mode PAUSABLE s'occupe automatiquement de la pause
	if pending_event:
		GameLog.d("EventManager: Événement en attente, pas de nouveau tirage")
		return
	
	var game_time = GameTime
	if not game_time:
		return
	
	var current_time = game_time.get_current_timestamp()
	var delta_hours = (current_time - last_check) / 3600.0  # Convertir en heures
	last_check = current_time
	
	# Calculer si on doit déclencher un événement
	if _should_trigger_event(delta_hours):
		var selected_event = _select_event()
		if selected_event:
			_trigger_event(selected_event)

func _should_trigger_event(delta_hours: float) -> bool:
	# Système pour respecter l'objectif d'~1 événement par jour maximum
	
	# Si on a déjà eu notre quota d'événements aujourd'hui
	if events_today >= daily_event_target:
		GameLog.d("EventManager: Quota d'événements atteint pour aujourd'hui")
		return false
	
	# Calculer la probabilité ajustée basée sur les événements restants dans la journée
	var hours_remaining = 24 - (events_today * (24.0 / daily_event_target))
	if hours_remaining <= 0:
		return false
	
	# Probabilité de base ajustée
	var base_probability = daily_event_target / 24.0  # Probabilité par heure
	var adjusted_probability = base_probability * (24.0 / hours_remaining)
	
	# Appliquer la probabilité
	var random_roll = randf()
	if OS.is_debug_build(): print("EventManager: Roll probabilité: %.3f vs %.3f" % [random_roll, adjusted_probability])
	
	return random_roll < adjusted_probability

func _select_event():
	var eligible_events = []
	var game_state = _get_game_state()
	
	# Filtrer les événements éligibles
	for event in event_pool:
		if _is_event_eligible(event, game_state):
			eligible_events.append(event)
	
	if eligible_events.is_empty():
		GameLog.d("EventManager: Aucun événement éligible trouvé")
		return null
	
	# Sélection pondérée basée sur MTTH et poids
	var weighted_events = []
	var total_weight = 0.0
	
	for event in eligible_events:
		var weight = _calculate_event_weight(event)
		weighted_events.append({"event": event, "weight": weight})
		total_weight += weight
	
	if total_weight <= 0:
		GameLog.d("EventManager: Poids total nul")
		return null
	
	# Tirage aléatoire pondéré
	var random_value = randf() * total_weight
	var cumulative_weight = 0.0
	
	for weighted_event in weighted_events:
		cumulative_weight += weighted_event.weight
		if random_value <= cumulative_weight:
			GameLog.d("EventManager: Événement sélectionné: %s" % weighted_event.event.title)
			return weighted_event.event
	
	# Fallback
	return eligible_events[0]

func _is_event_eligible(event: RandomEventResource, game_state: Dictionary) -> bool:
	# Vérifier les conditions d'éligibilité de base
	if not event.is_eligible(game_state):
		return false
	
	# Vérifier l'historique
	var history = event_history.get(event.id, {"last_triggered": 0.0, "occurrence_count": 0})
	
	# Vérifier le cooldown
	if event.cooldown > 0:
		var game_time = GameTime
		var time_since_last = (game_time.get_current_timestamp() - history.last_triggered) / 3600.0
		if time_since_last < event.cooldown:
			return false
	
	# Vérifier le nombre maximum d'occurrences
	if event.max_occurrences > 0 and history.occurrence_count >= event.max_occurrences:
		return false
	
	# Vérifier si événement unique déjà déclenché
	if event.one_time_only and history.occurrence_count > 0:
		return false
	
	return true

func _calculate_event_weight(event: RandomEventResource) -> float:
	var base_weight = event.weight
	var history = event_history.get(event.id, {"last_triggered": 0.0, "occurrence_count": 0})
	
	# Réduire le poids des événements récemment déclenchés
	var game_time = GameTime
	var time_since_last = (game_time.get_current_timestamp() - history.last_triggered) / 3600.0
	
	if time_since_last < 24.0:  # Moins de 24h
		base_weight *= 0.1
	elif time_since_last < 168.0:  # Moins d'une semaine
		base_weight *= 0.5
	
	# Ajuster selon MTTH
	var mtth_factor = min(1.0, time_since_last / event.mtth)
	base_weight *= mtth_factor
	
	return base_weight

func _trigger_event(event: RandomEventResource):
	GameLog.d("EventManager: Déclenchement de l'événement: %s" % event.title)
	GameLog.d("EventManager: ID de l'événement: %s" % event.id)
	
	# Mettre à jour l'historique
	var game_time = GameTime
	event_history[event.id] = {
		"last_triggered": game_time.get_current_timestamp(),
		"occurrence_count": event_history.get(event.id, {"occurrence_count": 0}).occurrence_count + 1
	}
	
	events_today += 1
	pending_event = event
	
	# Gérer les chaînes d'événements
	if event.event_chain_id != "":
		if not active_chains.has(event.event_chain_id):
			chain_started.emit(event.event_chain_id, event)
			active_chains[event.event_chain_id] = {
				"current_event_id": event.id,
				"position": event.chain_position
			}
		else:
			chain_continued.emit(event.event_chain_id, event)
			active_chains[event.event_chain_id]["current_event_id"] = event.id
			active_chains[event.event_chain_id]["position"] = event.chain_position
	
	# Émettre le signal — la diffusion vers l'UI passe uniquement par ce signal.
	# main.gd écoute event_triggered et affiche la popup ; pas de chemin de node
	# en dur vers la scène principale (anti-pattern source d'erreurs).
	event_triggered.emit(event)

func resolve_event(event: RandomEventResource, choice: EventChoiceResource) -> Dictionary:
	if pending_event != event:
		GameLog.d("EventManager: Erreur - événement non pending")
		return {}
	
	GameLog.d("EventManager: Résolution de l'événement %s avec le choix %s" % [event.title, choice.text])
	
	# Appliquer les conséquences du choix
	var consequences = choice.apply_consequences()
	_apply_consequences(consequences)
	
	# Gérer la suite de la chaîne
	if choice.follow_up_event_id != "":
		var next_event = _find_event_by_id(choice.follow_up_event_id)
		if next_event:
			# Déclencher l'événement suivant plus tard (après un délai)
			var timer = Timer.new()
			add_child(timer)
			timer.wait_time = 5.0  # 5 secondes de délai
			timer.one_shot = true
			timer.timeout.connect(_trigger_follow_up_event.bind(next_event, timer))
			timer.start()
	elif choice.ends_chain and event.event_chain_id != "":
		# Terminer la chaîne
		active_chains.erase(event.event_chain_id)
		chain_ended.emit(event.event_chain_id)
	
	pending_event = null
	event_resolved.emit(event, choice)
	
	return consequences

func _trigger_follow_up_event(event: RandomEventResource, timer: Timer):
	timer.queue_free()
	pending_event = event
	_trigger_event(event)

func _apply_consequences(consequences: Dictionary):
	var guild_manager = GuildManager
	var effect_system = EffectSystem
	
	if not guild_manager:
		GameLog.d("EventManager: GuildManager non trouvé")
		return
	
	# Appliquer les conséquences immédiates
	var immediate = consequences.get("immediate", {})
	for stat in immediate:
		var value = immediate[stat]
		_apply_stat_change(stat, value, guild_manager)
	
	# Appliquer les effets
	var effects = consequences.get("effects", [])
	if effect_system:
		for effect in effects:
			if effect.target_type == EffectResource.TargetType.GUILD and guild_manager.guild:
				effect_system.apply_effect(guild_manager.guild, effect, "Événement")
			elif effect.target_type == EffectResource.TargetType.ALL_PLAYERS:
				for member in guild_manager.guild_members:
					effect_system.apply_effect(member, effect, "Événement")
	
	# Appliquer les conséquences aléatoires
	var random_consequence = consequences.get("random", null)
	if random_consequence:
		for stat in random_consequence:
			var value = random_consequence[stat]
			_apply_stat_change(stat, value, guild_manager)

func _apply_stat_change(stat: String, value, guild_manager):
	match stat:
		"guild_xp":
			if guild_manager.guild:
				guild_manager.guild.gain_xp(value, "Événement")
		
		"guild_gold":
			if guild_manager.guild:
				guild_manager.guild.add_gold(value)
		
		"all_members_mood":
			for member in guild_manager.guild_members:
				member.update_mood(value)
		
		"all_members_energy":
			for member in guild_manager.guild_members:
				member.update_energy(value)
		
		"random_member_leave":
			if value and guild_manager.guild_members.size() > 0:
				var member_to_remove = guild_manager.guild_members[randi() % guild_manager.guild_members.size()]
				guild_manager.remove_member(member_to_remove)
				GameLog.d("Événement: %s a quitté la guilde" % member_to_remove.nom)

func _find_event_by_id(event_id: String):
	for event in event_pool:
		if event.id == event_id:
			return event
	return null

func _get_game_state() -> Dictionary:
	var guild_manager = GuildManager
	var game_time = GameTime
	
	var state = {}
	
	if guild_manager and guild_manager.guild:
		state["guild_level"] = guild_manager.guild.get_level()
		state["guild_xp"] = guild_manager.guild.xp
		state["guild_gold"] = guild_manager.guild.gold
		state["guild_members_count"] = guild_manager.guild_members.size()
	
	if game_time:
		state["current_hour"] = game_time.current_hour
		state["current_day"] = game_time.current_day
		state["current_week"] = game_time.current_week
		state["current_year"] = game_time.current_year
	
	return state

# Méthodes utilitaires publiques
func force_event(event_id: String) -> bool:
	GameLog.d("EventManager: Tentative de forcer l'événement: %s" % event_id)
	var event = _find_event_by_id(event_id)
	if event:
		GameLog.d("EventManager: Événement trouvé, déclenchement de %s" % event.title)
		_trigger_event(event)
		return true
	else:
		GameLog.d("EventManager: Événement non trouvé: %s" % event_id)
	return false

func get_event_stats() -> Dictionary:
	return {
		"events_today": events_today,
		"pending_event": pending_event != null,
		"active_chains": active_chains.keys(),
		"total_events": event_pool.size()
	}

# --- Sauvegarde ---

func serialize() -> Dictionary:
	"""Persiste les cooldowns et le gating one-time (sinon des événements uniques se redéclenchent)."""
	return {
		"event_history": event_history.duplicate(true),
		"active_chains": active_chains.duplicate(true),
		"events_today": events_today,
		"last_day_count": last_day_count,
	}

func deserialize(data: Dictionary) -> void:
	event_history = data.get("event_history", {})
	active_chains = data.get("active_chains", {})
	events_today = int(data.get("events_today", 0))
	last_day_count = int(data.get("last_day_count", 0))

# Méthodes de contrôle supprimées - utilise process_mode PAUSABLE