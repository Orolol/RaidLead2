extends Control

const MenuBarScript = preload("res://scripts/ui/components/menu_bar.gd")
const WindowManagerScript = preload("res://scripts/managers/window_manager.gd")
const RandomEventResource = preload("res://scripts/resources/random_event.gd")
const EventChoiceResource = preload("res://scripts/resources/event_choice.gd")
const EventPopupWindow = preload("res://scripts/ui/windows/event_popup.gd")
const PlayerControlPanelScript = preload("res://scripts/ui/components/player_control_panel.gd")
# const FastForwardDialog = preload("res://scripts/ui/windows/fast_forward_dialog.gd")  # Supprimé - système simplifié

var window_manager: Node
var menu_bar: Control

var chat_panel: ChatPanel = null
var event_popup: EventPopupWindow = null

# Système joueur
var player_control_panel: PlayerControlPanelScript = null
var player_character = null  # Référence au personnage joueur
# var fast_forward_manager: Node = null  # Supprimé - système simplifié

func _ready():
	# Les nœuds existent déjà dans la scène
	menu_bar = $VBoxContainer/menu_bar
	window_manager = $VBoxContainer/window_manager
	
	_setup_background()
	_setup_time_display()
	_setup_chat_panel()
	_setup_debug_menu()
	_connect_menu_signals()
	_register_windows()
	_connect_window_signals()
	_connect_event_system()
	_setup_player_systems()

	# Charger la sauvegarde si elle existe (après que tous les systèmes soient prêts)
	get_tree().create_timer(0.2).timeout.connect(func():
		if SaveManager.has_save():
			SaveManager.load_game()
	)
	


func _setup_background():
	var background = ColorRect.new()
	background.color = Color(0.1, 0.1, 0.15)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	move_child(background, 0)

func _setup_time_display():
	var time_display_scene = load("res://scenes/TimeDisplay.tscn")
	var time_display = time_display_scene.instantiate()
	add_child(time_display)
	# Ancrage top-center pour supporter toutes les résolutions
	time_display.set_anchors_preset(Control.PRESET_CENTER_TOP)
	time_display.offset_left = -time_display.custom_minimum_size.x / 2
	time_display.offset_top = 10
	time_display.offset_right = time_display.custom_minimum_size.x / 2
	time_display.offset_bottom = 10 + time_display.custom_minimum_size.y

func _setup_chat_panel():
	var chat_scene = load("res://scenes/ChatPanel.tscn")
	chat_panel = chat_scene.instantiate()
	add_child(chat_panel)
	
	# Ancrage bottom-right pour supporter toutes les résolutions
	chat_panel.custom_minimum_size = Vector2(400, 230)
	chat_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	chat_panel.offset_left = -420
	chat_panel.offset_top = -250
	chat_panel.offset_right = -20
	chat_panel.offset_bottom = -20
	chat_panel.z_index = 10  # Au-dessus du background mais sous les fenêtres

func _setup_debug_menu():
	# Créer un conteneur pour le menu debug
	var debug_container = PanelContainer.new()
	debug_container.custom_minimum_size = Vector2(150, 30)
	# Ancrage top-left pour supporter toutes les résolutions
	debug_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	debug_container.offset_left = 10
	debug_container.offset_top = 80
	debug_container.offset_right = 10 + 150
	debug_container.offset_bottom = 80 + 30
	
	var menu_button = MenuButton.new()
	menu_button.text = "Debug"
	menu_button.flat = false
	debug_container.add_child(menu_button)
	
	var popup = menu_button.get_popup()
	
	# Ajouter les options de debug
	popup.add_item("Ajouter 100 XP à la guilde")
	popup.add_item("Ajouter 1000 XP à la guilde")
	popup.add_separator()
	popup.add_item("Level up un membre aléatoire")
	popup.add_item("Level up tous les membres")
	popup.add_separator()
	popup.add_item("Ajouter 1000 or à la guilde")
	popup.add_item("Donner équipement aux membres")
	popup.add_separator()
	popup.add_item("Forcer mise à jour serveur")
	popup.add_item("Compléter un donjon (succès)")
	popup.add_separator()
	popup.add_item("Déclencher événement test")
	popup.add_item("Afficher stats événements")
	popup.add_separator()
	popup.add_item("Test notification INFO")
	popup.add_item("Test notification SUCCESS")
	popup.add_item("Test notification WARNING")
	popup.add_item("Test notification ERROR")
	popup.add_item("Test notification ACHIEVEMENT")
	
	# Connecter les signaux
	popup.id_pressed.connect(_on_debug_menu_pressed)
	
	add_child(debug_container)

