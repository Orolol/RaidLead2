class_name EventChoiceResource
extends Resource

const EffectResource = preload("res://scripts/resources/effect.gd")

@export var id: String = ""
@export var text: String = ""
@export var tooltip: String = ""
@export var icon: Texture2D = null

# Conditions pour que ce choix soit disponible
@export var requirements: Dictionary = {}  # condition_name -> required_value

# Effets immédiats du choix
@export var immediate_consequences: Dictionary = {}  # stat_name -> modification
@export var effects_to_apply: Array = []  # Array[EffectResource] - Effets à appliquer

# Navigation dans l'arbre d'événements
@export var follow_up_event_id: String = ""  # Prochain événement de la chaîne
@export var ends_chain: bool = false  # Termine la chaîne d'événements

# Probabilités de conséquences
@export var random_consequences: Array = []  # Array[Dictionary] - {probability, consequence}

func _init():
	pass

func is_available(player_data: Dictionary = {}, guild_data: Dictionary = {}) -> bool:
	for requirement in requirements.keys():
		var required_value = requirements[requirement]
		
		# Vérifier les conditions sur le joueur
		if requirement.begins_with("player_"):
			var stat = requirement.substr(7)  # Enlever "player_"
			var player_value = player_data.get(stat, 0)
			if not _check_condition(player_value, required_value):
				return false
		
		# Vérifier les conditions sur la guilde
		elif requirement.begins_with("guild_"):
			var stat = requirement.substr(6)  # Enlever "guild_"
			var guild_value = guild_data.get(stat, 0)
			if not _check_condition(guild_value, required_value):
				return false
		
		# Vérifier d'autres conditions générales
		else:
			match requirement:
				"time_of_day":
					var game_time = Engine.get_singleton("GameTime")
					if game_time and not _check_condition(game_time.current_hour, required_value):
						return false
				
				"day_of_week":
					var game_time = Engine.get_singleton("GameTime")
					if game_time and not _check_condition(game_time.current_day, required_value):
						return false
				
				"has_effect":
					# Vérifier si un effet spécifique est actif
					pass  # À implémenter selon les besoins
	
	return true

func _check_condition(actual_value, required_condition) -> bool:
	if typeof(required_condition) == TYPE_DICTIONARY:
		# Condition complexe avec opérateurs
		var operator = required_condition.get("op", ">=")
		var value = required_condition.get("value", 0)
		
		match operator:
			">=": return actual_value >= value
			"<=": return actual_value <= value
			">": return actual_value > value
			"<": return actual_value < value
			"==": return actual_value == value
			"!=": return actual_value != value
			"in": return actual_value in value  # value doit être un Array
			"not_in": return actual_value not in value
		
		return false
	else:
		# Condition simple (égalité ou minimum)
		return actual_value >= required_condition

func get_detailed_tooltip() -> String:
	var detailed_tooltip = text
	
	if tooltip != "":
		detailed_tooltip += "\n\n" + tooltip
	
	# Ajouter les conséquences immédiates
	if immediate_consequences.size() > 0:
		detailed_tooltip += "\n\n[b]Conséquences immédiates:[/b]"
		for consequence in immediate_consequences:
			var value = immediate_consequences[consequence]
			var sign_str = "+" if value > 0 else ""
			detailed_tooltip += "\n  %s: %s%s" % [consequence, sign_str, str(value)]
	
	# Ajouter les effets
	if effects_to_apply.size() > 0:
		detailed_tooltip += "\n\n[b]Effets appliqués:[/b]"
		for effect in effects_to_apply:
			detailed_tooltip += "\n  " + effect.name
			if effect.duration > 0:
				detailed_tooltip += " (%.1fh)" % effect.duration
	
	# Ajouter les conséquences aléatoires
	if random_consequences.size() > 0:
		detailed_tooltip += "\n\n[b]Conséquences possibles:[/b]"
		for random_consequence in random_consequences:
			var probability = random_consequence.get("probability", 0)
			var consequence = random_consequence.get("consequence", {})
			detailed_tooltip += "\n  %d%% chance: %s" % [probability * 100, str(consequence)]
	
	# Indiquer si cela continue la chaîne
	if follow_up_event_id != "":
		detailed_tooltip += "\n\n[color=yellow]Continue l'histoire...[/color]"
	elif ends_chain:
		detailed_tooltip += "\n\n[color=gray]Termine l'histoire.[/color]"
	
	return detailed_tooltip

func apply_consequences() -> Dictionary:
	var results = {
		"immediate": immediate_consequences.duplicate(),
		"effects": effects_to_apply.duplicate(),
		"random": null
	}
	
	# Appliquer les conséquences aléatoires
	if random_consequences.size() > 0:
		for random_consequence in random_consequences:
			var probability = random_consequence.get("probability", 0)
			if randf() <= probability:
				results.random = random_consequence.get("consequence", {})
				break
	
	return results