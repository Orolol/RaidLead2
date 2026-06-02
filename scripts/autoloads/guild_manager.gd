extends Node

const ActivityScript = preload("res://scripts/resources/activity.gd")
const AIGuild = preload("res://scripts/resources/ai_guild.gd")
const PlayerCharacterScript = preload("res://scripts/resources/player_character.gd")

signal member_connected(player)
signal member_disconnected(player)
signal member_activity_changed(player, activity)
signal guild_level_changed(new_level)
signal guild_perk_unlocked(perk_name)
signal member_leveled_up(player, new_level)
signal member_recruited(player)
signal member_left(player)
signal loot_conflict_occurred(conflict)
signal bank_changed()

var guild_members: Array = []
var loot_history: Array = []
var guild: Guild
var activity_manager
var game_time: Node
var player_character: PlayerCharacterScript
var behavior_system: Node

func _ready() -> void:
	# Créer la guilde
	# Créer la guilde - on utilise la classe directement sans preload
	var guild_class = load("res://scripts/resources/guild.gd")
	guild = guild_class.new()
	guild.level_up.connect(_on_guild_level_up)
	guild.perk_unlocked.connect(_on_guild_perk_unlocked)
	
	activity_manager = ActivityManager
	
	# Créer le système de comportement
	_init_behavior_system()
	
	game_time = GameTime
	if game_time:
		# Se connecter aussi au signal minute_changed pour plus de granularité
		game_time.minute_changed.connect(_on_minute_changed)
		game_time.hour_changed.connect(_on_hour_changed)
		game_time.day_changed.connect(_on_day_changed)
		game_time.week_changed.connect(_on_week_changed)
		
	# Se connecter aux mises à jour de version serveur
	if ServerVersion:
		ServerVersion.version_updated.connect(_on_server_version_updated)
	
	# Se connecter au AIGuildManager pour les tentatives de débauchage (sera connecté plus tard)
	call_deferred("_connect_to_ai_guild_manager")
		
	# Connecte les signaux du gestionnaire d'activités
	activity_manager.activity_started.connect(_on_activity_started)
	activity_manager.activity_completed.connect(_on_activity_completed)
	activity_manager.activity_interrupted.connect(_on_activity_interrupted)
	
	# Créer le personnage du joueur
	_create_player_character()
	
	# Créer les membres initiaux
	GuildInitializer.create_initial_members()

func _on_minute_changed(_minute: int, _hour: int) -> void:
	# Le BehaviorSystem gère maintenant les connexions/déconnexions granulaires
	# On ne fait plus rien ici pour éviter les doublons
	pass

func _on_hour_changed(_hour: int) -> void:
	# Mise à jour horaire pour les activités et stats
	_update_all_members()

func _on_day_changed(_day: int, _week: int, _year: int) -> void:
	# Incrémente les jours dans la guilde pour tous les membres
	for member in guild_members:
		member.increment_days_in_guild()

func _on_week_changed(week: int, _year: int) -> void:
	# Verse les salaires des recrues semi-pro (Phase Nationale)
	_pay_salaries()
	# Bonus mensuel de stabilité d'équipe : une équipe intégrée gagne en réputation.
	if week % 4 == 0:
		_apply_stability_bonus()

func _apply_stability_bonus() -> void:
	"""Récompense la stabilité : forte intégration moyenne → gain de réputation (US 5.x)."""
	if not guild or guild_members.is_empty():
		return
	var total_integration: float = 0.0
	for m in guild_members:
		total_integration += m.integration
	if total_integration / float(guild_members.size()) >= 60.0:
		guild.on_team_stability_bonus()

func get_total_weekly_salaries() -> int:
	"""Masse salariale hebdomadaire totale (recrues nationales)."""
	var total: int = 0
	for member in guild_members:
		total += member.get_meta("salary", 0)
	return total