func _connect_menu_signals():
	menu_bar.personnage_button_pressed.connect(_on_personnage_button_pressed)
	menu_bar.guilde_button_pressed.connect(_on_guilde_button_pressed)
	menu_bar.monde_button_pressed.connect(_on_monde_button_pressed)
	menu_bar.organisation_button_pressed.connect(_on_organisation_button_pressed)

func _on_personnage_button_pressed():
	window_manager.show_window("personnage")

func _on_guilde_button_pressed():
	window_manager.show_window("guilde")

func _on_monde_button_pressed():
	window_manager.show_window("monde")

func _on_organisation_button_pressed():
	window_manager.show_window("organisation")

func _register_windows():
	window_manager.register_window("personnage", "res://scenes/Fenetre_Personnage.tscn")
	window_manager.register_window("guilde", "res://scenes/Fenetre_Guilde.tscn")
	window_manager.register_window("monde", "res://scenes/Fenetre_Monde.tscn")
	window_manager.register_window("organisation", "res://scenes/Fenetre_OrganisationGroupe.tscn")

func _connect_window_signals():
	# Écouter l'ouverture des fenêtres pour connecter leurs signaux
	window_manager.window_opened.connect(_on_window_opened)

	# Ouvrir la fenêtre Personnage par défaut après que le tree soit stabilisé
	get_tree().create_timer(0.1).timeout.connect(func():
		window_manager.show_window("personnage")
	)

func _on_window_opened(window_name: String) -> void:
	# Connecter les signaux spécifiques quand une fenêtre est ouverte
	var instance: Control = window_manager._get_existing_instance(window_name)
	if not instance:
		return

	match window_name:
		"monde":
			if not instance.player_recruited.is_connected(_on_player_recruited):
				instance.player_recruited.connect(_on_player_recruited)
		"organisation":
			var guild_manager_node: Node = GuildManager
			if guild_manager_node:
				instance.set_guild_members(guild_manager_node.guild_members)

func _on_player_recruited(player: SimulatedPlayer) -> void:
	var guild_manager_node: Node = GuildManager
	if guild_manager_node:
		guild_manager_node.add_member(player)
		# Rafraîchir les fenêtres ouvertes via leurs instances dans le WindowManager
		var guilde_inst: Control = window_manager._get_existing_instance("guilde")
		if guilde_inst:
			guilde_inst._refresh_member_list()
		var org_inst: Control = window_manager._get_existing_instance("organisation")
		if org_inst:
			org_inst.set_guild_members(guild_manager_node.guild_members)

