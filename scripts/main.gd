extends Control

const MenuBarScript = preload("res://scripts/ui/components/menu_bar.gd")
const WindowManagerScript = preload("res://scripts/managers/window_manager.gd")
const RandomEventResource = preload("res://scripts/resources/random_event.gd")
const EventChoiceResource = preload("res://scripts/resources/event_choice.gd")
const EventPopupWindow = preload("res://scripts/ui/windows/event_popup.gd")
const PlayerControlPanelScript = preload("res://scripts/ui/components/player_control_panel.gd")
# const FastForwardDialog = preload("res://scripts/ui/windows/fast_forward_dialog.gd")  # Supprimé - système simplifié
const NO_SAVE_AUTOLOAD_ARG: String = "--no-save-autoload"

var window_manager: Node
var menu_bar: Control

var chat_panel: ChatPanel = null
var event_popup: EventPopupWindow = null
var _pending_event_queue: Array = []  # événements en attente derrière un autre popup modal
var _loot_dialog_active: bool = false

# Système joueur
var player_control_panel: PlayerControlPanelScript = null
var player_character = null  # Référence au personnage joueur
var is_in_forced_rest: bool = false  # Verrou pendant un repos (forcé ou volontaire)
var _auto_paused_for_idle: bool = false  # Le temps a été mis en pause car le joueur attend un ordre
var _activity_prompt: CanvasLayer = null  # Overlay thémé de choix d'activité (pause-si-oisif)
# var fast_forward_manager: Node = null  # Supprimé - système simplifié

func _ready() -> void:
	# Applique le thème global cohérent à toute l'UI (fenêtres, popups, notifications)
	get_tree().root.theme = UITheme.build()

	# Les nœuds existent déjà dans la scène
	menu_bar = $VBoxContainer/menu_bar
	window_manager = $VBoxContainer/window_manager
	
	_setup_background()
	_setup_time_display()
	_setup_chat_panel()
	_connect_phase_notifications()
	if _is_debug_ui_enabled():
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
		if _should_auto_load_save() and SaveManager.has_save():
			SaveManager.load_game()
	)
	


func _setup_background() -> void:
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

func _setup_time_display() -> void:
	var time_display_scene = load("res://scenes/TimeDisplay.tscn")
	var time_display = time_display_scene.instantiate()
	add_child(time_display)
	# Ancrage top-center pour supporter toutes les résolutions
	time_display.set_anchors_preset(Control.PRESET_CENTER_TOP)
	time_display.offset_left = -time_display.custom_minimum_size.x / 2
	time_display.offset_top = 10
	time_display.offset_right = time_display.custom_minimum_size.x / 2
	time_display.offset_bottom = 10 + time_display.custom_minimum_size.y

func _setup_chat_panel() -> void:
	var chat_scene = load("res://scenes/ChatPanel.tscn")
	chat_panel = chat_scene.instantiate()
	add_child(chat_panel)
	
	# Ancrage bottom-right pour supporter toutes les résolutions
	chat_panel.custom_minimum_size = Vector2(400, 230)
	chat_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	chat_panel.offset_left = -420
	# Remonté de 70px pour dégager la barre de menu (80px de haut) qui le chevauchait.
	chat_panel.offset_top = -320
	chat_panel.offset_right = -20
	chat_panel.offset_bottom = -90
	chat_panel.z_index = 10  # Au-dessus du background mais sous les fenêtres

func _connect_phase_notifications() -> void:
	if PhaseManager and PhaseManager.has_signal("phase_changed") and not PhaseManager.phase_changed.is_connected(_on_phase_changed_for_chat):
		PhaseManager.phase_changed.connect(_on_phase_changed_for_chat)

func _on_phase_changed_for_chat(new_phase: Variant, _old_phase: Variant) -> void:
	if not chat_panel or not chat_panel.has_method("add_phase_notification"):
		return
	var phase_name: String = str(new_phase)
	if PhaseManager and PhaseManager.has_method("get_phase_name"):
		phase_name = PhaseManager.get_phase_name(new_phase)
	chat_panel.add_phase_notification(phase_name)

