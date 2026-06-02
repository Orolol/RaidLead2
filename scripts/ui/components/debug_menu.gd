extends PanelContainer
class_name DebugMenuPanel

## Menu de debug (builds debug-only) extrait de `main.gd` pour dégonfler
## l'orchestrateur. Construit son propre bouton + popup et applique les actions
## de debug. `main` instancie ce panneau et lui passe le `WindowManager` pour
## pouvoir rafraîchir la fenêtre Guilde après une action.

var _window_manager: Node = null

func setup(window_manager: Node) -> void:
	_window_manager = window_manager
	custom_minimum_size = Vector2(150, 30)
	# Ancrage top-left pour supporter toutes les résolutions
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	offset_left = 10
	offset_top = 80
	offset_right = 10 + 150
	offset_bottom = 80 + 30

	var menu_button := MenuButton.new()
	menu_button.text = "Debug"
	menu_button.flat = false
	add_child(menu_button)

	var popup := menu_button.get_popup()
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

	popup.id_pressed.connect(_on_menu_pressed)

func trigger(id: int) -> void:
	"""Permet à main de déclencher une action de debug (raccourcis F1/F2)."""
	_on_menu_pressed(id)

func _on_menu_pressed(id: int) -> void:
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
			if NotificationManager:
				NotificationManager.show_info("Ceci est un test de notification info", "Test Info")

		11: # Test notification SUCCESS
			if NotificationManager:
				NotificationManager.show_success("Ceci est un test de notification succès", "Test Success")

		12: # Test notification WARNING
			if NotificationManager:
				NotificationManager.show_warning("Ceci est un test de notification avertissement", "Test Warning")

		13: # Test notification ERROR
			if NotificationManager:
				NotificationManager.show_error("Ceci est un test de notification erreur", "Test Error")

		14: # Test notification ACHIEVEMENT
			if NotificationManager:
				NotificationManager.show_achievement("Ceci est un test de notification achievement", "Test Achievement")

	# Rafraîchir la fenêtre guilde si elle est ouverte
	if not _window_manager:
		return
	var guilde_inst: Control = _window_manager.get_window_instance("guilde")
	if guilde_inst and guilde_inst.visible:
		guilde_inst._refresh_member_list()
		guilde_inst._update_guild_info()
