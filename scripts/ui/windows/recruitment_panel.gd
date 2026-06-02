extends PanelContainer
class_name RecruitmentPanel

## Composant autonome de l'onglet « Recrutement ».
## Extrait de fenetre_monde.gd : gère le pool de recrutement, l'affichage
## des candidats, la négociation salariale (recrues nationales), le scouting
## et l'envoi d'invitations. Émet player_recruited pour que la fenêtre/main.gd
## ajoute le membre à la guilde.

signal player_recruited(player)

var recruitment_list: ItemList
var recruit_details: VBoxContainer
var salary_spinbox: SpinBox = null

var available_players: Array = []
var selected_recruit = null
var recruitment_pool: Node
var guild_manager: Node

# Référence membre au filtre de classe (remplace la navigation fragile dans
# l'arbre des nodes pour retrouver l'OptionButton).
var _filter_option: OptionButton = null

func _ready() -> void:
	name = "Recrutement"

	recruitment_pool = RecruitmentPool
	guild_manager = GuildManager

	build()

	# Connecte aux signaux du RecruitmentPool
	if recruitment_pool:
		if not recruitment_pool.pool_refreshed.is_connected(_on_pool_refreshed):
			recruitment_pool.pool_refreshed.connect(_on_pool_refreshed)
		if not recruitment_pool.player_lost_to_competition.is_connected(_on_player_lost_to_competition):
			recruitment_pool.player_lost_to_competition.connect(_on_player_lost_to_competition)

	_refresh_recruitment_from_pool()

func refresh() -> void:
	"""Rafraîchit le contenu du panneau (appelé par la fenêtre à l'affichage)."""
	_refresh_recruitment_from_pool()

func build() -> void:
	"""Construit le contenu de l'onglet directement dans self (ex-_setup_recruitment_tab)."""
	var hsplit = HSplitContainer.new()
	hsplit.split_offset = 400
	add_child(hsplit)

	var left_panel = PanelContainer.new()
	hsplit.add_child(left_panel)

	var left_vbox = VBoxContainer.new()
	left_panel.add_child(left_vbox)

	var filter_hbox = HBoxContainer.new()
	left_vbox.add_child(filter_hbox)

	var filter_label = Label.new()
	filter_label.text = "Filtrer par classe:"
	filter_hbox.add_child(filter_label)

	var filter_option = OptionButton.new()
	filter_option.add_item("Tous")
	filter_option.add_item("Guerrier")
	filter_option.add_item("Mage")
	filter_option.add_item("Prêtre")
	filter_option.selected = 0
	filter_option.item_selected.connect(_on_filter_changed)
	filter_hbox.add_child(filter_option)
	_filter_option = filter_option

	recruitment_list = ItemList.new()
	recruitment_list.custom_minimum_size = Vector2(350, 400)
	recruitment_list.item_selected.connect(_on_recruit_selected)
	left_vbox.add_child(recruitment_list)

	var right_panel = PanelContainer.new()
	hsplit.add_child(right_panel)

	recruit_details = VBoxContainer.new()
	recruit_details.add_theme_constant_override("separation", 10)
	right_panel.add_child(recruit_details)

	_setup_recruit_details()

func _setup_recruit_details() -> void:
	var details_label = Label.new()
	details_label.text = "Détails du Candidat"
	details_label.add_theme_font_size_override("font_size", 16)
	recruit_details.add_child(details_label)

	var info_label = Label.new()
	info_label.text = "Sélectionnez un joueur pour voir ses détails"
	info_label.modulate = Color(0.7, 0.7, 0.7)
	recruit_details.add_child(info_label)

func _refresh_recruitment_from_pool() -> void:
	if not recruitment_pool:
		return

	available_players = recruitment_pool.available_players.duplicate()
	_refresh_recruitment_list()

func _on_pool_refreshed() -> void:
	_refresh_recruitment_from_pool()

func _on_player_lost_to_competition(player: SimulatedPlayer, guild_name: String) -> void:
	# Notification quand un joueur est recruté par une autre guilde
	if selected_recruit == player:
		selected_recruit = null
		_update_recruit_details()

	# Optionnel: afficher une notification
	GameLog.d("Le joueur %s a été recruté par %s" % [player.nom, guild_name])

