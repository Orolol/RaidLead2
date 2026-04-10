class_name EventsData
extends Resource

# Base de données des événements aléatoires

const RandomEventResource = preload("res://scripts/resources/random_event.gd")
const EventChoiceResource = preload("res://scripts/resources/event_choice.gd")
const EffectsDataResource = preload("res://scripts/data/effects_data.gd")

static func get_all_events() -> Array:
	var events: Array = []
	
	events.append(_create_member_dispute())
	events.append(_create_generous_donor())
	events.append(_create_server_update())
	events.append(_create_training_opportunity())
	events.append(_create_rival_guild_challenge())
	events.append(_create_member_injury())
	events.append(_create_lucky_drop())
	events.append(_create_recruitment_boost())
	
	# Chaîne d'événements: Le mystérieux bienfaiteur
	events.append(_create_mysterious_benefactor_1())
	events.append(_create_mysterious_benefactor_2a())
	events.append(_create_mysterious_benefactor_2b())
	events.append(_create_mysterious_benefactor_3a())
	events.append(_create_mysterious_benefactor_3b())
	
	return events

static func get_event_by_id(event_id: String):
	var all_events = get_all_events()
	
	for event in all_events:
		if event.id == event_id:
			return event
	
	return null

# Événements simples

static func _create_member_dispute():
	var event = RandomEventResource.new()
	event.id = "member_dispute"
	event.title = "Dispute entre membres"
	event.description = "Deux membres de la guilde se disputent à propos de la distribution du loot lors du dernier raid. La tension est palpable et cela affecte l'ambiance générale."
	event.mtth = 168.0  # 1 semaine
	event.weight = 1.0
	event.category = "social"
	event.tags = ["conflict", "loot", "mood"]
	
	# Conditions: Au moins 2 membres dans la guilde
	event.conditions = [{
		"type": "guild_members_count",
		"value": {"op": ">=", "value": 2}
	}]
	
	# Choix 1: Intervenir fermement
	var choice1 = EventChoiceResource.new()
	choice1.id = "intervene_firmly"
	choice1.text = "Intervenir fermement"
	choice1.tooltip = "Réprimander les deux membres et imposer une solution."
	choice1.immediate_consequences = {
		"all_members_mood": -10.0
	}
	choice1.effects_to_apply = [EffectsDataResource.get_effect_by_id("integration_bonus")]
	choice1.ends_chain = true
	
	# Choix 2: Laisser faire
	var choice2 = EventChoiceResource.new()
	choice2.id = "let_it_be"
	choice2.text = "Laisser faire"
	choice2.tooltip = "Espérer que ça se tasse tout seul."
	choice2.random_consequences = [{
		"probability": 0.3,
		"consequence": {"random_member_leave": true}
	}]
	choice2.effects_to_apply = [EffectsDataResource.get_effect_by_id("morale_penalty")]
	choice2.ends_chain = true
	
	# Choix 3: Organiser une activité fun
	var choice3 = EventChoiceResource.new()
	choice3.id = "organize_fun"
	choice3.text = "Organiser une activité fun"
	choice3.tooltip = "Dépenser de l'or pour organiser une activité qui remonte le moral."
	choice3.requirements = {"guild_gold": {"op": ">=", "value": 100}}
	choice3.immediate_consequences = {
		"guild_gold": -100,
		"all_members_mood": 25.0
	}
	choice3.effects_to_apply = [EffectsDataResource.get_effect_by_id("morale_boost")]
	choice3.ends_chain = true
	
	event.choices = [choice1, choice2, choice3]
	return event

static func _create_generous_donor():
	var event = RandomEventResource.new()
	event.id = "generous_donor"
	event.title = "Donateur généreux"
	event.description = "Un joueur vétéran anonyme a entendu parler de votre guilde et souhaite faire un don pour vous aider dans votre développement."
	event.mtth = 336.0  # 2 semaines
	event.weight = 0.8
	event.category = "positive"
	event.tags = ["gold", "support"]
	
	# Choix 1: Accepter avec gratitude
	var choice1 = EventChoiceResource.new()
	choice1.id = "accept_gratefully"
	choice1.text = "Accepter avec gratitude"
	choice1.tooltip = "Remercier le donateur et accepter son aide."
	choice1.immediate_consequences = {
		"guild_gold": 500,
		"guild_xp": 50
	}
	choice1.effects_to_apply = [EffectsDataResource.get_effect_by_id("morale_boost")]
	choice1.ends_chain = true
	
	# Choix 2: Refuser poliment
	var choice2 = EventChoiceResource.new()
	choice2.id = "refuse_politely"
	choice2.text = "Refuser poliment"
	choice2.tooltip = "Décliner l'offre par fierté."
	choice2.effects_to_apply = [EffectsDataResource.get_effect_by_id("integration_bonus")]
	choice2.ends_chain = true
	
	event.choices = [choice1, choice2]
	return event

