extends Panel

signal close_requested
signal abandon_requested

const LootWindowScene = preload("res://scenes/Fenetre_Loot.tscn")

@onready var title_label: Label = $VBoxContainer/Header/Title
@onready var close_button: Button = $VBoxContainer/Header/CloseButton
@onready var dungeon_name_label: Label = $VBoxContainer/DungeonInfo/DungeonName
@onready var time_label: Label = $VBoxContainer/DungeonInfo/TimeElapsed
@onready var progression_container: Control = $VBoxContainer/ProgressionContainer
@onready var dungeon_path: Control = $VBoxContainer/ProgressionContainer/DungeonPath
@onready var path_line: Line2D = $VBoxContainer/ProgressionContainer/DungeonPath/PathLine
@onready var group_marker: Panel = $VBoxContainer/ProgressionContainer/DungeonPath/GroupMarker
@onready var boss_markers: Control = $VBoxContainer/ProgressionContainer/DungeonPath/BossMarkers
@onready var group_info_label: Label = $VBoxContainer/GroupInfo/Label
@onready var members_list: ItemList = $VBoxContainer/GroupInfo/MembersList
@onready var status_label: Label = $VBoxContainer/StatusContainer/StatusLabel
@onready var wipe_count_label: Label = $VBoxContainer/StatusContainer/WipeCount
@onready var abandon_button: Button = $VBoxContainer/ActionButtons/AbandonButton

var current_instance: DungeonInstance = null
var boss_marker_nodes: Array[Panel] = []
var path_back_line: Line2D = null
var update_timer: float = 0.0
var loot_history: Array = []

const COLOR_PANEL = Color(0.105, 0.115, 0.155, 0.98)
const COLOR_BORDER = Color(0.30, 0.34, 0.46, 0.9)
const COLOR_TEXT = Color(0.90, 0.92, 0.96, 1.0)
const COLOR_TEXT_MUTED = Color(0.68, 0.72, 0.80, 1.0)
const COLOR_DANGER = Color(0.68, 0.18, 0.23, 1.0)
const COLOR_BOSS_PENDING = Color(0.30, 0.33, 0.43, 1.0)
const COLOR_BOSS_CURRENT = Color(1.0, 0.83, 0.28, 1.0)
const COLOR_BOSS_DEFEATED = Color(0.28, 0.86, 0.48, 1.0)
const COLOR_BOSS_FAILED = Color(1.0, 0.34, 0.32, 1.0)
const COLOR_BOSS_FINAL = Color(0.96, 0.56, 0.20, 1.0)
const COLOR_GROUP = Color(0.36, 0.95, 0.52, 1.0)
const COLOR_PATH = Color(0.24, 0.27, 0.36, 1.0)
const COLOR_PATH_COMPLETED = Color(0.30, 0.78, 0.46, 1.0)
const PATH_MARGIN = 64.0

func _ready() -> void:
	# Configuration initiale
	custom_minimum_size = Vector2(800, 600)
	_apply_visual_polish()
	
	# Connecter aux signaux du ResizableWindow si présent
	if has_node("ResizableWindow"):
		var resizable = $ResizableWindow
		resizable.setup_window("Donjon en cours", Vector2(800, 600))

func _apply_visual_polish() -> void:
	add_theme_stylebox_override("panel", _make_panel_style(COLOR_PANEL, COLOR_BORDER, 8, 1, 0.0))
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", COLOR_TEXT)
	dungeon_name_label.add_theme_font_size_override("font_size", 13)
	dungeon_name_label.modulate = COLOR_TEXT_MUTED
	time_label.add_theme_font_size_override("font_size", 13)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_label.custom_minimum_size = Vector2(112, 0)
	time_label.modulate = COLOR_TEXT
	progression_container.custom_minimum_size = Vector2(0, 250)

	group_info_label.text = "Groupe"
	group_info_label.add_theme_font_size_override("font_size", 13)
	group_info_label.modulate = COLOR_TEXT_MUTED
	members_list.custom_minimum_size = Vector2(0, 112)
	members_list.add_theme_stylebox_override("panel", _make_panel_style(Color(0.08, 0.09, 0.12, 0.72), Color(0.24, 0.27, 0.36, 0.9), 5, 1, 6.0))
	members_list.add_theme_constant_override("v_separation", 3)

	status_label.modulate = COLOR_TEXT
	wipe_count_label.modulate = COLOR_TEXT
	close_button.custom_minimum_size = Vector2(34, 30)
	_apply_button_style(close_button, Color(0.17, 0.18, 0.24, 1.0), Color(0.24, 0.26, 0.34, 1.0), Color(0.12, 0.13, 0.18, 1.0))
	_apply_button_style(abandon_button, Color(0.31, 0.10, 0.13, 1.0), Color(0.44, 0.13, 0.17, 1.0), COLOR_DANGER)
	path_line.width = 7.0
	path_line.default_color = COLOR_PATH_COMPLETED
	_style_group_marker()

