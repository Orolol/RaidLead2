extends Control

const MenuBarScript = preload("res://scripts/ui/components/menu_bar.gd")
const WindowManagerScript = preload("res://scripts/managers/window_manager.gd")
# RandomEventResource / EventChoiceResource / EventPopupWindow : résolus via leur class_name global
# (les preloads redondants masquaient l'identifiant global → SHADOWED_GLOBAL_IDENTIFIER).
const PlayerControlPanelScript = preload("res://scripts/ui/components/player_control_panel.gd")
const ResourceBarScript = preload("res://scripts/ui/components/resource_bar.gd")
const ObjectiveTrackerScript = preload("res://scripts/ui/components/objective_tracker.gd")
const AlertRailScript = preload("res://scripts/ui/components/alert_rail.gd")
const MemberInspectorScript = preload("res://scripts/ui/components/member_inspector.gd")
# const FastForwardDialog = preload("res://scripts/ui/windows/fast_forward_dialog.gd")  # Supprimé - système simplifié
const NO_SAVE_AUTOLOAD_ARG: String = "--no-save-autoload"
const REST_ACCELERATION_SPEED: float = 2880.0

var window_manager: Node
var menu_bar: Control
var hud_layer: CanvasLayer = null
var resource_bar: ResourceBar = null
var objective_tracker: ObjectiveTracker = null
var alert_rail: Control = null
var member_inspector: Control = null

var chat_panel: ChatPanel = null
var event_popup: EventPopupWindow = null
var _pending_event_queue: Array = []  # événements en attente derrière un autre popup modal
var _loot_dialog_active: bool = false
var _pending_loot_conflicts: Array = []

# Système joueur
var player_control_panel: PlayerControlPanelScript = null
var player_character = null  # Référence au personnage joueur
var is_in_forced_rest: bool = false  # Verrou pendant un repos (forcé ou volontaire)
var _auto_paused_for_idle: bool = false  # Le temps a été mis en pause car le joueur attend un ordre
var _activity_prompt: CanvasLayer = null  # Overlay thémé de choix d'activité (pause-si-oisif)
var _rest_overlay: CanvasLayer = null
var _rest_progress_bar: ProgressBar = null
var _rest_status_label: Label = null
var _rest_previous_speed: float = 60.0
var _rest_previous_pause: bool = false
var _rest_started_from_idle_pause: bool = false
var _rest_started_timestamp: float = 0.0
var _rest_end_timestamp: float = 0.0
var _debug_menu: DebugMenuPanel = null  # Menu de debug (builds debug-only), extrait de main
var _system_notifier: SystemNotifier = null  # Relais de notifications systèmes, extrait de main
# var fast_forward_manager: Node = null  # Supprimé - système simplifié

func _ready() -> void:
	# Applique le thème global cohérent à toute l'UI (fenêtres, popups, notifications)
	get_tree().root.theme = UITheme.build()

	# Les nœuds existent déjà dans la scène
	menu_bar = $VBoxContainer/menu_bar
	window_manager = $VBoxContainer/window_manager
	
	_setup_background()
	_setup_hud()
	_setup_chat_panel()
	_connect_phase_notifications()
	if _is_debug_ui_enabled():
		_setup_debug_menu()
	_connect_menu_signals()
	_register_windows()
	_connect_window_signals()
	_connect_event_system()
	_connect_loot_conflict_system()
	_setup_system_notifier()
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

