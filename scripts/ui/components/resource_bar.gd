extends PanelContainer
class_name ResourceBar

signal resource_action_requested(action: String)

const SPEED_PRESETS: Array[Dictionary] = [
	{"label": "1x", "value": 1.0},
	{"label": "10x", "value": 10.0},
	{"label": "60x", "value": 60.0},
	{"label": "600x", "value": 600.0},
	{"label": "Max", "value": 2400.0},
]

var _gold_button: Button
var _reputation_button: Button
var _morale_button: Button
var _online_button: Button
var _server_label: Label
var _date_label: Label
var _time_label: Label
var _speed_label: Label
var _pause_button: Button
var _debug_patch_button: Button
var _speed_buttons: Array[Button] = []

func _ready() -> void:
	custom_minimum_size = Vector2(0, 56)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _panel_style())
	_build_ui()
	_connect_signals()
	refresh_all()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(row)

	_gold_button = _make_resource_button("OR", "Tresorerie", "gold", 110)
	row.add_child(_gold_button)
	_reputation_button = _make_resource_button("REP", "Reputation de guilde", "reputation", 118)
	row.add_child(_reputation_button)
	_morale_button = _make_resource_button("MORAL", "Moral de guilde", "morale", 126)
	row.add_child(_morale_button)
	_online_button = _make_resource_button("ONLINE", "Membres en ligne", "roster", 132)
	row.add_child(_online_button)

	row.add_child(VSeparator.new())

	_server_label = Label.new()
	_server_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_server_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_server_label.clip_text = true
	_server_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_server_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	row.add_child(_server_label)

	row.add_child(VSeparator.new())

	_date_label = _make_status_label(158)
	row.add_child(_date_label)
	_time_label = _make_status_label(116)
	row.add_child(_time_label)
	_speed_label = _make_status_label(86)
	row.add_child(_speed_label)

	_pause_button = Button.new()
	_pause_button.text = "Pause"
	_pause_button.custom_minimum_size = Vector2(92, 36)
	_pause_button.tooltip_text = "Mettre en pause / reprendre"
	_pause_button.pressed.connect(_on_pause_pressed)
	row.add_child(_pause_button)

	for preset in SPEED_PRESETS:
		var speed_button: Button = _make_speed_button(str(preset["label"]), float(preset["value"]))
		row.add_child(speed_button)
		_speed_buttons.append(speed_button)

	_debug_patch_button = Button.new()
	_debug_patch_button.text = "Patch"
	_debug_patch_button.custom_minimum_size = Vector2(80, 36)
	_debug_patch_button.tooltip_text = "Debug: passer au prochain patch serveur"
	_debug_patch_button.visible = OS.is_debug_build()
	_debug_patch_button.pressed.connect(_on_debug_patch_pressed)
	row.add_child(_debug_patch_button)

func _make_resource_button(prefix: String, tooltip: String, action: String, min_width: int) -> Button:
	var button := Button.new()
	button.text = "%s --" % prefix
	button.custom_minimum_size = Vector2(min_width, 36)
	button.tooltip_text = tooltip
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.pressed.connect(func() -> void:
		resource_action_requested.emit(action)
	)
	return button

func _make_speed_button(label: String, value: float) -> Button:
	var button := Button.new()
	button.text = label
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(54, 36)
	button.tooltip_text = "Vitesse x%.0f" % value
	button.set_meta("speed_value", value)
	button.pressed.connect(_on_speed_preset_pressed.bind(value))
	return button

