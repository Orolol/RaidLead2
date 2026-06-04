extends PanelContainer
class_name RecruitmentPanel

signal player_recruited(player)
signal candidate_selected(player)

var recruitment_list: ItemList
var details_scroll: ScrollContainer
var recruit_details: VBoxContainer
var salary_spinbox: SpinBox = null

var available_players: Array = []
var selected_recruit: SimulatedPlayer = null
var recruitment_pool: Node
var guild_manager: Node

var _filter_option: OptionButton = null
var _visible_recruits: Array[SimulatedPlayer] = []


func _ready() -> void:
	name = "Recrutement"
	recruitment_pool = RecruitmentPool
	guild_manager = GuildManager

	build()

	if recruitment_pool:
		if not recruitment_pool.pool_refreshed.is_connected(_on_pool_refreshed):
			recruitment_pool.pool_refreshed.connect(_on_pool_refreshed)
		if not recruitment_pool.player_lost_to_competition.is_connected(_on_player_lost_to_competition):
			recruitment_pool.player_lost_to_competition.connect(_on_player_lost_to_competition)

	_refresh_recruitment_from_pool()


func refresh() -> void:
	_refresh_recruitment_from_pool()


func build() -> void:
	var hsplit: HSplitContainer = HSplitContainer.new()
	hsplit.split_offset = 420
	hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(hsplit)

	var left_panel: PanelContainer = PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(380, 420)
	hsplit.add_child(left_panel)

	var left_vbox: VBoxContainer = VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 8)
	left_panel.add_child(left_vbox)

	var filter_hbox: HBoxContainer = HBoxContainer.new()
	filter_hbox.add_theme_constant_override("separation", 8)
	left_vbox.add_child(filter_hbox)

	var filter_label: Label = Label.new()
	filter_label.text = "Classe:"
	filter_hbox.add_child(filter_label)

	_filter_option = OptionButton.new()
	_filter_option.add_item("Tous")
	_filter_option.add_item("Guerrier")
	_filter_option.add_item("Mage")
	_filter_option.add_item("Prêtre")
	_filter_option.item_selected.connect(_on_filter_changed)
	filter_hbox.add_child(_filter_option)

	recruitment_list = ItemList.new()
	recruitment_list.custom_minimum_size = Vector2(360, 420)
	recruitment_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	recruitment_list.item_selected.connect(_on_recruit_selected)
	left_vbox.add_child(recruitment_list)

	var right_panel: PanelContainer = PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hsplit.add_child(right_panel)

	details_scroll = ScrollContainer.new()
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(details_scroll)

	recruit_details = VBoxContainer.new()
	recruit_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recruit_details.add_theme_constant_override("separation", 10)
	details_scroll.add_child(recruit_details)

	_show_empty_details()


func _show_empty_details() -> void:
	_clear_details()
	var title: Label = Label.new()
	title.text = "Détails du candidat"
	title.add_theme_font_size_override("font_size", 16)
	recruit_details.add_child(title)

	var info: Label = Label.new()
	info.text = "Sélectionnez un joueur pour voir son profil."
	info.modulate = Color(0.7, 0.7, 0.7)
	recruit_details.add_child(info)


func _clear_details() -> void:
	for child in recruit_details.get_children():
		child.queue_free()


func _refresh_recruitment_from_pool() -> void:
	if not recruitment_pool:
		return
	available_players = recruitment_pool.available_players.duplicate()
	_refresh_recruitment_list(_get_current_filter_class())


func _on_pool_refreshed() -> void:
	_refresh_recruitment_from_pool()
	if selected_recruit and selected_recruit not in recruitment_pool.available_players:
		selected_recruit = null
		_show_empty_details()


func _on_player_lost_to_competition(player: SimulatedPlayer, guild_name: String) -> void:
	if selected_recruit == player:
		selected_recruit = null
		_show_empty_details()
	GameLog.d("Le joueur %s a été recruté par %s" % [player.nom, guild_name])


func _refresh_recruitment_list(filter_class: String = "") -> void:
	recruitment_list.clear()
	_visible_recruits.clear()

	if not recruitment_pool:
		return

	var filters: Dictionary = {}
	if filter_class != "":
		filters["class"] = filter_class

	var filtered_players: Array = recruitment_pool.get_filtered_players(filters)
	for player in filtered_players:
		_visible_recruits.append(player)
		_add_recruit_row(player)


