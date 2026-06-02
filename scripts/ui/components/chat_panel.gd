extends PanelContainer
class_name ChatPanel

@onready var chat_display: RichTextLabel = $VBoxContainer/ScrollContainer/ChatDisplay
@onready var scroll_container: ScrollContainer = $VBoxContainer/ScrollContainer

const MAX_MESSAGES = 100
# Couleurs dérivées de la palette canonique (UIConstants ← UITheme) plutôt que
# d'une 3e source. Seul l'orange « donjon » reste un hue spécifique au chat.
const MESSAGE_COLORS = {
	"info": UIConstants.COLOR_TEXT_DIM,
	"connect": UIConstants.COLOR_SUCCESS,
	"disconnect": UIConstants.COLOR_ERROR,
	"levelup": UIConstants.COLOR_TEXT_HIGHLIGHT,
	"activity": UIConstants.COLOR_INFO,
	"dungeon": Color(1.0, 0.6, 0.2),
	"loot": UIConstants.COLOR_RARITY_EPIC,
	"warning": UIConstants.COLOR_WARNING,
	"error": UIConstants.COLOR_ERROR,
}

var messages: Array = []
var auto_scroll: bool = true

func _ready() -> void:
	custom_minimum_size = Vector2(400, 200)
	
	# Créer la structure si elle n'existe pas dans la scène
	if not has_node("VBoxContainer"):
		_create_ui_structure()
	
	# S'assurer que le RichTextLabel est configuré correctement
	if chat_display:
		chat_display.bbcode_enabled = true
		chat_display.scroll_following = true
		chat_display.selection_enabled = true
		
	# Ajouter un message de bienvenue
	add_message("Bienvenue dans RaidLead!", "info")
	add_message("Le chat de guilde est maintenant actif.", "info")
	
	# Connecter aux signaux des autoloads
	_connect_to_guild_events()
	_connect_to_activity_events()
	_connect_to_chat_director()

func _create_ui_structure() -> void:
	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	add_child(vbox)

	# Titre
	var title := Label.new()
	title.text = "Chat de Guilde"
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	# Séparateur
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# ScrollContainer
	var scroll := ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.custom_minimum_size = Vector2(0, 150)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	# RichTextLabel pour l'affichage
	var display := RichTextLabel.new()
	display.name = "ChatDisplay"
	display.bbcode_enabled = true
	display.scroll_following = true
	display.selection_enabled = true
	display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(display)
	
	# Mettre à jour les références
	chat_display = display
	scroll_container = scroll

func _connect_to_guild_events() -> void:
	var guild_manager = GuildManager
	if guild_manager:
		# Connexions/Déconnexions
		if not guild_manager.member_connected.is_connected(_on_member_connected):
			guild_manager.member_connected.connect(_on_member_connected)
		if not guild_manager.member_disconnected.is_connected(_on_member_disconnected):
			guild_manager.member_disconnected.connect(_on_member_disconnected)
		
		# Level up
		if not guild_manager.member_leveled_up.is_connected(_on_member_leveled_up):
			guild_manager.member_leveled_up.connect(_on_member_leveled_up)
		
		# Nouveau membre
		if not guild_manager.member_recruited.is_connected(_on_member_recruited):
			guild_manager.member_recruited.connect(_on_member_recruited)

func _connect_to_activity_events() -> void:
	var activity_manager = ActivityManager
	if activity_manager:
		# Activités
		if not activity_manager.activity_started.is_connected(_on_activity_started):
			activity_manager.activity_started.connect(_on_activity_started)
		if not activity_manager.activity_completed.is_connected(_on_activity_completed):
			activity_manager.activity_completed.connect(_on_activity_completed)
		
		# Donjons
		if not activity_manager.dungeon_started.is_connected(_on_dungeon_started):
			activity_manager.dungeon_started.connect(_on_dungeon_started)
		if not activity_manager.dungeon_ended.is_connected(_on_dungeon_ended):
			activity_manager.dungeon_ended.connect(_on_dungeon_ended)

func _connect_to_chat_director() -> void:
	# Le ChatDirector (autoload) émet les répliques "en personnage" du chat vivant.
	# Le ChatPanel est une vue passive : il se contente de les afficher.
	if ChatDirector and not ChatDirector.line_emitted.is_connected(_on_chat_line):
		ChatDirector.line_emitted.connect(_on_chat_line)