func _make_panel_style(bg_color: Color, border_color: Color, radius: int, border_width: int, margin: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = margin
	style.content_margin_top = margin
	style.content_margin_right = margin
	style.content_margin_bottom = margin
	return style

func _apply_button_style(button: Button, normal_color: Color, hover_color: Color, pressed_color: Color) -> void:
	button.add_theme_stylebox_override("normal", _make_panel_style(normal_color, COLOR_BORDER, 6, 1, 8.0))
	button.add_theme_stylebox_override("hover", _make_panel_style(hover_color, COLOR_BORDER, 6, 1, 8.0))
	button.add_theme_stylebox_override("pressed", _make_panel_style(pressed_color, COLOR_BORDER, 6, 1, 8.0))
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)

func _ensure_path_back_line() -> void:
	if is_instance_valid(path_back_line):
		return

	path_back_line = dungeon_path.get_node_or_null("PathBackLine") as Line2D
	if path_back_line == null:
		path_back_line = Line2D.new()
		path_back_line.name = "PathBackLine"
		dungeon_path.add_child(path_back_line)
		dungeon_path.move_child(path_back_line, path_line.get_index())

	path_back_line.width = 7.0
	path_back_line.default_color = COLOR_PATH
	path_back_line.z_index = 0
	path_line.z_index = 1
	boss_markers.z_index = 2
	group_marker.z_index = 3

func _get_path_width() -> float:
	return maxf(240.0, dungeon_path.size.x - PATH_MARGIN * 2.0)

func _get_path_center_y() -> float:
	return maxf(86.0, dungeon_path.size.y * 0.48)

func _style_group_marker() -> void:
	group_marker.modulate = Color.WHITE
	group_marker.custom_minimum_size = Vector2(22, 22)
	group_marker.size = Vector2(22, 22)
	group_marker.tooltip_text = "Position du groupe"
	group_marker.add_theme_stylebox_override("panel", _make_panel_style(Color(0.09, 0.28, 0.14, 1.0), COLOR_GROUP, 6, 2, 0.0))

func _apply_boss_marker_style(marker: Panel, color: Color, highlighted: bool) -> void:
	var bg_color := Color(color.r * 0.24, color.g * 0.24, color.b * 0.24, 1.0)
	var border_width: int = 2 if highlighted else 1
	marker.modulate = Color.WHITE
	marker.add_theme_stylebox_override("panel", _make_panel_style(bg_color, color, 6, border_width, 0.0))
	for child in marker.get_children():
		var label := child as Label
		if label != null:
			label.modulate = color if highlighted else COLOR_TEXT_MUTED

func _build_subtitle(dungeon_data_dict: Dictionary) -> String:
	var bosses: Array = dungeon_data_dict.get("bosses", [])
	var level_recommended: int = int(dungeon_data_dict.get("level_recommended", 0))
	var duration_minutes: int = int(dungeon_data_dict.get("duration_minutes", 0))
	var parts: Array[String] = ["Donjon en cours"]
	if level_recommended > 0:
		parts.append("Niv. %d" % level_recommended)
	if bosses.size() > 0:
		parts.append("%d boss" % bosses.size())
	if duration_minutes > 0:
		parts.append("~%d min" % duration_minutes)
	return " - ".join(parts)

func _get_role_color(role: String) -> Color:
	var role_lower: String = role.to_lower()
	if role_lower.contains("tank"):
		return Color(0.55, 0.74, 1.0, 1.0)
	if role_lower.contains("heal") or role_lower.contains("soin"):
		return Color(0.52, 1.0, 0.66, 1.0)
	if role_lower.contains("dps"):
		return Color(1.0, 0.78, 0.50, 1.0)
	return COLOR_TEXT

func set_dungeon_instance(instance: DungeonInstance) -> void:
	# Déconnecter l'ancienne instance
	if current_instance:
		_disconnect_instance_signals()
		
	current_instance = instance
	loot_history.clear()
	
	if current_instance:
		_connect_instance_signals()
		_setup_display()
		_update_display()