func _pay_salaries() -> void:
	"""Verse les salaires hebdomadaires ; pénalise le moral si la guilde ne peut pas payer."""
	var total: int = get_total_weekly_salaries()
	if total <= 0:
		return

	var notification_manager: Node = NotificationManager
	if guild and guild.gold >= total:
		guild.spend_gold(total)
		if notification_manager:
			notification_manager.show_info("Salaires versés : %d or" % total, "Masse salariale")
	else:
		# Impossible de payer : impact moral des salariés + réputation
		var mood_penalty: float = BalanceManager.tunable_float("salary.unpaid_mood_penalty", 15.0)
		for member in guild_members:
			if member.get_meta("salary", 0) > 0:
				member.mood = maxf(0.0, member.mood - mood_penalty)
		if guild:
			guild.lose_reputation(BalanceManager.tunable_float("salary.unpaid_reputation_loss", 3.0), "Salaires impayés")
		if notification_manager:
			notification_manager.show_warning("Salaires impayés (%d or manquants) ! Moral en baisse." % (total - guild.gold), "Budget")

func _update_all_members() -> void:
	# Les connexions/déconnexions sont maintenant gérées par le BehaviorSystem
	# avec granularité à la minute
	for member in guild_members:
		# Gérer le joueur différemment
		if member.get_meta("is_player", false):
			_update_player_character(member)
			continue
		
		# Si en ligne et sans activité, choisir une activité
		if member.is_online and member.current_activity == null:
			_assign_default_activity(member)

func _update_player_character(player: PlayerCharacterScript) -> void:
	"""Met à jour le personnage joueur.
	Le drain d'énergie est géré exclusivement par l'ActivityManager (tick 5 min)
	pour éviter un double comptage. Ici on ne traite que la reconnexion programmée."""
	if not player.is_player_controlled:
		return

	# Vérifier les tentatives de reconnexion (repos volontaire programmé)
	if not player.is_online:
		player.try_reconnect()

func _connect_member(player) -> void:
	player.go_online()
	member_connected.emit(player)
	_assign_default_activity(player)

func _disconnect_member(player) -> void:
	if player.current_activity:
		activity_manager.interrupt_activity(player, "Déconnexion")
	player.go_offline()
	member_disconnected.emit(player)
	# Lance l'activité hors ligne
	activity_manager.start_activity(player, ActivityScript.ActivityType.OFFLINE)

func _assign_default_activity(player) -> void:
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
		# Niveau 60, vérifie si farming débloqué
		if guild and guild.has_farming():
			activity_manager.start_activity(player, ActivityScript.ActivityType.FARMING)
		else:
			# Si pas de farming, activité fun
			activity_manager.start_activity(player, ActivityScript.ActivityType.FUN, {
				"name": "Discute avec les autres membres"
			})

# ==================== BANQUE & ÉQUIPEMENT ====================

func route_loot(member, item) -> void:
	"""Distribue un loot à un membre : auto-équipe si c'est une amélioration,
	sinon dépose en banque ; l'ancien objet remplacé va aussi en banque.
	La camelote (commun) n'est pas banquée pour éviter le spam."""
	if not member or not item:
		return
	var r: Dictionary = member.try_auto_equip(item)
	if r.get("equipped", false):
		var old_item = r.get("old_item", null)
		if old_item:
			_bank_loot(old_item)
	else:
		_bank_loot(item)

func _bank_loot(item) -> void:
	if not guild or item == null:
		return
	if item.rarity <= Item.Rarity.COMMON:
		return  # la camelote commune est jetée
	guild.add_to_bank(item)
	bank_changed.emit()

func equip_from_bank(member, item) -> bool:
	"""Équipe un objet de la banque sur un membre. L'ancien objet retourne en
	banque. Vrai si effectué."""
	if not member or not item or not guild:
		return false
	if not guild.remove_from_bank(item):
		return false
	if not member.equipment:
		member.equipment = Equipment.new()
	var old_item = member.equipment.equip_item(item)
	if old_item:
		guild.add_to_bank(old_item)
	bank_changed.emit()
	return true

func unequip_to_bank(member, slot: int) -> bool:
	"""Retire l'objet d'un slot d'un membre vers la banque. Vrai si un objet retiré."""
	if not member or not member.equipment or not guild:
		return false
	var item = member.equipment.remove_item(slot)
	if item == null:
		return false
	guild.add_to_bank(item)
	bank_changed.emit()
	return true

