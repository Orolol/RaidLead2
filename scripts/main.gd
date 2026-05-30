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
var _pending_event_queue: Array = []  # événements en attente derrière un autre popup modal
var _loot_dialog_active: bool = false

# Système joueur
var player_control_panel: PlayerControlPanelScript = null
var player_character = null  # Référence au personnage joueur
# var fast_forward_manager: Node = null  # Supprimé - système simplifié

func _ready():
	# Applique le thème global cohérent à toute l'UI (fenêtres, popups, notifications)
	get_tree().root.theme = UITheme.build()

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
	_connect_loot_conflict_system()
	_connect_national_systems()
	_connect_esport_systems()
	_connect_culture_systems()
	_setup_player_systems()

	# Charger la sauvegarde si elle existe (après que tous les systèmes soient prêts)
	get_tree().create_timer(0.2).timeout.connect(func():
		if SaveManager.has_save():
			SaveManager.load_game()
	)
	


func _setup_background():
	var bg_texture: Texture2D = AssetLoader.get_background()
	if bg_texture:
		var background = TextureRect.new()
		background.texture = bg_texture
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background.modulate = Color(0.6, 0.6, 0.6)
		add_child(background)
		move_child(background, 0)
	else:
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
	menu_bar.national_button_pressed.connect(_on_national_button_pressed)
	menu_bar.esport_button_pressed.connect(_on_esport_button_pressed)
	menu_bar.cohesion_button_pressed.connect(_on_cohesion_button_pressed)
	menu_bar.conseils_button_pressed.connect(_on_conseils_button_pressed)

func _on_personnage_button_pressed():
	window_manager.show_window("personnage")

func _on_guilde_button_pressed():
	window_manager.show_window("guilde")

func _on_monde_button_pressed():
	window_manager.show_window("monde")

func _on_organisation_button_pressed():
	window_manager.show_window("organisation")

func _on_national_button_pressed():
	window_manager.show_window("national")

func _on_esport_button_pressed():
	window_manager.show_window("esport")

func _on_cohesion_button_pressed():
	window_manager.show_window("cohesion")

func _on_conseils_button_pressed():
	window_manager.show_window("conseils")

func _register_windows():
	window_manager.register_window("personnage", "res://scenes/Fenetre_Personnage.tscn")
	window_manager.register_window("guilde", "res://scenes/Fenetre_Guilde.tscn")
	window_manager.register_window("monde", "res://scenes/Fenetre_Monde.tscn")
	window_manager.register_window("organisation", "res://scenes/Fenetre_OrganisationGroupe.tscn")
	window_manager.register_window("national", "res://scenes/Fenetre_National.tscn")
	window_manager.register_window("esport", "res://scenes/Fenetre_Esport.tscn")
	window_manager.register_window("cohesion", "res://scenes/Fenetre_Social.tscn")
	window_manager.register_window("conseils", "res://scenes/Fenetre_Conseils.tscn")

func _connect_window_signals():
	# Écouter l'ouverture des fenêtres pour connecter leurs signaux
	window_manager.window_opened.connect(_on_window_opened)

	# Surligner le bouton de menu de la fenêtre active
	window_manager.window_focused.connect(func(wname: String): menu_bar.set_active_window(wname))

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
					menu_bar._on_organisation_pressed()
			KEY_N:  # N pour National
				if Input.is_key_pressed(KEY_CTRL):
					menu_bar._on_national_pressed()
			KEY_E:  # E pour Esport
				if Input.is_key_pressed(KEY_CTRL):
					menu_bar._on_esport_pressed()
			KEY_K:  # K pour Cohésion
				if Input.is_key_pressed(KEY_CTRL):
					menu_bar._on_cohesion_pressed()
			KEY_A:  # A pour Conseils (conseiller / aide)
				if Input.is_key_pressed(KEY_CTRL):
					menu_bar._on_conseils_pressed()
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
	
	# File d'attente : ne pas empiler sur un autre popup modal (loot, drama, ou un événement déjà affiché)
	if event_popup != null or _drama_popup_active or _loot_dialog_active:
		_pending_event_queue.append(event)
		return
	
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
	_show_next_pending_event.call_deferred()

func _on_event_popup_closed():
	event_popup = null
	_show_next_pending_event.call_deferred()