func _setup_debug_menu() -> void:
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

func _is_debug_ui_enabled() -> bool:
	return OS.is_debug_build()

func _should_auto_load_save() -> bool:
	var args: PackedStringArray = OS.get_cmdline_args()
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	return not args.has(NO_SAVE_AUTOLOAD_ARG) and not user_args.has(NO_SAVE_AUTOLOAD_ARG)

func _connect_menu_signals() -> void:
	menu_bar.personnage_button_pressed.connect(_on_personnage_button_pressed)
	menu_bar.guilde_button_pressed.connect(_on_guilde_button_pressed)
	menu_bar.monde_button_pressed.connect(_on_monde_button_pressed)
	menu_bar.organisation_button_pressed.connect(_on_organisation_button_pressed)
	menu_bar.national_button_pressed.connect(_on_national_button_pressed)
	menu_bar.esport_button_pressed.connect(_on_esport_button_pressed)
	menu_bar.cohesion_button_pressed.connect(_on_cohesion_button_pressed)
	menu_bar.conseils_button_pressed.connect(_on_conseils_button_pressed)

func _on_personnage_button_pressed() -> void:
	window_manager.show_window("personnage")

func _on_guilde_button_pressed() -> void:
	window_manager.show_window("guilde")

func _on_monde_button_pressed() -> void:
	window_manager.show_window("monde")

func _on_organisation_button_pressed() -> void:
	window_manager.show_window("organisation")

func _on_national_button_pressed() -> void:
	window_manager.show_window("national")

func _on_esport_button_pressed() -> void:
	window_manager.show_window("esport")

func _on_cohesion_button_pressed() -> void:
	window_manager.show_window("cohesion")

func _on_conseils_button_pressed() -> void:
	window_manager.show_window("conseils")

func _register_windows() -> void:
	window_manager.register_window("personnage", "res://scenes/Fenetre_Personnage.tscn")
	window_manager.register_window("guilde", "res://scenes/Fenetre_Guilde.tscn")
	window_manager.register_window("monde", "res://scenes/Fenetre_Monde.tscn")
	window_manager.register_window("organisation", "res://scenes/Fenetre_OrganisationGroupe.tscn")
	window_manager.register_window("national", "res://scenes/Fenetre_National.tscn")
	window_manager.register_window("esport", "res://scenes/Fenetre_Esport.tscn")
	window_manager.register_window("cohesion", "res://scenes/Fenetre_Social.tscn")
	window_manager.register_window("conseils", "res://scenes/Fenetre_Conseils.tscn")

func _connect_window_signals() -> void:
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
	var instance: Control = window_manager.get_window_instance(window_name)
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
		var guilde_inst: Control = window_manager.get_window_instance("guilde")
		if guilde_inst:
			guilde_inst._refresh_member_list()
		var org_inst: Control = window_manager.get_window_instance("organisation")
		if org_inst:
			org_inst.set_guild_members(guild_manager_node.guild_members)