func add_member(player: SimulatedPlayer) -> bool:
	if player not in guild_members:
		# Vérifier la limite de membres
		if guild_members.size() >= guild.get_max_members():
			return false
			
		guild_members.append(player)
		# Réinitialise l'intégration et les stats
		player.integration = 0
		player.days_in_guild = 0
		# Augmenter la réputation pour recrutement réussi
		if guild:
			guild.on_successful_recruitment(player.nom, player.skill)
		# Émettre le signal de recrutement
		member_recruited.emit(player)
		# Simule une connexion si dans les horaires
		if player.should_connect(game_time):
			_connect_member(player)
		return true
	return false

func remove_member(player, was_voluntary: bool = true) -> void:
	if player in guild_members:
		if player.is_online:
			_disconnect_member(player)
		# Impact sur la réputation
		if guild:
			guild.on_member_departure(player.nom, was_voluntary)
		guild_members.erase(player)
		if behavior_system and behavior_system.has_method("forget_player"):
			behavior_system.forget_player(player)
		# Notifie le départ (NotificationManager y est abonné)
		member_left.emit(player)

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
func _on_activity_started(player, activity) -> void:
	member_activity_changed.emit(player, activity)

func _on_activity_completed(player, _activity) -> void:
	member_activity_changed.emit(player, null)
	# Assigne une nouvelle activité si toujours en ligne
	if player.is_online:
		_assign_default_activity(player)

func _on_activity_interrupted(player, _activity, _reason: String) -> void:
	member_activity_changed.emit(player, null)
	# Assigne une nouvelle activité si toujours en ligne
	if player.is_online:
		_assign_default_activity(player)

func _on_server_version_updated(new_version: float, _update_name: String) -> void:
	GameLog.d("Guilde : mise à jour vers version %s" % new_version)
	
	# Permettre aux membres de progresser en niveau
	var max_level = ServerVersion.get_max_player_level()
	for member in guild_members:
		# 40% de chance qu'un membre gagne des niveaux lors d'une mise à jour
		if randf() < 0.4 and member.personnage_niveau < max_level:
			var level_gain = randi_range(1, min(3, max_level - member.personnage_niveau))
			for i in level_gain:
				member.personnage_niveau += 1
				# Déclenche gain_xp pour chaque niveau
				guild.gain_xp(member.personnage_niveau, member.nom + " a atteint le niveau " + str(member.personnage_niveau))
				# Émettre le signal de level up
				member_leveled_up.emit(member, member.personnage_niveau)
			# L'équipement ne suit plus automatiquement le niveau avec le nouveau système
			GameLog.d("%s a gagné %d niveau(s) (maintenant niveau %d)" % [member.nom, level_gain, member.personnage_niveau])

func _on_guild_level_up(new_level: int) -> void:
	guild_level_changed.emit(new_level)
	GameLog.d("La guilde a atteint le niveau %d!" % new_level)


func _create_player_character() -> void:
	# Créer le personnage du joueur avec la nouvelle classe
	player_character = PlayerCharacterScript.new()
	player_character.nom = "Joueur"
	player_character.personnage_classe = "Guerrier"
	player_character.personnage_niveau = 1  # Commence niveau 1
	player_character.personnage_xp = 0
	
	# Stats initiales ajustées
	player_character.skill = 30  # Débutant
	player_character.energy = 100.0
	player_character.mood = 80.0
	player_character.integration = 100.0  # Leader de la guilde
	player_character.is_online = true
	
	# Énergie spécifique au joueur
	player_character.player_energy_pool = 100.0
	player_character.max_energy_pool = 100.0
	player_character.manual_control_enabled = true
	
	# Tags du joueur - principalement positifs
	player_character.tags_comportement = ["leader", "organise", "social", "patient"]
	player_character.set_meta("is_player", true)  # Marquer comme personnage du joueur
	
	GameLog.d("Personnage joueur créé: %s (Niveau %d, Classe: %s)" % [player_character.nom, player_character.personnage_niveau, player_character.personnage_classe])
	
	# Ajouter à la guilde
	add_member(player_character)