func _on_debug_menu_pressed(id: int):
	print("Debug menu pressed - Option ID: %d" % id)
	var guild_manager = GuildManager
	if not guild_manager:
		print("ERREUR: GuildManager non trouvé")
		return
		
	match id:
		0: # Ajouter 100 XP à la guilde
			if guild_manager.guild:
				guild_manager.guild.gain_xp(100, "Debug: +100 XP")
				print("Debug: +100 XP à la guilde")
				
		1: # Ajouter 1000 XP à la guilde
			if guild_manager.guild:
				guild_manager.guild.gain_xp(1000, "Debug: +1000 XP")
				print("Debug: +1000 XP à la guilde")
				
		2: # Level up un membre aléatoire
			if guild_manager.guild_members.size() > 0:
				var member = guild_manager.guild_members[randi() % guild_manager.guild_members.size()]
				member.gain_experience(member.personnage_niveau * member.personnage_niveau * 100)
				print("Debug: Level up de %s" % member.nom)
				
		3: # Level up tous les membres
			for member in guild_manager.guild_members:
				member.gain_experience(member.personnage_niveau * member.personnage_niveau * 100)
			print("Debug: Level up de tous les membres")
			
		4: # Ajouter 1000 or à la guilde
			if guild_manager.guild:
				guild_manager.guild.add_gold(1000)
				print("Debug: +1000 or à la guilde")
				
		5: # Donner équipement aux membres
			for member in guild_manager.guild_members:
				# TODO: Avec le nouveau système, donner des objets spécifiques
				# member.personnage_equipement += 10
				pass
			print("Debug: +10 équipement à tous les membres")
			
		6: # Forcer mise à jour serveur
			var server_version = ServerVersion
			if server_version:
				server_version._check_version_update()
				print("Debug: Vérification de mise à jour serveur forcée")
				
		7: # Compléter un donjon (succès)
			if guild_manager.guild:
				guild_manager.guild.gain_xp(100, "Debug: Donjon complété")
				print("Debug: Simulation de donjon complété (+100 XP)")
		
		8: # Déclencher événement test
			var event_manager = EventManager
			if event_manager:
				event_manager.force_event("member_dispute")
				print("Debug: Événement 'dispute entre membres' forcé")
		
		9: # Afficher stats événements
			var event_manager = EventManager
			if event_manager:
				var stats = event_manager.get_event_stats()
				print("=== STATS ÉVÉNEMENTS ===")
				print("Événements aujourd'hui: %d" % stats.events_today)
				print("Événement en attente: %s" % ("Oui" if stats.pending_event else "Non"))
				print("Chaînes actives: %s" % str(stats.active_chains))
				print("Total événements: %d" % stats.total_events)
				print("========================")
				
		10: # Test notification INFO
			var notification_manager = NotificationManager
			if notification_manager:
				notification_manager.show_info("Ceci est un test de notification info", "Test Info")
				print("Debug: Test notification INFO")
				
		11: # Test notification SUCCESS
			var notification_manager = NotificationManager
			if notification_manager:
				notification_manager.show_success("Ceci est un test de notification succès", "Test Success")
				print("Debug: Test notification SUCCESS")
				
		12: # Test notification WARNING
			var notification_manager = NotificationManager
			if notification_manager:
				notification_manager.show_warning("Ceci est un test de notification avertissement", "Test Warning")
				print("Debug: Test notification WARNING")
				
		13: # Test notification ERROR
			var notification_manager = NotificationManager
			if notification_manager:
				notification_manager.show_error("Ceci est un test de notification erreur", "Test Error")
				print("Debug: Test notification ERROR")
				
		14: # Test notification ACHIEVEMENT
			var notification_manager = NotificationManager
			if notification_manager:
				notification_manager.show_achievement("Ceci est un test de notification achievement", "Test Achievement")
				print("Debug: Test notification ACHIEVEMENT")
	
	# Rafraîchir la fenêtre guilde si elle est ouverte
	var guilde_inst: Control = window_manager._get_existing_instance("guilde")
	if guilde_inst and guilde_inst.visible:
		guilde_inst._refresh_member_list()
		guilde_inst._update_guild_info()

func _process(delta: float) -> void:
	# Mettre à jour les donjons actifs via l'ActivityManager
	var activity_manager = ActivityManager
	if activity_manager:
		activity_manager.update_dungeons(delta)

