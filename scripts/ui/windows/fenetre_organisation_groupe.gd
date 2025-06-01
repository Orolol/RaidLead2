extends PanelContainer

const DungeonDataScript = preload("res://scripts/data/dungeon_data.gd")
const DungeonRunScript = preload("res://scripts/systems/dungeon_run.gd")
const ActivityScript = preload("res://scripts/resources/activity.gd")

var close_button: Button
var title_label: Label

var activity_option: OptionButton
var instance_option: OptionButton
var launch_button: Button

var available_members_list: ItemList
var group_composition: VBoxContainer
var group_slots: Dictionary = {}

var guild_members: Array = []
var selected_activity: String = ""
var selected_instance: String = ""

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(900, 700)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)
	
	_setup_header(vbox)
	_setup_content(vbox)
	
	hide()

func _setup_header(parent: VBoxContainer):
	var header = HBoxContainer.new()
	parent.add_child(header)
	
	title_label = Label.new()
	title_label.text = "Organisation de Groupe"
	title_label.add_theme_font_size_override("font_size", 20)
	header.add_child(title_label)
	
	header.add_spacer(false)
	
	close_button = Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(30, 30)
	close_button.pressed.connect(_on_close_pressed)
	header.add_child(close_button)

func _setup_content(parent: VBoxContainer):
	_setup_activity_selection(parent)
	
	parent.add_child(HSeparator.new())
	
	var hsplit = HSplitContainer.new()
	hsplit.split_offset = 300
	parent.add_child(hsplit)
	
	_setup_available_members(hsplit)
	_setup_group_composition(hsplit)
	
	parent.add_child(HSeparator.new())
	
	_setup_launch_button(parent)

func _setup_activity_selection(parent: VBoxContainer):
	var selection_panel = PanelContainer.new()
	parent.add_child(selection_panel)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	selection_panel.add_child(hbox)
	
	var activity_label = Label.new()
	activity_label.text = "Type d'activité:"
	hbox.add_child(activity_label)
	
	activity_option = OptionButton.new()
	activity_option.add_item("Sélectionner...")
	activity_option.add_item("Donjon")
	activity_option.add_item("Raid")
	activity_option.add_item("Activité Fun")
	activity_option.item_selected.connect(_on_activity_selected)
	hbox.add_child(activity_option)
	
	hbox.add_child(VSeparator.new())
	
	var instance_label = Label.new()
	instance_label.text = "Instance:"
	hbox.add_child(instance_label)
	
	instance_option = OptionButton.new()
	instance_option.add_item("Sélectionner une activité d'abord")
	instance_option.disabled = true
	instance_option.item_selected.connect(_on_instance_selected)
	hbox.add_child(instance_option)

func _setup_available_members(parent: HSplitContainer):
	var left_panel = PanelContainer.new()
	parent.add_child(left_panel)
	
	var vbox = VBoxContainer.new()
	left_panel.add_child(vbox)
	
	var label = Label.new()
	label.text = "Membres Disponibles"
	label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(label)
	
	available_members_list = ItemList.new()
	available_members_list.custom_minimum_size = Vector2(250, 400)
	vbox.add_child(available_members_list)

func _setup_group_composition(parent: HSplitContainer):
	var right_panel = PanelContainer.new()
	parent.add_child(right_panel)
	
	group_composition = VBoxContainer.new()
	group_composition.add_theme_constant_override("separation", 10)
	right_panel.add_child(group_composition)
	
	var label = Label.new()
	label.text = "Composition du Groupe"
	label.add_theme_font_size_override("font_size", 16)
	group_composition.add_child(label)
	
	var info_label = Label.new()
	info_label.text = "Sélectionnez une activité pour voir les rôles requis"
	info_label.modulate = Color(0.7, 0.7, 0.7)
	group_composition.add_child(info_label)

func _setup_launch_button(parent: VBoxContainer):
	launch_button = Button.new()
	launch_button.text = "Lancer l'activité"
	launch_button.custom_minimum_size = Vector2(200, 50)
	launch_button.disabled = true
	launch_button.pressed.connect(_on_launch_pressed)
	
	var center_container = CenterContainer.new()
	center_container.add_child(launch_button)
	parent.add_child(center_container)

func _on_activity_selected(index: int):
	instance_option.clear()
	instance_option.disabled = index == 0
	
	match index:
		1:
			selected_activity = "dungeon"
			_populate_dungeon_list()
		2:
			selected_activity = "raid"
			_populate_raid_list()
		3:
			selected_activity = "fun"
			_populate_fun_list()
		_:
			selected_activity = ""
	
	selected_instance = ""
	_update_group_composition()
	_refresh_available_members()