func _on_debug_menu_pressed(id: int) -> void:
	GameLog.d("Debug menu pressed - Option ID: %d" % id)
	var guild_manager = GuildManager
	if not guild_manager:
		GameLog.d("ERREUR: GuildManager non trouvé")
		return
		
	match id:
		0: # Ajouter 100 XP à la guilde
			if guild_manager.guild:
				guild_manager.guild.gain_xp(100, "Debug: +100 XP")
				GameLog.d("Debug: +100 XP à la guilde")
				
		1: # Ajouter 1000 XP à la guilde
			if guild_manager.guild:
				guild_manager.guild.gain_xp(1000, "Debug: +1000 XP")
				GameLog.d("Debug: +1000 XP à la guilde")
				
		2: # Level up un membre aléatoire
			if guild_manager.guild_members.size() > 0:
				var member = guild_manager.guild_members[randi() % guild_manager.guild_members.size()]
				member.gain_experience(member.personnage_niveau * member.personnage_niveau * 100)
				GameLog.d("Debug: Level up de %s" % member.nom)
				
		3: # Level up tous les membres
			for member in guild_manager.guild_members:
				member.gain_experience(member.personnage_niveau * member.personnage_niveau * 100)
			GameLog.d("Debug: Level up de tous les membres")
			
		4: # Ajouter 1000 or à la guilde
			if guild_manager.guild:
				guild_manager.guild.add_gold(1000)
				GameLog.d("Debug: +1000 or à la guilde")
				
		5: # Donner équipement aux membres
			for member in guild_manager.guild_members:
				# TODO: Avec le nouveau système, donner des objets spécifiques
				# member.personnage_equipement += 10
				pass
			GameLog.d("Debug: +10 équipement à tous les membres")
			
		6: # Forcer mise à jour serveur
			var server_version = ServerVersion
			if server_version:
				server_version._check_version_update()
				GameLog.d("Debug: Vérification de mise à jour serveur forcée")
				
		7: # Compléter un donjon (succès)
			if guild_manager.guild:
				guild_manager.guild.gain_xp(100, "Debug: Donjon complété")
				GameLog.d("Debug: Simulation de donjon complété (+100 XP)")
		
		8: # Déclencher événement test
			var event_manager = EventManager
			if event_manager:
				event_manager.force_event("member_dispute")
				GameLog.d("Debug: Événement 'dispute entre membres' forcé")
		
		9: # Afficher stats événements
			var event_manager = EventManager
			if event_manager:
				var stats = event_manager.get_event_stats()
				GameLog.d("=== STATS ÉVÉNEMENTS ===")
				GameLog.d("Événements aujourd'hui: %d" % stats.events_today)
				GameLog.d("Événement en attente: %s" % ("Oui" if stats.pending_event else "Non"))
				GameLog.d("Chaînes actives: %s" % str(stats.active_chains))
				GameLog.d("Total événements: %d" % stats.total_events)
				GameLog.d("========================")
				
		10: # Test notification INFO
			var notification_manager = NotificationManager
			if notification_manager:
				notification_manager.show_info("Ceci est un test de notification info", "Test Info")
				GameLog.d("Debug: Test notification INFO")
				
		11: # Test notification SUCCESS
			var notification_manager = NotificationManager
			if notification_manager:
				notification_manager.show_success("Ceci est un test de notification succès", "Test Success")
				GameLog.d("Debug: Test notification SUCCESS")
				
		12: # Test notification WARNING
			var notification_manager = NotificationManager
			if notification_manager:
				notification_manager.show_warning("Ceci est un test de notification avertissement", "Test Warning")
				GameLog.d("Debug: Test notification WARNING")
				
		13: # Test notification ERROR
			var notification_manager = NotificationManager
			if notification_manager:
				notification_manager.show_error("Ceci est un test de notification erreur", "Test Error")
				GameLog.d("Debug: Test notification ERROR")
				
		14: # Test notification ACHIEVEMENT
			var notification_manager = NotificationManager
			if notification_manager:
				notification_manager.show_achievement("Ceci est un test de notification achievement", "Test Achievement")
				GameLog.d("Debug: Test notification ACHIEVEMENT")
	
	# Rafraîchir la fenêtre guilde si elle est ouverte
	var guilde_inst: Control = window_manager.get_window_instance("guilde")
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
				if _is_debug_ui_enabled():
					GameLog.d("F1 pressed - Tentative de déclencher un événement")
					_on_debug_menu_pressed(8)  # ID 8 = Déclencher événement test
			KEY_F2:  # F2 pour afficher les stats
				if _is_debug_ui_enabled():
					GameLog.d("F2 pressed - Affichage des stats")
					_on_debug_menu_pressed(9)  # ID 9 = Afficher stats événements
			KEY_F5:  # F5 pour sauvegarder
				SaveManager.save_game()

