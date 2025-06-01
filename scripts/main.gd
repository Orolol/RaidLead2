extends Control

const MenuBarScript = preload("res://scripts/ui/components/menu_bar.gd")
const WindowManagerScript = preload("res://scripts/managers/window_manager.gd")

var window_manager: Node
var menu_bar: Control

var fenetre_guilde: PanelContainer = null
var fenetre_monde: PanelContainer = null
var fenetre_organisation: PanelContainer = null

func _ready():
	# Les nœuds existent déjà dans la scène
	menu_bar = $VBoxContainer/menu_bar
	window_manager = $VBoxContainer/window_manager
	
	_setup_background()
	_setup_time_display()
	_connect_menu_signals()
	_register_windows()
	_connect_windows()

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
	time_display.position = Vector2(970, 10)  # Coin supérieur droit

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

func _connect_windows():
	await get_tree().process_frame
	
	var guilde_scene = load("res://scenes/Fenetre_Guilde.tscn")
	fenetre_guilde = guilde_scene.instantiate()
	window_manager.add_child(fenetre_guilde)
	fenetre_guilde.hide()
	window_manager.windows["guilde"]["instance"] = fenetre_guilde
	
	var monde_scene = load("res://scenes/Fenetre_Monde.tscn")
	fenetre_monde = monde_scene.instantiate()
	window_manager.add_child(fenetre_monde)
	fenetre_monde.hide()
	window_manager.windows["monde"]["instance"] = fenetre_monde
	
	var organisation_scene = load("res://scenes/Fenetre_OrganisationGroupe.tscn")
	fenetre_organisation = organisation_scene.instantiate()
	window_manager.add_child(fenetre_organisation)
	fenetre_organisation.hide()
	window_manager.windows["organisation"]["instance"] = fenetre_organisation
	
	fenetre_monde.player_recruited.connect(_on_player_recruited)
	
	# Utilise le GuildManager pour initialiser les membres
	var guild_manager = get_node("/root/GuildManager")
	if guild_manager:
		fenetre_organisation.set_guild_members(guild_manager.guild_members)
	
	# Afficher la fenêtre Personnage par défaut au démarrage
	window_manager.show_window("personnage")

func _on_player_recruited(player: SimulatedPlayer):
	# Utilise le GuildManager pour ajouter le membre
	var guild_manager = get_node("/root/GuildManager")
	if guild_manager:
		guild_manager.add_member(player)
		# Actualise les fenêtres
		fenetre_guilde._refresh_member_list()
		fenetre_organisation.set_guild_members(guild_manager.guild_members)
