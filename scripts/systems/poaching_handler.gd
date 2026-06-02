extends Node
class_name PoachingHandler

## Gère les tentatives de débauchage par les guildes IA

const AIGuildScript = preload("res://scripts/resources/ai_guild.gd")

signal counter_offer_result(member, accepted: bool)

func _ready() -> void:
	_connect_to_ai_guild_manager()

func _connect_to_ai_guild_manager() -> void:
	"""Se connecte au AIGuildManager une fois qu'il est prêt"""
	if AIGuildManager:
		if not AIGuildManager.is_connected("poaching_attempt", _on_poaching_attempt):
			AIGuildManager.connect("poaching_attempt", _on_poaching_attempt)
		GameLog.d("PoachingHandler connecté au AIGuildManager")

func _on_poaching_attempt(target_member: SimulatedPlayer, source_guild: AIGuildScript, success: bool) -> void:
	"""Gère les tentatives de débauchage par les guildes IA"""
	if target_member not in GuildManager.guild_members:
		return

	# Ne pas traiter les tentatives sur le personnage du joueur
	if target_member.get_meta("is_player", false):
		return

	if success:
		GameLog.d("ALERTE DE DEBAUCHAGE: %s tente de recruter %s !" % [source_guild.name, target_member.nom])
		_show_poaching_popup(target_member, source_guild)
	else:
		GameLog.d("Tentative de débauchage échouée: %s a refusé l'offre de %s" % [target_member.nom, source_guild.name])

func _show_poaching_popup(member: SimulatedPlayer, source_guild: AIGuildScript) -> void:
	"""Affiche le popup de gestion de débauchage"""
	var poaching_popup_scene: Resource = load("res://scripts/ui/windows/poaching_popup.gd")
	var popup := Window.new()
	popup.set_script(poaching_popup_scene)

	get_tree().root.add_child(popup)

	popup.connect("counter_offer_made", _on_counter_offer_made)
	popup.connect("member_released", _on_member_released_to_poaching)
	popup.connect("poaching_ignored", _on_poaching_ignored)

	var offer: Dictionary = _generate_poaching_offer(source_guild, member)
	popup.show_poaching_attempt(member, source_guild, offer)

func _generate_poaching_offer(source_guild: AIGuildScript, member: SimulatedPlayer) -> Dictionary:
	"""Génère une offre de débauchage réaliste"""
	var offer: Dictionary = {}

	match source_guild.ai_strategy:
		AIGuildScript.Strategy.HARDCORE:
			offer["equipment_bonus"] = randi_range(20, 50)
		AIGuildScript.Strategy.AGGRESSIVE:
			offer["equipment_bonus"] = randi_range(15, 40)
		AIGuildScript.Strategy.BALANCED:
			offer["equipment_bonus"] = randi_range(10, 25)
		_:
			offer["equipment_bonus"] = randi_range(5, 20)

	offer["guaranteed_raid_spot"] = source_guild.ai_strategy in [AIGuildScript.Strategy.HARDCORE, AIGuildScript.Strategy.AGGRESSIVE]
	offer["leadership_role"] = member.skill > 85 and randf() < 0.3

	match source_guild.ai_strategy:
		AIGuildScript.Strategy.HARDCORE:
			offer["message"] = "Rejoignez l'élite et prouvez votre valeur !"
		AIGuildScript.Strategy.AGGRESSIVE:
			offer["message"] = "Nous offrons ce que votre guilde actuelle ne peut pas."
		AIGuildScript.Strategy.BALANCED:
			offer["message"] = "Venez progresser dans un environnement équilibré."
		AIGuildScript.Strategy.DEFENSIVE:
			offer["message"] = "Nous valorisons la stabilité et la loyauté."
		AIGuildScript.Strategy.CASUAL:
			offer["message"] = "Rejoignez une guilde détendue et amicale."

	return offer

func _on_counter_offer_made(member: SimulatedPlayer, counter_offer: Dictionary) -> void:
	"""Gère les contre-offres du joueur"""
	GameLog.d("Contre-offre envoyée pour %s: %s" % [member.nom, str(counter_offer)])

	if counter_offer.get("salary_increase", 0) > 0:
		member.mood = min(100.0, member.mood + 10.0)
		GameLog.d("Prime de fidélité accordée à %s" % member.nom)

func _on_member_released_to_poaching(member: SimulatedPlayer) -> void:
	"""Gère le départ d'un membre suite à un débauchage"""
	GameLog.d("%s quitte la guilde suite au débauchage" % member.nom)

	GuildManager.remove_member(member, false)

	for other_member in GuildManager.guild_members:
		if other_member != member and not other_member.get_meta("is_player", false):
			other_member.mood = max(0.0, other_member.mood - 5.0)
			other_member.integration = max(0.0, other_member.integration - 3.0)

	GameLog.d("Le moral de l'équipe a été affecté par le départ de %s" % member.nom)

func _on_poaching_ignored() -> void:
	"""Gère l'ignorance d'une tentative de débauchage"""
	GameLog.d("Tentative de débauchage ignorée")
