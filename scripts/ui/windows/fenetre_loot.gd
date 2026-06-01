extends AcceptDialog
class_name FenetreLoot

const ItemScript = preload("res://scripts/resources/item.gd")

var header_label: Label
var result_label: Label
var time_value_label: Label
var gold_value_label: Label
var boss_value_label: Label
var wipes_value_label: Label
var performance_value_label: Label
var participants_label: Label
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
		reason: String = "",
		run_details: Dictionary = {}
	) -> void:
	title = "Rapport PvE - %s" % dungeon_name
	
	header_label.text = "Victoire !" if success else "Expédition interrompue"
	
	if success:
		result_label.text = _build_success_summary(dungeon_name, total_time, run_details)
	else:
		var reason_text = reason if reason != "" else "Le groupe n'a pas réussi à terminer le donjon."
		result_label.text = reason_text
	
	time_value_label.text = _format_duration(total_time)
	gold_value_label.text = "%d or" % gold_reward if gold_reward > 0 else "0 or"
	_update_run_report(success, total_time, gold_reward, loot_entries, run_details)
	
	_populate_loot_entries(loot_entries)
	popup_centered(Vector2i(640, 520))

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
	
	var boss_label = Label.new()
	boss_label.text = "Boss :"
	boss_label.modulate = Color(0.8, 0.8, 0.8)
	info_grid.add_child(boss_label)
	
	boss_value_label = Label.new()
	boss_value_label.text = "0/0"
	info_grid.add_child(boss_value_label)
	
	var wipes_label = Label.new()
	wipes_label.text = "Wipes :"
	wipes_label.modulate = Color(0.8, 0.8, 0.8)
	info_grid.add_child(wipes_label)
	
	wipes_value_label = Label.new()
	wipes_value_label.text = "0"
	info_grid.add_child(wipes_value_label)
	
	var performance_label = Label.new()
	performance_label.text = "Performance :"
	performance_label.modulate = Color(0.8, 0.8, 0.8)
	info_grid.add_child(performance_label)
	
	performance_value_label = Label.new()
	performance_value_label.text = "0/100"
	info_grid.add_child(performance_value_label)
	
	participants_label = Label.new()
	participants_label.text = "Participants : -"
	participants_label.add_theme_font_size_override("font_size", 12)
	participants_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	participants_label.modulate = Color(0.78, 0.82, 0.92)
	root.add_child(participants_label)
	
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
		
		var item_hbox = HBoxContainer.new()
		item_hbox.add_theme_constant_override("separation", 6)
		item_column.add_child(item_hbox)

		if item:
			var slot_icon: Texture2D = AssetLoader.get_slot_icon(item.slot)
			if slot_icon:
				var icon_rect = TextureRect.new()
				icon_rect.texture = slot_icon
				icon_rect.custom_minimum_size = Vector2(18, 18)
				icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				item_hbox.add_child(icon_rect)

		var item_label = Label.new()
		if item:
			item_label.text = item.get_display_name()
			item_label.modulate = item.get_rarity_color()
		else:
			item_label.text = "Objet inconnu"
		item_label.add_theme_font_size_override("font_size", 13)
		item_hbox.add_child(item_label)
		
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

func _update_run_report(success: bool, total_time: float, gold_reward: int, loot_entries: Array, run_details: Dictionary) -> void:
	var bosses_defeated: int = int(run_details.get("bosses_defeated", 0))
	var total_bosses: int = int(run_details.get("total_bosses", bosses_defeated))
	var wipes: int = int(run_details.get("wipes", 0))
	var participants: Array = run_details.get("participants", [])
	var loot_count: int = loot_entries.size() if typeof(loot_entries) == TYPE_ARRAY else 0
	var performance_score: int = calculate_performance_score(success, total_time, gold_reward, loot_count, run_details)
	
	boss_value_label.text = "%d/%d" % [bosses_defeated, total_bosses]
	wipes_value_label.text = "%d" % wipes
	performance_value_label.text = "%d/100 (%s)" % [performance_score, get_performance_label(performance_score)]
	performance_value_label.modulate = _get_performance_color(performance_score)
	participants_label.text = "Participants : %s" % _format_participants(participants)

static func calculate_performance_score(success: bool, total_time: float, gold_reward: int, loot_count: int, run_details: Dictionary) -> int:
	var total_bosses: int = max(1, int(run_details.get("total_bosses", 1)))
	var bosses_defeated: int = clamp(int(run_details.get("bosses_defeated", 0)), 0, total_bosses)
	var wipes: int = max(0, int(run_details.get("wipes", 0)))
	var expected_duration: float = max(60.0, float(run_details.get("expected_duration_seconds", total_time)))
	
	var score: float = 20.0 + (float(bosses_defeated) / float(total_bosses)) * 45.0
	if success:
		score += 20.0
	score -= min(30.0, wipes * 7.0)
	
	if total_time > 0.0 and expected_duration > 0.0:
		var duration_ratio: float = total_time / expected_duration
		if duration_ratio <= 0.85:
			score += 10.0
		elif duration_ratio <= 1.1:
			score += 5.0
		elif duration_ratio > 1.4:
			score -= 10.0
	
	score += min(5.0, loot_count * 1.5)
	if gold_reward <= 0 and success:
		score -= 5.0
	
	return int(clamp(round(score), 0.0, 100.0))

static func get_performance_label(score: int) -> String:
	if score >= 85:
		return "excellent"
	if score >= 65:
		return "solide"
	if score >= 45:
		return "fragile"
	return "critique"

func _build_success_summary(dungeon_name: String, total_time: float, run_details: Dictionary) -> String:
	var bosses_defeated: int = int(run_details.get("bosses_defeated", 0))
	var total_bosses: int = int(run_details.get("total_bosses", bosses_defeated))
	var wipes: int = int(run_details.get("wipes", 0))
	return "%s termine en %s : %d/%d boss, %d wipe(s)." % [
		dungeon_name,
		_format_duration(total_time),
		bosses_defeated,
		total_bosses,
		wipes
	]

func _format_participants(participants: Array) -> String:
	if participants.is_empty():
		return "-"
	var names: Array[String] = []
	for participant in participants:
		names.append(str(participant))
	return ", ".join(names)

func _get_performance_color(score: int) -> Color:
	if score >= 85:
		return Color(0.35, 1.0, 0.45)
	if score >= 65:
		return Color(0.8, 0.95, 0.45)
	if score >= 45:
		return Color(1.0, 0.7, 0.25)
	return Color(1.0, 0.35, 0.35)

func _format_duration(duration_seconds: float) -> String:
	var seconds = int(round(duration_seconds))
	if seconds < 0:
		seconds = 0
	var minutes = seconds / 60
	var remaining = seconds % 60
	return "%02d:%02d" % [minutes, remaining]

func _on_dialog_closed() -> void:
	queue_free()