func _connect_event_system() -> void:
	GameLog.d("Main: Connexion du système d'événements")
	var event_manager = EventManager
	if event_manager:
		event_manager.event_triggered.connect(_on_event_triggered)
		GameLog.d("Main: Signal event_triggered connecté")
	else:
		GameLog.d("Main: ERREUR - EventManager non trouvé!")

func _on_event_triggered(event: RandomEventResource) -> void:
	GameLog.d("Main: Signal event_triggered reçu pour: %s" % event.title)
	show_event_popup(event)

func show_event_popup(event: RandomEventResource) -> void:
	GameLog.d("Main: show_event_popup appelé pour l'événement: %s" % event.title)
	
	# File d'attente : ne pas empiler sur un autre popup modal (loot, drama, ou un événement déjà affiché)
	if event_popup != null or _drama_popup_active or _loot_dialog_active:
		_pending_event_queue.append(event)
		return
	
	GameLog.d("Main: Chargement de la scène EventPopup.tscn")
	var event_popup_scene = load("res://scenes/EventPopup.tscn")
	event_popup = event_popup_scene.instantiate()
	add_child(event_popup)
	
	GameLog.d("Main: Popup ajoutée comme enfant")
	
	# Connecter les signaux
	event_popup.choice_selected.connect(_on_event_choice_selected)
	event_popup.popup_closed.connect(_on_event_popup_closed)
	
	GameLog.d("Main: Signaux connectés, affichage de l'événement")
	# Afficher l'événement
	event_popup.show_event(event)

func _on_event_choice_selected(choice: EventChoiceResource) -> void:
	var event_manager = EventManager
	if event_manager and event_manager.pending_event:
		event_manager.resolve_event(event_manager.pending_event, choice)
	
	event_popup = null
	_show_next_pending_event.call_deferred()

func _on_event_popup_closed() -> void:
	event_popup = null
	_show_next_pending_event.call_deferred()

func _show_next_pending_event() -> void:
	"""Affiche le prochain événement en file, si plus aucun popup modal n'est ouvert."""
	if _pending_event_queue.is_empty():
		return
	if event_popup != null or _drama_popup_active or _loot_dialog_active:
		return
	show_event_popup(_pending_event_queue.pop_front())

func _connect_loot_conflict_system() -> void:
	var gm: Node = GuildManager
	if gm:
		gm.loot_conflict_occurred.connect(_on_loot_conflict)

func _on_loot_conflict(conflict: Dictionary) -> void:
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

	# Fermeture sans choix (Échap/croix) : attribue par défaut au 1er candidat pour
	# éviter un soft-lock (jeu resté en pause + verrou _loot_dialog_active) (C14).
	dialog.close_requested.connect(func():
		if not _loot_dialog_active:
			return
		_resolve_loot_conflict(item, candidates[0], candidates, dungeon_name, boss_name)
		dialog.queue_free()
		if game_time_node and not was_paused:
			game_time_node.toggle_pause()
		_loot_dialog_active = false
		_show_next_pending_event.call_deferred()
	)

	_loot_dialog_active = true
	add_child(dialog)
	dialog.popup_centered(Vector2(500, 300))

func _resolve_loot_conflict(item: Item, winner: SimulatedPlayer, candidates: Array, dungeon_name: String, boss_name: String) -> void:
	"""Résout un conflit de loot en attribuant l'item au gagnant"""
	# Équiper l'item au gagnant (sinon dépose en banque de guilde plutôt que jeter)
	GuildManager.route_loot(winner, item)

	# Ajouter à l'historique
	GuildManager.add_loot_entry(item, winner.nom, dungeon_name, boss_name)

	# Réduire la satisfaction des perdants
	for candidate in candidates:
		if candidate != winner:
			candidate.mood = max(0, candidate.mood - 5)
			candidate.trigger_loot_conflict()

	# Notification
	var notification_manager: Node = NotificationManager
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

	# Fermeture sans choix (Échap/croix) : réponse « silence » par défaut pour éviter
	# un soft-lock (jeu resté en pause + verrou _drama_popup_active) (C14).
	dialog.close_requested.connect(func():
		if not _drama_popup_active:
			return
		DramaManager.resolve_drama(drama, "silence")
		dialog.queue_free()
		if game_time_node and not was_paused:
			game_time_node.toggle_pause()
		_drama_popup_active = false
		_process_next_drama()
		_show_next_pending_event.call_deferred()
	)

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

