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

var guild_members: Array = []
var guild: Guild
var activity_manager
var game_time: Node
var player_character: PlayerCharacterScript
var behavior_system: Node

func _ready(): 
	# Créer la guilde
	# Créer la guilde - on utilise la classe directement sans preload
	var guild_class = load("res://scripts/resources/guild.gd")
	guild = guild_class.new()
	guild.level_up.connect(_on_guild_level_up)
	guild.perk_unlocked.connect(_on_guild_perk_unlocked)
	
	activity_manager = get_node("/root/ActivityManager")
	
	# Créer le système de comportement
	_init_behavior_system()
	
	game_time = get_node("/root/GameTime")
	if game_time:
		# Se connecter aussi au signal minute_changed pour plus de granularité
		game_time.minute_changed.connect(_on_minute_changed)
		game_time.hour_changed.connect(_on_hour_changed)
		game_time.day_changed.connect(_on_day_changed)
		
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
	
	# Créer 10 membres initiaux pour faciliter les tests
	_create_initial_guild_members()

func _on_minute_changed(_minute: int, _hour: int):
	# Le BehaviorSystem gère maintenant les connexions/déconnexions granulaires
	# On ne fait plus rien ici pour éviter les doublons
	pass

func _on_hour_changed(_hour: int):
	# Mise à jour horaire pour les activités et stats
	_update_all_members()

func _on_day_changed(_day: int, _week: int, _year: int):
	# Incrémente les jours dans la guilde pour tous les membres
	for member in guild_members:
		member.increment_days_in_guild()

func _update_all_members():
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

func _update_player_character(player: PlayerCharacterScript):
	"""Met à jour le personnage joueur"""
	if not player.is_player_controlled:
		return
	
	# Mettre à jour l'énergie du joueur basée sur le temps écoulé
	if player.current_activity:
		player.update_player_energy(5.0)  # 5 minutes écoulées
	
	# Vérifier les tentatives de reconnexion
	if not player.is_online:
		player.try_reconnect()

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
		# Niveau 60, vérifie si farming débloqué
		if guild and guild.has_farming():
			activity_manager.start_activity(player, ActivityScript.ActivityType.FARMING)
		else:
			# Si pas de farming, activité fun
			activity_manager.start_activity(player, ActivityScript.ActivityType.FUN, {
				"name": "Discute avec les autres membres"
			})

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

func remove_member(player, was_voluntary: bool = true):
	if player in guild_members:
		if player.is_online:
			_disconnect_member(player)
		# Impact sur la réputation
		if guild:
			guild.on_member_departure(player.nom, was_voluntary)
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

func _on_server_version_updated(new_version: float, _update_name: String):
	print("Guilde : mise à jour vers version %s" % new_version)
	
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
			print("%s a gagné %d niveau(s) (maintenant niveau %d)" % [member.nom, level_gain, member.personnage_niveau])

func _on_guild_level_up(new_level: int):
	guild_level_changed.emit(new_level)
	print("La guilde a atteint le niveau %d!" % new_level)


func _create_player_character():
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
	
	print("Personnage joueur créé: %s (Niveau %d, Classe: %s)" % [player_character.nom, player_character.personnage_niveau, player_character.personnage_classe])
	
	# Ajouter à la guilde
	add_member(player_character)

func _on_guild_perk_unlocked(_perk_name: String, _level: int):
	guild_perk_unlocked.emit(_perk_name)
	print("Nouveau perk débloqué: %s (niveau %d)" % [_perk_name, _level])

func get_total_integration_bonus() -> float:
	return guild.get_integration_bonus()

func get_player_character() -> PlayerCharacterScript:
	"""Retourne le personnage du joueur"""
	return player_character

func is_player_online() -> bool:
	"""Vérifie si le joueur est connecté"""
	return player_character != null and player_character.is_online