static func _create_server_update():
	var event = RandomEventResource.new()
	event.id = "server_update"
	event.title = "Mise à jour du serveur"
	event.description = "Le serveur vient de recevoir une mise à jour majeure avec de nouveaux donjons et mécaniques. Comment voulez-vous que la guilde s'adapte ?"
	event.mtth = 672.0  # 4 semaines
	event.weight = 0.5
	event.category = "neutral"
	event.tags = ["adaptation", "learning"]
	
	# Choix 1: Formation intensive
	var choice1 = EventChoiceResource.new()
	choice1.id = "intensive_training"
	choice1.text = "Organiser une formation intensive"
	choice1.tooltip = "Dépenser du temps et de l'or pour former les membres."
	choice1.requirements = {"guild_gold": {"op": ">=", "value": 200}}
	choice1.immediate_consequences = {
		"guild_gold": -200,
		"all_members_energy": -15.0
	}
	choice1.effects_to_apply = [EffectsDataResource.get_effect_by_id("skill_bonus")]
	choice1.ends_chain = true
	
	# Choix 2: Adaptation progressive
	var choice2 = EventChoiceResource.new()
	choice2.id = "gradual_adaptation"
	choice2.text = "S'adapter progressivement"
	choice2.tooltip = "Laisser les membres apprendre à leur rythme."
	choice2.immediate_consequences = {
		"guild_xp": 25
	}
	choice2.ends_chain = true
	
	event.choices = [choice1, choice2]
	return event

static func _create_training_opportunity():
	var event = RandomEventResource.new()
	event.id = "training_opportunity"
	event.title = "Opportunité d'entraînement"
	event.description = "Une guilde alliée propose un entraînement conjoint. C'est l'occasion d'améliorer les compétences de vos membres."
	event.mtth = 240.0  # 10 jours
	event.weight = 1.2
	event.category = "positive"
	event.tags = ["training", "skills", "alliance"]
	
	var choice1 = EventChoiceResource.new()
	choice1.id = "accept_training"
	choice1.text = "Accepter l'entraînement"
	choice1.tooltip = "Envoyer tous les membres disponibles."
	choice1.immediate_consequences = {
		"all_members_energy": -20.0
	}
	choice1.effects_to_apply = [EffectsDataResource.get_effect_by_id("skill_bonus")]
	choice1.ends_chain = true
	
	var choice2 = EventChoiceResource.new()
	choice2.id = "decline_training"
	choice2.text = "Décliner l'offre"
	choice2.tooltip = "Les membres ont besoin de repos."
	choice2.immediate_consequences = {
		"all_members_energy": 10.0
	}
	choice2.ends_chain = true
	
	event.choices = [choice1, choice2]
	return event

static func _create_rival_guild_challenge():
	var event = RandomEventResource.new()
	event.id = "rival_guild_challenge"
	event.title = "Défi d'une guilde rivale"
	event.description = "Une guilde rivale vous défie dans une compétition de raid. L'enjeu est votre réputation et celle de vos membres."
	event.mtth = 504.0  # 3 semaines
	event.weight = 0.9
	event.category = "challenge"
	event.tags = ["competition", "reputation", "raid"]
	
	# Conditions: Au moins niveau 3 de guilde
	event.conditions = [{
		"type": "guild_level",
		"value": {"op": ">=", "value": 3}
	}]
	
	var choice1 = EventChoiceResource.new()
	choice1.id = "accept_challenge"
	choice1.text = "Accepter le défi"
	choice1.tooltip = "Affronter la guilde rivale."
	choice1.random_consequences = [
		{
			"probability": 0.6,
			"consequence": {"guild_xp": 150, "all_members_mood": 20.0}
		},
		{
			"probability": 0.4,
			"consequence": {"all_members_mood": -25.0}
		}
	]
	choice1.ends_chain = true
	
	var choice2 = EventChoiceResource.new()
	choice2.id = "decline_challenge"
	choice2.text = "Décliner le défi"
	choice2.tooltip = "Éviter le conflit mais perdre en réputation."
	choice2.immediate_consequences = {
		"all_members_mood": -10.0
	}
	choice2.ends_chain = true
	
	event.choices = [choice1, choice2]
	return event