func _setup_player_systems() -> void:
	"""Configure les systèmes spécifiques au joueur"""
	# Attendre que le GuildManager soit prêt
	await get_tree().process_frame
	await get_tree().process_frame
	
	var guild_manager = GuildManager
	if not guild_manager:
		GameLog.d("ERREUR: GuildManager non trouvé pour _setup_player_systems")
		return
	
	# Créer le panneau de contrôle du joueur
	_setup_player_control_panel()
	
	# Créer le gestionnaire de fast-forward
	# _setup_fast_forward_manager()  # Supprimé - système simplifié
	
	# Configurer les connexions
	_connect_player_systems()

func _setup_player_control_panel() -> void:
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

func _connect_player_systems() -> void:
	"""Connecte les signaux des systèmes joueur"""
	if player_control_panel:
		player_control_panel.disconnect_requested.connect(_on_player_disconnect_requested)
		player_control_panel.activity_changed.connect(_on_player_activity_changed)
		if player_control_panel.has_signal("organize_requested"):
			player_control_panel.organize_requested.connect(_on_player_organize_requested)
	
	# Connecter le signal de déconnexion forcée du joueur
	var guild_manager = GuildManager
	if guild_manager and guild_manager.get_player_character():
		player_character = guild_manager.get_player_character()
		player_character.forced_disconnect_requested.connect(_on_player_forced_disconnect)
		# Suivi temps réel de l'état joueur (énergie/activité) pour la pause-si-oisif
		if player_character.has_signal("player_state_changed"):
			player_character.player_state_changed.connect(_on_player_state_changed)

	# Après un chargement de save, SaveManager reconstruit le personnage joueur :
	# il faut re-pointer l'UI vers ce nouvel objet (bug C1).
	if SaveManager and not SaveManager.load_completed.is_connected(_on_save_loaded):
		SaveManager.load_completed.connect(_on_save_loaded)

	if OS.is_debug_build():
		GameLog.d("Systèmes joueur configurés")

	# Au démarrage, si le joueur n'a aucune activité, on bloque le temps et on
	# demande un ordre (sauf en mode test sans save autoload).
	call_deferred("_on_player_state_changed")

func _on_save_loaded(success: bool) -> void:
	"""Une sauvegarde vient d'être chargée : re-synchronise l'UI joueur (C1)."""
	if success:
		_rewire_player_after_load()

func _rewire_player_after_load() -> void:
	"""Après un chargement, SaveManager remplace GuildManager.player_character par un
	NOUVEL objet. Sans re-wiring, main + le panneau de contrôle continueraient de
	piloter l'ancien objet (orphelin, hors guilde) pendant que la simulation/UI lit
	le nouveau → niveau/énergie/activité désynchronisés (bug C1)."""
	var gm: Node = GuildManager
	if not gm:
		return
	var new_pc = gm.get_player_character()
	if not new_pc or new_pc == player_character:
		return
	# Déconnecte les signaux de l'ancien objet joueur (orphelin)
	if player_character:
		if player_character.forced_disconnect_requested.is_connected(_on_player_forced_disconnect):
			player_character.forced_disconnect_requested.disconnect(_on_player_forced_disconnect)
		if player_character.has_signal("player_state_changed") and player_character.player_state_changed.is_connected(_on_player_state_changed):
			player_character.player_state_changed.disconnect(_on_player_state_changed)
	# Re-pointe vers le personnage chargé
	player_character = new_pc
	if player_control_panel:
		player_control_panel.set_player_character(new_pc)
	if not new_pc.forced_disconnect_requested.is_connected(_on_player_forced_disconnect):
		new_pc.forced_disconnect_requested.connect(_on_player_forced_disconnect)
	if new_pc.has_signal("player_state_changed") and not new_pc.player_state_changed.is_connected(_on_player_state_changed):
		new_pc.player_state_changed.connect(_on_player_state_changed)
	_on_player_state_changed()

