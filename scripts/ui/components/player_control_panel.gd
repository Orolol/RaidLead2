extends PanelContainer
class_name PlayerControlPanel

const PlayerCharacterScript = preload("res://scripts/resources/player_character.gd")
const CustomProgressBarScript = preload("res://scripts/ui/components/custom_progress_bar.gd")

signal activity_changed(activity_type: String)
signal disconnect_requested(return_hour: int, return_minute: int)
signal organize_requested(kind: String)  # Donjon/Raid : ouvre l'organisation de groupe

var player_character: PlayerCharacterScript = null

# UI Elements
var header_label: Label
var energy_progress: CustomProgressBarScript
var energy_label: Label
var activity_option: OptionButton
var disconnect_button: Button
var status_label: Label
var session_info_label: Label

func _ready():
	custom_minimum_size = Vector2(300, 200)
	_setup_ui()
	_connect_signals()
	# Rafraîchissement event-driven : piloté par player_character.player_state_changed
	# (connecté dans set_player_character) + appel direct sur set_player_character.
	# Plus de Timer 5 s.

func _setup_ui():
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	add_child(main_vbox)
	
	# Header
	_setup_header(main_vbox)
	
	# Jauge d'énergie
	_setup_energy_display(main_vbox)
	
	main_vbox.add_child(HSeparator.new())
	
	# Sélection d'activité
	_setup_activity_selector(main_vbox)
	
	main_vbox.add_child(HSeparator.new())
	
	# Statut et contrôles
	_setup_status_and_controls(main_vbox)
	
	main_vbox.add_child(HSeparator.new())
	
	# Informations de session
	_setup_session_info(main_vbox)

func _setup_header(parent: VBoxContainer):
	header_label = Label.new()
	header_label.text = "🎮 Contrôle Joueur"
	header_label.add_theme_font_size_override("font_size", 16)
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_label.modulate = Color(1.0, 0.8, 0.2)
	parent.add_child(header_label)

func _setup_energy_display(parent: VBoxContainer):
	var energy_container = VBoxContainer.new()
	parent.add_child(energy_container)
	
	var energy_header = Label.new()
	energy_header.text = "⚡ Énergie"
	energy_header.add_theme_font_size_override("font_size", 14)
	energy_container.add_child(energy_header)
	
	# Barre de progression personnalisée
	energy_progress = CustomProgressBarScript.new()
	energy_progress.custom_minimum_size = Vector2(0, 25)
	energy_progress.set_range(0, 100)
	energy_progress.set_value_immediate(100)
	energy_progress.set_colors(Color.GREEN, Color.ORANGE, Color.RED)
	energy_container.add_child(energy_progress)
	
	# Label avec valeurs (masqué : la barre affiche déjà la valeur, évite la superposition)
	energy_label = Label.new()
	energy_label.text = "100 / 100"
	energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energy_label.add_theme_font_size_override("font_size", 12)
	energy_label.visible = false
	energy_container.add_child(energy_label)

func _setup_activity_selector(parent: VBoxContainer):
	var activity_container = VBoxContainer.new()
	parent.add_child(activity_container)
	
	var activity_header = Label.new()
	activity_header.text = "🎯 Activité"
	activity_header.add_theme_font_size_override("font_size", 14)
	activity_container.add_child(activity_header)
	
	activity_option = OptionButton.new()
	activity_option.custom_minimum_size = Vector2(0, 35)
	activity_container.add_child(activity_option)

	# Ajouter les options d'activité
	_populate_activity_options()

	# Contenu de groupe : ouvre la fenêtre d'organisation (vrai flow PvE)
	var organize_button = Button.new()
	organize_button.text = "⚔️ Donjon / Raid"
	organize_button.tooltip_text = "Organiser un groupe pour lancer un donjon ou un raid"
	organize_button.custom_minimum_size = Vector2(0, 32)
	organize_button.pressed.connect(func(): organize_requested.emit("dungeon"))
	activity_container.add_child(organize_button)