func _setup_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 40
	add_child(hud_layer)

	resource_bar = ResourceBarScript.new()
	hud_layer.add_child(resource_bar)
	resource_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	resource_bar.offset_left = 16
	resource_bar.offset_top = 10
	resource_bar.offset_right = -16
	resource_bar.offset_bottom = 66
	resource_bar.resource_action_requested.connect(_on_hud_resource_action_requested)

	objective_tracker = ObjectiveTrackerScript.new()
	hud_layer.add_child(objective_tracker)
	objective_tracker.set_anchors_preset(Control.PRESET_CENTER_TOP)
	objective_tracker.offset_left = -280
	objective_tracker.offset_top = 78
	objective_tracker.offset_right = 280
	objective_tracker.offset_bottom = 154
	objective_tracker.open_requested.connect(_on_objective_tracker_open_requested)

	alert_rail = AlertRailScript.new()
	hud_layer.add_child(alert_rail)
	alert_rail.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	alert_rail.offset_left = -316
	alert_rail.offset_top = 82
	alert_rail.offset_right = -16
	alert_rail.offset_bottom = 442
	alert_rail.alert_action_requested.connect(_on_alert_action_requested)

	member_inspector = MemberInspectorScript.new()
	hud_layer.add_child(member_inspector)
	member_inspector.set_anchors_preset(Control.PRESET_TOP_LEFT)
	member_inspector.offset_left = 20
	member_inspector.offset_top = 320
	member_inspector.offset_right = 320
	member_inspector.offset_bottom = 650
	member_inspector.action_requested.connect(_on_member_inspector_action_requested)

func _on_hud_resource_action_requested(action: String) -> void:
	if not window_manager:
		return
	match action:
		"gold":
			if PhaseManager and PhaseManager.get_current_phase() >= PhaseManager.GamePhase.NATIONAL:
				_open_hub_section("hub_business", "national")
			else:
				_open_hub_section("hub_advice", "stats")
		"reputation":
			_open_hub_section("hub_guild", "player")
		"morale":
			_open_hub_section("hub_guild", "cohesion")
		"roster":
			_open_hub_section("hub_guild", "roster")
		_:
			_open_hub_section("hub_advice", "weekly")

func _on_objective_tracker_open_requested() -> void:
	if window_manager:
		_open_hub_section("hub_competition", "progression")

func _on_alert_action_requested(action: String, context: Dictionary) -> void:
	if not window_manager:
		return
	var member: SimulatedPlayer = context.get("member", null) as SimulatedPlayer
	if member and GuildManager and GuildManager.has_method("select_member"):
		GuildManager.select_member(member, str(context.get("context", action)))
	var target_hub: String = str(context.get("hub", ""))
	if target_hub != "":
		_open_hub_section(target_hub, str(context.get("section", "")), context)
		return
	var target_window: String = str(context.get("window", ""))
	if target_window != "":
		window_manager.show_window(target_window)
		return
	match action:
		"drama":
			_open_hub_section("hub_guild", "cohesion")
		"recruitment":
			_open_hub_section("hub_recruitment", "recruitment", context)
		"burnout", "cohesion":
			_open_hub_section("hub_guild", "cohesion", context)
		"finance":
			_open_hub_section("hub_advice", "stats")
		_:
			_open_hub_section("hub_advice", "weekly")

func _on_member_inspector_action_requested(action: String, player) -> void:
	var context: Dictionary = {"member": player}
	match action:
		"roster":
			_open_hub_section("hub_guild", "roster", context)
		"cohesion":
			_open_hub_section("hub_guild", "cohesion", context)
		"equipment":
			var inst: Control = window_manager.show_window("guilde")
			if inst and inst.has_method("focus_member"):
				inst.call_deferred("focus_member", player, true)
		"pve":
			_open_organization("dungeon")
		_:
			_open_hub_section("hub_guild", "roster", context)

func _open_hub_section(hub_name: String, section_id: String = "", context: Dictionary = {}) -> Control:
	if not window_manager:
		return null
	var instance: Control = window_manager.show_window(hub_name)
	if not instance:
		return null
	if context.has("member") and context["member"] != null and GuildManager and GuildManager.has_method("select_member"):
		GuildManager.select_member(context["member"], str(context.get("context", section_id)))
	if section_id != "" and instance.has_method("select_section"):
		instance.call_deferred("select_section", section_id)
	if instance.has_method("apply_context"):
		instance.call_deferred("apply_context", context)
	return instance

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
	# Le menu de debug vit désormais dans son propre composant (DebugMenuPanel)
	# pour alléger main.gd.
	_debug_menu = DebugMenuPanel.new()
	add_child(_debug_menu)
	_debug_menu.setup(window_manager)

