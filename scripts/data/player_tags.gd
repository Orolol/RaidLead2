extends Resource
class_name PlayerTags

# Définition des tags et leurs conditions de découverte
enum TagCategory {
	PERSONALITY,      # Traits de personnalité de base
	BEHAVIOR,         # Comportements en jeu
	PERFORMANCE,      # Liés aux performances
	SOCIAL,          # Interactions sociales
	SPECIAL          # Tags spéciaux avec conditions
}

enum RevealCondition {
	INTEGRATION,      # Se révèle avec l'intégration
	LOOT_CONFLICT,    # Se révèle lors d'un conflit de loot
	WIPE,            # Se révèle lors d'un wipe
	SUCCESS,         # Se révèle lors d'un succès
	TIME,            # Se révèle après un certain temps
	SPECIAL_EVENT    # Se révèle lors d'événements spéciaux
}

# Base de données des tags
static var TAG_DATABASE = {
	# Traits de personnalité (visibles ou révélés rapidement)
	"ambitieux": {
		"category": TagCategory.PERSONALITY,
		"reveal_condition": RevealCondition.INTEGRATION,
		"reveal_threshold": 10,
		"visible_chance": 0.3,  # 30% de chance d'être visible au recrutement
		"description": "Cherche toujours à progresser rapidement"
	},
	"social": {
		"category": TagCategory.SOCIAL,
		"reveal_condition": RevealCondition.INTEGRATION,
		"reveal_threshold": 15,
		"visible_chance": 0.5,
		"description": "Aime interagir avec les autres membres"
	},
	"solitaire": {
		"category": TagCategory.SOCIAL,
		"reveal_condition": RevealCondition.INTEGRATION,
		"reveal_threshold": 20,
		"visible_chance": 0.4,
		"description": "Préfère jouer seul la plupart du temps"
	},
	"perfectionniste": {
		"category": TagCategory.PERSONALITY,
		"reveal_condition": RevealCondition.INTEGRATION,
		"reveal_threshold": 25,
		"visible_chance": 0.2,
		"description": "Veut que tout soit parfait"
	},
	
	# Comportements en jeu (découverts avec le temps)
	"ponctuel": {
		"category": TagCategory.BEHAVIOR,
		"reveal_condition": RevealCondition.TIME,
		"reveal_threshold": 7,  # Jours dans la guilde
		"visible_chance": 0.1,
		"description": "Toujours à l'heure pour les raids"
	},
	"retardataire": {
		"category": TagCategory.BEHAVIOR,
		"reveal_condition": RevealCondition.TIME,
		"reveal_threshold": 7,
		"visible_chance": 0.0,
		"description": "Souvent en retard aux événements"
	},
	"serviable": {
		"category": TagCategory.BEHAVIOR,
		"reveal_condition": RevealCondition.INTEGRATION,
		"reveal_threshold": 30,
		"visible_chance": 0.4,
		"description": "Aide volontiers les autres membres"
	},
	
	# Tags de performance (découverts en raid/donjon)
	"tryhard": {
		"category": TagCategory.PERFORMANCE,
		"reveal_condition": RevealCondition.SUCCESS,
		"reveal_threshold": 3,  # Nombre de succès
		"visible_chance": 0.2,
		"description": "Donne toujours le maximum"
	},
	"casual": {
		"category": TagCategory.PERFORMANCE,
		"reveal_condition": RevealCondition.INTEGRATION,
		"reveal_threshold": 40,
		"visible_chance": 0.3,
		"description": "Joue de manière décontractée"
	},
	
	# Tags problématiques (cachés, révélés dans des conditions spéciales)
	"ninja_looter": {
		"category": TagCategory.SPECIAL,
		"reveal_condition": RevealCondition.LOOT_CONFLICT,
		"reveal_threshold": 1,  # Dès le premier conflit
		"visible_chance": 0.0,  # Jamais visible au recrutement
		"description": "Prend parfois des objets sans permission"
	},
	"rage_quitter": {
		"category": TagCategory.SPECIAL,
		"reveal_condition": RevealCondition.WIPE,
		"reveal_threshold": 2,  # Après 2 wipes
		"visible_chance": 0.0,
		"description": "Quitte facilement après un échec"
	},
	"drama_queen": {
		"category": TagCategory.SPECIAL,
		"reveal_condition": RevealCondition.SPECIAL_EVENT,
		"reveal_threshold": 1,
		"visible_chance": 0.0,
		"description": "Crée des conflits dans la guilde"
	},
	"greedy": {
		"category": TagCategory.BEHAVIOR,
		"reveal_condition": RevealCondition.LOOT_CONFLICT,
		"reveal_threshold": 1,
		"visible_chance": 0.1,
		"description": "Veut toujours plus de loot"
	},
	"impatient": {
		"category": TagCategory.PERSONALITY,
		"reveal_condition": RevealCondition.WIPE,
		"reveal_threshold": 1,
		"visible_chance": 0.2,
		"description": "Supporte mal l'attente et les échecs répétés (recrutement plus difficile)"
	}
}

