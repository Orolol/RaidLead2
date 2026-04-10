class_name RandomEventResource
extends Resource

const EventChoiceResource = preload("res://scripts/resources/event_choice.gd")

@export var id: String = ""
@export var title: String = ""
@export var description: String = ""
@export var image: Texture2D = null

# Système MTTH (Mean Time To Happen)
@export var mtth: float = 168.0  # En heures (168h = 1 semaine par défaut)
@export var weight: float = 1.0  # Poids relatif pour la sélection

# Gestion des occurrences
@export var cooldown: float = 0.0  # Temps minimum avant répétition (en heures)
@export var max_occurrences: int = -1  # -1 = illimité
@export var one_time_only: bool = false

# Conditions pour que l'événement soit éligible
@export var conditions: Array = []  # Array[Dictionary] - temporarily untyped for compatibility

# Navigation dans l'arbre d'événements
@export var event_chain_id: String = ""  # ID de la chaîne d'événements
@export var chain_position: int = 0  # Position dans la chaîne (0 = début)

# Choix disponibles pour le joueur
@export var choices: Array = []  # Array[EventChoiceResource] - temporarily untyped for compatibility

# Catégorie de l'événement
@export var category: String = "general"
@export var tags: Array = []  # Array[String] - temporarily untyped for compatibility

func _init():
	pass

func is_eligible(game_state: Dictionary = {}) -> bool:
	# Vérifier les conditions d'éligibilité
	for condition_data in conditions:
		if not _evaluate_condition(condition_data, game_state):
			return false
	
	return true

func _evaluate_condition(condition_data: Dictionary, game_state: Dictionary) -> bool:
	var condition_type = condition_data.get("type", "")
	var condition_value = condition_data.get("value", null)
	
	match condition_type:
		"guild_level":
			var guild_manager = Engine.get_singleton("GuildManager")
			if guild_manager and guild_manager.guild:
				var current_level = guild_manager.guild.get_level()
				return _check_value_condition(current_level, condition_value)
		
		"guild_members_count":
			var guild_manager = Engine.get_singleton("GuildManager")
			if guild_manager:
				var member_count = guild_manager.guild_members.size()
				return _check_value_condition(member_count, condition_value)
		
		"time_of_day":
			var game_time = Engine.get_singleton("GameTime")
			if game_time:
				return _check_value_condition(game_time.current_hour, condition_value)
		
		"day_of_week":
			var game_time = Engine.get_singleton("GameTime")
			if game_time:
				return _check_value_condition(game_time.current_day, condition_value)
		
		"server_version":
			var server_version = Engine.get_singleton("ServerVersion")
			if server_version:
				return server_version.current_version == condition_value
		
		"has_active_effect":
			# Vérifier si un effet spécifique est actif sur la guilde ou un joueur
			var effect_system = Engine.get_singleton("EffectSystem")
			var guild_manager = Engine.get_singleton("GuildManager")
			
			if effect_system and guild_manager:
				if guild_manager.guild and guild_manager.guild.has_effect(condition_value):
					return true
				
				for member in guild_manager.guild_members:
					if member.has_effect(condition_value):
						return true
			
			return false
		
		"random":
			# Condition aléatoire (probabilité)
			return randf() <= condition_value
		
		_:
			print("Condition inconnue: %s" % condition_type)
			return true
	
	return true

func _check_value_condition(actual_value, condition_value) -> bool:
	if typeof(condition_value) == TYPE_DICTIONARY:
		var operator = condition_value.get("op", ">=")
		var value = condition_value.get("value", 0)
		
		match operator:
			">=": return actual_value >= value
			"<=": return actual_value <= value
			">": return actual_value > value
			"<": return actual_value < value
			"==": return actual_value == value
			"!=": return actual_value != value
			"in": return actual_value in value
			"not_in": return actual_value not in value
		
		return false
	else:
		return actual_value >= condition_value

func get_available_choices(player_data: Dictionary = {}, guild_data: Dictionary = {}) -> Array:
	var available_choices = []
	
	for choice in choices:
		if choice.is_available(player_data, guild_data):
			available_choices.append(choice)
	
	return available_choices

func calculate_probability(delta_hours: float) -> float:
	# Formule MTTH: probabilité = 1 - e^(-delta_time / MTTH)
	if mtth <= 0:
		return 0.0
	
	return 1.0 - exp(-delta_hours / mtth)

func get_display_data() -> Dictionary:
	return {
		"id": id,
		"title": title,
		"description": description,
		"image": image,
		"choices": get_available_choices(),
		"category": category,
		"chain_id": event_chain_id,
		"chain_position": chain_position
	}

func get_tooltip() -> String:
	var tooltip = "[b]%s[/b]\n%s" % [title, description]
	
	if event_chain_id != "":
		tooltip += "\n[color=yellow]Partie %d de la chaîne '%s'[/color]" % [chain_position + 1, event_chain_id]
	
	if category != "general":
		tooltip += "\n[color=gray]Catégorie: %s[/color]" % category
	
	if tags.size() > 0:
		tooltip += "\n[color=gray]Tags: %s[/color]" % ", ".join(tags)
	
	return tooltip