func _disconnect_instance_signals() -> void:
	if not current_instance:
		return
		
	if current_instance.boss_reached.is_connected(_on_boss_reached):
		current_instance.boss_reached.disconnect(_on_boss_reached)
	if current_instance.boss_defeated.is_connected(_on_boss_defeated):
		current_instance.boss_defeated.disconnect(_on_boss_defeated)
	if current_instance.boss_failed.is_connected(_on_boss_failed):
		current_instance.boss_failed.disconnect(_on_boss_failed)
	if current_instance.dungeon_completed.is_connected(_on_dungeon_completed):
		current_instance.dungeon_completed.disconnect(_on_dungeon_completed)
	if current_instance.dungeon_abandoned.is_connected(_on_dungeon_abandoned):
		current_instance.dungeon_abandoned.disconnect(_on_dungeon_abandoned)
	if current_instance.progress_updated.is_connected(_on_progress_updated):
		current_instance.progress_updated.disconnect(_on_progress_updated)
	if current_instance.loot_distributed.is_connected(_on_loot_distributed):
		current_instance.loot_distributed.disconnect(_on_loot_distributed)

func _connect_instance_signals() -> void:
	current_instance.boss_reached.connect(_on_boss_reached)
	current_instance.boss_defeated.connect(_on_boss_defeated)
	current_instance.boss_failed.connect(_on_boss_failed)
	current_instance.dungeon_completed.connect(_on_dungeon_completed)
	current_instance.dungeon_abandoned.connect(_on_dungeon_abandoned)
	current_instance.progress_updated.connect(_on_progress_updated)
	current_instance.loot_distributed.connect(_on_loot_distributed)

func _setup_display() -> void:
	var dungeon_data_dict: Dictionary = current_instance.dungeon_data
	var dungeon_name: String = dungeon_data_dict.get("name", "Donjon inconnu")
	title_label.text = dungeon_name
	dungeon_name_label.text = _build_subtitle(dungeon_data_dict)

	var dungeon_id: String = dungeon_data_dict.get("id", "")
	var banner: Texture2D = AssetLoader.get_dungeon_banner(dungeon_id)
	if banner:
		var banner_rect: TextureRect = dungeon_path.get_node_or_null("BannerRect")
		if not banner_rect:
			banner_rect = TextureRect.new()
			banner_rect.name = "BannerRect"
			banner_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			banner_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			banner_rect.modulate = Color(0.42, 0.45, 0.52, 0.36)
			banner_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			banner_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dungeon_path.add_child(banner_rect)
			dungeon_path.move_child(banner_rect, 0)
		banner_rect.texture = banner

	await get_tree().process_frame

	# Configurer la ligne du chemin
	_ensure_path_back_line()
	var path_start := Vector2(PATH_MARGIN, _get_path_center_y())
	var path_end := Vector2(PATH_MARGIN + _get_path_width(), _get_path_center_y())
	path_back_line.clear_points()
	path_back_line.add_point(path_start)
	path_back_line.add_point(path_end)
	path_line.clear_points()
	path_line.add_point(path_start)
	path_line.add_point(path_end)
	path_line.default_color = COLOR_PATH_COMPLETED
	_style_group_marker()
	
	# Créer les marqueurs de boss
	_create_boss_markers()
	
	# Remplir la liste des membres
	_update_members_list()

func _create_boss_markers() -> void:
	# Nettoyer les anciens marqueurs
	for marker in boss_marker_nodes:
		marker.queue_free()
	boss_marker_nodes.clear()

	var bosses: Array = current_instance.dungeon_data.get("bosses", [])
	var positions: Array[float] = current_instance.boss_positions

	# S'assurer que les dimensions sont correctes
	var path_width: float = _get_path_width()
	var path_center_y: float = _get_path_center_y()

	for i in range(bosses.size()):
		var boss_name: String = bosses[i]
		var position: float = positions[i] if i < positions.size() else float(i) / float(max(1, bosses.size() - 1))

		# Créer le marqueur
		var marker := Panel.new()
		marker.custom_minimum_size = Vector2(34, 34)
		marker.size = Vector2(34, 34)
		marker.tooltip_text = boss_name

		# Positionner le marqueur le long du chemin
		var x_pos: float = PATH_MARGIN + position * path_width
		var y_pos: float = path_center_y - 17.0  # Centrer verticalement
		marker.position = Vector2(x_pos, y_pos)

		# Couleur selon le statut
		if i == bosses.size() - 1:
			_apply_boss_marker_style(marker, COLOR_BOSS_FINAL, false)
		else:
			_apply_boss_marker_style(marker, COLOR_BOSS_PENDING, false)

		# Ajouter un label pour le nom du boss
		var label := Label.new()
		label.text = boss_name
		label.add_theme_font_size_override("font_size", 11)
		label.position = Vector2(-35, 35)  # Décaler en dessous du marqueur
		label.size = Vector2(142, 34)
		label.position = Vector2(-54, 42)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.clip_text = true
		label.modulate = COLOR_TEXT_MUTED
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker.add_child(label)
		
		boss_markers.add_child(marker)
		boss_marker_nodes.append(marker)