func _input(event: InputEvent) -> void:
	# Raccourcis clavier pour ouvrir les fenêtres
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_P:  # P pour Personnage
				if Input.is_key_pressed(KEY_CTRL):
					menu_bar._on_personnage_pressed()
			KEY_G:  # G pour Guilde
				if Input.is_key_pressed(KEY_CTRL):
					menu_bar._on_guilde_pressed()
			KEY_M:  # M pour Monde
				if Input.is_key_pressed(KEY_CTRL):
					menu_bar._on_monde_pressed()
			KEY_O:  # O pour Organisation
				if Input.is_key_pressed(KEY_CTRL):
					menu_bar._on_organisation_groupe_pressed()
			KEY_SPACE:  # Espace pour pause
				var game_time_node = GameTime
				if game_time_node:
					game_time_node.toggle_pause()
			KEY_ESCAPE:  # Échap pour fermer la fenêtre active
				window_manager.close_active_window()
			KEY_F1:  # F1 pour déclencher un événement test
				print("F1 pressed - Tentative de déclencher un événement")
				_on_debug_menu_pressed(8)  # ID 8 = Déclencher événement test
			KEY_F2:  # F2 pour afficher les stats
				print("F2 pressed - Affichage des stats")
				_on_debug_menu_pressed(9)  # ID 9 = Afficher stats événements
			KEY_F5:  # F5 pour sauvegarder
				SaveManager.save_game()

func _connect_event_system():
	print("Main: Connexion du système d'événements")
	var event_manager = EventManager
	if event_manager:
		event_manager.event_triggered.connect(_on_event_triggered)
		print("Main: Signal event_triggered connecté")
	else:
		print("Main: ERREUR - EventManager non trouvé!")

func _on_event_triggered(event: RandomEventResource):
	print("Main: Signal event_triggered reçu pour: %s" % event.title)
	show_event_popup(event)

func show_event_popup(event: RandomEventResource):
	print("Main: show_event_popup appelé pour l'événement: %s" % event.title)
	
	if event_popup:
		print("Main: Nettoyage de l'ancienne popup")
		event_popup.queue_free()
	
	print("Main: Chargement de la scène EventPopup.tscn")
	var event_popup_scene = load("res://scenes/EventPopup.tscn")
	event_popup = event_popup_scene.instantiate()
	add_child(event_popup)
	
	print("Main: Popup ajoutée comme enfant")
	
	# Connecter les signaux
	event_popup.choice_selected.connect(_on_event_choice_selected)
	event_popup.popup_closed.connect(_on_event_popup_closed)
	
	print("Main: Signaux connectés, affichage de l'événement")
	# Afficher l'événement
	event_popup.show_event(event)

func _on_event_choice_selected(choice: EventChoiceResource):
	var event_manager = EventManager
	if event_manager and event_manager.pending_event:
		event_manager.resolve_event(event_manager.pending_event, choice)
	
	event_popup = null

func _on_event_popup_closed():
	event_popup = null

func _setup_player_systems():
	"""Configure les systèmes spécifiques au joueur"""
	# Attendre que le GuildManager soit prêt
	await get_tree().process_frame
	await get_tree().process_frame
	
	var guild_manager = GuildManager
	if not guild_manager:
		print("ERREUR: GuildManager non trouvé pour _setup_player_systems")
		return
	
	# Créer le panneau de contrôle du joueur
	_setup_player_control_panel()
	
	# Créer le gestionnaire de fast-forward
	# _setup_fast_forward_manager()  # Supprimé - système simplifié
	
	# Configurer les connexions
	_connect_player_systems()

func _setup_player_control_panel():
	"""Configure le panneau de contrôle du joueur"""
	var control_panel_scene = load("res://scenes/PlayerControlPanel.tscn")
	player_control_panel = control_panel_scene.instantiate()
	add_child(player_control_panel)
	
	# Ancrage top-left pour supporter toutes les résolutions
	player_control_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	player_control_panel.offset_left = 20
	player_control_panel.offset_top = 20
	player_control_panel.offset_right = 20 + player_control_panel.custom_minimum_size.x
	player_control_panel.offset_bottom = 20 + player_control_panel.custom_minimum_size.y
	player_control_panel.z_index = 15  # Au-dessus des autres éléments

	# Configurer avec le personnage du joueur
	if GuildManager and GuildManager.get_player_character():
		player_control_panel.set_player_character(GuildManager.get_player_character())

# func _setup_fast_forward_manager():  # Supprimé - système simplifié

