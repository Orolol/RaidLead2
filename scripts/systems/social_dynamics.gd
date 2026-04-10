extends Node
class_name SocialDynamics

signal relationship_formed(player1, player2, relationship_type)
signal relationship_changed(player1, player2, old_type, new_type)
signal relationship_broken(player1, player2)
signal clique_formed(members, clique_name)
signal social_conflict(player1, player2, reason)

# Types de relations possibles
enum RelationType {
	FRIEND,
	RIVAL,
	MENTOR,
	STUDENT,
	NEUTRAL,
	ROMANTIC,  # Rare mais possible
	ENEMY      # Suite à des conflits répétés
}

# Structure pour stocker les relations
var relationships: Dictionary = {}  # "player1_id:player2_id" -> RelationshipData
var cliques: Array = []  # Groupes sociaux formés
var social_graph_cache: Dictionary = {}  # Cache pour optimisation

class RelationshipData:
	var type: int = RelationType.NEUTRAL
	var strength: float = 0.0  # 0.0 à 1.0
	var history: Array = []  # Historique des interactions
	var formed_day: int = 0
	var last_interaction_day: int = 0
	
	func _init(t: int = RelationType.NEUTRAL):
		type = t
		strength = 0.3 if t != RelationType.NEUTRAL else 0.0

class Clique:
	var name: String = ""
	var members: Array = []
	var leader = null
	var formation_day: int = 0
	var cohesion: float = 0.5
	var preferred_activities: Array = []

func _ready():
	var game_time = get_node("/root/GameTime")
	if game_time:
		game_time.day_changed.connect(_on_day_changed)
		game_time.week_changed.connect(_on_week_changed)

func _on_day_changed(_day: int, _week: int, _year: int):
	_decay_relationships()
	_check_clique_cohesion()

func _on_week_changed(_week: int, _year: int):
	_evaluate_clique_formations()

# Gestion des relations

func get_relationship(player1, player2) -> RelationshipData:
	"""Obtient la relation entre deux joueurs"""
	var key = _get_relationship_key(player1, player2)
	if relationships.has(key):
		return relationships[key]
	return null

func form_relationship(player1, player2, type: int, initial_strength: float = 0.3):
	"""Forme une nouvelle relation entre deux joueurs"""
	
	if player1 == player2:
		return
	
	var key = _get_relationship_key(player1, player2)
	var existing = relationships.get(key)
	
	if existing:
		# Relation existante, vérifier si on la change
		if existing.type != type:
			var old_type = existing.type
			existing.type = type
			existing.strength = max(existing.strength, initial_strength)
			relationship_changed.emit(player1, player2, old_type, type)
		else:
			# Renforcer la relation existante
			existing.strength = min(1.0, existing.strength + 0.1)
	else:
		# Nouvelle relation
		var rel = RelationshipData.new(type)
		rel.strength = initial_strength
		rel.formed_day = _get_current_day()
		rel.last_interaction_day = rel.formed_day
		relationships[key] = rel
		relationship_formed.emit(player1, player2, type)
	
	# Invalider le cache
	_invalidate_cache()

func strengthen_relationship(player1, player2, amount: float = 0.1):
	"""Renforce une relation existante"""
	var rel = get_relationship(player1, player2)
	if rel:
		rel.strength = min(1.0, rel.strength + amount)
		rel.last_interaction_day = _get_current_day()
		_add_interaction_history(rel, "strengthen", amount)

func weaken_relationship(player1, player2, amount: float = 0.1):
	"""Affaiblit une relation existante"""
	var rel = get_relationship(player1, player2)
	if rel:
		rel.strength = max(0.0, rel.strength - amount)
		rel.last_interaction_day = _get_current_day()
		_add_interaction_history(rel, "weaken", -amount)
		
		# Si la relation devient trop faible, la briser
		if rel.strength < 0.1:
			break_relationship(player1, player2)

func break_relationship(player1, player2):
	"""Brise une relation entre deux joueurs"""
	var key = _get_relationship_key(player1, player2)
	if relationships.has(key):
		relationships.erase(key)
		relationship_broken.emit(player1, player2)
		_invalidate_cache()

