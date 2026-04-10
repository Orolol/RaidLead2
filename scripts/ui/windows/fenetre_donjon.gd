extends Panel

signal close_requested
signal abandon_requested

const LootWindowScene = preload("res://scenes/Fenetre_Loot.tscn")

@onready var title_label: Label = $VBoxContainer/Header/Title
@onready var dungeon_name_label: Label = $VBoxContainer/DungeonInfo/DungeonName
@onready var time_label: Label = $VBoxContainer/DungeonInfo/TimeElapsed
@onready var dungeon_path: Control = $VBoxContainer/ProgressionContainer/DungeonPath
@onready var path_line: Line2D = $VBoxContainer/ProgressionContainer/DungeonPath/PathLine
@onready var group_marker: Panel = $VBoxContainer/ProgressionContainer/DungeonPath/GroupMarker
@onready var boss_markers: Control = $VBoxContainer/ProgressionContainer/DungeonPath/BossMarkers
@onready var members_list: ItemList = $VBoxContainer/GroupInfo/MembersList
@onready var status_label: Label = $VBoxContainer/StatusContainer/StatusLabel
@onready var wipe_count_label: Label = $VBoxContainer/StatusContainer/WipeCount
@onready var abandon_button: Button = $VBoxContainer/ActionButtons/AbandonButton

var current_instance: DungeonInstance = null
var boss_marker_nodes: Array[Panel] = []
var update_timer: float = 0.0
var loot_history: Array = []

# Couleurs
const COLOR_BOSS_PENDING = Color(0.8, 0.8, 0.8, 1)
const COLOR_BOSS_CURRENT = Color(1, 1, 0, 1)
const COLOR_BOSS_DEFEATED = Color(0, 0.8, 0, 1)
const COLOR_BOSS_FAILED = Color(1, 0, 0, 1)
const COLOR_BOSS_FINAL = Color(1, 0.5, 0, 1)
const COLOR_GROUP = Color(0, 0.8, 0, 1)
const COLOR_PATH = Color(0.4, 0.4, 0.4, 1)
const COLOR_PATH_COMPLETED = Color(0, 0.6, 0, 1)

func _ready() -> void:
	# Configuration initiale
	custom_minimum_size = Vector2(800, 600)
	
	# Connecter aux signaux du ResizableWindow si présent
	if has_node("ResizableWindow"):
		var resizable = $ResizableWindow
		resizable.setup_window("Donjon en cours", Vector2(800, 600))

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
	# Mettre à jour les infos du donjon
	var dungeon_data = current_instance.dungeon_data
	dungeon_name_label.text = dungeon_data.get("name", "Donjon inconnu")
	title_label.text = "Donjon: " + dungeon_data.get("name", "Inconnu")
	
	# Attendre le prochain frame pour que la taille soit correcte
	await get_tree().process_frame
	
	# Configurer la ligne du chemin
	var path_start = Vector2(50, dungeon_path.size.y / 2)
	var path_end = Vector2(dungeon_path.size.x - 50, dungeon_path.size.y / 2)
	path_line.clear_points()
	path_line.add_point(path_start)
	path_line.add_point(path_end)
	
	# Créer les marqueurs de boss
	_create_boss_markers()
	
	# Remplir la liste des membres
	_update_members_list()

func _create_boss_markers() -> void:
	# Nettoyer les anciens marqueurs
	for marker in boss_marker_nodes:
		marker.queue_free()
	boss_marker_nodes.clear()
	
	var bosses = current_instance.dungeon_data.get("bosses", [])
	var positions = current_instance.boss_positions
	
	# S'assurer que les dimensions sont correctes
	var path_width = max(700, dungeon_path.size.x - 100)
	var path_height = dungeon_path.size.y
	var path_center_y = path_height / 2
	
	for i in range(bosses.size()):
		var boss_name = bosses[i]
		var position = positions[i] if i < positions.size() else float(i) / float(max(1, bosses.size() - 1))
		
		# Créer le marqueur
		var marker = Panel.new()
		marker.custom_minimum_size = Vector2(30, 30)
		marker.size = Vector2(30, 30)
		
		# Positionner le marqueur le long du chemin
		var x_pos = 50 + position * path_width
		var y_pos = path_center_y - 15  # Centrer verticalement
		marker.position = Vector2(x_pos, y_pos)
		
		# Couleur selon le statut
		if i == bosses.size() - 1:
			marker.modulate = COLOR_BOSS_FINAL
		else:
			marker.modulate = COLOR_BOSS_PENDING
			
		# Ajouter un label pour le nom du boss
		var label = Label.new()
		label.text = boss_name
		label.add_theme_font_size_override("font_size", 10)
		label.position = Vector2(-35, 35)  # Décaler en dessous du marqueur
		label.size = Vector2(100, 20)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker.add_child(label)
		
		boss_markers.add_child(marker)
		boss_marker_nodes.append(marker)