func _is_debug_ui_enabled() -> bool:
	return OS.is_debug_build()

func _should_auto_load_save() -> bool:
	var args: PackedStringArray = OS.get_cmdline_args()
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	return not args.has(NO_SAVE_AUTOLOAD_ARG) and not user_args.has(NO_SAVE_AUTOLOAD_ARG)

func _connect_menu_signals() -> void:
	menu_bar.guild_hub_button_pressed.connect(_on_guild_hub_button_pressed)
	menu_bar.competition_hub_button_pressed.connect(_on_competition_hub_button_pressed)
	menu_bar.business_hub_button_pressed.connect(_on_business_hub_button_pressed)
	menu_bar.recruitment_hub_button_pressed.connect(_on_recruitment_hub_button_pressed)
	menu_bar.advice_hub_button_pressed.connect(_on_advice_hub_button_pressed)

func _on_guild_hub_button_pressed() -> void:
	window_manager.show_window("hub_guild")

func _on_competition_hub_button_pressed() -> void:
	window_manager.show_window("hub_competition")

func _on_business_hub_button_pressed() -> void:
	window_manager.show_window("hub_business")

func _on_recruitment_hub_button_pressed() -> void:
	window_manager.show_window("hub_recruitment")

func _on_advice_hub_button_pressed() -> void:
	window_manager.show_window("hub_advice")

func _on_personnage_button_pressed() -> void:
	_open_hub_section("hub_guild", "player")

func _on_guilde_button_pressed() -> void:
	_open_hub_section("hub_guild", "roster")

func _on_monde_button_pressed() -> void:
	_open_hub_section("hub_competition", "rankings")

func _on_organisation_button_pressed() -> void:
	_open_hub_section("hub_competition", "group")

func _on_national_button_pressed() -> void:
	_open_hub_section("hub_business", "national")

func _on_esport_button_pressed() -> void:
	_open_hub_section("hub_business", "esport")

func _on_cohesion_button_pressed() -> void:
	_open_hub_section("hub_guild", "cohesion")

func _on_conseils_button_pressed() -> void:
	_open_hub_section("hub_advice", "weekly")

func _register_windows() -> void:
	window_manager.register_window("hub_guild", "res://scenes/Hub_Guilde.tscn")
	window_manager.register_window("hub_competition", "res://scenes/Hub_Competition.tscn")
	window_manager.register_window("hub_business", "res://scenes/Hub_Business.tscn")
	window_manager.register_window("hub_recruitment", "res://scenes/Hub_Recrutement.tscn")
	window_manager.register_window("hub_advice", "res://scenes/Hub_Conseil.tscn")
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
		window_manager.show_window("hub_guild")
	)

func _on_window_opened(window_name: String) -> void:
	# Connecter les signaux spécifiques quand une fenêtre est ouverte
	var instance: Control = window_manager.get_window_instance(window_name)
	if not instance:
		return

	match window_name:
		"hub_guild", "hub_competition", "hub_business", "hub_recruitment", "hub_advice":
			if instance.has_signal("section_requested") and not instance.section_requested.is_connected(_on_hub_section_requested):
				instance.section_requested.connect(_on_hub_section_requested)
			if instance.has_signal("legacy_player_recruited") and not instance.legacy_player_recruited.is_connected(_on_player_recruited):
				instance.legacy_player_recruited.connect(_on_player_recruited)
		"monde":
			if not instance.player_recruited.is_connected(_on_player_recruited):
				instance.player_recruited.connect(_on_player_recruited)
		"organisation":
			var guild_manager_node: Node = GuildManager
			if guild_manager_node:
				instance.set_guild_members(guild_manager_node.guild_members)

func _on_hub_section_requested(window_name: String, section_id: String) -> void:
	if window_name == "":
		return
	var instance: Control = window_manager.show_window(window_name)
	_focus_legacy_section.call_deferred(window_name, section_id, instance)