func _setup_status_and_controls(parent: VBoxContainer):
	var controls_container = VBoxContainer.new()
	parent.add_child(controls_container)
	
	# Statut actuel
	status_label = Label.new()
	status_label.text = "En attente..."
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.modulate = Color(0.8, 0.8, 0.8)
	controls_container.add_child(status_label)
	
	# Bouton de repos (récupère l'énergie puis reprend l'activité)
	disconnect_button = Button.new()
	disconnect_button.text = "😴 Se reposer"
	disconnect_button.tooltip_text = "Repos : récupère toute l'énergie puis reprend automatiquement l'activité en cours"
	disconnect_button.custom_minimum_size = Vector2(0, 35)
	disconnect_button.modulate = Color(0.8, 0.9, 1.0)
	controls_container.add_child(disconnect_button)

func _setup_session_info(parent: VBoxContainer):
	var session_container = VBoxContainer.new()
	parent.add_child(session_container)
	
	var session_header = Label.new()
	session_header.text = "📊 Session"
	session_header.add_theme_font_size_override("font_size", 12)
	session_container.add_child(session_header)
	
	session_info_label = Label.new()
	session_info_label.text = "XP: 0 | Or: 0 | Durée: 0min"
	session_info_label.add_theme_font_size_override("font_size", 10)
	session_info_label.modulate = Color(0.9, 0.9, 0.9)
	session_container.add_child(session_info_label)

func _populate_activity_options():
	activity_option.clear()
	activity_option.add_item("Choisir une activité...", -1)
	activity_option.add_separator()
	
	var activities = [
		{"key": "LEVELING", "name": "🗡️ Leveling", "desc": "Gagner de l'XP en tuant des mobs"},
		{"key": "FARMING", "name": "💰 Farming", "desc": "Récolter de l'or et des ressources"},
		{"key": "FUN", "name": "🎮 Glander en ville", "desc": "Se détendre, récupérer du moral"}
	]
	
	for i in range(activities.size()):
		var activity = activities[i]
		var item_index = activity_option.get_item_count()  # Index réel après ajout
		activity_option.add_item(activity.name, i)
		activity_option.set_item_metadata(item_index, activity.key)

func _connect_signals():
	if activity_option:
		activity_option.item_selected.connect(_on_activity_selected)
	if disconnect_button:
		disconnect_button.pressed.connect(_on_disconnect_pressed)

func set_player_character(player: PlayerCharacterScript):
	player_character = player
	_update_display()

	# Rafraîchissement temps réel piloté par le signal d'état (énergie/activité)
	if player_character and player_character.has_signal("player_state_changed"):
		if not player_character.player_state_changed.is_connected(_update_display):
			player_character.player_state_changed.connect(_update_display)

func _update_display():
	if not player_character:
		return
	
	# Mise à jour de l'énergie
	var energy_percent = player_character.get_energy_percentage()
	energy_progress.set_value(energy_percent)
	energy_label.text = "%.0f / %.0f" % [player_character.player_energy_pool, player_character.max_energy_pool]
	
	# Coloration selon l'état
	if player_character.is_energy_critical():
		energy_label.modulate = Color.RED
	elif player_character.is_energy_low():
		energy_label.modulate = Color.ORANGE
	else:
		energy_label.modulate = Color.WHITE
	
	# Mise à jour du statut
	_update_status_display()
	
	# Mise à jour des informations de session
	_update_session_display()
	
	# Mise à jour des activités disponibles
	_update_available_activities()

func _update_status_display():
	if not player_character:
		return
	
	if not player_character.is_online:
		status_label.text = "🔌 Déconnecté"
		status_label.modulate = Color.GRAY
	elif player_character.current_activity:
		var activity_name = player_character.get_activity_display_name(player_character.current_activity.get_type_string().to_upper())
		status_label.text = "🎯 " + activity_name
		status_label.modulate = Color.GREEN
	else:
		status_label.text = "⏳ En attente..."
		status_label.modulate = Color.YELLOW

