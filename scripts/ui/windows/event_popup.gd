extends Window
class_name EventPopupWindow

const RandomEventResource = preload("res://scripts/resources/random_event.gd")
const EventChoiceResource = preload("res://scripts/resources/event_choice.gd")

var current_event: RandomEventResource = null
var choice_buttons: Array[Button] = []

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var image_container: Control = $VBoxContainer/ImageContainer
@onready var description_label: RichTextLabel = $VBoxContainer/DescriptionContainer/DescriptionLabel
@onready var choices_container: VBoxContainer = $VBoxContainer/ChoicesContainer
@onready var close_button: Button = $VBoxContainer/ButtonContainer/CloseButton

signal choice_selected(choice: EventChoiceResource)
signal popup_closed()

func _ready():
	# Configuration de la fenêtre
	set_flag(Window.FLAG_ALWAYS_ON_TOP, true)
	popup_window = true
	
	# Connexions
	close_button.pressed.connect(_on_close_button_pressed)
	close_requested.connect(_on_close_requested)
	
	# Style (sera configuré dans show_event)
	pass

func show_event(event: RandomEventResource):
	print("EventPopup: show_event appelé")
	if not event:
		print("EventPopup: Pas d'événement à afficher")
		return
	
	print("EventPopup: Affichage de l'événement: %s" % event.title)
	current_event = event
	_setup_ui()
	
	# Pause du jeu
	var game_time = GameTime
	if game_time:
		game_time.pause()
		print("EventPopup: Jeu mis en pause")
	
	# Animation d'entrée
	print("EventPopup: Centrage de la popup")
	popup_centered()
	
	# Utiliser un autre effet d'entrée car Window n'a pas modulate
	var tween = create_tween()
	tween.tween_property(self, "size", size, 0.3).from(Vector2i(10, 10))
	print("EventPopup: Animation de taille lancée")

func _setup_ui():
	if not current_event:
		return
	
	# Titre
	title_label.text = current_event.title
	title_label.add_theme_color_override("font_color", _get_title_color())
	
	# Image (optionnelle)
	_setup_image()
	
	# Description
	description_label.text = current_event.description
	description_label.fit_content = true
	
	# Choix
	_setup_choices()
	
	# Ajuster la taille de la fenêtre
	_adjust_window_size()

func _get_title_color() -> Color:
	if current_event.category == "positive":
		return Color.GREEN
	elif current_event.category == "negative":
		return Color.CORAL
	elif current_event.category == "neutral":
		return Color.WHITE
	else:
		return Color.CYAN  # Couleur par défaut

func _setup_image():
	# Supprimer l'ancienne image
	for child in image_container.get_children():
		child.queue_free()
	
	if current_event.image:
		var texture_rect = TextureRect.new()
		texture_rect.texture = current_event.image
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.custom_minimum_size = Vector2(200, 150)
		image_container.add_child(texture_rect)
		image_container.visible = true
	else:
		image_container.visible = false

func _setup_choices():
	# Nettoyer les anciens boutons
	for button in choice_buttons:
		button.queue_free()
	choice_buttons.clear()
	
	var guild_manager = GuildManager
	var player_data = {}
	var guild_data = {}
	
	if guild_manager:
		if guild_manager.guild:
			guild_data = {
				"level": guild_manager.guild.get_level(),
				"xp": guild_manager.guild.xp,
				"gold": guild_manager.guild.gold,
				"members_count": guild_manager.guild_members.size()
			}
		
		# Données du joueur principal (premier membre)
		if guild_manager.guild_members.size() > 0:
			var main_member = guild_manager.guild_members[0]
			player_data = {
				"level": main_member.personnage_niveau,
				"skill": main_member.skill,
				"energy": main_member.energy,
				"mood": main_member.mood,
				"integration": main_member.integration
			}
	
	# Créer les boutons de choix
	var available_choices = current_event.get_available_choices(player_data, guild_data)
	
	for i in range(available_choices.size()):
		var choice = available_choices[i]
		var button = Button.new()
		button.text = choice.text
		button.custom_minimum_size.y = 50
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		
		# Style du bouton selon le type de conséquence
		_style_choice_button(button, choice)
		
		# Tooltip
		button.tooltip_text = choice.get_detailed_tooltip()
		
		# Connexion
		button.pressed.connect(_on_choice_selected.bind(choice))
		
		choices_container.add_child(button)
		choice_buttons.append(button)
		
		# Raccourci clavier
		if i < 9:  # Touches 1-9
			button.shortcut = _create_number_shortcut(i + 1)
	
	# Si aucun choix disponible, ajouter un bouton de fermeture
	if available_choices.is_empty():
		var close_btn = Button.new()
		close_btn.text = "Fermer"
		close_btn.pressed.connect(_on_close_button_pressed)
		choices_container.add_child(close_btn)
		choice_buttons.append(close_btn)

func _style_choice_button(button: Button, choice: EventChoiceResource):
	# Style basé sur les conséquences du choix
	var consequences = choice.immediate_consequences
	var has_positive = false
	var has_negative = false
	
	for stat in consequences:
		var value = consequences[stat]
		if value > 0:
			has_positive = true
		elif value < 0:
			has_negative = true
	
	if has_positive and not has_negative:
		button.add_theme_color_override("font_color", Color.LIGHT_GREEN)
	elif has_negative and not has_positive:
		button.add_theme_color_override("font_color", Color.LIGHT_CORAL)
	elif has_positive and has_negative:
		button.add_theme_color_override("font_color", Color.YELLOW)

func _create_number_shortcut(number: int) -> Shortcut:
	var shortcut = Shortcut.new()
	var input_event = InputEventKey.new()
	input_event.keycode = KEY_0 + number
	shortcut.events = [input_event]
	return shortcut

func _adjust_window_size():
	# Calculer la taille nécessaire
	var base_height = 200  # Taille de base
	
	# Ajouter la hauteur des choix
	base_height += choice_buttons.size() * 60
	
	# Ajouter la hauteur de l'image si présente
	if current_event.image:
		base_height += 150
	
	# Limiter la taille
	var final_height = min(base_height, 800)
	var final_width = min(600, get_viewport().size.x * 0.8)
	
	size = Vector2(final_width, final_height)
	position = (get_viewport().size - size) / 2

func _on_choice_selected(choice: EventChoiceResource):
	print("EventPopup: Choix sélectionné - %s" % choice.text)
	
	# Animation de sortie simple
	var tween = create_tween()
	tween.tween_property(self, "size", Vector2i(10, 10), 0.2)
	await tween.finished
	
	# Reprendre le jeu
	var game_time = GameTime
	if game_time:
		game_time.resume()
	
	# Émettre le signal
	choice_selected.emit(choice)
	
	# Fermer la popup
	hide()
	queue_free()

func _on_close_button_pressed():
	_on_close_requested()

func _on_close_requested():
	# Animation de sortie simple
	var tween = create_tween()
	tween.tween_property(self, "size", Vector2i(10, 10), 0.2)
	await tween.finished
	
	# Reprendre le jeu
	var game_time = GameTime
	if game_time:
		game_time.resume()
	
	popup_closed.emit()
	hide()
	queue_free()

func _input(event):
	if not visible:
		return
		
	if event is InputEventKey and event.pressed:
		# Échap pour fermer
		if event.keycode == KEY_ESCAPE:
			_on_close_requested()
		# Touches numériques pour sélectionner les choix
		elif event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var choice_index = event.keycode - KEY_1
			if choice_index < choice_buttons.size():
				choice_buttons[choice_index].emit_signal("pressed")
