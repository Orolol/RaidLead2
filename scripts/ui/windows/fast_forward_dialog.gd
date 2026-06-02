extends Window
class_name FastForwardDialog

signal fast_forward_requested(target_hour: int, target_minute: int)

var fast_forward_manager: Node
var progress_bar: ProgressBar
var progress_label: Label
var time_label: Label
var report_container: VBoxContainer
var time_selection_container: VBoxContainer
var progress_display_container: VBoxContainer
var energy_label: Label
var bonus_label: Label
var hour_slider: HSlider

# Boutons personnalisés
var ok_button: Button
var cancel_button: Button
var button_container: HBoxContainer

var is_showing_progress: bool = false
var is_forced_disconnect: bool = false

func _init():
	title = "Fast-Forward - Temps de repos"
	
	# Configuration de base de la fenêtre
	set_flag(Window.FLAG_RESIZE_DISABLED, false)
	unresizable = false
	borderless = false

func _ready():
	# Créer le contenu personnalisé
	_setup_content()
	
	# Configurer la taille après la création du contenu
	min_size = Vector2(400, 300)  # Taille minimale raisonnable
	
	# Connecter le signal de fermeture
	close_requested.connect(_on_close_requested)
	
	# Se connecter aux signaux si le manager est déjà configuré
	if fast_forward_manager:
		_connect_manager_signals()

func set_fast_forward_manager(manager: Node):
	fast_forward_manager = manager
	if is_node_ready():
		_connect_manager_signals()

func _connect_manager_signals():
	if not fast_forward_manager:
		return
	
	if not fast_forward_manager.fast_forward_started.is_connected(_on_fast_forward_started):
		fast_forward_manager.fast_forward_started.connect(_on_fast_forward_started)
	if not fast_forward_manager.fast_forward_progress.is_connected(_on_fast_forward_progress):
		fast_forward_manager.fast_forward_progress.connect(_on_fast_forward_progress)
	if not fast_forward_manager.fast_forward_completed.is_connected(_on_fast_forward_completed):
		fast_forward_manager.fast_forward_completed.connect(_on_fast_forward_completed)

func _setup_content():
	# Créer un container principal
	var main_container = VBoxContainer.new()
	main_container.add_theme_constant_override("separation", 15)
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	add_child(main_container)
	
	# Phase 1: Sélection du temps
	_setup_time_selection(main_container)
	
	# Phase 2: Barre de progression (cachée au début)
	_setup_progress_display(main_container)
	
	# Phase 3: Rapport final (caché au début)
	_setup_report_display(main_container)
	
	# Ajouter les boutons en bas
	_setup_buttons(main_container)

func _setup_time_selection(parent: VBoxContainer):
	time_selection_container = VBoxContainer.new()
	time_selection_container.name = "TimeSelection"
	time_selection_container.add_theme_constant_override("separation", 10)
	parent.add_child(time_selection_container)
	var selection_container = time_selection_container
	
	var title_label = Label.new()
	title_label.text = "⏰ Temps de repos"
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selection_container.add_child(title_label)
	
	var desc_label = Label.new()
	desc_label.text = "Votre personnage va se reposer et récupérer de l'énergie.\nChoisissez dans combien d'heures vous voulez revenir :"
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selection_container.add_child(desc_label)
	
	# Container pour le slider
	var time_container = VBoxContainer.new()
	time_container.add_theme_constant_override("separation", 5)
	selection_container.add_child(time_container)
	
	var slider_label = Label.new()
	slider_label.text = "Durée du repos :"
	slider_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_container.add_child(slider_label)
	
	var slider_container = HBoxContainer.new()
	time_container.add_child(slider_container)
	
	hour_slider = HSlider.new()
	hour_slider.min_value = 1
	hour_slider.max_value = 24
	hour_slider.value = 8
	hour_slider.step = 1
	hour_slider.custom_minimum_size = Vector2(250, 30)
	slider_container.add_child(hour_slider)
	
	time_label = Label.new()
	time_label.text = "8h"
	time_label.custom_minimum_size = Vector2(50, 0)
	slider_container.add_child(time_label)
	
	# Mise à jour du label et calcul de l'heure de retour
	hour_slider.value_changed.connect(func(value): _update_time_display(int(value)))
	
	# Informations sur la récupération
	var recovery_container = VBoxContainer.new()
	recovery_container.add_theme_constant_override("separation", 5)
	selection_container.add_child(recovery_container)
	
	var recovery_title = Label.new()
	recovery_title.text = "💊 Récupération estimée :"
	recovery_title.add_theme_font_size_override("font_size", 14)
	recovery_container.add_child(recovery_title)
	
	energy_label = Label.new()
	energy_label.name = "EnergyLabel"
	energy_label.text = "+80 énergie"
	energy_label.modulate = Color.GREEN
	recovery_container.add_child(energy_label)
	
	bonus_label = Label.new()
	bonus_label.name = "BonusLabel"
	bonus_label.text = "+20 bonus (repos > 8h)"
	bonus_label.modulate = Color.CYAN
	recovery_container.add_child(bonus_label)
	
	# Mettre à jour les informations initiales
	_update_time_display(8)