func _connect_player_systems():
	"""Connecte les signaux des systèmes joueur"""
	if player_control_panel:
		player_control_panel.disconnect_requested.connect(_on_player_disconnect_requested)
		player_control_panel.activity_changed.connect(_on_player_activity_changed)
	
	# Connecter le signal de déconnexion forcée du joueur
	var guild_manager = GuildManager
	if guild_manager and guild_manager.get_player_character():
		player_character = guild_manager.get_player_character()
		player_character.forced_disconnect_requested.connect(_on_player_forced_disconnect)
	
	print("Systèmes joueur configurés")

func _on_player_disconnect_requested(return_hour: int, return_minute: int):
	"""Gère la demande de déconnexion manuelle du joueur"""
	print("Joueur demande déconnexion manuelle")
	# TODO: Implémenter déconnexion manuelle simple si nécessaire
	print("Déconnexion manuelle temporairement désactivée")

func _on_player_forced_disconnect(recovery_hours: int):
	"""Gère la déconnexion forcée du joueur (épuisement)"""
	print("Joueur déconnecté automatiquement - repos forcé de %d heures" % recovery_hours)
	execute_forced_rest()

func execute_forced_rest():
	"""Execute le repos forcé de 12h avec système robuste"""
	print("Démarrage du repos forcé - BLOCAGE TOTAL")
	
	# 1. PAUSE GLOBALE - Bloque tout sauf les dialogs avec PROCESS_MODE_ALWAYS
	get_tree().paused = true
	
	# 2. Créer dialog simple et robuste
	var dialog = AcceptDialog.new()
	dialog.title = "ÉPUISEMENT TOTAL"
	dialog.dialog_text = "Votre personnage est complètement épuisé !\n\nUn repos de 12 heures est OBLIGATOIRE.\n\nPendant ce temps :\n• Récupération de 100% d'énergie\n• Aucune action possible\n• Le temps passera à vitesse maximale"
	dialog.get_ok_button().text = "COMMENCER LE REPOS"
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS  # Reste actif pendant la pause
	dialog.exclusive = true  # Modal exclusif
	
	get_tree().root.add_child(dialog)
	dialog.popup_centered(Vector2(600, 400))
	
	# 3. Attendre la confirmation de l'utilisateur
	await dialog.confirmed
	print("Utilisateur a confirmé le repos - démarrage fast-forward")
	
	# 4. REPRENDRE LE JEU pour permettre le fast-forward
	get_tree().paused = false
	print("Jeu repris pour le fast-forward")
	
	# 5. Fast-forward direct sans FastForwardManager
	var game_time = GameTime
	if game_time:
		game_time.set_time_speed(2400.0)  # Vitesse maximum
		print("Vitesse mise au maximum (2400x)")
	
	# 6. Calculer combien de temps réel pour 12h de jeu
	var real_time_for_12h = (12.0 * 3600.0) / 2400.0  # 12h de jeu / vitesse = temps réel en secondes
	print("Fast-forward de 12h en %.1f secondes réelles" % real_time_for_12h)
	
	# 7. Timer pour attendre la fin du fast-forward
	var timer = Timer.new()
	timer.wait_time = real_time_for_12h
	timer.one_shot = true
	timer.process_mode = Node.PROCESS_MODE_ALWAYS  # Continue pendant la pause
	add_child(timer)
	timer.start()
	
	# 8. Attendre la fin du fast-forward
	await timer.timeout
	print("Fast-forward terminé - restauration")
	
	# 9. Restaurer l'énergie directement
	if player_character:
		player_character.player_energy_pool = player_character.max_energy_pool
		print("Énergie restaurée : %.1f/%.1f" % [player_character.player_energy_pool, player_character.max_energy_pool])
		
		# Reconnecter le joueur
		player_character.reconnect_player()
	
	# 10. Retour à la normale
	if game_time:
		game_time.set_time_speed(60.0)  # Vitesse normale
	
	# 11. Nettoyer
	dialog.queue_free()
	timer.queue_free()
	
	print("Repos forcé terminé - retour à la normale")

func _on_player_activity_changed(activity_type: String):
	"""Gère le changement d'activité du joueur"""
	print("Joueur a changé d'activité: %s" % activity_type)
	
	# Actualiser le panneau de contrôle
	if player_control_panel:
		player_control_panel.refresh_display()