func _show_next_pending_event() -> void:
	"""Affiche le prochain événement en file, si plus aucun popup modal n'est ouvert."""
	if _pending_event_queue.is_empty():
		return
	if event_popup != null or _drama_popup_active or _loot_dialog_active:
		return
	show_event_popup(_pending_event_queue.pop_front())

func _connect_loot_conflict_system():
	var gm: Node = GuildManager
	if gm:
		gm.loot_conflict_occurred.connect(_on_loot_conflict)

func _on_loot_conflict(conflict: Dictionary):
	"""Affiche un popup pour résoudre un conflit de loot"""
	var item: Item = conflict.get("item", null)
	var candidates: Array = conflict.get("candidates", [])
	var dungeon_name: String = conflict.get("dungeon_name", "")
	var boss_name: String = conflict.get("boss_name", "")

	if not item or candidates.is_empty():
		return

	# Pause le jeu pour la décision
	var game_time_node: Node = GameTime
	var was_paused: bool = false
	if game_time_node:
		was_paused = game_time_node.is_paused
		if not was_paused:
			game_time_node.toggle_pause()

	# Créer le popup de sélection
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = "Conflit de Loot!"
	dialog.exclusive = true
	dialog.get_ok_button().hide()  # On utilise nos propres boutons

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	dialog.add_child(vbox)

	# Infos sur l'item
	var item_label: Label = Label.new()
	item_label.text = "%s (iLvl %d) - %s" % [item.name, item.ilvl, item.get_rarity_name()]
	item_label.modulate = item.get_rarity_color()
	item_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(item_label)

	var stats_label: Label = Label.new()
	stats_label.text = item.get_stat_summary(true)
	stats_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(stats_label)

	var context_label: Label = Label.new()
	context_label.text = "Drop de %s dans %s" % [boss_name, dungeon_name]
	context_label.modulate = Color(0.7, 0.7, 0.7)
	context_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(context_label)

	vbox.add_child(HSeparator.new())

	var instruction_label: Label = Label.new()
	instruction_label.text = "Choisissez qui reçoit l'objet :"
	instruction_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(instruction_label)

	# Boutons pour chaque candidat
	for candidate in candidates:
		var btn: Button = Button.new()
		var current_item: Item = candidate.equipment.get_item_in_slot(item.slot) if candidate.equipment else null
		var current_ilvl_text: String = " (actuel: iLvl %d)" % current_item.ilvl if current_item else " (slot vide)"
		btn.text = "%s - %s Niv.%d%s" % [candidate.nom, candidate.personnage_classe, candidate.personnage_niveau, current_ilvl_text]
		btn.custom_minimum_size = Vector2(400, 35)
		var member_ref: SimulatedPlayer = candidate
		btn.pressed.connect(func():
			_resolve_loot_conflict(item, member_ref, candidates, dungeon_name, boss_name)
			dialog.queue_free()
			# Reprendre le jeu
			if game_time_node and not was_paused:
				game_time_node.toggle_pause()
			_loot_dialog_active = false
			_show_next_pending_event.call_deferred()
		)
		vbox.add_child(btn)

	_loot_dialog_active = true
	add_child(dialog)
	dialog.popup_centered(Vector2(500, 300))

func _resolve_loot_conflict(item: Item, winner: SimulatedPlayer, candidates: Array, dungeon_name: String, boss_name: String):
	"""Résout un conflit de loot en attribuant l'item au gagnant"""
	# Équiper l'item au gagnant
	winner.try_auto_equip(item)

	# Ajouter à l'historique
	GuildManager.add_loot_entry(item, winner.nom, dungeon_name, boss_name)

	# Réduire la satisfaction des perdants
	for candidate in candidates:
		if candidate != winner:
			candidate.mood = max(0, candidate.mood - 5)
			candidate.trigger_loot_conflict()

	# Notification
	var notification_manager: Node = get_node_or_null("/root/NotificationManager")
	if notification_manager:
		notification_manager.show_info(
			"%s a reçu %s" % [winner.nom, item.name],
			"Loot attribué"
		)

# === SYSTÈMES NATIONAUX (Milestone 3 : médias, sponsors, dramas) ===

var _drama_popup_active: bool = false
var _pending_dramas: Array = []