func _update_members_list() -> void:
	members_list.clear()
	
	for member in current_instance.group_members:
		var energy: int = int(round(member.energy))
		var text: String = "%s - %s Niv.%d" % [
			member.nom,
			member.personnage_role,
			member.personnage_niveau
		]
		members_list.add_item(text)
		var item_index: int = members_list.get_item_count() - 1
		members_list.set_item_custom_fg_color(item_index, _get_role_color(member.personnage_role))
		members_list.set_item_tooltip(item_index, "%s - %s - Energie %d%%" % [
			member.nom,
			member.personnage_role,
			energy
		])

func _process(delta: float) -> void:
	if not current_instance or not current_instance.is_active:
		return
		
	update_timer += delta
	if update_timer >= 0.1:  # Mettre à jour 10 fois par seconde
		update_timer = 0.0
		_update_display()

func _update_display() -> void:
	# Mettre à jour le temps
	var game_time = GameTime
	var elapsed: float = current_instance.get_elapsed_time(game_time)
	var minutes: int = int(elapsed) / 60
	var seconds: int = int(elapsed) % 60
	time_label.text = "Temps %02d:%02d" % [minutes, seconds]

	# Mettre à jour la position du groupe avec les bonnes dimensions
	_ensure_path_back_line()
	var path_width: float = _get_path_width()
	var path_center_y: float = _get_path_center_y()
	var group_x: float = PATH_MARGIN + current_instance.current_position * path_width
	var group_y: float = path_center_y - 11.0
	group_marker.position = Vector2(group_x - 11.0, group_y)

	# Mettre à jour la ligne du chemin
	var path_start := Vector2(PATH_MARGIN, path_center_y)
	var completed_end := Vector2(group_x, path_center_y)
	var path_end := Vector2(PATH_MARGIN + path_width, path_center_y)

	path_back_line.clear_points()
	path_back_line.add_point(path_start)
	path_back_line.add_point(path_end)

	path_line.clear_points()
	path_line.add_point(path_start)
	path_line.add_point(completed_end)
	path_line.default_color = COLOR_PATH_COMPLETED
	
	# Mettre à jour le nombre de wipes
	wipe_count_label.text = "Wipes: %d" % current_instance.total_wipes
	
	# Mettre à jour les couleurs des boss
	for i in range(boss_marker_nodes.size()):
		if i < current_instance.current_boss_index:
			_apply_boss_marker_style(boss_marker_nodes[i], COLOR_BOSS_DEFEATED, false)
		elif i == current_instance.current_boss_index and current_instance.is_fighting_boss:
			_apply_boss_marker_style(boss_marker_nodes[i], COLOR_BOSS_CURRENT, true)

func _on_boss_reached(boss_index: int, boss_name: String) -> void:
	status_label.text = "Combat contre %s..." % boss_name
	if boss_index < boss_marker_nodes.size():
		_apply_boss_marker_style(boss_marker_nodes[boss_index], COLOR_BOSS_CURRENT, true)

func _on_boss_defeated(boss_index: int, boss_name: String, loot_winner: SimulatedPlayer) -> void:
	if loot_winner:
		status_label.text = "%s vaincu! Loot: %s" % [boss_name, loot_winner.nom]
	else:
		status_label.text = "%s vaincu!" % boss_name
		
	if boss_index < boss_marker_nodes.size():
		_apply_boss_marker_style(boss_marker_nodes[boss_index], COLOR_BOSS_DEFEATED, false)