func _refresh_recruitment_list(filter_class: String = "") -> void:
	recruitment_list.clear()

	if not recruitment_pool:
		return

	# Utilise le système de filtres du RecruitmentPool
	var filters = {}
	if filter_class != "":
		filters["class"] = filter_class

	var filtered_players = recruitment_pool.get_filtered_players(filters)

	for player in filtered_players:
		var difficulty = player.get_meta("recruitment_difficulty", 0.5)
		var difficulty_text = ""
		if difficulty > 0.7:
			difficulty_text = " (Difficile)"
		elif difficulty < 0.3:
			difficulty_text = " (Facile)"

		var national_marker = "💼 " if player.get_meta("is_national", false) else ""
		var text = "%s%s - %s Niv.%d (Équip: %d)%s" % [
			national_marker,
			player.nom,
			player.personnage_classe,
			player.personnage_niveau,
			player.get_total_ilvl(),
			difficulty_text
		]
		recruitment_list.add_item(text)

func _on_filter_changed(index: int) -> void:
	var filter_class = ""
	match index:
		1: filter_class = "Guerrier"
		2: filter_class = "Mage"
		3: filter_class = "Prêtre"
	_refresh_recruitment_list(filter_class)

func _on_recruit_selected(index: int) -> void:
	if not recruitment_pool:
		return

	# Récupère la classe filtrée actuelle directement depuis le filtre (plus de
	# navigation fragile dans l'arbre des nodes).
	var filter_class = ""
	if _filter_option:
		match _filter_option.selected:
			1: filter_class = "Guerrier"
			2: filter_class = "Mage"
			3: filter_class = "Prêtre"

	var filters = {}
	if filter_class != "":
		filters["class"] = filter_class

	var filtered_players = recruitment_pool.get_filtered_players(filters)

	if index < 0 or index >= filtered_players.size():
		return

	selected_recruit = filtered_players[index]
	_update_recruit_details()

func _update_recruit_details() -> void:
	for child in recruit_details.get_children():
		child.queue_free()

	if not selected_recruit:
		return

	var details_label = Label.new()
	details_label.text = "Candidat: " + selected_recruit.nom
	details_label.add_theme_font_size_override("font_size", 18)
	recruit_details.add_child(details_label)

	recruit_details.add_child(HSeparator.new())

	var info_grid = GridContainer.new()
	info_grid.columns = 2
	info_grid.add_theme_constant_override("h_separation", 20)
	info_grid.add_theme_constant_override("v_separation", 10)
	recruit_details.add_child(info_grid)

	_add_detail_row(info_grid, "Classe:", selected_recruit.personnage_classe)
	_add_detail_row(info_grid, "Niveau:", str(selected_recruit.personnage_niveau))
	_add_detail_row(info_grid, "Équipement:", selected_recruit.get_equipment_summary())
	_add_detail_row(info_grid, "Rôle:", selected_recruit.get_role())

	recruit_details.add_child(HSeparator.new())

	var tags_label = Label.new()
	tags_label.text = "Tags visibles:"
	recruit_details.add_child(tags_label)

	var tags_text = Label.new()
	var visible_tags = selected_recruit.get_visible_tags()
	if visible_tags.is_empty():
		tags_text.text = "Aucun tag visible pour le moment"
		tags_text.modulate = Color(0.6, 0.6, 0.6)
	else:
		tags_text.text = ", ".join(visible_tags)
		tags_text.modulate = Color(0.8, 0.8, 1.0)
	recruit_details.add_child(tags_text)

	# Ajoute la motivation du joueur
	if recruitment_pool:
		var motivation = selected_recruit.get_meta("recruitment_motivation", "")
		if motivation != "":
			recruit_details.add_child(HSeparator.new())

			var motivation_label = Label.new()
			motivation_label.text = "Motivation:"
			recruit_details.add_child(motivation_label)

			# RichTextLabel : la motivation peut contenir du BBCode (mise en forme),
			# sinon les balises s'afficheraient en texte littéral dans un Label.
			var motivation_text = RichTextLabel.new()
			motivation_text.bbcode_enabled = true
			motivation_text.fit_content = true
			motivation_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			motivation_text.scroll_active = false
			motivation_text.text = motivation
			motivation_text.modulate = Color(0.9, 0.9, 0.7)
			recruit_details.add_child(motivation_text)

	var planning_label = Label.new()
	planning_label.text = "\nDisponibilité probable:"
	recruit_details.add_child(planning_label)

	var planning_text = Label.new()
	planning_text.text = _get_planning_summary(selected_recruit.planning)
	planning_text.modulate = Color(0.8, 1.0, 0.8)
	recruit_details.add_child(planning_text)

	recruit_details.add_child(HSeparator.new())

	# Contrôles de recrutement : négociation salariale pour les recrues semi-pro (national)
	if selected_recruit.get_meta("is_national", false):
		_build_national_recruit_controls()
	else:
		_build_standard_invite_controls()