static func _create_member_injury():
	var event = RandomEventResource.new()
	event.id = "member_injury"
	event.title = "Membre blessé"
	event.description = "Un de vos membres s'est blessé lors d'un raid difficile et ne pourra pas participer aux prochaines activités."
	event.mtth = 200.0  # ~8 jours
	event.weight = 0.7
	event.category = "negative"
	event.tags = ["injury", "member", "raids"]
	
	# Conditions: Au moins 1 membre
	event.conditions = [{
		"type": "guild_members_count",
		"value": {"op": ">=", "value": 1}
	}]
	
	var choice1 = EventChoiceResource.new()
	choice1.id = "pay_for_healing"
	choice1.text = "Payer pour des soins"
	choice1.tooltip = "Dépenser de l'or pour accélérer la guérison."
	choice1.requirements = {"guild_gold": {"op": ">=", "value": 150}}
	choice1.immediate_consequences = {
		"guild_gold": -150
	}
	choice1.ends_chain = true
	
	var choice2 = EventChoiceResource.new()
	choice2.id = "wait_for_recovery"
	choice2.text = "Attendre la guérison naturelle"
	choice2.tooltip = "Le membre se rétablira avec le temps."
	choice2.effects_to_apply = [EffectsDataResource.get_effect_by_id("injured")]
	choice2.ends_chain = true
	
	event.choices = [choice1, choice2]
	return event

static func _create_lucky_drop():
	var event = RandomEventResource.new()
	event.id = "lucky_drop"
	event.title = "Drop exceptionnel"
	event.description = "Lors du dernier raid, la guilde a obtenu un drop particulièrement rare et précieux !"
	event.mtth = 120.0  # 5 jours
	event.weight = 1.5
	event.category = "positive"
	event.tags = ["loot", "luck", "raid"]
	
	var choice1 = EventChoiceResource.new()
	choice1.id = "sell_item"
	choice1.text = "Vendre l'objet"
	choice1.tooltip = "Convertir l'objet en or pour la guilde."
	choice1.immediate_consequences = {
		"guild_gold": 800
	}
	choice1.ends_chain = true
	
	var choice2 = EventChoiceResource.new()
	choice2.id = "keep_for_member"
	choice2.text = "Le garder pour un membre"
	choice2.tooltip = "Améliorer l'équipement d'un membre."
	choice2.immediate_consequences = {
		"all_members_mood": 15.0
	}
	choice2.effects_to_apply = [EffectsDataResource.get_effect_by_id("lucky_streak")]
	choice2.ends_chain = true
	
	event.choices = [choice1, choice2]
	return event

static func _create_recruitment_boost():
	var event = RandomEventResource.new()
	event.id = "recruitment_boost"
	event.title = "Buzz positif"
	event.description = "Votre guilde fait parler d'elle en bien sur les forums. De nombreux joueurs s'intéressent maintenant à vous rejoindre."
	event.mtth = 400.0  # ~16 jours
	event.weight = 0.8
	event.category = "positive"
	event.tags = ["recruitment", "reputation"]
	
	var choice1 = EventChoiceResource.new()
	choice1.id = "capitalize_on_buzz"
	choice1.text = "Capitaliser sur le buzz"
	choice1.tooltip = "Lancer une campagne de recrutement active."
	choice1.effects_to_apply = [EffectsDataResource.get_effect_by_id("recruitment_bonus")]
	choice1.ends_chain = true
	
	var choice2 = EventChoiceResource.new()
	choice2.id = "stay_modest"
	choice2.text = "Rester modeste"
	choice2.tooltip = "Ne pas changer d'approche."
	choice2.immediate_consequences = {
		"guild_xp": 30
	}
	choice2.ends_chain = true
	
	event.choices = [choice1, choice2]
	return event

# Chaîne d'événements: Le mystérieux bienfaiteur

static func _create_mysterious_benefactor_1():
	var event = RandomEventResource.new()
	event.id = "mysterious_benefactor_1"
	event.title = "Le mystérieux bienfaiteur"
	event.description = "Un joueur masqué s'approche de vous en jeu. Il prétend connaître votre guilde et vous propose une aide importante en échange d'un service futur."
	event.mtth = 800.0  # Très rare - ~33 jours
	event.weight = 0.3
	event.category = "mysterious"
	event.tags = ["mystery", "chain", "choice"]
	event.event_chain_id = "mysterious_benefactor"
	event.chain_position = 0
	
	var choice1 = EventChoiceResource.new()
	choice1.id = "accept_help"
	choice1.text = "Accepter son aide"
	choice1.tooltip = "Accepter son offre mystérieuse."
	choice1.follow_up_event_id = "mysterious_benefactor_2a"
	choice1.immediate_consequences = {
		"guild_gold": 1000
	}
	
	var choice2 = EventChoiceResource.new()
	choice2.id = "refuse_help"
	choice2.text = "Refuser son aide"
	choice2.tooltip = "Décliner poliment mais fermement."
	choice2.follow_up_event_id = "mysterious_benefactor_2b"
	
	event.choices = [choice1, choice2]
	return event