func _add_recruit_row(player: SimulatedPlayer) -> void:
	var preview: Dictionary = recruitment_pool.get_recruitment_preview(player, _build_guild_data())
	var status_text: String = recruitment_pool.get_candidate_status_text(player)
	var pro_marker: String = "[Pro] " if player.get_meta("is_national", false) else ""
	var cooldown_marker: String = "[Pause] " if recruitment_pool.is_player_on_recruitment_cooldown(player) else ""
	var row_text: String = "%s%s%s - %s Niv.%d (iLvl %d) - %s - %s" % [
		cooldown_marker,
		pro_marker,
		player.nom,
		player.personnage_classe,
		player.personnage_niveau,
		player.get_total_ilvl(),
		preview.get("label", "Incertain"),
		status_text
	]

	recruitment_list.add_item(row_text)
	var index: int = recruitment_list.item_count - 1
	if recruitment_pool.is_player_on_recruitment_cooldown(player):
		recruitment_list.set_item_custom_fg_color(index, Color(0.55, 0.55, 0.58))
	elif float(preview.get("chance", 0.0)) >= 0.55:
		recruitment_list.set_item_custom_fg_color(index, Color(0.75, 1.0, 0.75))
	else:
		recruitment_list.set_item_custom_fg_color(index, Color(0.9, 0.9, 0.93))


func _on_filter_changed(_index: int) -> void:
	_refresh_recruitment_list(_get_current_filter_class())


func _get_current_filter_class() -> String:
	if not _filter_option:
		return ""
	var item_text: String = _filter_option.get_item_text(_filter_option.selected)
	return "" if item_text == "Tous" else item_text


func _on_recruit_selected(index: int) -> void:
	if index < 0 or index >= _visible_recruits.size():
		return
	selected_recruit = _visible_recruits[index]
	candidate_selected.emit(selected_recruit)
	_update_recruit_details()

func focus_candidate(player: SimulatedPlayer) -> void:
	if player == null:
		return
	_refresh_recruitment_from_pool()
	var index: int = _visible_recruits.find(player)
	if index < 0:
		return
	selected_recruit = player
	if recruitment_list:
		recruitment_list.select(index)
	candidate_selected.emit(selected_recruit)
	_update_recruit_details()


func _update_recruit_details() -> void:
	_clear_details()
	if not selected_recruit:
		_show_empty_details()
		return

	var title: Label = Label.new()
	title.text = "Candidat: " + selected_recruit.nom
	title.add_theme_font_size_override("font_size", 18)
	recruit_details.add_child(title)

	var info_grid: GridContainer = GridContainer.new()
	info_grid.columns = 2
	info_grid.add_theme_constant_override("h_separation", 18)
	info_grid.add_theme_constant_override("v_separation", 8)
	recruit_details.add_child(info_grid)

	var preview: Dictionary = recruitment_pool.get_recruitment_preview(selected_recruit, _build_guild_data())
	_add_detail_row(info_grid, "Classe:", selected_recruit.personnage_classe)
	_add_detail_row(info_grid, "Rôle:", selected_recruit.get_role())
	_add_detail_row(info_grid, "Niveau:", str(selected_recruit.personnage_niveau))
	_add_detail_row(info_grid, "Équipement:", selected_recruit.get_equipment_summary())
	_add_detail_row(info_grid, "Recrutement:", "%s (%.0f%%)" % [preview.get("label", "Incertain"), float(preview.get("chance", 0.0)) * 100.0])
	_add_detail_row(info_grid, "Marché:", recruitment_pool.get_candidate_status_text(selected_recruit))
	_add_detail_row(info_grid, "Offres:", str(selected_recruit.get_meta("offers_received", 0)))

	recruit_details.add_child(HSeparator.new())
	_add_text_block("Tags visibles:", _format_visible_tags(selected_recruit), Color(0.8, 0.8, 1.0))
	_add_text_block("Motivation:", String(selected_recruit.get_meta("recruitment_motivation", "")), Color(0.9, 0.9, 0.7))
	_add_text_block("Rumeur de marché:", String(selected_recruit.get_meta("market_story", "")), Color(0.85, 0.85, 0.65))
	_add_text_block("Lecture:", " - ".join(preview.get("reasons", [])), Color(0.7, 0.9, 1.0))
	_add_text_block("Disponibilité probable:", _get_planning_summary(selected_recruit.planning), Color(0.8, 1.0, 0.8))

	recruit_details.add_child(HSeparator.new())
	if selected_recruit.get_meta("is_national", false):
		_build_national_recruit_controls()
	else:
		_build_standard_invite_controls()