func _setup_buttons(parent: VBoxContainer):
	"""Crée les boutons OK et Cancel"""
	# Ajouter un separateur
	parent.add_child(HSeparator.new())
	
	# Container pour les boutons
	button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_END
	button_container.add_theme_constant_override("separation", 10)
	parent.add_child(button_container)
	
	# Bouton Cancel
	cancel_button = Button.new()
	cancel_button.text = "Annuler"
	cancel_button.custom_minimum_size = Vector2(100, 35)
	cancel_button.pressed.connect(_on_canceled)
	button_container.add_child(cancel_button)
	
	# Bouton OK
	ok_button = Button.new()
	ok_button.text = "Commencer le repos"
	ok_button.custom_minimum_size = Vector2(150, 35)
	ok_button.pressed.connect(_on_confirmed)
	button_container.add_child(ok_button)

func _setup_progress_display(parent: VBoxContainer):
	progress_display_container = VBoxContainer.new()
	progress_display_container.name = "ProgressDisplay"
	progress_display_container.add_theme_constant_override("separation", 10)
	progress_display_container.visible = false
	parent.add_child(progress_display_container)
	var progress_container = progress_display_container
	
	var progress_title = Label.new()
	progress_title.text = "⚡ Fast-Forward en cours..."
	progress_title.add_theme_font_size_override("font_size", 18)
	progress_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_container.add_child(progress_title)
	
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(300, 25)
	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_container.add_child(progress_bar)
	
	progress_label = Label.new()
	progress_label.text = "Progression: 0%"
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_container.add_child(progress_label)
	
	var current_time_label = Label.new()
	current_time_label.name = "CurrentTimeLabel"
	current_time_label.text = "Heure actuelle: --:--"
	current_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current_time_label.add_theme_font_size_override("font_size", 12)
	progress_container.add_child(current_time_label)

func _setup_report_display(parent: VBoxContainer):
	report_container = VBoxContainer.new()
	report_container.name = "ReportDisplay"
	report_container.add_theme_constant_override("separation", 10)
	report_container.visible = false
	parent.add_child(report_container)
	
	var report_title = Label.new()
	report_title.text = "📋 Rapport de période de repos"
	report_title.add_theme_font_size_override("font_size", 18)
	report_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	report_container.add_child(report_title)

func show_time_selection():
	"""Affiche la phase de sélection du temps"""
	if time_selection_container:
		time_selection_container.visible = true
	if progress_display_container:
		progress_display_container.visible = false
	if report_container:
		report_container.visible = false
	is_showing_progress = false
	
	# Configurer les boutons
	if ok_button:
		ok_button.text = "Commencer le repos"
		ok_button.visible = true
	if cancel_button:
		cancel_button.visible = true
	
	# Ajuster la taille de la fenêtre
	_adjust_dialog_size()

func start_forced_disconnect(recovery_hours: int):
	"""Démarre un fast-forward forcé avec durée prédéfinie"""
	is_forced_disconnect = true
	
	# IMMÉDIATEMENT en fullscreen avec blocage total de l'interface
	mode = Window.MODE_FULLSCREEN
	exclusive = true  # Bloque complètement l'interface
	transient = false  # Pas de parent, vraiment modal
	always_on_top = true
	
	# Configurer directement le slider sur la durée forcée
	if hour_slider:
		hour_slider.value = recovery_hours
		hour_slider.editable = false
		hour_slider.visible = false  # Masquer le slider en mode forcé
	
	# Cacher tous les éléments de sélection normale
	if time_selection_container:
		time_selection_container.visible = false
	
	# Afficher directement l'interface de repos forcé
	_setup_forced_rest_interface(recovery_hours)
	
	# Rendre la fenêtre non-fermable
	if close_requested.is_connected(_on_close_requested):
		close_requested.disconnect(_on_close_requested)
	
	# NE PAS appeler _on_confirmed automatiquement - attendre le clic utilisateur