static func _create_mysterious_benefactor_2a():
	var event = RandomEventResource.new()
	event.id = "mysterious_benefactor_2a"
	event.title = "La faveur demandée"
	event.description = "Quelques jours après avoir accepté l'aide du mystérieux bienfaiteur, il revient vous voir. Il vous demande d'aider sa propre guilde dans un raid particulièrement difficile."
	event.mtth = 0.0  # Événement de suite
	event.weight = 1.0
	event.category = "mysterious"
	event.event_chain_id = "mysterious_benefactor"
	event.chain_position = 1
	
	var choice1 = EventChoiceResource.new()
	choice1.id = "help_in_raid"
	choice1.text = "Aider dans le raid"
	choice1.tooltip = "Honorer votre accord."
	choice1.follow_up_event_id = "mysterious_benefactor_3a"
	choice1.immediate_consequences = {
		"all_members_energy": -30.0
	}
	
	var choice2 = EventChoiceResource.new()
	choice2.id = "refuse_favor"
	choice2.text = "Refuser la faveur"
	choice2.tooltip = "Rompre l'accord, mais garder l'or."
	choice2.follow_up_event_id = "mysterious_benefactor_3b"
	choice2.effects_to_apply = [EffectsDataResource.get_effect_by_id("morale_penalty")]
	
	event.choices = [choice1, choice2]
	return event

static func _create_mysterious_benefactor_2b():
	var event = RandomEventResource.new()
	event.id = "mysterious_benefactor_2b"
	event.title = "Conséquences du refus"
	event.description = "Vous aviez refusé l'aide du mystérieux bienfaiteur. Il semble que ce soit une sage décision : vous apprenez qu'il était membre d'une guilde de ninjas looteurs notoires."
	event.mtth = 0.0  # Événement de suite
	event.weight = 1.0
	event.category = "positive"
	event.event_chain_id = "mysterious_benefactor"
	event.chain_position = 1
	
	var choice1 = EventChoiceResource.new()
	choice1.id = "warn_others"
	choice1.text = "Avertir les autres guildes"
	choice1.tooltip = "Partager l'information sur les forums."
	choice1.immediate_consequences = {
		"guild_xp": 100
	}
	choice1.effects_to_apply = [EffectsDataResource.get_effect_by_id("recruitment_bonus")]
	choice1.ends_chain = true
	
	event.choices = [choice1]
	return event

static func _create_mysterious_benefactor_3a():
	var event = RandomEventResource.new()
	event.id = "mysterious_benefactor_3a"
	event.title = "Récompense méritée"
	event.description = "Le raid s'est parfaitement déroulé grâce à votre aide. Le mystérieux bienfaiteur se révèle être le leader d'une guilde prestigieuse et vous propose une alliance permanente."
	event.mtth = 0.0  # Événement de suite
	event.weight = 1.0
	event.category = "positive"
	event.event_chain_id = "mysterious_benefactor"
	event.chain_position = 2
	
	var choice1 = EventChoiceResource.new()
	choice1.id = "accept_alliance"
	choice1.text = "Accepter l'alliance"
	choice1.tooltip = "Forger une alliance durable."
	choice1.immediate_consequences = {
		"guild_xp": 200
	}
	choice1.effects_to_apply = [EffectsDataResource.get_effect_by_id("guild_xp_bonus")]
	choice1.ends_chain = true
	
	event.choices = [choice1]
	return event

static func _create_mysterious_benefactor_3b():
	var event = RandomEventResource.new()
	event.id = "mysterious_benefactor_3b"
	event.title = "Réputation ternie"
	event.description = "Votre refus d'honorer l'accord fait le tour des forums. Votre réputation en prend un coup, mais au moins vous avez gardé votre intégrité."
	event.mtth = 0.0  # Événement de suite
	event.weight = 1.0
	event.category = "negative"
	event.event_chain_id = "mysterious_benefactor"
	event.chain_position = 2
	
	var choice1 = EventChoiceResource.new()
	choice1.id = "work_to_rebuild"
	choice1.text = "Travailler pour reconstruire"
	choice1.tooltip = "Redorer votre blason par les actes."
	choice1.immediate_consequences = {
		"all_members_mood": -15.0
	}
	choice1.effects_to_apply = [EffectsDataResource.get_effect_by_id("integration_bonus")]
	choice1.ends_chain = true
	
	event.choices = [choice1]
	return event