func _on_chat_line(speaker_name: String, text: String, _channel: String) -> void:
	add_chat_line(speaker_name, text)

func add_chat_line(speaker_name: String, text: String) -> void:
	# Ligne de chat en personnage : "[HH:MM] Nom: texte" (nom mis en évidence).
	var message := ""
	if GameTime:
		message = "[color=#666666][%s][/color] " % GameTime.get_current_time_string()
	var name_color: Color = MESSAGE_COLORS.get("levelup", UIConstants.COLOR_TEXT_HIGHLIGHT)
	var name_hex := "#%02x%02x%02x" % [int(name_color.r * 255), int(name_color.g * 255), int(name_color.b * 255)]
	message += "[color=%s]%s[/color]: %s" % [name_hex, speaker_name, text]

	messages.append(message)
	if messages.size() > MAX_MESSAGES:
		messages.pop_front()
	_update_display()

func add_message(text: String, type: String = "info", timestamp: bool = true) -> void:
	# Créer le message avec timestamp si demandé
	var message = ""
	if timestamp:
		var game_time = GameTime
		if game_time:
			message = "[color=#666666][%s][/color] " % game_time.get_current_time_string()
		else:
			var time = Time.get_time_dict_from_system()
			message = "[color=#666666][%02d:%02d][/color] " % [time.hour, time.minute]
	
	# Ajouter la couleur selon le type
	var color = MESSAGE_COLORS.get(type, MESSAGE_COLORS["info"])
	var color_hex = "#%02x%02x%02x" % [int(color.r * 255), int(color.g * 255), int(color.b * 255)]
	message += "[color=%s]%s[/color]" % [color_hex, text]
	
	# Ajouter le message à la liste
	messages.append(message)
	
	# Limiter le nombre de messages
	if messages.size() > MAX_MESSAGES:
		messages.pop_front()
	
	# Mettre à jour l'affichage
	_update_display()

func _update_display() -> void:
	if not chat_display:
		return
		
	chat_display.clear()
	for msg in messages:
		chat_display.append_text(msg + "\n")
	
	# Auto-scroll vers le bas si activé
	if auto_scroll:
		await get_tree().process_frame
		scroll_container.scroll_vertical = int(scroll_container.get_v_scroll_bar().max_value)

func clear_chat() -> void:
	messages.clear()
	if chat_display:
		chat_display.clear()

# Handlers pour les événements de guilde
func _on_member_connected(member: SimulatedPlayer) -> void:
	var msg := "%s s'est connecté(e)" % member.nom
	add_message(msg, "connect")

func _on_member_disconnected(member: SimulatedPlayer) -> void:
	var msg := "%s s'est déconnecté(e)" % member.nom
	add_message(msg, "disconnect")

func _on_member_leveled_up(member: SimulatedPlayer, new_level: int) -> void:
	var msg := "%s a atteint le niveau %d !" % [member.nom, new_level]
	add_message(msg, "levelup")

func _on_member_recruited(member: SimulatedPlayer) -> void:
	var msg := "%s a rejoint la guilde ! Bienvenue !" % member.nom
	add_message(msg, "connect")

# Handlers pour les événements d'activité
func _on_activity_started(player: SimulatedPlayer, activity) -> void:
	if activity.type == activity.ActivityType.LEVELING:
		var zone = activity.location if activity.location != "" else "une zone de leveling"
		var msg = "%s part leveler dans %s" % [player.nom, zone]
		add_message(msg, "activity")
	elif activity.type == activity.ActivityType.FARMING:
		var location = activity.location if activity.location != "" else "des ressources"
		var msg = "%s commence à farmer %s" % [player.nom, location]
		add_message(msg, "activity")

func _on_activity_completed(_player: SimulatedPlayer, _activity) -> void:
	# Message de fin d'activité si pertinent
	pass