func _setup_forced_rest_interface(recovery_hours: int):
	"""Configure l'interface spéciale pour le repos forcé"""
	# Créer un container principal centré
	var main_container = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	main_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Fond semi-transparent noir
	var background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.8)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	
	# Titre principal
	var title_label = Label.new()
	title_label.text = "⚠️ ÉPUISEMENT TOTAL ⚠️"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", Color.RED)
	main_container.add_child(title_label)
	
	# Espacement
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 50)
	main_container.add_child(spacer1)
	
	# Message explicatif
	var message_label = Label.new()
	message_label.text = "Votre personnage est complètement épuisé.\nUn repos de %d heures est OBLIGATOIRE.\n\nPendant ce temps :\n• Récupération de 100%% d'énergie\n• Aucune action possible\n• Le temps passera à vitesse maximale" % recovery_hours
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 24)
	message_label.add_theme_color_override("font_color", Color.WHITE)
	main_container.add_child(message_label)
	
	# Espacement
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 80)
	main_container.add_child(spacer2)
	
	# Bouton principal
	var accept_button = Button.new()
	accept_button.text = "ACCEPTER ET SE REPOSER"
	accept_button.custom_minimum_size = Vector2(400, 80)
	accept_button.add_theme_font_size_override("font_size", 28)
	accept_button.add_theme_color_override("font_color", Color.WHITE)
	accept_button.flat = false
	accept_button.pressed.connect(_on_forced_rest_accepted)
	main_container.add_child(accept_button)
	
	# Ajouter le container principal
	add_child(main_container)

func _on_forced_rest_accepted():
	"""Appelé quand l'utilisateur accepte le repos forcé"""
	print("Utilisateur a accepté le repos forcé")
	
	# Maintenant seulement, démarrer le fast-forward
	if hour_slider:
		var hours = int(hour_slider.value)
		
		# Calculer l'heure de retour
		var game_time = GameTime
		var return_hour = (game_time.current_hour + hours) % 24
		
		# Émettre le signal
		fast_forward_requested.emit(return_hour, 0)

func _update_time_display(hours: int):
	time_label.text = "%dh" % hours
	
	# Calculer l'heure de retour
	var game_time = GameTime
	if game_time:
		var return_hour = (game_time.current_hour + hours) % 24
		var return_day = game_time.current_day
		if game_time.current_hour + hours >= 24:
			return_day += 1
			if return_day > 7:
				return_day = 1
		
		var day_names = ["", "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi", "Dimanche"]
		time_label.text += " (retour %s %02d:00)" % [day_names[return_day], return_hour]
	
	# Mettre à jour les informations de récupération selon la formule
	var energy_recovery_percent = 0
	if hours >= 12:
		energy_recovery_percent = 100
	elif hours >= 8:
		energy_recovery_percent = 80
	elif hours >= 6:
		energy_recovery_percent = 50
	else:
		energy_recovery_percent = hours * 8  # Approximation pour moins de 6h
	
	if energy_label:
		energy_label.text = "+%d%% énergie" % energy_recovery_percent
		# Changer la couleur selon le pourcentage
		if energy_recovery_percent >= 100:
			energy_label.modulate = Color.CYAN
		elif energy_recovery_percent >= 80:
			energy_label.modulate = Color.GREEN
		elif energy_recovery_percent >= 50:
			energy_label.modulate = Color.YELLOW
		else:
			energy_label.modulate = Color.ORANGE
	
	if bonus_label:
		bonus_label.visible = hours >= 12
		if hours >= 12:
			bonus_label.text = "✨ Récupération COMPLÈTE!"
		else:
			bonus_label.visible = false

func _on_confirmed():
	# Récupérer la valeur du slider
	if hour_slider:
		var hours = int(hour_slider.value)
		
		# Calculer l'heure de retour
		var game_time = GameTime
		var return_hour = (game_time.current_hour + hours) % 24
		
		# Émettre le signal
		fast_forward_requested.emit(return_hour, 0)

func _on_fast_forward_started():
	"""Appelé quand le fast-forward commence"""
	if time_selection_container:
		time_selection_container.visible = false
	if progress_display_container:
		progress_display_container.visible = true
	if report_container:
		report_container.visible = false
	is_showing_progress = true
	
	# Configurer les boutons
	if ok_button:
		ok_button.visible = false
	if cancel_button:
		cancel_button.text = "Annuler Fast-Forward"
		cancel_button.visible = true
	
	# Passer en mode plein écran pour le fast-forward
	mode = Window.MODE_FULLSCREEN
	
	# Ajuster la taille de la fenêtre
	_adjust_dialog_size()

func _on_fast_forward_progress(current_time: Dictionary, target_time: Dictionary, progress: float):
	"""Appelé pendant la progression du fast-forward"""
	if not is_showing_progress:
		return
	
	# Mettre à jour la barre de progression
	progress_bar.value = progress * 100
	progress_label.text = "Progression: %.0f%%" % (progress * 100)
	
	# Mettre à jour l'heure actuelle
	var current_time_label = progress_display_container.get_node_or_null("CurrentTimeLabel")
	if current_time_label:
		var day_names = ["", "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi", "Dimanche"]
		var day_name = "?"
		if current_time.day >= 0 and current_time.day < day_names.size():
			day_name = day_names[current_time.day]
		current_time_label.text = "Heure actuelle: %s %02d:%02d" % [
			day_name,
			current_time.hour,
			current_time.minute
		]