func _focus_legacy_section(window_name: String, section_id: String, instance: Control) -> void:
	if not is_instance_valid(instance):
		instance = window_manager.get_window_instance(window_name)
	if not is_instance_valid(instance) or not instance.get("advanced_tabs"):
		return
	var tabs: AdvancedTabs = instance.get("advanced_tabs")
	if not tabs:
		return
	var tab_index: int = 0
	match section_id:
		"recruitment":
			tab_index = 1
		"progression":
			tab_index = 1
		"advice":
			tab_index = 1
		"stats":
			tab_index = 2
	if tab_index < tabs.get_tab_count():
		tabs.select_tab(tab_index)

func _on_player_recruited(player: SimulatedPlayer) -> void:
	var guild_manager_node: Node = GuildManager
	if guild_manager_node:
		if player not in guild_manager_node.guild_members:
			var added: bool = guild_manager_node.add_member(player)
			if not added:
				if NotificationManager:
					NotificationManager.show_warning("Recrutement impossible : la guilde est pleine ou verrouillee.", "Recrutement")
				return
		if guild_manager_node.has_method("select_member"):
			guild_manager_node.select_member(player, "recruitment")
		# Rafraîchir les fenêtres ouvertes via leurs instances dans le WindowManager
		var guilde_inst: Control = window_manager.get_window_instance("guilde")
		if guilde_inst:
			guilde_inst._refresh_member_list()
		var org_inst: Control = window_manager.get_window_instance("organisation")
		if org_inst:
			org_inst.set_guild_members(guild_manager_node.guild_members)

func _process(delta: float) -> void:
	# Mettre à jour les donjons actifs via l'ActivityManager
	var activity_manager = ActivityManager
	if activity_manager:
		activity_manager.update_dungeons(delta)

func _input(event: InputEvent) -> void:
	if is_in_forced_rest:
		if event is InputEventKey and event.pressed:
			get_viewport().set_input_as_handled()
		return

	# Raccourcis clavier pour ouvrir les fenêtres
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_P:  # P pour Personnage
				if Input.is_key_pressed(KEY_CTRL):
					_on_personnage_button_pressed()
			KEY_G:  # G pour Guilde
				if Input.is_key_pressed(KEY_CTRL):
					menu_bar._on_guild_hub_pressed()
			KEY_C:  # C pour Competition
				if Input.is_key_pressed(KEY_CTRL):
					menu_bar._on_competition_hub_pressed()
			KEY_B:  # B pour Business
				if Input.is_key_pressed(KEY_CTRL):
					menu_bar._on_business_hub_pressed()
			KEY_R:  # R pour Recrutement
				if Input.is_key_pressed(KEY_CTRL):
					menu_bar._on_recruitment_hub_pressed()
			KEY_M:  # M pour Monde
				if Input.is_key_pressed(KEY_CTRL):
					_on_monde_button_pressed()
			KEY_O:  # O pour Organisation
				if Input.is_key_pressed(KEY_CTRL):
					_on_organisation_button_pressed()
			KEY_N:  # N pour National
				if Input.is_key_pressed(KEY_CTRL):
					_on_national_button_pressed()
			KEY_E:  # E pour Esport
				if Input.is_key_pressed(KEY_CTRL):
					_on_esport_button_pressed()
			KEY_K:  # K pour Cohésion
				if Input.is_key_pressed(KEY_CTRL):
					_on_cohesion_button_pressed()
			KEY_A:  # A pour Conseils (conseiller / aide)
				if Input.is_key_pressed(KEY_CTRL):
					menu_bar._on_advice_hub_pressed()
			KEY_SPACE:  # Espace pour pause
				var game_time_node = GameTime
				if game_time_node:
					game_time_node.toggle_pause()
			KEY_ESCAPE:  # Échap pour fermer la fenêtre active
				window_manager.close_active_window()
			KEY_F1:  # F1 pour déclencher un événement test
				if _debug_menu:
					_debug_menu.trigger(8)  # ID 8 = Déclencher événement test
			KEY_F2:  # F2 pour afficher les stats
				if _debug_menu:
					_debug_menu.trigger(9)  # ID 9 = Afficher stats événements
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
	if is_in_forced_rest or event_popup != null or _drama_popup_active or _loot_dialog_active:
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
	_process_deferred_rest_popups.call_deferred()