func _populate_dungeon_list():
	instance_option.add_item("Sélectionner un donjon...")
	
	# Trie les donjons par niveau
	var dungeons = []
	for id in DungeonDataScript.DUNGEONS:
		var dungeon = DungeonDataScript.DUNGEONS[id]
		dungeons.append({"id": id, "data": dungeon})
	
	dungeons.sort_custom(func(a, b): return a.data.level_recommended < b.data.level_recommended)
	
	for dungeon in dungeons:
		var text = "%s (Niv. %d-%d)" % [dungeon.data.name, dungeon.data.level_min, dungeon.data.level_max]
		instance_option.add_item(text)
		instance_option.set_item_metadata(instance_option.get_item_count() - 1, dungeon.id)

func _populate_raid_list():
	instance_option.add_item("Sélectionner un raid...")
	
	for id in DungeonDataScript.RAIDS:
		var raid = DungeonDataScript.RAIDS[id]
		var text = "%s (%d joueurs)" % [raid.name, raid.group_size]
		instance_option.add_item(text)
		instance_option.set_item_metadata(instance_option.get_item_count() - 1, id)

func _populate_fun_list():
	instance_option.add_item("Sélectionner une activité...")
	instance_option.add_item("Duel amical devant Orgrimmar")
	instance_option.add_item("Course de montures")
	instance_option.add_item("Concours de pêche")
	instance_option.add_item("Chasse aux pets rares")

func _on_instance_selected(index: int):
	if index > 0:  # Ignorer "Sélectionner..."
		selected_instance = instance_option.get_item_metadata(index)
		if selected_instance == null:
			selected_instance = instance_option.get_item_text(index)
	else:
		selected_instance = ""
	_update_group_composition()

func _update_group_composition():
	for child in group_composition.get_children():
		child.queue_free()
	
	group_slots.clear()
	
	if selected_activity == "" or selected_instance == "":
		return
	
	var composition_label = Label.new()
	composition_label.text = "Composition requise:"
	composition_label.add_theme_font_size_override("font_size", 14)
	group_composition.add_child(composition_label)
	
	if selected_activity == "fun":
		var participants_label = Label.new()
		participants_label.text = "Participants (illimité)"
		group_composition.add_child(participants_label)
	else:
		# Récupère la composition depuis DungeonData
		var composition = DungeonDataScript.get_group_composition(selected_instance)
		if not composition.is_empty():
			for role in composition:
				_add_role_slot(role, composition[role])
		else:
			# Fallback pour activités non définies
			match selected_activity:
				"dungeon":
					_add_role_slot("Tank", 1)
					_add_role_slot("Healer", 1)
					_add_role_slot("DPS", 3)
	
	_check_launch_button()

func _add_role_slot(role: String, count: int):
	for i in count:
		var slot_hbox = HBoxContainer.new()
		slot_hbox.add_theme_constant_override("separation", 10)
		group_composition.add_child(slot_hbox)
		
		var role_label = Label.new()
		role_label.text = role + ":"
		role_label.custom_minimum_size.x = 80
		slot_hbox.add_child(role_label)
		
		var slot_button = Button.new()
		slot_button.text = "Vide - Cliquer pour assigner"
		slot_button.custom_minimum_size = Vector2(300, 30)
		slot_button.modulate = Color(0.8, 0.8, 0.8)
		slot_hbox.add_child(slot_button)
		
		var slot_id = role + "_" + str(i)
		group_slots[slot_id] = {
			"role": role,
			"button": slot_button,
			"member": null
		}
		
		slot_button.pressed.connect(_on_slot_clicked.bind(slot_id))

func _on_slot_clicked(slot_id: String):
	var slot = group_slots[slot_id]
	if slot.member:
		slot.member = null
		slot.button.text = "Vide - Cliquer pour assigner"
		slot.button.modulate = Color(0.8, 0.8, 0.8)
		_refresh_available_members()
		_check_launch_button()

func _check_launch_button():
	if selected_activity == "fun":
		launch_button.disabled = false
		return
	
	var all_filled = true
	for slot_id in group_slots:
		if group_slots[slot_id].member == null:
			all_filled = false
			break
	
	launch_button.disabled = not all_filled or selected_instance == ""