func _connect_national_systems() -> void:
	"""Connecte les signaux des systèmes médias, sponsors et dramas (Phase Nationale)."""
	var media: Node = MediaManager
	if media:
		media.media_incident.connect(_on_media_incident)
		media.streamer_started.connect(_on_streamer_started)

	var sponsors: Node = SponsorshipManager
	if sponsors:
		sponsors.sponsor_acquired.connect(_on_sponsor_acquired)
		sponsors.sponsor_lost.connect(_on_sponsor_lost)

	var dramas: Node = DramaManager
	if dramas:
		dramas.drama_occurred.connect(_on_drama_occurred)
		dramas.drama_response_needed.connect(_on_drama_response_needed)
		dramas.drama_resolved.connect(_on_drama_resolved)

func _on_media_incident(_member_name: String, _incident_type: String, description: String) -> void:
	if chat_panel:
		chat_panel.add_message("[Média] %s" % description, "warning")

func _on_streamer_started(member_name: String) -> void:
	if chat_panel:
		chat_panel.add_message("[Stream] %s commence à streamer !" % member_name, "activity")
	if NotificationManager:
		NotificationManager.show_info("%s est désormais streamer" % member_name, "Nouveau streamer")

func _on_sponsor_acquired(sponsor) -> void:
	if NotificationManager:
		NotificationManager.show_success(
			"Contrat signé avec %s (+%d or/sem.)" % [sponsor.sponsor_name, sponsor.weekly_revenue],
			"Sponsor")
	if chat_panel:
		chat_panel.add_message("[Sponsor] Nouveau contrat : %s" % sponsor.sponsor_name, "loot")

func _on_sponsor_lost(sponsor, reason: String) -> void:
	if NotificationManager:
		NotificationManager.show_warning("%s : %s" % [sponsor.sponsor_name, reason], "Sponsor perdu")

func _on_drama_occurred(drama) -> void:
	if chat_panel:
		chat_panel.add_message("[Drama] %s" % drama.description, "error")
	if NotificationManager:
		NotificationManager.show_warning(
			drama.description,
			"%s (%s)" % [drama.get_type_name(), drama.get_severity_name()])

func _on_drama_resolved(drama) -> void:
	if chat_panel:
		chat_panel.add_message("[Drama] Crise résolue : %s" % drama.get_type_name(), "info")

func _on_drama_response_needed(drama) -> void:
	# File d'attente pour éviter les popups simultanées
	if _drama_popup_active:
		_pending_dramas.append(drama)
		return
	_show_drama_popup(drama)

func _show_drama_popup(drama) -> void:
	"""Affiche un popup pour résoudre un drama, avec mise en pause du jeu."""
	_drama_popup_active = true

	var game_time_node: Node = GameTime
	var was_paused: bool = false
	if game_time_node:
		was_paused = game_time_node.is_paused
		if not was_paused:
			game_time_node.toggle_pause()

	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = "Drama : %s" % drama.get_type_name()
	dialog.exclusive = true
	dialog.get_ok_button().hide()
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	dialog.add_child(vbox)

	var severity_label: Label = Label.new()
	severity_label.text = "Gravité : %s" % drama.get_severity_name()
	severity_label.add_theme_font_size_override("font_size", 16)
	severity_label.modulate = Color(0.9, 0.3, 0.3) if drama.severity >= 3 else Color(0.9, 0.7, 0.2)
	vbox.add_child(severity_label)

	var desc_label: Label = Label.new()
	desc_label.text = drama.description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(440, 0)
	vbox.add_child(desc_label)

	vbox.add_child(HSeparator.new())

	var instruction: Label = Label.new()
	instruction.text = "Comment réagissez-vous ?"
	instruction.add_theme_font_size_override("font_size", 14)
	vbox.add_child(instruction)

	var options: Array = [
		{"id": "silence", "label": "Garder le silence", "desc": "Résolution lente (4 sem.), aucun effet immédiat"},
		{"id": "communication", "label": "Communication de crise", "desc": "Résolution en 2 sem., +2 réputation"},
		{"id": "sanctions", "label": "Sanctions disciplinaires", "desc": "Rapide (1 sem.), -15 moral, +5 réputation"},
		{"id": "exclusion", "label": "Exclure le membre fautif", "desc": "Immédiat, -25 moral, +10 réputation"},
	]
	for opt in options:
		var btn: Button = Button.new()
		btn.text = opt.label
		btn.custom_minimum_size = Vector2(440, 34)
		var resolution: String = opt.id
		btn.pressed.connect(func():
			DramaManager.resolve_drama(drama, resolution)
			dialog.queue_free()
			if game_time_node and not was_paused:
				game_time_node.toggle_pause()
			_drama_popup_active = false
			_process_next_drama()
			_show_next_pending_event.call_deferred()
		)
		vbox.add_child(btn)

		var desc: Label = Label.new()
		desc.text = opt.desc
		desc.add_theme_font_size_override("font_size", 11)
		desc.modulate = Color(0.65, 0.67, 0.72)
		vbox.add_child(desc)

	add_child(dialog)
	dialog.popup_centered(Vector2(540, 380))