func _format_visible_tags(player: SimulatedPlayer) -> String:
	var tags: Array = player.get_visible_tags()
	if tags.is_empty():
		return "Aucun tag visible pour le moment"
	return ", ".join(tags)


func _add_text_block(label_text: String, value_text: String, color: Color) -> void:
	if value_text == "":
		return
	var label: Label = Label.new()
	label.text = label_text
	recruit_details.add_child(label)

	var value: Label = Label.new()
	value.text = value_text
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.modulate = color
	recruit_details.add_child(value)


func _build_standard_invite_controls() -> void:
	var box: HBoxContainer = HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	recruit_details.add_child(box)

	var invite_button: Button = Button.new()
	invite_button.text = "Envoyer une invitation"
	invite_button.custom_minimum_size = Vector2(250, 44)
	_apply_recruit_button_state(invite_button)
	invite_button.pressed.connect(_on_invite_pressed)
	box.add_child(invite_button)


func _build_national_recruit_controls() -> void:
	var demand: int = selected_recruit.salary_demand
	var has_agent: bool = selected_recruit.get_meta("has_agent", false)

	var header: Label = Label.new()
	header.text = "Recrue semi-professionnelle"
	header.add_theme_font_size_override("font_size", 15)
	header.modulate = Color(1.0, 0.82, 0.30)
	recruit_details.add_child(header)

	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 6)
	recruit_details.add_child(grid)
	_add_detail_row(grid, "Salaire demandé:", "%d or/sem" % demand)
	var agent_text: String = "Non"
	if has_agent:
		agent_text = "Oui (commission %d or)" % int(selected_recruit.get_meta("agent_commission", 0))
	_add_detail_row(grid, "Agent:", agent_text)
	_add_detail_row(grid, "Masse salariale:", "%d or/sem" % (guild_manager.get_total_weekly_salaries() if guild_manager else 0))

	var offer_box: HBoxContainer = HBoxContainer.new()
	offer_box.add_theme_constant_override("separation", 8)
	recruit_details.add_child(offer_box)

	var offer_label: Label = Label.new()
	offer_label.text = "Votre offre:"
	offer_box.add_child(offer_label)

	salary_spinbox = SpinBox.new()
	salary_spinbox.min_value = 0
	salary_spinbox.max_value = maxi(demand * 3, 10)
	salary_spinbox.step = 5
	salary_spinbox.value = demand
	offer_box.add_child(salary_spinbox)

	var currency_label: Label = Label.new()
	currency_label.text = "or/sem"
	offer_box.add_child(currency_label)

	var button_box: HBoxContainer = HBoxContainer.new()
	button_box.add_theme_constant_override("separation", 10)
	recruit_details.add_child(button_box)

	var negotiate_btn: Button = Button.new()
	negotiate_btn.text = "Négocier"
	_apply_recruit_button_state(negotiate_btn)
	negotiate_btn.pressed.connect(_on_negotiate_pressed)
	button_box.add_child(negotiate_btn)

	var scout_btn: Button = Button.new()
	scout_btn.text = "Scouter (-2 réput.)"
	scout_btn.tooltip_text = "Révèle des traits cachés et le skill réel"
	scout_btn.pressed.connect(_on_scout_pressed)
	button_box.add_child(scout_btn)


func _apply_recruit_button_state(button: Button) -> void:
	if guild_manager and guild_manager.guild and not guild_manager.guild.can_recruit():
		button.disabled = true
		button.tooltip_text = "Votre guilde doit atteindre le niveau 2 pour pouvoir recruter"
	if recruitment_pool and recruitment_pool.is_player_on_recruitment_cooldown(selected_recruit):
		button.disabled = true
		button.text = "À relancer dans %dh" % recruitment_pool.get_recruitment_cooldown_remaining_hours(selected_recruit)
		button.tooltip_text = "Cette recrue vient de refuser. Attendez 24h avant une nouvelle approche."


func _on_invite_pressed() -> void:
	if not selected_recruit or not recruitment_pool or not guild_manager:
		return
	var result: Dictionary = recruitment_pool.attempt_recruitment(selected_recruit, _build_guild_data())
	_handle_recruitment_result(result)