func _update_session_display():
	if not player_character:
		return
	
	var report = player_character.get_session_report()
	var duration_text = _format_duration(report.duration_minutes)
	
	session_info_label.text = "XP: %d | Or: %d | %s" % [
		report.xp_gained,
		report.gold_gained,
		duration_text
	]
	
	# Ajouter information sur level up
	if report.levels_gained > 0:
		session_info_label.text += " | +%d LVL!" % report.levels_gained

func _update_available_activities():
	if not player_character:
		return
	
	var available = player_character.get_available_activities()
	
	# Désactiver les options non disponibles
	for i in range(activity_option.get_item_count()):
		var metadata = activity_option.get_item_metadata(i)
		if metadata != null:
			var is_available = metadata in available
			activity_option.set_item_disabled(i, not is_available)

func _format_duration(minutes: int) -> String:
	if minutes < 60:
		return "%dmin" % minutes
	else:
		# Division entière voulue : heures pleines + minutes restantes.
		@warning_ignore("integer_division")
		var hours: int = minutes / 60
		var mins: int = minutes % 60
		return "%dh%02dmin" % [hours, mins]

func _on_activity_selected(index: int):
	var metadata = activity_option.get_item_metadata(index)
	if metadata == null or not player_character:
		return
	
	var activity_type = metadata as String

	if player_character.can_perform_activity(activity_type):
		if player_character.choose_activity(activity_type):
			activity_changed.emit(activity_type)
			_show_activity_feedback(activity_type)
		else:
			_show_error_message("Impossible de démarrer cette activité")
	else:
		_show_error_message("Énergie insuffisante pour cette activité")

func _on_disconnect_pressed():
	if not player_character:
		return
	
	# Émettre directement le signal pour demander une déconnexion manuelle
	disconnect_requested.emit(-1, -1)  # -1, -1 indique une déconnexion manuelle (choix utilisateur)

func _show_activity_feedback(activity_type: String):
	var activity_name = player_character.get_activity_display_name(activity_type)
	
	# Créer une notification temporaire
	var feedback = Label.new()
	feedback.text = "✓ Activité démarrée: %s" % activity_name
	feedback.modulate = Color.GREEN
	feedback.add_theme_font_size_override("font_size", 12)
	add_child(feedback)
	
	# Créer une animation pour faire disparaître le message
	var tween = create_tween()
	tween.tween_property(feedback, "modulate:a", 0.0, 2.0)
	tween.tween_callback(feedback.queue_free)

func _show_error_message(message: String):
	# Créer une notification d'erreur temporaire
	var error = Label.new()
	error.text = "❌ " + message
	error.modulate = Color.RED
	error.add_theme_font_size_override("font_size", 12)
	add_child(error)
	
	# Animation pour faire disparaître le message
	var tween = create_tween()
	tween.tween_property(error, "modulate:a", 0.0, 3.0)
	tween.tween_callback(error.queue_free)

func show_reconnection_dialog():
	"""Affiche un dialogue quand le joueur peut se reconnecter"""
	if not player_character:
		return
	
	var dialog = AcceptDialog.new()
	dialog.title = "Retour de connexion"
	dialog.dialog_text = "Votre personnage est prêt à se reconnecter !\n\nÉnergie récupérée: %.0f/%.0f" % [
		player_character.player_energy_pool, 
		player_character.max_energy_pool
	]
	
	get_tree().root.add_child(dialog)
	dialog.confirmed.connect(func():
		if player_character.reconnect_player():
			_update_display()
		dialog.queue_free()
	)
	dialog.popup_centered()

# Méthodes publiques pour intégration
func refresh_display():
	"""Force une mise à jour de l'affichage"""
	_update_display()

func is_player_online() -> bool:
	"""Vérifie si le joueur est en ligne"""
	return player_character != null and player_character.is_online

func get_current_activity() -> String:
	"""Retourne l'activité actuelle du joueur"""
	if player_character and player_character.current_activity:
		return player_character.current_activity.get_type_string()
	return ""