func transform_relationship(player1, player2, new_type: int):
	"""Transforme une relation en un autre type"""
	var rel = get_relationship(player1, player2)
	if rel:
		var old_type = rel.type
		rel.type = new_type
		relationship_changed.emit(player1, player2, old_type, new_type)
		_add_interaction_history(rel, "transform", new_type)

# Requêtes sociales

func get_friends(player) -> Array:
	"""Retourne tous les amis d'un joueur"""
	return _get_relations_of_type(player, RelationType.FRIEND)

func get_rivals(player) -> Array:
	"""Retourne tous les rivaux d'un joueur"""
	return _get_relations_of_type(player, RelationType.RIVAL)

func get_online_friends(player) -> Array:
	"""Retourne les amis en ligne d'un joueur"""
	var friends = get_friends(player)
	var online_friends = []
	
	for friend in friends:
		if friend.is_online:
			online_friends.append(friend)
	
	return online_friends

func get_social_circle(player) -> Array:
	"""Retourne le cercle social complet d'un joueur"""
	var circle = []
	
	for key in relationships:
		var players = key.split(":")
		if player.get_instance_id() == int(players[0]) or player.get_instance_id() == int(players[1]):
			var other_id = int(players[0]) if player.get_instance_id() == int(players[1]) else int(players[1])
			var other = _get_player_by_id(other_id)
			if other and other not in circle:
				circle.append(other)
	
	return circle

func get_influence_on_player(player) -> float:
	"""Calcule l'influence sociale totale sur un joueur"""
	var influence = 0.0
	var relations = get_social_circle(player)
	
	for other in relations:
		var rel = get_relationship(player, other)
		if rel:
			var base_influence = rel.strength
			
			# Modifier selon le type de relation
			match rel.type:
				RelationType.FRIEND:
					influence += base_influence * 1.2
				RelationType.MENTOR:
					influence += base_influence * 1.5
				RelationType.RIVAL:
					influence += base_influence * 0.8
				RelationType.ENEMY:
					influence -= base_influence * 0.5
	
	return clamp(influence, -1.0, 3.0)

func are_friends(player1, player2) -> bool:
	"""Vérifie si deux joueurs sont amis"""
	var rel = get_relationship(player1, player2)
	return rel != null and rel.type == RelationType.FRIEND

func are_rivals(player1, player2) -> bool:
	"""Vérifie si deux joueurs sont rivaux"""
	var rel = get_relationship(player1, player2)
	return rel != null and rel.type == RelationType.RIVAL

# Gestion des cliques

func form_clique(members: Array, name: String = ""):
	"""Forme une nouvelle clique"""
	
	if members.size() < 3:
		return  # Besoin d'au moins 3 membres
	
	var clique = Clique.new()
	clique.members = members.duplicate()
	clique.name = name if name != "" else _generate_clique_name()
	clique.formation_day = _get_current_day()
	
	# Déterminer le leader (plus haute influence sociale)
	var max_influence = -1.0
	for member in members:
		var influence = get_influence_on_player(member)
		if influence > max_influence:
			max_influence = influence
			clique.leader = member
	
	# Renforcer les relations entre membres
	for i in range(members.size()):
		for j in range(i + 1, members.size()):
			if not are_friends(members[i], members[j]):
				form_relationship(members[i], members[j], RelationType.FRIEND, 0.4)
			else:
				strengthen_relationship(members[i], members[j], 0.2)
	
	cliques.append(clique)
	clique_formed.emit(members, clique.name)

func get_player_cliques(player) -> Array:
	"""Retourne toutes les cliques dont fait partie un joueur"""
	var player_cliques = []
	
	for clique in cliques:
		if player in clique.members:
			player_cliques.append(clique)
	
	return player_cliques

func is_in_same_clique(player1, player2) -> bool:
	"""Vérifie si deux joueurs sont dans la même clique"""
	for clique in cliques:
		if player1 in clique.members and player2 in clique.members:
			return true
	return false