func _on_player_disconnect_requested(_return_hour: int, _return_minute: int) -> void:
	"""Bouton « Se reposer » : repos volontaire avec reprise auto de l'activité."""
	_perform_rest(8, false)

func _on_player_forced_disconnect(recovery_hours: int) -> void:
	"""Déconnexion forcée du joueur (épuisement total)."""
	_perform_rest(recovery_hours, true)

func _perform_rest(recovery_hours: int, forced: bool) -> void:
	"""Repos unifié (forcé ou volontaire), NON bloquant : avance le temps
	instantanément, restaure l'énergie, reconnecte et reprend la dernière activité.
	Un toast informe le joueur — plus de modale « Épuisement total » qui interrompt
	la partie (C4)."""
	if is_in_forced_rest:
		return
	is_in_forced_rest = true

	# Fermer un éventuel prompt d'oisiveté (il est remplacé par le repos)
	if is_instance_valid(_activity_prompt):
		_activity_prompt.queue_free()
		_activity_prompt = null

	# Déconnecter le joueur s'il est encore en ligne (cas du repos volontaire)
	if player_character and player_character.is_online:
		player_character.disconnect_player("Repos")

	# Avance le temps de jeu instantanément
	if GameTime:
		GameTime.fast_forward_hours(recovery_hours)

	# Récupération complète + reconnexion
	if player_character:
		player_character.player_energy_pool = player_character.max_energy_pool
		player_character.energy = 100.0
		player_character.reconnect_player()

	is_in_forced_rest = false

	# Informe via un toast non bloquant (au lieu d'une modale)
	if NotificationManager:
		if forced:
			NotificationManager.show_warning(
				"Personnage épuisé : repos de %dh, énergie restaurée." % recovery_hours, "Repos")
		else:
			NotificationManager.show_info(
				"Repos de %dh : énergie restaurée." % recovery_hours, "Repos")

	# Reprise automatique de la dernière activité (sinon, demander un ordre)
	if player_character and not player_character.resume_last_activity():
		_auto_paused_for_idle = false
		_on_player_state_changed()
	else:
		_exit_idle_prompt()

	if player_control_panel:
		player_control_panel.refresh_display()

func _on_player_activity_changed(_activity_type: String) -> void:
	"""Le joueur a changé d'activité depuis le panneau : rafraîchit l'affichage."""
	if player_control_panel:
		player_control_panel.refresh_display()

# --- Pause-si-oisif : le temps se bloque tant que le joueur n'a pas d'ordre ---

func _on_player_state_changed() -> void:
	"""Réagit aux changements d'état du joueur (énergie/activité/connexion)."""
	if is_in_forced_rest:
		return
	if not player_character:
		return
	if player_character.needs_activity_choice():
		_enter_idle_prompt()
	else:
		_exit_idle_prompt()
	if player_control_panel:
		player_control_panel.refresh_display()

func _enter_idle_prompt() -> void:
	"""Bloque le temps et demande une activité au joueur."""
	if _auto_paused_for_idle:
		return
	_auto_paused_for_idle = true
	if GameTime:
		GameTime.pause()
	_show_activity_prompt()

func _exit_idle_prompt() -> void:
	"""Ferme le prompt et reprend le temps si on l'avait mis en pause pour oisiveté."""
	if is_instance_valid(_activity_prompt):
		_activity_prompt.queue_free()
		_activity_prompt = null
	if not _auto_paused_for_idle:
		return
	_auto_paused_for_idle = false
	if GameTime:
		GameTime.resume()

