extends Node

# Script de test pour vérifier que les joueurs ont des comportements variés

var game_time: Node
var guild_manager: Node
var behavior_system: Node

var connection_log: Array = []
var activity_log: Dictionary = {}

func _ready():
	print("=== TEST DE VARIANCE DES COMPORTEMENTS ===")
	print("Observation sur 2 heures de jeu simulées")
	print("")
	
	game_time = get_node("/root/GameTime")
	guild_manager = get_node("/root/GuildManager")
	
	# Se connecter aux signaux
	guild_manager.member_connected.connect(_on_member_connected)
	guild_manager.member_disconnected.connect(_on_member_disconnected)
	guild_manager.member_activity_changed.connect(_on_activity_changed)
	
	# Accélérer le temps pour le test (1 seconde = 1 heure de jeu)
	game_time.set_time_speed(3600.0)
	
	# Lancer le timer de rapport
	var timer = Timer.new()
	timer.wait_time = 10.0  # Rapport toutes les 10 secondes
	timer.timeout.connect(_print_report)
	add_child(timer)
	timer.start()
	
	# Arrêter après 20 secondes (environ 2 heures de jeu)
	await get_tree().create_timer(20.0).timeout
	_print_final_report()
	get_tree().quit()

func _on_member_connected(player):
	var time_str = game_time.get_current_time_string()
	connection_log.append({
		"time": time_str,
		"player": player.nom,
		"action": "connected"
	})

func _on_member_disconnected(player):
	var time_str = game_time.get_current_time_string()
	connection_log.append({
		"time": time_str,
		"player": player.nom,
		"action": "disconnected"
	})

func _on_activity_changed(player, activity):
	if activity:
		var time_str = game_time.get_current_time_string()
		if not activity_log.has(player.nom):
			activity_log[player.nom] = []
		activity_log[player.nom].append({
			"time": time_str,
			"activity": activity.get_type_string()
		})

func _print_report():
	print("\n--- Rapport intermédiaire ---")
	print("Heure actuelle: %s" % game_time.get_current_time_string())
	
	var online_count = 0
	var activities = {}
	
	for member in guild_manager.guild_members:
		if member.is_online:
			online_count += 1
			if member.current_activity:
				var activity_type = member.current_activity.get_type_string()
				if not activities.has(activity_type):
					activities[activity_type] = 0
				activities[activity_type] += 1
	
	print("Membres en ligne: %d/%d" % [online_count, guild_manager.guild_members.size()])
	print("Activités:")
	for activity in activities:
		print("  - %s: %d joueurs" % [activity, activities[activity]])

func _print_final_report():
	print("\n=== RAPPORT FINAL ===")
	print("Période simulée: %s" % game_time.get_full_datetime_string())
	
	# Analyser la variance des connexions
	print("\n## Historique des connexions/déconnexions:")
	var connection_times = {}
	for log_entry in connection_log:
		if not connection_times.has(log_entry.player):
			connection_times[log_entry.player] = []
		connection_times[log_entry.player].append(log_entry.time + " - " + log_entry.action)
	
	for player_name in connection_times:
		print("%s:" % player_name)
		for time_action in connection_times[player_name]:
			print("  %s" % time_action)
	
	# Analyser la diversité des activités
	print("\n## Diversité des activités par joueur:")
	for player_name in activity_log:
		var unique_activities = {}
		for entry in activity_log[player_name]:
			unique_activities[entry.activity] = true
		print("%s: %d activités différentes" % [player_name, unique_activities.size()])
	
	# Statistiques de variance
	print("\n## Analyse de la variance:")
	var all_connection_times = []
	for log_entry in connection_log:
		if log_entry.action == "connected":
			var time_parts = log_entry.time.split(":")
			var minutes = int(time_parts[0]) * 60 + int(time_parts[1])
			all_connection_times.append(minutes)
	
	if all_connection_times.size() > 0:
		all_connection_times.sort()
		var min_time = all_connection_times[0]
		var max_time = all_connection_times[-1]
		var spread = max_time - min_time
		print("Étalement des connexions: %d minutes" % spread)
		print("Première connexion: %02d:%02d" % [min_time / 60, min_time % 60])
		print("Dernière connexion: %02d:%02d" % [max_time / 60, max_time % 60])
	
	print("\nTest terminé.")