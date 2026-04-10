extends AcceptDialog
class_name FenetreLoot

const ItemScript = preload("res://scripts/resources/item.gd")

var header_label: Label
var result_label: Label
var time_value_label: Label
var gold_value_label: Label
var total_items_label: Label
var loot_container: VBoxContainer
var empty_label: Label

func _ready():
	_setup_ui()
	if has_method("get_ok_button"):
		var ok_button = get_ok_button()
		if ok_button:
			ok_button.text = "Fermer"
	connect("confirmed", Callable(self, "_on_dialog_closed"))
	connect("close_requested", Callable(self, "_on_dialog_closed"))

func show_loot_summary(
		dungeon_name: String,
		success: bool,
		total_time: float,
		gold_reward: int,
		loot_entries: Array,
		reason: String = ""
	) -> void:
	title = "Butin - %s" % dungeon_name
	
	header_label.text = "Victoire !" if success else "Expédition interrompue"
	
	if success:
		result_label.text = "Le groupe a vaincu tous les boss du donjon."
	else:
		var reason_text = reason if reason != "" else "Le groupe n'a pas réussi à terminer le donjon."
		result_label.text = reason_text
	
	time_value_label.text = _format_duration(total_time)
	gold_value_label.text = "%d or" % gold_reward if gold_reward > 0 else "0 or"
	
	_populate_loot_entries(loot_entries)
	popup_centered(Vector2i(560, 420))

func _setup_ui() -> void:
	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	
	header_label = Label.new()
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_label.add_theme_font_size_override("font_size", 22)
	root.add_child(header_label)
	
	result_label = Label.new()
	result_label.add_theme_font_size_override("font_size", 14)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.modulate = Color(0.85, 0.85, 0.85)
	root.add_child(result_label)
	
	var info_grid = GridContainer.new()
	info_grid.columns = 2
	info_grid.add_theme_constant_override("h_separation", 12)
	info_grid.add_theme_constant_override("v_separation", 6)
	root.add_child(info_grid)
	
	var time_label = Label.new()
	time_label.text = "Durée :"
	time_label.modulate = Color(0.8, 0.8, 0.8)
	info_grid.add_child(time_label)
	
	time_value_label = Label.new()
	time_value_label.text = "00:00"
	info_grid.add_child(time_value_label)
	
	var gold_label = Label.new()
	gold_label.text = "Récompense or :"
	gold_label.modulate = Color(0.8, 0.8, 0.8)
	info_grid.add_child(gold_label)
	
	gold_value_label = Label.new()
	gold_value_label.text = "0"
	info_grid.add_child(gold_value_label)
	
	total_items_label = Label.new()
	total_items_label.text = "Aucun objet obtenu"
	total_items_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_items_label.add_theme_font_size_override("font_size", 14)
	root.add_child(total_items_label)
	
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 220)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	root.add_child(scroll)
	
	loot_container = VBoxContainer.new()
	loot_container.add_theme_constant_override("separation", 8)
	scroll.add_child(loot_container)
	
	empty_label = Label.new()
	empty_label.text = "Aucun butin n'a été trouvé."
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.modulate = Color(0.7, 0.7, 0.7)
	loot_container.add_child(empty_label)

func _populate_loot_entries(loot_entries: Array) -> void:
	for child in loot_container.get_children():
		child.queue_free()

	var entries: Array = []
	if typeof(loot_entries) == TYPE_ARRAY:
		entries = loot_entries

	if entries.is_empty():
		empty_label = Label.new()
		empty_label.text = "Aucun butin n'a été trouvé."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.modulate = Color(0.7, 0.7, 0.7)
		loot_container.add_child(empty_label)
		total_items_label.text = "Aucun objet obtenu"
		return
	
	var totals: Dictionary = {}
	
	for entry in entries:
		var member_name = entry.get("member_name", "Membre inconnu")
		var item: ItemScript = entry.get("item", null)
		var boss_name = entry.get("boss_name", "")
		var drop_time = entry.get("time", 0.0)
		
		if not totals.has(member_name):
			totals[member_name] = 0
		totals[member_name] += 1
		
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		loot_container.add_child(row)
		
		var time_label = Label.new()
		time_label.text = "[%s]" % _format_duration(drop_time)
		time_label.custom_minimum_size = Vector2(80, 0)
		time_label.modulate = Color(0.75, 0.75, 0.75)
		row.add_child(time_label)
		
		var member_label = Label.new()
		member_label.text = member_name
		member_label.custom_minimum_size = Vector2(140, 0)
		row.add_child(member_label)
		
		var item_column = VBoxContainer.new()
		item_column.add_theme_constant_override("separation", 2)
		row.add_child(item_column)
		
		var item_label = Label.new()
		if item:
			item_label.text = item.get_display_name()
			item_label.modulate = item.get_rarity_color()
		else:
			item_label.text = "Objet inconnu"
		item_label.add_theme_font_size_override("font_size", 13)
		item_column.add_child(item_label)
		
		var detail_parts: Array[String] = []
		if boss_name != "":
			detail_parts.append("Boss : %s" % boss_name)
		if item:
			detail_parts.append("Slot : %s" % item.get_slot_name())
		var detail_label = Label.new()
		detail_label.text = " • ".join(detail_parts)
		detail_label.modulate = Color(0.75, 0.75, 0.75)
		detail_label.add_theme_font_size_override("font_size", 11)
		item_column.add_child(detail_label)
	
	var summary_parts: Array[String] = []
	var member_names = totals.keys()
	member_names.sort()
	for name in member_names:
		summary_parts.append("%s ×%d" % [name, totals[name]])
	
	var total_count = 0
	for count in totals.values():
		total_count += count
	
	total_items_label.text = "Objets obtenus : %d (%s)" % [total_count, ", ".join(summary_parts)]

func _format_duration(duration_seconds: float) -> String:
	var seconds = int(round(duration_seconds))
	if seconds < 0:
		seconds = 0
	var minutes = seconds / 60
	var remaining = seconds % 60
	return "%02d:%02d" % [minutes, remaining]

func _on_dialog_closed() -> void:
	queue_free()