func _create_initial_guild_members():
	# Noms de membres pour la guilde
	var member_names = [
		"Thorin", "Legolas", "Gimli", "Aragorn", "Gandalf",
		"Frodo", "Sam", "Merry", "Pippin", "Boromir"
	]
	
	var classes = ["Guerrier", "Prêtre", "Mage", "Voleur", "Chasseur", "Druide", "Démoniste", "Paladin", "Chaman"]
	var roles_by_class = {
		"Guerrier": "Tank",
		"Prêtre": "Healer",
		"Mage": "DPS",
		"Voleur": "DPS",
		"Chasseur": "DPS",
		"Druide": ["Tank", "Healer", "DPS"],  # Peut faire plusieurs rôles
		"Démoniste": "DPS",
		"Paladin": ["Tank", "Healer", "DPS"],  # Peut faire plusieurs rôles
		"Chaman": ["Healer", "DPS"]  # Peut faire plusieurs rôles
	}
	
	# S'assurer d'avoir une bonne composition
	var required_tanks = 1
	var required_healers = 1
	var created_tanks = 0
	var created_healers = 0
	
	for i in range(10):
		var member = SimulatedPlayer.new()
		member.nom = member_names[i]
		
		# Assigner une classe en fonction des besoins de composition
		var chosen_class = ""
		if created_tanks < required_tanks:
			# Besoin de tanks
			chosen_class = ["Guerrier", "Druide", "Paladin"].pick_random()
			member.personnage_role = "Tank"
			created_tanks += 1
		elif created_healers < required_healers:
			# Besoin de healers
			chosen_class = ["Prêtre", "Druide", "Paladin", "Chaman"].pick_random()
			member.personnage_role = "Healer"
			created_healers += 1
		else:
			# Le reste en DPS
			chosen_class = classes.pick_random()
			var role_options = roles_by_class[chosen_class]
			if role_options is Array:
				member.personnage_role = "DPS"  # Toujours DPS pour le reste
			else:
				member.personnage_role = role_options
		
		member.personnage_classe = chosen_class
		
		# Niveau 1 pour tous
		member.personnage_niveau = 1
		
		# L'équipement de départ est géré par SimulatedPlayer
		
		# Skill entre 40 et 80
		member.skill = randi_range(40, 80)
		
		# Stats initiales
		member.energy = randi_range(60, 100)
		member.mood = randi_range(50, 90)
		member.integration = randi_range(20, 60)  # Déjà un peu intégrés
		member.days_in_guild = randi_range(7, 30)  # Dans la guilde depuis 1-4 semaines
		
		# Planning varié - copier le planning du joueur modifié
		member.planning = {
			"lundi": {"soir": randf() > 0.3},
			"mardi": {"soir": randf() > 0.3},
			"mercredi": {"soir": randf() > 0.3},
			"jeudi": {"soir": randf() > 0.3},
			"vendredi": {"soir": randf() > 0.3},
			"samedi": {"apres_midi": randf() > 0.2, "soir": randf() > 0.1},
			"dimanche": {"apres_midi": randf() > 0.2, "soir": randf() > 0.2}
		}
		
		# Tags comportementaux variés
		if randf() > 0.5:
			member.tags_comportement = [["social", "patient"].pick_random()]
		else:
			member.tags_comportement = []
		
		# Certains membres ont de l'or initial
		if randf() < 0.3:
			member.or_actuel = randi_range(50, 200)
		
		# Ajouter le membre à la guilde
		add_member(member)
		
		print("Membre initial créé: %s - %s %s Niv.%d" % [
			member.nom, 
			member.personnage_role,
			member.personnage_classe, 
			member.personnage_niveau
		])

# Gestion des tentatives de débauchage

func _connect_to_ai_guild_manager():
	"""Se connecte au AIGuildManager une fois qu'il est prêt"""
	var ai_guild_manager = get_node_or_null("/root/AIGuildManager")
	if ai_guild_manager:
		ai_guild_manager.connect("poaching_attempt", _on_poaching_attempt)
		print("GuildManager connecté au AIGuildManager")

func _on_poaching_attempt(target_member, source_guild: AIGuild, success: bool):
	"""Gère les tentatives de débauchage par les guildes IA"""
	# Vérifier si le membre ciblé est dans notre guilde
	if target_member not in guild_members:
		return
	
	# Ne pas traiter les tentatives sur le personnage du joueur
	if target_member.get_meta("is_player", false):
		return
	
	if success:
		print("🚨 ALERTE DE DÉBAUCHAGE: %s tente de recruter %s !" % [source_guild.name, target_member.nom])
		_show_poaching_popup(target_member, source_guild)
	else:
		print("🛡️ Tentative de débauchage échouée: %s a refusé l'offre de %s" % [target_member.nom, source_guild.name])

func _show_poaching_popup(member, source_guild: AIGuild):
	"""Affiche le popup de gestion de débauchage"""
	# Créer le popup
	var poaching_popup_scene = load("res://scripts/ui/windows/poaching_popup.gd")
	var popup = Window.new()
	popup.set_script(poaching_popup_scene)
	
	get_tree().root.add_child(popup)
	
	# Connecter les signaux
	popup.connect("counter_offer_made", _on_counter_offer_made)
	popup.connect("member_released", _on_member_released_to_poaching)
	popup.connect("poaching_ignored", _on_poaching_ignored)
	
	# Générer une offre fictive basée sur la stratégie de la guilde
	var offer = _generate_poaching_offer(source_guild, member)
	
	# Afficher le popup
	popup.show_poaching_attempt(member, source_guild, offer)