func _on_guild_perk_unlocked(_perk_name: String, _level: int) -> void:
	guild_perk_unlocked.emit(_perk_name)
	GameLog.d("Nouveau perk débloqué: %s (niveau %d)" % [_perk_name, _level])

func get_total_integration_bonus() -> float:
	return guild.get_integration_bonus()

func get_player_character() -> PlayerCharacterScript:
	"""Retourne le personnage du joueur"""
	return player_character

func is_player_online() -> bool:
	"""Vérifie si le joueur est connecté"""
	return player_character != null and player_character.is_online

# Gestion des tentatives de débauchage — déléguée au PoachingHandler
var poaching_handler: Node

func _connect_to_ai_guild_manager() -> void:
	"""Initialise le PoachingHandler qui gère les tentatives de débauchage"""
	var handler_script = load("res://scripts/systems/poaching_handler.gd")
	poaching_handler = Node.new()
	poaching_handler.set_script(handler_script)
	poaching_handler.name = "PoachingHandler"
	add_child(poaching_handler)
	GameLog.d("GuildManager connecté au AIGuildManager")

func _init_behavior_system() -> void:
	"""Initialise le système de comportement dynamique"""
	var behavior_system_script = load("res://scripts/systems/behavior_system.gd")
	behavior_system = Node.new()
	behavior_system.set_script(behavior_system_script)
	behavior_system.name = "BehaviorSystem"
	add_child(behavior_system)
	
	# Connecter les signaux
	if behavior_system.has_signal("behavior_changed"):
		behavior_system.behavior_changed.connect(_on_behavior_changed)
	if behavior_system.has_signal("personal_event_triggered"):
		behavior_system.personal_event_triggered.connect(_on_personal_event)
	if behavior_system.has_signal("burnout_level_changed"):
		behavior_system.burnout_level_changed.connect(_on_burnout_changed)

func _on_behavior_changed(player, change_type: String) -> void:
	"""Gère les changements de comportement"""
	match change_type:
		"urgent_disconnect":
			GameLog.d("%s a eu une urgence et doit se déconnecter!" % player.nom)
			if player.is_online:
				_disconnect_member(player)
		"bonus_time":
			GameLog.d("%s peut jouer plus longtemps aujourd'hui!" % player.nom)
		"scheduled_connection":
			GameLog.d("%s se connecte (planifié)" % player.nom)
			_connect_member(player)
		"scheduled_disconnection":
			GameLog.d("%s se déconnecte (planifié)" % player.nom)
			_disconnect_member(player)
		"spontaneous_connection":
			GameLog.d("%s se connecte spontanément!" % player.nom)
			_connect_member(player)
		"spontaneous_disconnection":
			GameLog.d("%s doit se déconnecter de manière imprévue" % player.nom)
			_disconnect_member(player)

func _on_personal_event(player, event: Dictionary) -> void:
	"""Gère les événements personnels"""
	if event.has("message"):
		var message = event.message.replace("{player}", player.nom)
		GameLog.d("📅 " + message)

func add_loot_entry(item: Item, member_name: String, dungeon_name: String, boss_name: String) -> void:
	"""Ajoute une entrée à l'historique de loot"""
	var entry: Dictionary = {
		"item": item,
		"member_name": member_name,
		"dungeon_name": dungeon_name,
		"boss_name": boss_name,
		"timestamp": {
			"day": GameTime.current_day,
			"week": GameTime.current_week,
			"year": GameTime.current_year,
		}
	}
	loot_history.append(entry)
	# Limiter à 200 entrées
	while loot_history.size() > 200:
		loot_history.pop_front()

func _on_burnout_changed(player, new_level: int) -> void:
	"""Gère les changements de niveau de burnout"""
	match new_level:
		0:
			GameLog.d("%s se sent en forme!" % player.nom)
		1:
			GameLog.d("%s commence à ressentir de la fatigue" % player.nom)
		2:
			GameLog.d("⚠️ %s montre des signes de burnout" % player.nom)
		3:
			GameLog.d("🚨 %s est en burnout sévère!" % player.nom)