# Génère des tags pour un nouveau joueur
static func generate_tags_for_player() -> Dictionary:
	var visible_tags: Array = []
	var hidden_tags: Array = []
	var all_tags: Array = TAG_DATABASE.keys()
	all_tags.shuffle()

	# Sélectionne 2-4 tags visibles
	var visible_count: int = randi_range(1, 2)
	var hidden_count: int = randi_range(2, 4)

	for tag in all_tags:
		if visible_tags.size() >= visible_count and hidden_tags.size() >= hidden_count:
			break

		var tag_data: Dictionary = TAG_DATABASE[tag]
		
		# Décide si le tag est visible ou caché
		if visible_tags.size() < visible_count and randf() < tag_data.visible_chance:
			visible_tags.append(tag)
		elif hidden_tags.size() < hidden_count:
			# Évite les doublons
			if tag not in visible_tags:
				hidden_tags.append(tag)
	
	# Assure au moins 1 tag visible
	if visible_tags.is_empty() and not hidden_tags.is_empty():
		visible_tags.append(hidden_tags.pop_front())
	
	return {
		"visible": visible_tags,
		"hidden": hidden_tags,
		"reveal_progress": {}  # tag -> progress
	}

# Vérifie si un tag peut être révélé
static func can_reveal_tag(tag: String, player_data: Dictionary) -> bool:
	if not TAG_DATABASE.has(tag):
		return false
		
	var tag_info: Dictionary = TAG_DATABASE[tag]
	var progress = player_data.get("reveal_progress", {}).get(tag, 0)
	
	match tag_info.reveal_condition:
		RevealCondition.INTEGRATION:
			return player_data.get("integration", 0) >= tag_info.reveal_threshold
		RevealCondition.TIME:
			return player_data.get("days_in_guild", 0) >= tag_info.reveal_threshold
		RevealCondition.LOOT_CONFLICT:
			return player_data.get("loot_conflicts", 0) >= tag_info.reveal_threshold
		RevealCondition.WIPE:
			return player_data.get("wipes_experienced", 0) >= tag_info.reveal_threshold
		RevealCondition.SUCCESS:
			return player_data.get("raid_successes", 0) >= tag_info.reveal_threshold
		RevealCondition.SPECIAL_EVENT:
			return progress >= tag_info.reveal_threshold
			
	return false

# Obtient la description d'un tag
static func get_tag_description(tag: String) -> String:
	if TAG_DATABASE.has(tag):
		return TAG_DATABASE[tag].description
	return "Tag inconnu"

# Obtient les tags qui pourraient être révélés prochainement
static func get_potential_reveals(player_data: Dictionary) -> Array:
	var potential: Array = []
	var hidden_tags = player_data.get("hidden_tags", [])

	for tag in hidden_tags:
		if not TAG_DATABASE.has(tag):
			continue

		var tag_info: Dictionary = TAG_DATABASE[tag]
		var reveal_info: Dictionary = {
			"tag": tag,
			"condition": tag_info.reveal_condition,
			"threshold": tag_info.reveal_threshold,
			"current_progress": 0
		}
		
		match tag_info.reveal_condition:
			RevealCondition.INTEGRATION:
				reveal_info.current_progress = player_data.get("integration", 0)
			RevealCondition.TIME:
				reveal_info.current_progress = player_data.get("days_in_guild", 0)
			# etc...
		
		potential.append(reveal_info)
	
	return potential