func _process_next_drama() -> void:
	"""Affiche le prochain drama en attente, s'il en reste."""
	while not _pending_dramas.is_empty():
		var next = _pending_dramas.pop_front()
		if next and next.active:
			_show_drama_popup(next)
			return

# === SYSTÈMES ESPORT (Milestone 4 : staff, tournois, transferts, legacy) ===

func _connect_esport_systems() -> void:
	"""Connecte les notifications des systèmes de la phase Esport."""
	if TournamentManager:
		TournamentManager.tournament_completed.connect(_on_tournament_completed)
	if StaffManager:
		StaffManager.staff_hired.connect(_on_staff_hired)
	if TransferManager:
		TransferManager.transfer_completed.connect(_on_transfer_completed)
		TransferManager.transfer_window_opened.connect(_on_transfer_window_opened)
	if LegacyManager:
		LegacyManager.title_unlocked.connect(_on_legacy_title_unlocked)

func _on_tournament_completed(_tournament, _stage_reached: int, is_champion: bool, results: Dictionary) -> void:
	if chat_panel:
		if is_champion:
			chat_panel.add_message("[Esport] Victoire au %s ! (+%d or)" % [results.get("tournament", ""), results.get("gold", 0)], "loot")
		else:
			chat_panel.add_message("[Esport] Éliminé : %s (tour %d/%d)" % [results.get("tournament", ""), results.get("stage_reached", 0), results.get("rounds", 0)], "info")
	if NotificationManager:
		if is_champion:
			NotificationManager.show_achievement("Champion : %s" % results.get("tournament", ""), "Tournoi")
		else:
			NotificationManager.show_info("Tournoi terminé (tour %d/%d)" % [results.get("stage_reached", 0), results.get("rounds", 0)], "Esport")

func _on_staff_hired(staff) -> void:
	if chat_panel:
		chat_panel.add_message("[Staff] %s rejoint le staff (%s)" % [staff.staff_name, staff.get_role_name()], "activity")

func _on_transfer_completed(player) -> void:
	if NotificationManager:
		NotificationManager.show_success("%s rejoint la guilde (transfert international)" % player.nom, "Transfert")
	if chat_panel:
		chat_panel.add_message("[Transfert] %s arrive de %s" % [player.nom, player.get_meta("region", "?")], "loot")

func _on_transfer_window_opened() -> void:
	if NotificationManager:
		NotificationManager.show_info("La fenêtre de transfert internationale est ouverte", "Transferts")

func _on_legacy_title_unlocked(title) -> void:
	if chat_panel:
		chat_panel.add_message("[Legacy] Nouveau titre débloqué : %s" % title, "loot")

# === SYSTÈME DE COHÉSION (Milestone 5 : moral, social, team-building, traditions, conflits) ===

func _connect_culture_systems() -> void:
	"""Connecte les notifications du système de cohésion de guilde."""
	if GuildCultureManager:
		GuildCultureManager.tension_detected.connect(_on_tension_detected)
		GuildCultureManager.team_building_done.connect(_on_team_building_done)
		GuildCultureManager.tradition_established.connect(_on_tradition_established)

func _on_tension_detected(player1_name: String, player2_name: String, reason: String) -> void:
	if chat_panel:
		chat_panel.add_message("[Cohésion] Tension entre %s et %s (%s)" % [player1_name, player2_name, reason], "warning")

func _on_team_building_done(activity_name: String, _morale_gain: float) -> void:
	if chat_panel:
		chat_panel.add_message("[Cohésion] Team-building : %s" % activity_name, "activity")

func _on_tradition_established(tradition_name: String) -> void:
	if chat_panel:
		chat_panel.add_message("[Cohésion] Nouvelle tradition établie : %s" % tradition_name, "loot")

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