func _refresh_available_members():
	available_members_list.clear()
	
	for member in guild_members:
		if member.is_available_now():
			var assigned = false
			for slot_id in group_slots:
				if group_slots[slot_id].member == member:
					assigned = true
					break
			
			if not assigned:
				var text = "%s - %s (%s)" % [member.nom, member.personnage_classe, member.get_role()]
				available_members_list.add_item(text)

func _on_launch_pressed():
	if selected_activity == "fun":
		_launch_fun_activity()
	else:
		_launch_dungeon_or_raid()

func _launch_fun_activity():
	var participants = []
	for slot_id in group_slots:
		var slot = group_slots[slot_id]
		if slot.member != null:
			participants.append(slot.member)
	
	if participants.is_empty():
		var dialog = AcceptDialog.new()
		dialog.dialog_text = "Aucun participant sélectionné!"
		get_tree().root.add_child(dialog)
		dialog.popup_centered()
		return
	
	# Lance l'activité fun via l'ActivityManager
	var guild_manager = get_node("/root/GuildManager")
	if guild_manager and guild_manager.activity_manager:
		for member in participants:
			guild_manager.activity_manager.start_activity(
				member, 
				ActivityScript.ActivityType.FUN,
				{"name": selected_instance, "participants": participants}
			)
	
	var dialog = AcceptDialog.new()
	dialog.dialog_text = "Activité '%s' lancée avec %d participants!" % [selected_instance, participants.size()]
	get_tree().root.add_child(dialog)
	dialog.popup_centered()
	hide()

func _launch_dungeon_or_raid():
	# Vérifie que tous les slots sont remplis
	var group = []
	for slot_id in group_slots:
		var slot = group_slots[slot_id]
		if slot.member == null:
			var dialog = AcceptDialog.new()
			dialog.dialog_text = "Tous les rôles doivent être assignés!"
			get_tree().root.add_child(dialog)
			dialog.popup_centered()
			return
		group.append(slot.member)
	
	# Crée et démarre le DungeonRun
	var dungeon_run = DungeonRunScript.new()
	dungeon_run.start_run(selected_instance, group)
	
	# Connecte les signaux pour suivre la progression
	dungeon_run.boss_defeated.connect(_on_boss_defeated)
	dungeon_run.run_completed.connect(_on_run_completed)
	dungeon_run.player_wiped.connect(_on_player_wiped)
	
	# Pour le MVP, on simule le donjon directement
	_simulate_dungeon_run(dungeon_run)

func _simulate_dungeon_run(dungeon_run):
	var instance_data = dungeon_run.instance_data
	var result_text = "=== %s ===\n\n" % instance_data.name
	
	# Simule chaque boss
	for i in range(instance_data.bosses.size()):
		if not dungeon_run.can_continue():
			result_text += "\nLe groupe abandonne après trop de wipes!\n"
			break
			
		var result = dungeon_run.simulate_boss_fight(i)
		
		if result.success:
			result_text += "✓ %s vaincu!\n" % result.boss_name
		else:
			result_text += "✗ Wipe sur %s: %s\n" % [result.boss_name, result.wipe_reason]
	
	# Finalise le run
	var success = dungeon_run.defeated_bosses.size() == instance_data.bosses.size()
	dungeon_run.complete_run(success)
	
	if success:
		result_text += "\n🎉 Donjon complété avec succès!\n"
	else:
		result_text += "\n💀 Échec du donjon (%d/%d boss vaincus)\n" % [dungeon_run.defeated_bosses.size(), instance_data.bosses.size()]
	
	# Affiche le loot
	if not dungeon_run.loot_collected.is_empty():
		result_text += "\nLoot obtenu:\n"
		for member_name in dungeon_run.loot_collected:
			result_text += "- %s: +%d équipement\n" % [member_name, dungeon_run.loot_collected[member_name]]
	
	# Affiche les résultats
	var dialog = AcceptDialog.new()
	dialog.dialog_text = result_text
	dialog.title = "Résultat du donjon"
	get_tree().root.add_child(dialog)
	dialog.popup_centered(Vector2(500, 400))
	
	hide()

func _on_boss_defeated(boss_name: String, loot_dropped: bool):
	print("Boss vaincu: ", boss_name, " Loot: ", loot_dropped)

func _on_run_completed(success: bool, _loot_gained: Dictionary):
	print("Run terminé. Succès: ", success)

func _on_player_wiped(reason: String):
	print("Wipe! Raison: ", reason)

func _on_close_pressed():
	hide()

func set_guild_members(members: Array):
	guild_members = members
	_refresh_available_members()