func _build_standard_invite_controls() -> void:
	var button_container = HBoxContainer.new()
	button_container.add_theme_constant_override("separation", 10)
	recruit_details.add_child(button_container)
	button_container.add_spacer(false)

	var invite_button = Button.new()
	invite_button.text = "Envoyer une invitation"
	invite_button.custom_minimum_size = Vector2(250, 50)
	invite_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if guild_manager and guild_manager.guild:
		if not guild_manager.guild.can_recruit():
			invite_button.disabled = true
			invite_button.tooltip_text = "Votre guilde doit atteindre le niveau 2 pour pouvoir recruter"
	invite_button.pressed.connect(_on_invite_pressed)
	button_container.add_child(invite_button)
	button_container.add_spacer(false)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	recruit_details.add_child(spacer)

func _build_national_recruit_controls() -> void:
	var demand: int = selected_recruit.salary_demand
	var has_agent: bool = selected_recruit.get_meta("has_agent", false)

	var header = Label.new()
	header.text = "💼 Recrue semi-professionnelle"
	header.add_theme_font_size_override("font_size", 15)
	header.modulate = Color(1.0, 0.82, 0.30)
	recruit_details.add_child(header)

	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 6)
	recruit_details.add_child(grid)
	_add_detail_row(grid, "Salaire demandé:", "%d or/sem" % demand)
	if has_agent:
		_add_detail_row(grid, "Agent:", "Oui (commission %d or)" % selected_recruit.get_meta("agent_commission", 0))
	else:
		_add_detail_row(grid, "Agent:", "Non")
	_add_detail_row(grid, "Masse salariale actuelle:", "%d or/sem" % (guild_manager.get_total_weekly_salaries() if guild_manager else 0))

	# Négociation salariale
	var neg_box = HBoxContainer.new()
	neg_box.add_theme_constant_override("separation", 8)
	recruit_details.add_child(neg_box)
	var lbl = Label.new()
	lbl.text = "Votre offre:"
	neg_box.add_child(lbl)
	salary_spinbox = SpinBox.new()
	salary_spinbox.min_value = 0
	salary_spinbox.max_value = maxi(demand * 3, 10)
	salary_spinbox.step = 5
	salary_spinbox.value = demand
	neg_box.add_child(salary_spinbox)
	var lbl2 = Label.new()
	lbl2.text = "or/sem"
	neg_box.add_child(lbl2)

	var btn_box = HBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 10)
	recruit_details.add_child(btn_box)
	var negotiate_btn = Button.new()
	negotiate_btn.text = "Négocier"
	negotiate_btn.pressed.connect(_on_negotiate_pressed)
	btn_box.add_child(negotiate_btn)
	var scout_btn = Button.new()
	scout_btn.text = "Scouter (-2 réput.)"
	scout_btn.tooltip_text = "Révèle les traits cachés et le skill réel"
	scout_btn.pressed.connect(_on_scout_pressed)
	btn_box.add_child(scout_btn)

func _on_negotiate_pressed() -> void:
	if not selected_recruit or not recruitment_pool or not salary_spinbox:
		return
	var offer: int = int(salary_spinbox.value)
	var result: Dictionary = recruitment_pool.attempt_national_recruitment(selected_recruit, offer)
	match result.get("step", ""):
		"accepted":
			player_recruited.emit(result.player)
			_show_recruit_dialog(_format_national_signing(result))
			selected_recruit = null
			_refresh_recruitment_list()
			_update_recruit_details()
		"counter":
			_show_counter_offer_dialog(selected_recruit, result.counter_offer)
		"rejected":
			_show_recruit_dialog(result.reason)
		"error":
			_show_recruit_dialog(result.get("reason", "Recrutement impossible"))
		_:
			# Pas d'exigence salariale → recrutement standard
			if result.get("success", false):
				player_recruited.emit(result.player)
				_show_recruit_dialog("%s rejoint la guilde !" % result.player.nom)
				selected_recruit = null
				_refresh_recruitment_list()
				_update_recruit_details()
			else:
				_show_recruit_dialog(result.get("reason", "Recrutement échoué"))