func _update_members_list() -> void:
	members_list.clear()
	
	for member in current_instance.group_members:
		var text = "%s - %s Niv.%d" % [
			member.nom,
			member.personnage_role,
			member.personnage_niveau
		]
		members_list.add_item(text)

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
	var elapsed = current_instance.get_elapsed_time(game_time)
	var minutes = int(elapsed) / 60
	var seconds = int(elapsed) % 60
	time_label.text = "Temps: %02d:%02d" % [minutes, seconds]
	
	# Mettre à jour la position du groupe avec les bonnes dimensions
	var path_width = max(700, dungeon_path.size.x - 100)
	var path_center_y = dungeon_path.size.y / 2
	var group_x = 50 + current_instance.current_position * path_width
	var group_y = path_center_y - 10
	group_marker.position = Vector2(group_x - 10, group_y)
	
	# Mettre à jour la ligne du chemin
	var path_start = Vector2(50, path_center_y)
	var completed_end = Vector2(group_x, path_center_y)
	var path_end = Vector2(50 + path_width, path_center_y)
	
	path_line.clear_points()
	path_line.add_point(path_start)
	path_line.add_point(completed_end)
	path_line.default_color = COLOR_PATH_COMPLETED
	
	# Mettre à jour le nombre de wipes
	wipe_count_label.text = "Wipes: %d" % current_instance.total_wipes
	
	# Mettre à jour les couleurs des boss
	for i in range(boss_marker_nodes.size()):
		if i < current_instance.current_boss_index:
			boss_marker_nodes[i].modulate = COLOR_BOSS_DEFEATED
		elif i == current_instance.current_boss_index and current_instance.is_fighting_boss:
			boss_marker_nodes[i].modulate = COLOR_BOSS_CURRENT

func _on_boss_reached(boss_index: int, boss_name: String) -> void:
	status_label.text = "Combat contre %s..." % boss_name
	if boss_index < boss_marker_nodes.size():
		boss_marker_nodes[boss_index].modulate = COLOR_BOSS_CURRENT

func _on_boss_defeated(boss_index: int, boss_name: String, loot_winner: SimulatedPlayer) -> void:
	if loot_winner:
		status_label.text = "%s vaincu! Loot: %s" % [boss_name, loot_winner.nom]
	else:
		status_label.text = "%s vaincu!" % boss_name
		
	if boss_index < boss_marker_nodes.size():
		boss_marker_nodes[boss_index].modulate = COLOR_BOSS_DEFEATED

func _on_boss_failed(boss_index: int, boss_name: String, wipe_count: int) -> void:
	status_label.text = "Wipe sur %s (tentative %d)" % [boss_name, wipe_count]
	if boss_index < boss_marker_nodes.size():
		# Flash rouge temporaire
		boss_marker_nodes[boss_index].modulate = COLOR_BOSS_FAILED
		await get_tree().create_timer(1.0).timeout
		if boss_index < boss_marker_nodes.size():
			boss_marker_nodes[boss_index].modulate = COLOR_BOSS_CURRENT

func _on_dungeon_completed(total_time: float, gold_reward: int) -> void:
	var minutes = int(total_time) / 60
	var seconds = int(total_time) % 60
	status_label.text = "Donjon terminé en %02d:%02d! Récompense: %d or" % [minutes, seconds, gold_reward]
	abandon_button.disabled = true
	
	# Colorer tous les boss en vert
	for marker in boss_marker_nodes:
		marker.modulate = COLOR_BOSS_DEFEATED

	_show_loot_window(true, total_time, gold_reward)

func _on_dungeon_abandoned(reason: String) -> void:
	status_label.text = "Donjon abandonné: %s" % reason
	abandon_button.disabled = true

	var elapsed = 0.0
	if current_instance:
		elapsed = current_instance.get_elapsed_time(current_instance.game_time_node)
	_show_loot_window(false, elapsed, 0, reason)

func _on_progress_updated(progress_percent: float) -> void:
	# Peut être utilisé pour une barre de progression globale
	pass

func _on_loot_distributed(member: SimulatedPlayer, item: Item) -> void:
	if not current_instance or not item or not member:
		return

	var bosses = current_instance.dungeon_data.get("bosses", [])
	var boss_index = clamp(current_instance.current_boss_index, 0, bosses.size() - 1) if bosses.size() > 0 else 0
	var boss_name = bosses[boss_index] if boss_index < bosses.size() else ""
	var drop_time = current_instance.get_elapsed_time(current_instance.game_time_node)

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
		dialog.confirmed.connect(func(): 
			abandon_requested.emit()
			current_instance._abandon_dungeon("Abandonné par le joueur")
		)
		get_tree().root.add_child(dialog)
		dialog.show_dialog()

func _show_loot_window(success: bool, total_time: float, gold_reward: int, reason: String = "") -> void:
	if not LootWindowScene:
		return

	var loot_data = loot_history.duplicate(true)
	loot_history.clear()

	var loot_window = LootWindowScene.instantiate()
	if not loot_window:
		return

	get_tree().root.add_child(loot_window)
	var dungeon_name = "Donjon"
	if current_instance and current_instance.dungeon_data.has("name"):
		dungeon_name = str(current_instance.dungeon_data.get("name"))

	if loot_window.has_method("show_loot_summary"):
		loot_window.show_loot_summary(dungeon_name, success, total_time, gold_reward, loot_data, reason)
	else:
		loot_window.popup_centered()