func _on_event_popup_closed() -> void:
	event_popup = null
	_process_deferred_rest_popups.call_deferred()

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
	if is_in_forced_rest:
		_pending_loot_conflicts.append(conflict)
		return

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
			_process_deferred_rest_popups.call_deferred()
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
		_process_deferred_rest_popups.call_deferred()
	)

	_loot_dialog_active = true
	add_child(dialog)
	dialog.popup_centered(Vector2(500, 300))

func _process_next_loot_conflict() -> void:
	if _pending_loot_conflicts.is_empty():
		return
	if event_popup != null or _drama_popup_active or _loot_dialog_active or is_in_forced_rest:
		return
	var conflict: Dictionary = _pending_loot_conflicts.pop_front()
	_on_loot_conflict(conflict)

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

func _setup_system_notifier() -> void:
	"""Délègue le relais des notifications systèmes (National/Esport/Cohésion) à
	SystemNotifier. Le popup modal de drama reste géré ici (couplé à la pause)."""
	_system_notifier = SystemNotifier.new()
	add_child(_system_notifier)
	_system_notifier.setup(chat_panel)
	_system_notifier.drama_response_needed.connect(_on_drama_response_needed)

func _on_drama_response_needed(drama) -> void:
	# File d'attente pour éviter les popups simultanées
	if is_in_forced_rest or _drama_popup_active or event_popup != null or _loot_dialog_active:
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
			_process_deferred_rest_popups.call_deferred()
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
		_process_deferred_rest_popups.call_deferred()
	)

	add_child(dialog)
	dialog.popup_centered(Vector2(540, 380))

func _process_next_drama() -> void:
	"""Affiche le prochain drama en attente, s'il en reste."""
	if event_popup != null or _loot_dialog_active or is_in_forced_rest:
		return
	while not _pending_dramas.is_empty():
		var next = _pending_dramas.pop_front()
		if next and next.active:
			_show_drama_popup(next)
			return

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
	player_control_panel.offset_top = 92
	player_control_panel.offset_right = 20 + player_control_panel.custom_minimum_size.x
	player_control_panel.offset_bottom = 92 + player_control_panel.custom_minimum_size.y
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
	if is_in_forced_rest:
		return
	is_in_forced_rest = true
	_run_accelerated_rest(recovery_hours, forced)

func _run_accelerated_rest(recovery_hours: int, forced: bool) -> void:
	var game_time_node: Node = GameTime
	_rest_previous_speed = game_time_node.time_speed if game_time_node else 60.0
	_rest_previous_pause = game_time_node.is_paused if game_time_node else false
	_rest_started_from_idle_pause = _auto_paused_for_idle
	_auto_paused_for_idle = false

	if is_instance_valid(_activity_prompt):
		_activity_prompt.queue_free()
		_activity_prompt = null

	if player_character and player_character.is_online:
		player_character.disconnect_player("Repos")

	if player_control_panel and player_control_panel.has_method("set_resting_state"):
		player_control_panel.set_resting_state(true, forced, recovery_hours)

	if game_time_node:
		_rest_started_timestamp = game_time_node.get_current_timestamp()
		_rest_end_timestamp = _rest_started_timestamp + float(recovery_hours) * 3600.0
	else:
		_rest_started_timestamp = 0.0
		_rest_end_timestamp = float(recovery_hours) * 3600.0

	_show_rest_overlay(recovery_hours, forced)

	if game_time_node:
		game_time_node.set_time_speed(REST_ACCELERATION_SPEED)
		game_time_node.resume()
		_update_rest_overlay()
		while game_time_node.get_current_timestamp() < _rest_end_timestamp:
			await game_time_node.minute_changed
			_update_rest_overlay()
		game_time_node.set_time_speed(_rest_previous_speed)

	if player_character:
		player_character.player_energy_pool = player_character.max_energy_pool
		player_character.energy = 100.0
		player_character.reconnect_player()

	is_in_forced_rest = false
	_hide_rest_overlay()

	if player_control_panel and player_control_panel.has_method("set_resting_state"):
		player_control_panel.set_resting_state(false, forced, recovery_hours)

	if NotificationManager:
		if forced:
			NotificationManager.show_warning(
				"Personnage épuisé : repos de %dh, énergie restaurée." % recovery_hours, "Repos")
		else:
			NotificationManager.show_info(
				"Repos de %dh : énergie restaurée." % recovery_hours, "Repos")

	if player_character and not player_character.resume_last_activity():
		_auto_paused_for_idle = false
		_on_player_state_changed()
	else:
		_exit_idle_prompt()
		_restore_post_rest_pause_state()

	if player_control_panel:
		player_control_panel.refresh_display()

	_process_deferred_rest_popups()