func _on_fast_forward_completed(report: Dictionary):
	"""Appelé quand le fast-forward est terminé"""
	# En mode déconnexion forcée, fermer automatiquement la fenêtre
	if is_forced_disconnect:
		print("Fast-forward forcé terminé - fermeture automatique")
		queue_free()
		return
	
	# Mode normal : afficher le rapport
	if progress_display_container:
		progress_display_container.visible = false
	if report_container:
		report_container.visible = true
	
	# Remplir le rapport
	_populate_report(report)
	
	# Revenir en mode fenêtre normale
	mode = Window.MODE_WINDOWED
	
	# Configurer les boutons
	if ok_button:
		ok_button.visible = true
		ok_button.text = "Continuer"
	if cancel_button:
		cancel_button.visible = false  # Pas d'annulation possible après completion
	
	# Ajuster la taille de la fenêtre
	_adjust_dialog_size()

func _populate_report(report: Dictionary):
	"""Remplit le rapport avec les données"""
	# Nettoyer le rapport précédent
	for child in report_container.get_children():
		if child.name != "ReportDisplay":  # Garder seulement le titre
			if child.name.ends_with("Label") and child.text.begins_with("📋"):
				continue
			child.queue_free()
	
	# Résumé principal
	var summary_label = Label.new()
	summary_label.text = report.get("summary", "Période de repos terminée")
	summary_label.add_theme_font_size_override("font_size", 14)
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report_container.add_child(summary_label)
	
	report_container.add_child(HSeparator.new())
	
	# Détails de récupération
	var recovery_title = Label.new()
	recovery_title.text = "💊 Récupération"
	recovery_title.add_theme_font_size_override("font_size", 14)
	report_container.add_child(recovery_title)
	
	var energy_info = Label.new()
	energy_info.text = "Énergie récupérée: +%.0f" % report.get("energy_recovery", 0)
	energy_info.modulate = Color.GREEN
	report_container.add_child(energy_info)
	
	# Événements manqués
	var events = report.get("events_missed", [])
	if events.size() > 0:
		report_container.add_child(HSeparator.new())
		
		var events_title = Label.new()
		events_title.text = "📰 Événements pendant votre absence"
		events_title.add_theme_font_size_override("font_size", 14)
		report_container.add_child(events_title)
		
		for event in events:
			var event_label = Label.new()
			event_label.text = "• " + str(event)
			event_label.add_theme_font_size_override("font_size", 12)
			event_label.modulate = Color(0.8, 0.8, 1.0)
			report_container.add_child(event_label)

func _on_canceled():
	"""Gérer l'annulation selon la phase"""
	# INTERDIRE l'annulation en mode déconnexion forcée
	if is_forced_disconnect:
		print("Annulation impossible - repos forcé requis")
		return
	
	if is_showing_progress and fast_forward_manager:
		# Annuler le fast-forward en cours
		fast_forward_manager.cancel_fast_forward()
		queue_free()
	else:
		# Fermer le dialogue
		queue_free()

func _on_close_requested():
	"""Gérer la tentative de fermeture de la fenêtre"""
	# INTERDIRE la fermeture en mode déconnexion forcée
	if is_forced_disconnect:
		print("Fermeture impossible - repos forcé requis")
		return
	
	# Sinon, agir comme une annulation
	_on_canceled()

func _adjust_dialog_size():
	"""Ajuste automatiquement la taille de la fenêtre selon le contenu visible"""
	# Attendre une frame pour que les changements de visibilité prennent effet
	await get_tree().process_frame
	
	# Calculer la hauteur nécessaire en comptant les containers visibles
	var needed_height = 80  # Espace pour le titre et les boutons
	var needed_width = 400
	
	# Ajouter l'espace pour chaque container visible
	if time_selection_container and time_selection_container.visible:
		needed_height += 280  # Espace réduit pour la sélection de temps
	
	if progress_display_container and progress_display_container.visible:
		needed_height += 160  # Espace réduit pour la barre de progression
	
	if report_container and report_container.visible:
		# Calculer dynamiquement selon le nombre d'éléments dans le rapport
		var report_children = report_container.get_children()
		needed_height += min(300, 40 + report_children.size() * 20)  # Réduit la taille du rapport
		needed_width = max(needed_width, 450)  # Largeur modérée pour le rapport
	
	# Limiter la hauteur maximale pour éviter que la fenêtre dépasse l'écran
	var screen_size = get_viewport().get_visible_rect().size
	needed_height = min(needed_height, screen_size.y - 150)  # Plus de marge
	
	# Appliquer la nouvelle taille sans recentrer (éviter double popup_centered)
	size = Vector2(needed_width, needed_height)