func update_clique_cohesion(clique: Clique, delta: float):
	"""Met à jour la cohésion d'une clique"""
	clique.cohesion = clamp(clique.cohesion + delta, 0.0, 1.0)
	
	# Si la cohésion devient trop faible, dissoudre la clique
	if clique.cohesion < 0.2:
		dissolve_clique(clique)

func dissolve_clique(clique: Clique):
	"""Dissout une clique"""
	
	# Affaiblir les relations entre membres
	for i in range(clique.members.size()):
		for j in range(i + 1, clique.members.size()):
			weaken_relationship(clique.members[i], clique.members[j], 0.3)
	
	cliques.erase(clique)

# Conflits sociaux

func trigger_social_conflict(player1, player2, reason: String):
	"""Déclenche un conflit social entre deux joueurs"""
	
	social_conflict.emit(player1, player2, reason)
	
	var rel = get_relationship(player1, player2)
	if rel:
		match rel.type:
			RelationType.FRIEND:
				# Les amis peuvent se réconcilier
				weaken_relationship(player1, player2, 0.3)
				if randf() < 0.3:  # 30% chance de devenir rivaux
					transform_relationship(player1, player2, RelationType.RIVAL)
			
			RelationType.NEUTRAL:
				# Peuvent devenir ennemis
				if randf() < 0.5:
					form_relationship(player1, player2, RelationType.ENEMY, 0.4)
			
			RelationType.RIVAL:
				# Renforce la rivalité
				strengthen_relationship(player1, player2, 0.2)
				if rel.strength > 0.8 and randf() < 0.2:
					# Peut devenir ennemi si rivalité intense
					transform_relationship(player1, player2, RelationType.ENEMY)
	else:
		# Pas de relation, créer une relation négative
		form_relationship(player1, player2, RelationType.RIVAL, 0.3)
	
	# Impact sur les cliques
	if is_in_same_clique(player1, player2):
		var cliques_affectees = get_player_cliques(player1)
		for clique in cliques_affectees:
			if player2 in clique.members:
				update_clique_cohesion(clique, -0.2)

func mediate_conflict(mediator, player1, player2) -> bool:
	"""Un médiateur tente de résoudre un conflit"""
	
	# Le médiateur doit avoir de bonnes relations avec les deux
	var rel1 = get_relationship(mediator, player1)
	var rel2 = get_relationship(mediator, player2)
	
	if not rel1 or not rel2:
		return false
	
	if rel1.type != RelationType.FRIEND or rel2.type != RelationType.FRIEND:
		return false
	
	# Chance de succès basée sur la force des relations
	var success_chance = (rel1.strength + rel2.strength) / 2.0
	
	if randf() < success_chance:
		# Médiation réussie
		var conflict_rel = get_relationship(player1, player2)
		if conflict_rel:
			if conflict_rel.type == RelationType.ENEMY:
				transform_relationship(player1, player2, RelationType.NEUTRAL)
			elif conflict_rel.type == RelationType.RIVAL:
				weaken_relationship(player1, player2, 0.3)
			else:
				strengthen_relationship(player1, player2, 0.2)
		else:
			form_relationship(player1, player2, RelationType.NEUTRAL, 0.2)
		
		# Renforcer les relations avec le médiateur
		strengthen_relationship(mediator, player1, 0.1)
		strengthen_relationship(mediator, player2, 0.1)
		
		return true
	
	return false

# Méthodes privées

func _get_relationship_key(player1, player2) -> String:
	"""Génère une clé unique pour une relation"""
	var id1 = player1.get_instance_id()
	var id2 = player2.get_instance_id()
	
	# Toujours mettre le plus petit ID en premier pour cohérence
	if id1 < id2:
		return "%d:%d" % [id1, id2]
	else:
		return "%d:%d" % [id2, id1]

func _get_relations_of_type(player, type: int) -> Array:
	"""Retourne toutes les relations d'un type donné"""
	var relations = []
	
	for key in relationships:
		var rel = relationships[key]
		if rel.type != type:
			continue
		
		var players = key.split(":")
		if player.get_instance_id() == int(players[0]) or player.get_instance_id() == int(players[1]):
			var other_id = int(players[0]) if player.get_instance_id() == int(players[1]) else int(players[1])
			var other = _get_player_by_id(other_id)
			if other:
				relations.append(other)
	
	return relations