func _on_negotiate_pressed() -> void:
	if not selected_recruit or not recruitment_pool or not salary_spinbox:
		return
	var offer: int = int(salary_spinbox.value)
	var result: Dictionary = recruitment_pool.attempt_national_recruitment(selected_recruit, offer)
	match result.get("step", ""):
		"counter":
			_show_counter_offer_dialog(selected_recruit, int(result.get("counter_offer", offer)))
		_:
			_handle_recruitment_result(result)


func _handle_recruitment_result(result: Dictionary) -> void:
	if result.get("success", false):
		var recruited_player: SimulatedPlayer = result.get("player", null) as SimulatedPlayer
		if recruited_player:
			player_recruited.emit(recruited_player)
		_show_recruit_dialog(_format_success_message(result))
		selected_recruit = null
		_refresh_recruitment_list(_get_current_filter_class())
		_show_empty_details()
		return

	_show_recruit_dialog(result.get("reason", "Recrutement impossible"))
	_refresh_recruitment_list(_get_current_filter_class())
	_update_recruit_details()


func _show_counter_offer_dialog(player: SimulatedPlayer, counter: int) -> void:
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "Contre-proposition"
	dialog.dialog_text = "%s demande %d or/semaine. Accepter ce contrat ?" % [player.nom, counter]
	get_tree().root.add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		var result: Dictionary = recruitment_pool.accept_counter_offer(player, counter)
		_handle_recruitment_result(result)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()


func _on_scout_pressed() -> void:
	if not selected_recruit or not recruitment_pool:
		return
	var result: Dictionary = recruitment_pool.scout_player(selected_recruit)
	var msg: String = "Skill réel : %d\nSalaire demandé : %d or/sem\nAgent : %s" % [
		result.get("skill", 0),
		result.get("salary_demand", 0),
		"Oui" if result.get("has_agent", false) else "Non"
	]
	var revealed: Array = result.get("revealed_tags", [])
	if not revealed.is_empty():
		msg += "\nTraits révélés : " + ", ".join(revealed)
	_show_recruit_dialog(msg)
	_update_recruit_details()


func _format_success_message(result: Dictionary) -> String:
	var recruited_player: SimulatedPlayer = result.get("player", null) as SimulatedPlayer
	var player_name: String = recruited_player.nom if recruited_player else "La recrue"
	var text: String = String(result.get("reason", "%s rejoint la guilde !" % player_name))
	if result.has("salary"):
		text = "%s rejoint la guilde pour %d or/semaine !" % [player_name, result.get("salary", 0)]
	var agent_cost: int = int(result.get("agent_cost", 0))
	if agent_cost > 0:
		text += "\nCommission d'agent payée : %d or." % agent_cost
	return text


func _show_recruit_dialog(text: String) -> void:
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.dialog_text = text
	get_tree().root.add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.popup_centered()


func _add_detail_row(parent: GridContainer, label_text: String, value_text: String) -> void:
	var label: Label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 14)
	parent.add_child(label)

	var value: Label = Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 14)
	value.modulate = Color(0.9, 0.9, 1.0)
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(value)


func _get_planning_summary(planning: Dictionary) -> String:
	if selected_recruit and selected_recruit.has_method("get_schedule_summary"):
		return selected_recruit.get_schedule_summary()
	var active_days: Array[String] = []
	if planning.has("vendredi") and planning["vendredi"].get("soir", false):
		active_days.append("Vendredi soir")
	if planning.has("samedi") and (planning["samedi"].get("apres_midi", false) or planning["samedi"].get("soir", false)):
		active_days.append("Samedi")
	if planning.has("dimanche") and (planning["dimanche"].get("apres_midi", false) or planning["dimanche"].get("soir", false)):
		active_days.append("Dimanche")
	return "Peu actif" if active_days.is_empty() else "Actif: " + ", ".join(active_days)


func _build_guild_data() -> Dictionary:
	if recruitment_pool and recruitment_pool.has_method("get_current_guild_recruitment_data"):
		return recruitment_pool.get_current_guild_recruitment_data()
	var data: Dictionary = {"guild_size": guild_manager.guild_members.size() if guild_manager else 0}
	if guild_manager and guild_manager.guild:
		data["hardcore"] = false
		data["recent_raid_success"] = false
		data["reputation"] = guild_manager.guild.get_reputation()
	return data
