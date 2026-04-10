extends Node

signal player_state_changed(player, state_type, old_value, new_value)
signal player_activity_requested(player, activity_type, params)
signal player_activity_started(player, activity)
signal player_activity_completed(player, activity)
signal player_activity_interrupted(player, activity, reason)

signal player_connection_requested(player)
signal player_disconnection_requested(player)
signal player_connected(player)
signal player_disconnected(player)

signal decision_needed(player, decision_type, context)
signal decision_made(player, decision_type, result)

signal fatigue_changed(player, old_value, new_value)
signal burnout_changed(player, old_level, new_level)
signal mood_changed(player, old_value, new_value)
signal energy_changed(player, old_value, new_value)

signal relationship_formed(player1, player2, type)
signal relationship_changed(player1, player2, old_type, new_type)
signal relationship_broken(player1, player2)
signal social_influence_calculated(player, influence_value)

signal personal_event_triggered(player, event_type, event_data)
signal emergency_event(player, event_type)
signal schedule_disrupted(player, reason)

signal preference_updated(player, preference_type, old_value, new_value)
signal behavior_pattern_detected(player, pattern_type, confidence)

signal system_event(event_type, data)
signal debug_event(message, data)

var event_history: Array = []
var max_history_size: int = 100
var subscribers: Dictionary = {}
var event_filters: Dictionary = {}

func _ready():
	name = "EventBus"
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Initialize subscriber tracking
	_initialize_subscriber_tracking()

func emit_event(event_name: String, args: Array = []):
	"""
	Emit un événement avec support pour l'historique et le filtrage
	"""
	# Enregistrer dans l'historique
	_add_to_history(event_name, args)
	
	# Appliquer les filtres
	if _should_filter_event(event_name, args):
		return
	
	# Émettre le signal correspondant
	if has_signal(event_name):
		var signal_obj = get(event_name)
		if signal_obj and signal_obj is Signal:
			match args.size():
				0: signal_obj.emit()
				1: signal_obj.emit(args[0])
				2: signal_obj.emit(args[0], args[1])
				3: signal_obj.emit(args[0], args[1], args[2])
				4: signal_obj.emit(args[0], args[1], args[2], args[3])
				_: 
					push_warning("EventBus: Too many arguments for signal %s" % event_name)
	else:
		push_warning("EventBus: Unknown event %s" % event_name)

func subscribe(subscriber: Node, event_name: String, callback: Callable):
	"""
	Abonne un nœud à un événement spécifique
	"""
	if not has_signal(event_name):
		push_error("EventBus: Cannot subscribe to unknown event %s" % event_name)
		return false
	
	# Tracker l'abonnement
	if not subscribers.has(subscriber):
		subscribers[subscriber] = []
	subscribers[subscriber].append(event_name)
	
	# Connecter le signal
	var signal_obj = get(event_name)
	if signal_obj and signal_obj is Signal:
		if not signal_obj.is_connected(callback):
			signal_obj.connect(callback)
			return true
	
	return false

func unsubscribe(subscriber: Node, event_name: String, callback: Callable):
	"""
	Désabonne un nœud d'un événement
	"""
	if not has_signal(event_name):
		return false
	
	# Retirer du tracking
	if subscribers.has(subscriber):
		subscribers[subscriber].erase(event_name)
		if subscribers[subscriber].is_empty():
			subscribers.erase(subscriber)
	
	# Déconnecter le signal
	var signal_obj = get(event_name)
	if signal_obj and signal_obj is Signal:
		if signal_obj.is_connected(callback):
			signal_obj.disconnect(callback)
			return true
	
	return false

func add_event_filter(filter_name: String, filter_func: Callable):
	"""
	Ajoute un filtre pour intercepter/modifier des événements
	"""
	if not event_filters.has(filter_name):
		event_filters[filter_name] = []
	event_filters[filter_name].append(filter_func)

func remove_event_filter(filter_name: String, filter_func: Callable):
	"""
	Retire un filtre d'événements
	"""
	if event_filters.has(filter_name):
		event_filters[filter_name].erase(filter_func)

func get_event_history(event_name: String = "", limit: int = 10) -> Array:
	"""
	Retourne l'historique des événements
	"""
	var filtered_history = []
	
	for entry in event_history:
		if event_name == "" or entry.event == event_name:
			filtered_history.append(entry)
	
	# Retourner les derniers événements selon la limite
	if filtered_history.size() > limit:
		return filtered_history.slice(-limit)
	
	return filtered_history

func clear_history():
	"""
	Vide l'historique des événements
	"""
	event_history.clear()

func get_subscriber_count(event_name: String) -> int:
	"""
	Retourne le nombre d'abonnés à un événement
	"""
	var count = 0
	for subscriber in subscribers:
		if event_name in subscribers[subscriber]:
			count += 1
	return count