func _on_boss_failed(boss_index: int, boss_name: String, wipe_count: int) -> void:
	status_label.text = "Wipe sur %s (tentative %d)" % [boss_name, wipe_count]
	if boss_index < boss_marker_nodes.size():
		# Flash rouge temporaire
		_apply_boss_marker_style(boss_marker_nodes[boss_index], COLOR_BOSS_FAILED, true)
		await get_tree().create_timer(1.0).timeout
		if boss_index < boss_marker_nodes.size():
			_apply_boss_marker_style(boss_marker_nodes[boss_index], COLOR_BOSS_CURRENT, true)

func _on_dungeon_completed(total_time: float, gold_reward: int) -> void:
	var minutes: int = int(total_time) / 60
	var seconds: int = int(total_time) % 60
	status_label.text = "Donjon terminé en %02d:%02d! Récompense: %d or" % [minutes, seconds, gold_reward]
	abandon_button.disabled = true
	
	# Colorer tous les boss en vert
	for marker in boss_marker_nodes:
		_apply_boss_marker_style(marker, COLOR_BOSS_DEFEATED, false)

	_show_loot_window(true, total_time, gold_reward)

func _on_dungeon_abandoned(reason: String) -> void:
	status_label.text = "Donjon abandonné: %s" % reason
	abandon_button.disabled = true

	var elapsed: float = 0.0
	if current_instance:
		elapsed = current_instance.get_elapsed_time(current_instance.game_time_node)
	_show_loot_window(false, elapsed, 0, reason)

func _on_progress_updated(_progress_percent: float) -> void:
	# Peut être utilisé pour une barre de progression globale
	pass

func _on_loot_distributed(member: SimulatedPlayer, item: Item) -> void:
	if not current_instance or not item or not member:
		return

	var bosses: Array = current_instance.dungeon_data.get("bosses", [])
	var boss_index: int = clamp(current_instance.current_boss_index, 0, bosses.size() - 1) if bosses.size() > 0 else 0
	var boss_name = bosses[boss_index] if boss_index < bosses.size() else ""
	var drop_time: float = current_instance.get_elapsed_time(current_instance.game_time_node)

	loot_history.append({
		"member_name": member.nom,
		"member": member,
		"item": item,
		"boss_name": boss_name,
		"time": drop_time
	})

func _on_close_button_pressed() -> void:
	close_requested.emit()

func _on_abandon_button_pressed() -> void:
	if current_instance and current_instance.is_active:
		# Demander confirmation avec ConfirmDialog
		var dialog = load("res://scripts/ui/components/confirm_dialog.gd").new()
		dialog.dialog_type = dialog.DialogType.WARNING
		dialog.title_text = "Abandonner le donjon"
		dialog.message_text = "Êtes-vous sûr de vouloir abandonner le donjon?\nTous les membres perdront de l'énergie et le moral baissera."
		# Propriétaire unique de l'abandon : on se contente d'émettre le signal.
		# Le parent (Fenetre_OrganisationGroupe) est l'unique exécutant de
		# l'abandon réel — éviter d'appliquer les conséquences deux fois (C14).
		dialog.confirmed.connect(func() -> void:
			abandon_requested.emit()
		)
		get_tree().root.add_child(dialog)
		dialog.show_dialog()

func _show_loot_window(success: bool, total_time: float, gold_reward: int, reason: String = "") -> void:
	if not LootWindowScene:
		return

	var loot_data: Array = loot_history.duplicate(true)
	loot_history.clear()

	var loot_window = LootWindowScene.instantiate()
	if not loot_window:
		return

	get_tree().root.add_child(loot_window)
	var dungeon_name: String = "Donjon"
	if current_instance and current_instance.dungeon_data.has("name"):
		dungeon_name = str(current_instance.dungeon_data.get("name"))
	var run_details: Dictionary = _build_run_report_details()

	if loot_window.has_method("show_loot_summary"):
		loot_window.show_loot_summary(dungeon_name, success, total_time, gold_reward, loot_data, reason, run_details)
	else:
		loot_window.popup_centered()

func _build_run_report_details() -> Dictionary:
	if not current_instance:
		return {}
	
	var participants: Array[String] = []
	for member in current_instance.group_members:
		if member:
			participants.append(member.nom)
	
	var bosses: Array = current_instance.dungeon_data.get("bosses", [])
	return {
		"content_id": current_instance.dungeon_id,
		"participants": participants,
		"bosses_defeated": min(current_instance.current_boss_index, bosses.size()),
		"total_bosses": bosses.size(),
		"wipes": current_instance.total_wipes,
		"expected_duration_seconds": float(current_instance.dungeon_data.get("duration_minutes", 60)) * 60.0
	}