func _get_player_by_id(id: int):
	"""Retrouve un joueur par son ID"""
	var guild_manager = get_node("/root/GuildManager")
	if guild_manager:
		for member in guild_manager.guild_members:
			if member.get_instance_id() == id:
				return member
	return null

func _get_current_day() -> int:
	"""Obtient le jour actuel du jeu"""
	var game_time = get_node("/root/GameTime")
	if game_time:
		return game_time.current_day
	return 0

func _add_interaction_history(rel: RelationshipData, interaction_type: String, value):
	"""Ajoute une interaction à l'historique"""
	rel.history.append({
		"type": interaction_type,
		"value": value,
		"day": _get_current_day()
	})
	
	# Limiter l'historique à 50 entrées
	if rel.history.size() > 50:
		rel.history.pop_front()

func _decay_relationships():
	"""Fait décroître les relations non entretenues"""
	var current_day = _get_current_day()
	
	for key in relationships:
		var rel = relationships[key]
		var days_since_interaction = current_day - rel.last_interaction_day
		
		# Décroissance après 7 jours sans interaction
		if days_since_interaction > 7:
			var decay_amount = 0.01 * (days_since_interaction - 7)
			rel.strength = max(0.0, rel.strength - decay_amount)
			
			# Les relations neutres disparaissent plus vite
			if rel.type == RelationType.NEUTRAL and rel.strength < 0.05:
				var players = key.split(":")
				var player1 = _get_player_by_id(int(players[0]))
				var player2 = _get_player_by_id(int(players[1]))
				if player1 and player2:
					break_relationship(player1, player2)

func _check_clique_cohesion():
	"""Vérifie la cohésion des cliques"""
	for clique in cliques:
		var total_strength = 0.0
		var relation_count = 0
		
		# Calculer la force moyenne des relations dans la clique
		for i in range(clique.members.size()):
			for j in range(i + 1, clique.members.size()):
				var rel = get_relationship(clique.members[i], clique.members[j])
				if rel:
					total_strength += rel.strength
					relation_count += 1
		
		if relation_count > 0:
			var avg_strength = total_strength / relation_count
			var new_cohesion = avg_strength * 0.8 + clique.cohesion * 0.2
			update_clique_cohesion(clique, new_cohesion - clique.cohesion)

func _evaluate_clique_formations():
	"""Évalue si de nouvelles cliques peuvent se former"""
	var guild_manager = get_node("/root/GuildManager")
	if not guild_manager:
		return
	
	# Chercher des groupes d'amis proches
	for member in guild_manager.guild_members:
		var friends = get_friends(member)
		if friends.size() >= 2:
			# Vérifier si ces amis sont aussi amis entre eux
			var potential_clique = [member]
			
			for friend in friends:
				var friend_of_friends = true
				for other_friend in potential_clique:
					if other_friend != friend and not are_friends(friend, other_friend):
						friend_of_friends = false
						break
				
				if friend_of_friends:
					potential_clique.append(friend)
				
				if potential_clique.size() >= 4:
					break  # Limiter la taille des cliques
			
			# Former la clique si conditions remplies
			if potential_clique.size() >= 3:
				var already_in_clique = false
				for existing_clique in cliques:
					var members_in_common = 0
					for potential_member in potential_clique:
						if potential_member in existing_clique.members:
							members_in_common += 1
					
					if members_in_common >= potential_clique.size() - 1:
						already_in_clique = true
						break
				
				if not already_in_clique and randf() < 0.3:  # 30% chance par semaine
					form_clique(potential_clique)

func _generate_clique_name() -> String:
	"""Génère un nom pour une clique"""
	var prefixes = ["Les", "La bande des", "Team", "Squad", "Groupe"]
	var suffixes = ["Elite", "Legends", "Warriors", "Raiders", "Bros", "United"]
	
	return prefixes[randi() % prefixes.size()] + " " + suffixes[randi() % suffixes.size()]

func _invalidate_cache():
	"""Invalide le cache du graphe social"""
	social_graph_cache.clear()