func _show_rest_overlay(recovery_hours: int, forced: bool) -> void:
	if is_instance_valid(_rest_overlay):
		return

	var overlay := CanvasLayer.new()
	overlay.layer = 240

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = UITheme.BG_PANEL
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = UITheme.ACCENT_DIM
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Repos forcé" if forced else "Repos en cours"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", UITheme.FONT_NORMAL + 6)
	title.add_theme_color_override("font_color", UITheme.ACCENT)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "%dh de repos accéléré" % recovery_hours
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	vbox.add_child(subtitle)

	_rest_progress_bar = ProgressBar.new()
	_rest_progress_bar.min_value = 0.0
	_rest_progress_bar.max_value = 100.0
	_rest_progress_bar.value = 0.0
	_rest_progress_bar.show_percentage = true
	_rest_progress_bar.custom_minimum_size = Vector2(0, 28)
	vbox.add_child(_rest_progress_bar)

	_rest_status_label = Label.new()
	_rest_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rest_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rest_status_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	vbox.add_child(_rest_status_label)

	add_child(overlay)
	_rest_overlay = overlay
	_update_rest_overlay()

func _update_rest_overlay() -> void:
	if not is_instance_valid(_rest_overlay) or not GameTime:
		return
	var total_seconds: float = maxf(1.0, _rest_end_timestamp - _rest_started_timestamp)
	var elapsed_seconds: float = clampf(GameTime.get_current_timestamp() - _rest_started_timestamp, 0.0, total_seconds)
	var remaining_seconds: float = maxf(0.0, _rest_end_timestamp - GameTime.get_current_timestamp())
	var percent: float = clampf((elapsed_seconds / total_seconds) * 100.0, 0.0, 100.0)
	if _rest_progress_bar:
		_rest_progress_bar.value = percent
	if _rest_status_label:
		_rest_status_label.text = "%s restants - retour vers %s - vitesse x%.0f" % [
			_format_rest_duration(remaining_seconds),
			GameTime.get_current_time_string(),
			GameTime.time_speed
		]

func _hide_rest_overlay() -> void:
	if is_instance_valid(_rest_overlay):
		_rest_overlay.queue_free()
	_rest_overlay = null
	_rest_progress_bar = null
	_rest_status_label = null

func _format_rest_duration(seconds: float) -> String:
	var total_minutes: int = int(ceil(seconds / 60.0))
	@warning_ignore("integer_division")
	var hours: int = total_minutes / 60
	var minutes: int = total_minutes % 60
	if hours > 0:
		return "%dh%02d" % [hours, minutes]
	return "%dmin" % minutes

func _restore_post_rest_pause_state() -> void:
	if not GameTime:
		return
	if _rest_previous_pause and not _rest_started_from_idle_pause:
		GameTime.pause()
	else:
		GameTime.resume()

func _process_deferred_rest_popups() -> void:
	_process_next_loot_conflict()
	if not _loot_dialog_active:
		_process_next_drama()
	if not _loot_dialog_active and not _drama_popup_active:
		_show_next_pending_event.call_deferred()

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
