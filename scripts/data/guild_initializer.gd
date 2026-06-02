class_name GuildInitializer

## Crée les membres initiaux de la guilde pour le démarrage du jeu.
## Séparé du GuildManager pour garder le manager léger.

static func create_initial_members() -> void:
	"""Crée 10 membres initiaux pour la guilde"""
	var member_names: Array[String] = [
		"Thorin", "Legolas", "Gimli", "Aragorn", "Gandalf",
		"Frodo", "Sam", "Merry", "Pippin", "Boromir"
	]

	var classes: Array[String] = ["Guerrier", "Prêtre", "Mage", "Voleur", "Chasseur", "Druide", "Démoniste", "Paladin", "Chaman"]
	var roles_by_class: Dictionary = {
		"Guerrier": "Tank",
		"Prêtre": "Healer",
		"Mage": "DPS",
		"Voleur": "DPS",
		"Chasseur": "DPS",
		"Druide": ["Tank", "Healer", "DPS"],
		"Démoniste": "DPS",
		"Paladin": ["Tank", "Healer", "DPS"],
		"Chaman": ["Healer", "DPS"]
	}

	var required_tanks: int = 1
	var required_healers: int = 1
	var created_tanks: int = 0
	var created_healers: int = 0

	for i in range(10):
		var member := SimulatedPlayer.new()
		member.nom = member_names[i]

		# Assigner une classe en fonction des besoins de composition
		var chosen_class: String = ""
		if created_tanks < required_tanks:
			chosen_class = ["Guerrier", "Druide", "Paladin"].pick_random()
			member.personnage_role = "Tank"
			created_tanks += 1
		elif created_healers < required_healers:
			chosen_class = ["Prêtre", "Druide", "Paladin", "Chaman"].pick_random()
			member.personnage_role = "Healer"
			created_healers += 1
		else:
			chosen_class = classes.pick_random()
			var role_options = roles_by_class[chosen_class]
			if role_options is Array:
				member.personnage_role = "DPS"
			else:
				member.personnage_role = role_options

		member.personnage_classe = chosen_class
		member.personnage_niveau = 1
		member.skill = randi_range(40, 80)
		member.energy = randi_range(60, 100)
		member.mood = randi_range(50, 90)
		member.integration = randi_range(20, 60)
		member.days_in_guild = randi_range(7, 30)

		member.planning = {
			"lundi": {"soir": randf() > 0.3},
			"mardi": {"soir": randf() > 0.3},
			"mercredi": {"soir": randf() > 0.3},
			"jeudi": {"soir": randf() > 0.3},
			"vendredi": {"soir": randf() > 0.3},
			"samedi": {"apres_midi": randf() > 0.2, "soir": randf() > 0.1},
			"dimanche": {"apres_midi": randf() > 0.2, "soir": randf() > 0.2}
		}

		if randf() > 0.5:
			member.tags_comportement = [["social", "patient"].pick_random()]
		else:
			member.tags_comportement = []

		if randf() < 0.3:
			member.or_actuel = randi_range(50, 200)

		GuildManager.add_member(member)

		GameLog.d("Membre initial créé: %s - %s %s Niv.%d" % [
			member.nom,
			member.personnage_role,
			member.personnage_classe,
			member.personnage_niveau
		])