func _show_counter_offer_dialog(player, counter: int) -> void:
	var dialog = ConfirmationDialog.new()
	dialog.title = "Contre-proposition"
	dialog.dialog_text = "%s demande %d or/semaine. Accepter ce contrat ?" % [player.nom, counter]
	get_tree().root.add_child(dialog)
	dialog.confirmed.connect(func():
		var res: Dictionary = recruitment_pool.accept_counter_offer(player, counter)
		if res.get("success", false):
			player_recruited.emit(res.player)
			_show_recruit_dialog(_format_national_signing(res))
			selected_recruit = null
			_refresh_recruitment_list()
			_update_recruit_details()
		else:
			_show_recruit_dialog(res.get("reason", "Recrutement impossible"))
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

func _on_scout_pressed() -> void:
	if not selected_recruit or not recruitment_pool:
		return
	var result: Dictionary = recruitment_pool.scout_player(selected_recruit)
	var msg = "Skill réel : %d\nSalaire demandé : %d or/sem\nAgent : %s" % [
		result.get("skill", 0), result.get("salary_demand", 0),
		"Oui" if result.get("has_agent", false) else "Non"]
	var revealed: Array = result.get("revealed_tags", [])
	if not revealed.is_empty():
		msg += "\nTraits révélés : " + ", ".join(revealed)
	_show_recruit_dialog(msg)
	_update_recruit_details()

func _format_national_signing(result: Dictionary) -> String:
	var player_name: String = result.player.nom if result.get("player", null) else "La recrue"
	var text: String = "%s rejoint la guilde pour %d or/semaine !" % [player_name, result.get("salary", 0)]
	var agent_cost: int = int(result.get("agent_cost", 0))
	if agent_cost > 0:
		text += "\nCommission d'agent payée : %d or." % agent_cost
	return text

func _show_recruit_dialog(text: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.dialog_text = text
	get_tree().root.add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)

func _add_detail_row(parent: GridContainer, label_text: String, value_text: String) -> void:
	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 14)
	parent.add_child(label)

	var value = Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 14)
	value.modulate = Color(0.9, 0.9, 1.0)
	parent.add_child(value)

func _get_planning_summary(planning: Dictionary) -> String:
	var active_days = []
	if planning.has("vendredi") and planning["vendredi"].get("soir", false):
		active_days.append("Vendredi soir")
	if planning.has("samedi") and (planning["samedi"].get("apres_midi", false) or planning["samedi"].get("soir", false)):
		active_days.append("Samedi")
	if planning.has("dimanche") and (planning["dimanche"].get("apres_midi", false) or planning["dimanche"].get("soir", false)):
		active_days.append("Dimanche")

	if active_days.is_empty():
		return "Peu actif"
	else:
		return "Actif: " + ", ".join(active_days)

func _on_invite_pressed() -> void:
	GameLog.d("Debug: Bouton recruter cliqué")
	GameLog.d("Debug: selected_recruit = " + str(selected_recruit))
	GameLog.d("Debug: recruitment_pool = " + str(recruitment_pool))
	GameLog.d("Debug: guild_manager = " + str(guild_manager))

	if not selected_recruit or not recruitment_pool or not guild_manager:
		GameLog.d("Debug: Une des conditions n'est pas remplie")
		return

	# Prépare les données de la guilde pour le recrutement
	var guild_data = {
		"guild_size": guild_manager.guild_members.size(),
		"hardcore": false,  # TODO: Déterminer selon l'activité de la guilde
		"recent_raid_success": false,  # TODO: Tracker les succès récents
		"reputation": guild_manager.guild.get_reputation() if guild_manager.guild else 50.0
	}

	# Tente le recrutement via le pool
	var result = recruitment_pool.attempt_recruitment(selected_recruit, guild_data)

	if result.success:
		# Le joueur a accepté!
		player_recruited.emit(result.player)
		selected_recruit = null
		_refresh_recruitment_list()
		_update_recruit_details()

		var dialog = AcceptDialog.new()
		dialog.dialog_text = "Le joueur a accepté votre invitation et rejoint la guilde!"
		get_tree().root.add_child(dialog)
		dialog.popup_centered()
		dialog.confirmed.connect(dialog.queue_free)
	else:
		# Le joueur a refusé
		var dialog = AcceptDialog.new()
		dialog.dialog_text = "Le joueur a décliné votre invitation.\nRaison: %s" % result.reason
		get_tree().root.add_child(dialog)
		dialog.popup_centered()
		dialog.confirmed.connect(dialog.queue_free)
