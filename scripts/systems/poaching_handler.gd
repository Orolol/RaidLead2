extends Node
class_name PoachingHandler

## Gère les tentatives de débauchage par les guildes IA

const AIGuildScript = preload("res://scripts/resources/ai_guild.gd")

signal counter_offer_result(member, accepted: bool)

## Contexte des tentatives en attente de décision joueur : member -> source_guild.
## Permet de savoir vers quelle guilde IA le membre part réellement, une fois la
## décision rendue (le popup ne renvoie que le membre).
var _pending_poaching: Dictionary = {}

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

	# Garde anti-concurrence : une tentative est déjà en attente de décision pour ce
	# membre. En ouvrir une 2e écraserait _pending_poaching[member] (clé unique par
	# membre) et pourrait aboutir à un « départ vers le néant » (retrait sans guilde IA).
	if _pending_poaching.has(target_member):
		GameLog.d("Tentative de débauchage ignorée: %s a déjà une décision en attente" % target_member.nom)
		return

	if success:
		GameLog.d("ALERTE DE DEBAUCHAGE: %s tente de recruter %s !" % [source_guild.name, target_member.nom])
		_show_poaching_popup(target_member, source_guild)
	else:
		GameLog.d("Tentative de débauchage échouée: %s a refusé l'offre de %s" % [target_member.nom, source_guild.name])

func _show_poaching_popup(member: SimulatedPlayer, source_guild: AIGuildScript) -> void:
	"""Affiche le popup de gestion de débauchage (le membre est ENCORE dans la guilde).

	On mémorise le contexte (member -> source_guild) pour pouvoir finaliser le départ
	vers la bonne guilde IA si le joueur laisse partir le membre ou si la contre-offre
	échoue. Aucune mutation du roster ici : tout est différé à la décision du joueur."""
	_pending_poaching[member] = source_guild

	var poaching_popup_scene: Resource = load("res://scripts/ui/windows/poaching_popup.gd")
	var popup := Window.new()
	popup.set_script(poaching_popup_scene)

	get_tree().root.add_child(popup)

	popup.connect("counter_offer_made", _on_counter_offer_made)
	popup.connect("member_released", _on_member_released_to_poaching)
	popup.connect("poaching_ignored", _on_poaching_ignored)
	# Nettoyage du contexte si le popup se ferme sans départ (membre conservé).
	popup.tree_exited.connect(_on_poaching_popup_closed.bind(member))

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
	"""Gère les contre-offres du joueur (journalisation uniquement).

	Le membre reste dans la guilde à ce stade : le popup résout ensuite si la guilde
	IA abandonne (membre conservé) ou insiste (départ éventuel relayé via member_released).
	Les bénéfices de la contre-offre (dont la prime de fidélité : moral) sont appliqués
	une seule fois par le popup via _apply_counter_offer_benefits() ; ne pas les
	dupliquer ici sous peine de doubler le gain de moral."""
	GameLog.d("Contre-offre envoyée pour %s: %s" % [member.nom, str(counter_offer)])

func _on_member_released_to_poaching(member: SimulatedPlayer) -> void:
	"""Effectue le départ RÉEL d'un membre suite à un débauchage.

	C'est le seul chemin qui mute le roster : retrait du membre + ajout à la guilde IA
	source mémorisée. Déclenché quand le joueur laisse partir le membre, ou quand la
	contre-offre/ignorance aboutit au départ (logique de probabilité dans le popup)."""
	if member == null:
		return

	# Garde : le personnage joueur n'est jamais débauché.
	if member.get_meta("is_player", false):
		_pending_poaching.erase(member)
		return

	# Idempotence : membre déjà parti (fantôme) -> ne rien faire.
	if member not in GuildManager.guild_members:
		_pending_poaching.erase(member)
		return

	GameLog.d("%s quitte la guilde suite au débauchage" % member.nom)

	var source_guild: AIGuildScript = _pending_poaching.get(member, null)
	if source_guild != null:
		# Retrait + ajout à la guilde IA gérés atomiquement côté AIGuildManager.
		AIGuildManager.finalize_poaching_departure(member, source_guild)
	else:
		# Pas de guilde source connue (cas dégénéré) : retrait simple.
		GuildManager.remove_member(member, false)

	_pending_poaching.erase(member)

	for other_member in GuildManager.guild_members:
		if other_member != member and not other_member.get_meta("is_player", false):
			other_member.mood = max(0.0, other_member.mood - 5.0)
			other_member.integration = max(0.0, other_member.integration - 3.0)

	GameLog.d("Le moral de l'équipe a été affecté par le départ de %s" % member.nom)

func _on_poaching_ignored() -> void:
	"""Gère l'ignorance d'une tentative de débauchage (signal réservé / extension future)."""
	GameLog.d("Tentative de débauchage ignorée")

func _on_poaching_popup_closed(member: SimulatedPlayer) -> void:
	"""Nettoie le contexte si le popup se ferme sans départ (membre conservé)."""
	_pending_poaching.erase(member)