func emit_player_state_change(player, state_type: String, old_value, new_value):
	"""
	Helper pour émettre un changement d'état de joueur
	"""
	emit_event("player_state_changed", [player, state_type, old_value, new_value])
	
	# Émettre aussi des événements spécifiques selon le type
	match state_type:
		"energy":
			emit_event("energy_changed", [player, old_value, new_value])
		"mood":
			emit_event("mood_changed", [player, old_value, new_value])
		"fatigue":
			emit_event("fatigue_changed", [player, old_value, new_value])
		"burnout":
			emit_event("burnout_changed", [player, old_value, new_value])

func emit_activity_event(event_type: String, player, activity, params = null):
	"""
	Helper pour émettre des événements d'activité
	"""
	match event_type:
		"requested":
			emit_event("player_activity_requested", [player, activity, params if params else {}])
		"started":
			emit_event("player_activity_started", [player, activity])
		"completed":
			emit_event("player_activity_completed", [player, activity])
		"interrupted":
			emit_event("player_activity_interrupted", [player, activity, params if params else "Unknown"])

func emit_connection_event(event_type: String, player):
	"""
	Helper pour émettre des événements de connexion
	"""
	match event_type:
		"requested":
			emit_event("player_connection_requested", [player])
		"connected":
			emit_event("player_connected", [player])
		"disconnect_requested":
			emit_event("player_disconnection_requested", [player])
		"disconnected":
			emit_event("player_disconnected", [player])

func emit_decision_event(player, decision_type: String, context = null, result = null):
	"""
	Helper pour émettre des événements de décision
	"""
	if result == null:
		emit_event("decision_needed", [player, decision_type, context if context else {}])
	else:
		emit_event("decision_made", [player, decision_type, result])

func emit_social_event(event_type: String, player1, player2 = null, data = null):
	"""
	Helper pour émettre des événements sociaux
	"""
	match event_type:
		"relationship_formed":
			emit_event("relationship_formed", [player1, player2, data])
		"relationship_changed":
			emit_event("relationship_changed", [player1, player2, data.old_type, data.new_type])
		"relationship_broken":
			emit_event("relationship_broken", [player1, player2])
		"influence_calculated":
			emit_event("social_influence_calculated", [player1, data])

func emit_system_event(event_type: String, data = null):
	"""
	Helper pour émettre des événements système
	"""
	emit_event("system_event", [event_type, data if data else {}])

func emit_debug(message: String, data = null):
	"""
	Helper pour émettre des événements de debug
	"""
	if OS.is_debug_build():
		emit_event("debug_event", [message, data if data else {}])
		print("[EventBus Debug] %s" % message)
		if data:
			print("  Data: %s" % str(data))

# Méthodes privées

func _initialize_subscriber_tracking():
	"""
	Initialise le tracking des abonnés
	"""
	subscribers.clear()

func _add_to_history(event_name: String, args: Array):
	"""
	Ajoute un événement à l'historique
	"""
	var entry = {
		"event": event_name,
		"args": args,
		"timestamp": Time.get_ticks_msec(),
		"game_time": _get_game_time_snapshot()
	}
	
	event_history.append(entry)
	
	# Limiter la taille de l'historique
	if event_history.size() > max_history_size:
		event_history.pop_front()

func _should_filter_event(event_name: String, args: Array) -> bool:
	"""
	Vérifie si un événement doit être filtré
	"""
	if not event_filters.has(event_name):
		return false
	
	for filter_func in event_filters[event_name]:
		if filter_func.call(args):
			return true  # Filtrer l'événement
	
	return false

func _get_game_time_snapshot() -> Dictionary:
	"""
	Capture l'état actuel du temps de jeu
	"""
	var game_time = get_node_or_null("/root/GameTime")
	if game_time:
		return {
			"day": game_time.current_day,
			"week": game_time.current_week,
			"hour": game_time.current_hour,
			"minute": game_time.current_minute
		}
	return {}

func get_stats() -> Dictionary:
	"""
	Retourne des statistiques sur l'utilisation de l'EventBus
	"""
	var stats = {
		"total_subscribers": subscribers.size(),
		"total_events_in_history": event_history.size(),
		"events_by_type": {},
		"most_active_subscribers": []
	}
	
	# Compter les événements par type
	for entry in event_history:
		if not stats.events_by_type.has(entry.event):
			stats.events_by_type[entry.event] = 0
		stats.events_by_type[entry.event] += 1
	
	# Identifier les abonnés les plus actifs
	var subscriber_activity = []
	for subscriber in subscribers:
		subscriber_activity.append({
			"node": subscriber.name if subscriber else "Unknown",
			"subscriptions": subscribers[subscriber].size()
		})
	
	subscriber_activity.sort_custom(func(a, b): return a.subscriptions > b.subscriptions)
	stats.most_active_subscribers = subscriber_activity.slice(0, 5)
	
	return stats