func _generate_poaching_offer(source_guild: AIGuild, member) -> Dictionary:
	"""Génère une offre de débauchage réaliste"""
	var offer = {}
	
	# Bonus d'équipement basé sur la stratégie
	match source_guild.ai_strategy:
		AIGuild.Strategy.HARDCORE:
			offer["equipment_bonus"] = randi_range(20, 50)
		AIGuild.Strategy.AGGRESSIVE:
			offer["equipment_bonus"] = randi_range(15, 40)
		AIGuild.Strategy.BALANCED:
			offer["equipment_bonus"] = randi_range(10, 25)
		_:
			offer["equipment_bonus"] = randi_range(5, 20)
	
	# Place garantie en raid pour les guildes agressives
	offer["guaranteed_raid_spot"] = source_guild.ai_strategy in [AIGuild.Strategy.HARDCORE, AIGuild.Strategy.AGGRESSIVE]
	
	# Rôle de leadership pour les très bons joueurs
	offer["leadership_role"] = member.skill > 85 and randf() < 0.3
	
	# Message personnalisé selon la stratégie
	match source_guild.ai_strategy:
		AIGuild.Strategy.HARDCORE:
			offer["message"] = "Rejoignez l'élite et prouvez votre valeur !"
		AIGuild.Strategy.AGGRESSIVE:
			offer["message"] = "Nous offrons ce que votre guilde actuelle ne peut pas."
		AIGuild.Strategy.BALANCED:
			offer["message"] = "Venez progresser dans un environnement équilibré."
		AIGuild.Strategy.DEFENSIVE:
			offer["message"] = "Nous valorisons la stabilité et la loyauté."
		AIGuild.Strategy.CASUAL:
			offer["message"] = "Rejoignez une guilde détendue et amicale."
	
	return offer

func _on_counter_offer_made(member, counter_offer: Dictionary):
	"""Gère les contre-offres du joueur"""
	print("Contre-offre envoyée pour %s: %s" % [member.nom, str(counter_offer)])
	
	# Appliquer immédiatement certains bénéfices pour montrer notre engagement
	if counter_offer.get("equipment_bonus", 0) > 0:
		# TODO: Avec le nouveau système, donner des objets spécifiques plutôt qu'un bonus général
		# member.personnage_equipement += counter_offer.equipment_bonus
		print("Équipement de %s amélioré de +%d" % [member.nom, counter_offer.equipment_bonus])
	
	if counter_offer.get("salary_increase", 0) > 0:
		# Augmenter le moral pour représenter la prime
		member.mood = min(100.0, member.mood + 10.0)
		print("Prime de fidélité accordée à %s" % member.nom)

func _on_member_released_to_poaching(member):
	"""Gère le départ d'un membre suite à un débauchage"""
	print("💔 %s quitte la guilde suite au débauchage" % member.nom)
	
	# Supprimer le membre de la guilde (départ non volontaire = débauchage)
	remove_member(member, false)
	
	# Impact sur le moral des autres membres
	for other_member in guild_members:
		if other_member != member and not other_member.get_meta("is_player", false):
			other_member.mood = max(0.0, other_member.mood - 5.0)
			# Légère baisse d'intégration par peur d'être la prochaine cible
			other_member.integration = max(0.0, other_member.integration - 3.0)
	
	print("Le moral de l'équipe a été affecté par le départ de %s" % member.nom)

func _on_poaching_ignored():
	"""Gère l'ignorance d'une tentative de débauchage"""
	print("Tentative de débauchage ignorée")
	# Les conséquences sont gérées dans le popup

func _init_behavior_system():
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

func _on_behavior_changed(player, change_type: String):
	"""Gère les changements de comportement"""
	match change_type:
		"urgent_disconnect":
			print("%s a eu une urgence et doit se déconnecter!" % player.nom)
			if player.is_online:
				_disconnect_member(player)
		"bonus_time":
			print("%s peut jouer plus longtemps aujourd'hui!" % player.nom)
		"scheduled_connection":
			print("%s se connecte (planifié)" % player.nom)
			_connect_member(player)
		"scheduled_disconnection":
			print("%s se déconnecte (planifié)" % player.nom)
			_disconnect_member(player)
		"spontaneous_connection":
			print("%s se connecte spontanément!" % player.nom)
			_connect_member(player)
		"spontaneous_disconnection":
			print("%s doit se déconnecter de manière imprévue" % player.nom)
			_disconnect_member(player)

func _on_personal_event(player, event: Dictionary):
	"""Gère les événements personnels"""
	if event.has("message"):
		var message = event.message.replace("{player}", player.nom)
		print("📅 " + message)

func _on_burnout_changed(player, new_level: int):
	"""Gère les changements de niveau de burnout"""
	match new_level:
		0:
			print("%s se sent en forme!" % player.nom)
		1:
			print("%s commence à ressentir de la fatigue" % player.nom)
		2:
			print("⚠️ %s montre des signes de burnout" % player.nom)
		3:
			print("🚨 %s est en burnout sévère!" % player.nom)
