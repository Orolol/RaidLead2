extends Node

const ActivityManagerScript = preload("res://scripts/systems/activity_manager.gd")
const ActivityScript = preload("res://scripts/resources/activity.gd")

signal member_connected(player)
signal member_disconnected(player)
signal member_activity_changed(player, activity)

var guild_members: Array = []
var activity_manager
var game_time: Node

func _ready():
	activity_manager = ActivityManagerScript.new()
	add_child(activity_manager)
	
	game_time = get_node("/root/GameTime")
	if game_time:
		game_time.hour_changed.connect(_on_hour_changed)
		game_time.day_changed.connect(_on_day_changed)
		
	# Connecte les signaux du gestionnaire d'activités
	activity_manager.activity_started.connect(_on_activity_started)
	activity_manager.activity_completed.connect(_on_activity_completed)
	activity_manager.activity_interrupted.connect(_on_activity_interrupted)

func _on_hour_changed(_hour: int):
	_update_all_members()

func _on_day_changed(_day: int, _week: int, _year: int):
	# Incrémente les jours dans la guilde pour tous les membres
	for member in guild_members:
		member.increment_days_in_guild()

func _update_all_members():
	for member in guild_members:
		# Gestion connexion/déconnexion
		if member.is_online and member.should_disconnect(game_time):
			_disconnect_member(member)
		elif not member.is_online and member.should_connect(game_time):
			_connect_member(member)
		
		# Si en ligne et sans activité, choisir une activité
		if member.is_online and member.current_activity == null:
			_assign_default_activity(member)

func _connect_member(player):
	player.go_online()
	member_connected.emit(player)
	_assign_default_activity(player)

func _disconnect_member(player):
	if player.current_activity:
		activity_manager.interrupt_activity(player, "Déconnexion")
	player.go_offline()
	member_disconnected.emit(player)
	# Lance l'activité hors ligne
	activity_manager.start_activity(player, ActivityScript.ActivityType.OFFLINE)

func _assign_default_activity(player):
	if not player.is_online:
		return
		
	# Logique simple basée sur l'état du joueur
	if player.mood < 30:
		# Moral bas, activité fun
		activity_manager.start_activity(player, ActivityScript.ActivityType.FUN, {
			"name": "Danse devant la banque d'Orgrimmar"
		})
	elif player.personnage_niveau < 60:
		# Pas niveau max, leveling
		activity_manager.start_activity(player, ActivityScript.ActivityType.LEVELING)
	else:
		# Niveau 60, farming
		activity_manager.start_activity(player, ActivityScript.ActivityType.FARMING)

func add_member(player: SimulatedPlayer):
	if player not in guild_members:
		guild_members.append(player)
		# Réinitialise l'intégration et les stats
		player.integration = 0
		player.days_in_guild = 0
		# Simule une connexion si dans les horaires
		if player.should_connect(game_time):
			_connect_member(player)

func remove_member(player):
	if player in guild_members:
		if player.is_online:
			_disconnect_member(player)
		guild_members.erase(player)

func get_online_members() -> Array:
	var online = []
	for member in guild_members:
		if member.is_online:
			online.append(member)
	return online

func get_members_by_role(role: String) -> Array:
	var members = []
	for member in guild_members:
		if member.get_role() == role:
			members.append(member)
	return members

func get_available_members_for_activity(activity_type: String) -> Array:
	var available = []
	for member in get_online_members():
		if member.is_available_now() and member.will_accept_activity(activity_type):
			available.append(member)
	return available

# Callbacks des activités
func _on_activity_started(player, activity):
	member_activity_changed.emit(player, activity)

func _on_activity_completed(player, _activity):
	member_activity_changed.emit(player, null)
	# Assigne une nouvelle activité si toujours en ligne
	if player.is_online:
		_assign_default_activity(player)

func _on_activity_interrupted(player, _activity, _reason: String):
	member_activity_changed.emit(player, null)
	# Assigne une nouvelle activité si toujours en ligne
	if player.is_online:
		_assign_default_activity(player)