func _on_dungeon_started(dungeon_instance) -> void:
	var dungeon_name = dungeon_instance.dungeon_data.get("name", "Donjon")
	var members_names := []
	for member in dungeon_instance.group_members:
		members_names.append(member.nom)
	var msg := "Groupe formé pour %s : %s" % [dungeon_name, ", ".join(members_names)]
	add_message(msg, "dungeon")
	
	# Connecter aux signaux de l'instance de donjon
	if not dungeon_instance.boss_defeated.is_connected(_on_boss_defeated):
		dungeon_instance.boss_defeated.connect(_on_boss_defeated)
	if not dungeon_instance.boss_failed.is_connected(_on_boss_failed):
		dungeon_instance.boss_failed.connect(_on_boss_failed)
	var completion_callback := _on_dungeon_completed.bind(dungeon_instance)
	if not dungeon_instance.dungeon_completed.is_connected(completion_callback):
		dungeon_instance.dungeon_completed.connect(completion_callback)
	if not dungeon_instance.loot_distributed.is_connected(_on_loot_distributed):
		dungeon_instance.loot_distributed.connect(_on_loot_distributed)

func _on_dungeon_ended(_dungeon_instance) -> void:
	# Les signaux sont déjà connectés dans _on_dungeon_started
	pass

func _on_boss_defeated(_boss_index: int, boss_name: String, loot_winner) -> void:
	var msg := "Boss vaincu : %s" % boss_name
	if loot_winner:
		msg += " (Loot : %s)" % loot_winner.nom
	add_message(msg, "dungeon")

func _on_boss_failed(_boss_index: int, boss_name: String, wipe_count: int) -> void:
	var msg := "Wipe sur %s (tentative #%d)" % [boss_name, wipe_count]
	add_message(msg, "error")

func _on_dungeon_completed(total_time: float, gold_reward: int, dungeon_instance = null) -> void:
	# Troncature volontaire : on veut le nombre entier de minutes écoulées.
	@warning_ignore("integer_division")
	var minutes = int(total_time) / 60
	var seconds = int(total_time) % 60
	var dungeon_name = "Donjon"
	var boss_count = 0
	var wipe_count = 0
	if dungeon_instance:
		dungeon_name = dungeon_instance.dungeon_data.get("name", dungeon_name)
		boss_count = dungeon_instance.dungeon_data.get("bosses", []).size()
		wipe_count = dungeon_instance.total_wipes
	
	var msg := "Rapport %s : terminé en %02d:%02d, %d boss, %d wipe(s), %d or" % [
		dungeon_name,
		minutes,
		seconds,
		boss_count,
		wipe_count,
		gold_reward
	]
	add_message(msg, "dungeon")

	# Notification toast pour succès de donjon
	if NotificationManager != null:
		var notification_manager = NotificationManager
		notification_manager.show_success("Donjon complété avec succès !", "Victoire")

func _on_loot_distributed(member, item) -> void:
	add_loot_notification(member.nom, item)

	# Notification toast pour loot rare/épique
	if item.rarity >= item.Rarity.RARE and NotificationManager != null:
		var notification_manager = NotificationManager
		var message := "%s a obtenu %s" % [member.nom, item.name]
		notification_manager.show_success(message, "Loot Rare")

# Méthode publique pour ajouter des messages custom
func add_system_message(text: String) -> void:
	add_message("[Système] " + text, "info")

func add_guild_message(text: String) -> void:
	add_message("[Guilde] " + text, "info")

func add_dungeon_message(text: String) -> void:
	add_message("[Donjon] " + text, "dungeon")

func add_loot_message(player_name: String, item: String) -> void:
	var msg := "%s a obtenu : %s" % [player_name, item]
	add_message(msg, "loot")

func add_loot_notification(player_name: String, item) -> void:
	# Nouvelle méthode pour les objets Item complets
	var msg
	if item.has_method("get_display_name"):
		# Objet Item complet
		msg = "[Loot] %s a obtenu %s (iLvl %d)" % [player_name, item.name, item.ilvl]
		var stat_summary = item.get_stat_summary()
		if stat_summary != "":
			msg += " [%s]" % stat_summary
		var color = item.get_rarity_color()
		var color_hex = "#%02x%02x%02x" % [int(color.r * 255), int(color.g * 255), int(color.b * 255)]
		msg = "[color=%s]%s[/color]" % [color_hex, msg]
		add_message(msg, "loot", true)
	else:
		# Fallback pour les anciens objets string
		add_loot_message(player_name, str(item))

func add_phase_notification(phase_name: String) -> void:
	var msg := "[PHASE] Félicitations ! Passage en %s" % phase_name
	add_message(msg, "levelup")