func _make_status_label(min_width: int) -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(min_width, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", UITheme.TEXT)
	return label

func _connect_signals() -> void:
	if GameTime:
		if not GameTime.minute_changed.is_connected(_on_minute_changed):
			GameTime.minute_changed.connect(_on_minute_changed)
		if not GameTime.hour_changed.is_connected(_on_hour_changed):
			GameTime.hour_changed.connect(_on_hour_changed)
		if not GameTime.day_changed.is_connected(_on_day_changed):
			GameTime.day_changed.connect(_on_day_changed)
		if GameTime.has_signal("speed_changed") and not GameTime.speed_changed.is_connected(_on_speed_changed):
			GameTime.speed_changed.connect(_on_speed_changed)
		if GameTime.has_signal("pause_changed") and not GameTime.pause_changed.is_connected(_on_pause_changed):
			GameTime.pause_changed.connect(_on_pause_changed)
	if ServerVersion:
		if not ServerVersion.version_updated.is_connected(_on_version_updated):
			ServerVersion.version_updated.connect(_on_version_updated)
		if ServerVersion.has_signal("hype_changed") and not ServerVersion.hype_changed.is_connected(_on_hype_changed):
			ServerVersion.hype_changed.connect(_on_hype_changed)
	if GuildManager:
		if not GuildManager.member_connected.is_connected(_on_roster_changed):
			GuildManager.member_connected.connect(_on_roster_changed)
		if not GuildManager.member_disconnected.is_connected(_on_roster_changed):
			GuildManager.member_disconnected.connect(_on_roster_changed)
		if not GuildManager.member_recruited.is_connected(_on_roster_changed):
			GuildManager.member_recruited.connect(_on_roster_changed)
		if GuildManager.has_signal("member_left") and not GuildManager.member_left.is_connected(_on_roster_changed):
			GuildManager.member_left.connect(_on_roster_changed)
		_connect_guild_signals()
	if GuildCultureManager:
		if not GuildCultureManager.morale_changed.is_connected(_on_morale_changed):
			GuildCultureManager.morale_changed.connect(_on_morale_changed)
	if SaveManager:
		if not SaveManager.load_completed.is_connected(_on_save_loaded):
			SaveManager.load_completed.connect(_on_save_loaded)

func _connect_guild_signals() -> void:
	if not (GuildManager and GuildManager.guild):
		return
	var guild: Guild = GuildManager.guild
	if not guild.gold_changed.is_connected(_on_gold_changed):
		guild.gold_changed.connect(_on_gold_changed)
	if not guild.reputation_changed.is_connected(_on_reputation_changed):
		guild.reputation_changed.connect(_on_reputation_changed)

func refresh_all() -> void:
	_connect_guild_signals()
	_refresh_resources()
	_refresh_time()
	_refresh_server()
	_refresh_speed()

func _refresh_resources() -> void:
	if GuildManager and GuildManager.guild:
		var guild: Guild = GuildManager.guild
		_gold_button.text = "OR %s" % _format_gold(guild.gold)
		_gold_button.tooltip_text = "Tresorerie: %d or" % guild.gold
		_reputation_button.text = "REP %d" % int(round(guild.get_reputation()))
		_reputation_button.tooltip_text = "Reputation: %s (%.1f)" % [guild.get_reputation_tier(), guild.get_reputation()]
	else:
		_gold_button.text = "OR --"
		_reputation_button.text = "REP --"

	if GuildCultureManager and GuildCultureManager.has_method("get_guild_morale"):
		var morale: float = GuildCultureManager.get_guild_morale()
		var tier: String = GuildCultureManager.get_morale_tier() if GuildCultureManager.has_method("get_morale_tier") else ""
		_morale_button.text = "MORAL %d" % int(round(morale))
		_morale_button.tooltip_text = "Moral: %s (%.1f)" % [tier, morale]
	else:
		_morale_button.text = "MORAL --"

	if GuildManager:
		var online_count: int = GuildManager.get_online_members().size()
		var total_count: int = GuildManager.guild_members.size()
		_online_button.text = "ONLINE %d/%d" % [online_count, total_count]
		_online_button.tooltip_text = "%d membre(s) connecte(s) sur %d" % [online_count, total_count]
	else:
		_online_button.text = "ONLINE --"

func _refresh_time() -> void:
	if not GameTime:
		_date_label.text = "Date --"
		_time_label.text = "--:--"
		return
	_date_label.text = GameTime.get_current_date_string()
	_time_label.text = GameTime.get_current_time_string()
	if GameTime.is_paused:
		_time_label.text += " PAUSE"
		_time_label.add_theme_color_override("font_color", UIConstants.COLOR_WARNING)
	else:
		_time_label.add_theme_color_override("font_color", UITheme.TEXT)
	_pause_button.text = "Reprendre" if GameTime.is_paused else "Pause"

func _refresh_server() -> void:
	if not ServerVersion:
		_server_label.text = "Serveur --"
		return
	var version_info: Dictionary = ServerVersion.get_current_version_info()
	var server_text: String = "Serveur v%s - %s" % [str(ServerVersion.get_current_version()), str(version_info.get("name", ""))]
	if ServerVersion.has_method("get_server_hype"):
		server_text += " | Hype %d%%" % int(round(ServerVersion.get_server_hype()))
	var days_until_next: int = ServerVersion.get_days_until_next_version()
	if days_until_next > 0:
		server_text += " | Patch J-%d" % days_until_next
	elif days_until_next == 0:
		server_text += " | Patch imminent"
	_server_label.text = server_text

func _refresh_speed() -> void:
	if not GameTime:
		_speed_label.text = "x--"
		return
	_speed_label.text = "x%.0f" % GameTime.time_speed
	for button in _speed_buttons:
		var value: float = float(button.get_meta("speed_value", 0.0))
		button.set_pressed_no_signal(is_equal_approx(value, GameTime.time_speed))

func _format_gold(value: int) -> String:
	if value >= 1000000:
		return "%.1fM" % [float(value) / 1000000.0]
	if value >= 10000:
		return "%.1fk" % [float(value) / 1000.0]
	return str(value)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UITheme.BG_PANEL
	style.bg_color.a = 0.96
	style.set_corner_radius_all(UITheme.RADIUS)
	style.set_border_width_all(1)
	style.border_color = UITheme.BORDER
	return style

func _on_pause_pressed() -> void:
	if GameTime:
		GameTime.toggle_pause()

func _on_speed_preset_pressed(value: float) -> void:
	if GameTime:
		GameTime.set_time_speed(value)

func _on_debug_patch_pressed() -> void:
	if not ServerVersion:
		return
	var current_version: float = ServerVersion.get_current_version()
	var next_version: Variant = null
	for version in ServerVersion.get_all_versions():
		if float(version) > current_version:
			if next_version == null or float(version) < float(next_version):
				next_version = version
	if next_version != null:
		ServerVersion.force_version_update(float(next_version))

func _on_gold_changed(_old_gold: int, _new_gold: int) -> void:
	_refresh_resources()

func _on_reputation_changed(_old_reputation: float, _new_reputation: float, _reason: String) -> void:
	_refresh_resources()

func _on_morale_changed(_new_morale: float, _old_morale: float) -> void:
	_refresh_resources()

func _on_roster_changed(_player: Variant = null) -> void:
	_refresh_resources()

func _on_minute_changed(_minute: int, _hour: int) -> void:
	_refresh_time()

func _on_hour_changed(_hour: int) -> void:
	_refresh_time()

func _on_day_changed(_day: int, _week: int, _year: int) -> void:
	_refresh_time()

func _on_speed_changed(_speed: float) -> void:
	_refresh_speed()

func _on_pause_changed(_paused: bool) -> void:
	_refresh_time()

func _on_version_updated(_new_version: float, _update_name: String) -> void:
	_refresh_server()

func _on_hype_changed(_new_hype: float, _old_hype: float) -> void:
	_refresh_server()

func _on_save_loaded(_success: bool) -> void:
	refresh_all()