func _show_activity_prompt() -> void:
	"""Overlay thémé de choix d'activité (style Football Manager : « donnez un ordre »).
	Construit en jeu (CanvasLayer + PanelContainer) pour hériter du thème global et
	assombrir l'arrière-plan plutôt qu'un AcceptDialog brut."""
	if is_instance_valid(_activity_prompt):
		return
	var p = player_character
	if not p:
		return

	var overlay := CanvasLayer.new()
	overlay.layer = 200  # au-dessus des fenêtres et du chat

	# Fond assombri qui capture les clics (empêche d'agir derrière)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	# Panneau thémé avec bordure accent pour bien ressortir sur le fond assombri
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = UITheme.BG_PANEL
	pstyle.set_corner_radius_all(8)
	pstyle.set_border_width_all(2)
	pstyle.border_color = UITheme.ACCENT_DIM
	pstyle.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", pstyle)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "⏸️  Jeu en pause"
	title.add_theme_font_size_override("font_size", UITheme.FONT_NORMAL + 6)
	title.add_theme_color_override("font_color", UITheme.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var info := Label.new()
	info.text = "Que fait %s ?" % p.nom
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(info)

	var energy := Label.new()
	energy.text = "⚡ Énergie : %.0f / %.0f" % [p.player_energy_pool, p.max_energy_pool]
	energy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energy.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	vbox.add_child(energy)

	vbox.add_child(HSeparator.new())

	var choices := [
		{"key": "LEVELING", "label": "🗡️  Leveling", "desc": "Gagner de l'XP"},
		{"key": "FARMING", "label": "💰  Farming", "desc": "Récolter de l'or"},
		{"key": "FUN", "label": "🎮  Détente", "desc": "Récupérer du moral"},
	]
	for c in choices:
		var b := Button.new()
		b.text = "%s — %s" % [c["label"], c["desc"]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 44)
		b.disabled = not p.can_perform_activity(c["key"])
		b.pressed.connect(_on_prompt_activity_chosen.bind(c["key"]))
		vbox.add_child(b)

	# Contenu de groupe : route vers la fenêtre d'organisation (vrai flow PvE)
	var org_btn := Button.new()
	org_btn.text = "⚔️  Donjon / Raid — organiser un groupe"
	org_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	org_btn.tooltip_text = "Ouvre l'organisation de groupe pour composer et lancer un donjon ou un raid"
	org_btn.custom_minimum_size = Vector2(0, 44)
	org_btn.pressed.connect(_on_prompt_organize_chosen.bind("dungeon"))
	vbox.add_child(org_btn)

	vbox.add_child(HSeparator.new())

	var rest_btn := Button.new()
	rest_btn.text = "😴  Se reposer (8h)"
	rest_btn.tooltip_text = "Récupère toute l'énergie puis reprend l'activité précédente"
	rest_btn.custom_minimum_size = Vector2(0, 40)
	rest_btn.pressed.connect(_on_prompt_rest_chosen)
	vbox.add_child(rest_btn)

	add_child(overlay)
	_activity_prompt = overlay

func _on_prompt_activity_chosen(activity_type: String) -> void:
	"""Choix d'activité depuis le prompt : démarre l'activité (le temps reprend via le signal)."""
	if not player_character:
		return
	player_character.choose_activity(activity_type)
	# choose_activity émet player_state_changed → _exit_idle_prompt (ferme + reprend le temps)

func _on_prompt_rest_chosen() -> void:
	"""Bouton « Se reposer » du prompt d'oisiveté."""
	_perform_rest(8, false)

func _on_prompt_organize_chosen(kind: String) -> void:
	"""Donjon/Raid : ferme le prompt, relance le temps et ouvre l'organisation de groupe."""
	_exit_idle_prompt()
	_open_organization(kind)

func _open_organization(kind: String) -> void:
	"""Ouvre la fenêtre d'organisation de groupe présélectionnée sur Donjon/Raid."""
	if not window_manager:
		return
	window_manager.show_window("organisation")
	var inst: Control = window_manager.get_window_instance("organisation")
	if inst and inst.has_method("preselect_activity"):
		inst.call_deferred("preselect_activity", kind)

func _on_player_organize_requested(kind: String) -> void:
	"""Bouton « Donjon/Raid » du panneau de contrôle joueur."""
	_open_organization(kind)
