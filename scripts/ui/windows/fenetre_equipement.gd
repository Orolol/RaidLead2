extends PanelContainer

## Fenêtre « Banque & Équipement » : gère l'équipement de chaque membre et la
## banque de guilde par glisser-déposer (drag & drop natif Godot).
## - Glisser un objet de la banque sur un slot → l'équipe (l'ancien retourne en banque).
## - Glisser un objet équipé sur la banque → le range.

const ItemScript = preload("res://scripts/resources/item.gd")
const EquipDragCellScript = preload("res://scripts/ui/components/equip_drag_cell.gd")

var current_member = null
var _drag_active: bool = false

var member_option: OptionButton
var total_ilvl_label: Label
var total_stats_label: Label
var slots_container: VBoxContainer
var bank_container: VBoxContainer
var _slot_cells: Dictionary = {}  # slot:int -> EquipDragCell

func _ready() -> void:
	custom_minimum_size = Vector2(760, 540)
	z_index = 200
	_setup_ui()
	hide()  # affichée et centrée par show_member_equipment()
	if GuildManager and GuildManager.has_signal("bank_changed"):
		GuildManager.bank_changed.connect(_refresh)

func _setup_ui() -> void:
	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	add_child(root_vbox)

	# --- En-tête (titre draggable + fermer) ---
	var header := HBoxContainer.new()
	root_vbox.add_child(header)
	var title := Label.new()
	title.text = "Banque & Équipement"
	title.add_theme_font_size_override("font_size", 20)
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	title.mouse_default_cursor_shape = Control.CURSOR_MOVE
	title.tooltip_text = "Glissez pour déplacer la fenêtre"
	title.gui_input.connect(_on_header_drag)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(30, 30)
	close_button.pressed.connect(_on_close_pressed)
	header.add_child(close_button)

	# --- Sélecteur de membre + totaux ---
	var sel_row := HBoxContainer.new()
	sel_row.add_theme_constant_override("separation", 10)
	root_vbox.add_child(sel_row)
	sel_row.add_child(_mk_label("Membre :", 14))
	member_option = OptionButton.new()
	member_option.custom_minimum_size = Vector2(180, 0)
	member_option.item_selected.connect(_on_member_selected)
	sel_row.add_child(member_option)
	sel_row.add_spacer(false)
	total_ilvl_label = _mk_label("iLvl Total: 0", 16)
	sel_row.add_child(total_ilvl_label)

	total_stats_label = _mk_label("Stats: FOR 0 / AGI 0 / INT 0", 12)
	total_stats_label.modulate = Color(0.85, 0.85, 0.85)
	root_vbox.add_child(total_stats_label)

	root_vbox.add_child(HSeparator.new())

	# --- Deux colonnes : équipement | banque ---
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(cols)

	# Colonne gauche : slots d'équipement
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.custom_minimum_size = Vector2(330, 0)
	cols.add_child(left)
	left.add_child(_mk_label("Équipement — glisser un objet de la banque sur un slot", 13))
	slots_container = VBoxContainer.new()
	slots_container.add_theme_constant_override("separation", 6)
	left.add_child(slots_container)
	for slot in [0, 1, 2, 3, 4]:
		var cell := EquipDragCellScript.new()
		cell.configure("slot", slot, null, self)
		slots_container.add_child(cell)
		_slot_cells[slot] = cell

	cols.add_child(VSeparator.new())

	# Colonne droite : banque (zone de dépôt) + liste scrollable
	var bank_drop := EquipDragCellScript.new()
	bank_drop.configure("bank_drop", -1, null, self)
	bank_drop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bank_drop.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(bank_drop)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	bank_drop.add_child(right)
	right.add_child(_mk_label("Banque de guilde — glisser un objet équipé ici pour le ranger", 13))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(330, 360)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	bank_container = VBoxContainer.new()
	bank_container.add_theme_constant_override("separation", 4)
	bank_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(bank_container)

func _mk_label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	return l

# ==================== API PUBLIQUE ====================

func show_member_equipment(member) -> void:
	if not member:
		return
	current_member = member
	_populate_member_options()
	_refresh()
	_center()
	show()

func _populate_member_options() -> void:
	member_option.clear()
	var members: Array = GuildManager.guild_members if GuildManager else []
	for i in range(members.size()):
		member_option.add_item(members[i].nom, i)
	var idx: int = members.find(current_member)
	if idx >= 0:
		member_option.select(idx)

func _on_member_selected(index: int) -> void:
	var members: Array = GuildManager.guild_members if GuildManager else []
	if index >= 0 and index < members.size():
		current_member = members[index]
		_refresh()

# ==================== RAFRAÎCHISSEMENT ====================

func _refresh() -> void:
	if not current_member:
		return
	var equipment = current_member.equipment
	for slot in _slot_cells:
		var it = equipment.get_item_in_slot(slot) if equipment else null
		_slot_cells[slot].configure("slot", slot, it, self)

	var total_ilvl: int = current_member.get_total_ilvl()
	total_ilvl_label.text = "iLvl Total: %d" % total_ilvl
	var avg: int = total_ilvl / 5
	if avg >= 50:
		total_ilvl_label.modulate = Color.PURPLE
	elif avg >= 35:
		total_ilvl_label.modulate = Color.BLUE
	elif avg >= 15:
		total_ilvl_label.modulate = Color.GREEN
	else:
		total_ilvl_label.modulate = Color.WHITE

	var stats: Dictionary = current_member.get_equipment_stats()
	total_stats_label.text = "Stats: FOR %d / AGI %d / INT %d" % [
		stats.get("strength", 0), stats.get("agility", 0), stats.get("intelligence", 0)
	]

	_refresh_bank()

func _refresh_bank() -> void:
	for child in bank_container.get_children():
		child.queue_free()
	var bank: Array = []
	if GuildManager and GuildManager.guild:
		bank = GuildManager.guild.get_bank_items()
	if bank.is_empty():
		var empty := _mk_label("(banque vide — le loot non équipé arrive ici)", 12)
		empty.modulate = Color(0.55, 0.57, 0.62)
		bank_container.add_child(empty)
		return
	for it in bank:
		var cell := EquipDragCellScript.new()
		cell.configure("bank_item", -1, it, self)
		bank_container.add_child(cell)

# ==================== CALLBACKS DU DRAG & DROP ====================

func _on_equip_dropped(item) -> void:
	if item and current_member and GuildManager:
		GuildManager.equip_from_bank(current_member, item)
		_refresh()

func _on_unequip_dropped(slot: int) -> void:
	if slot >= 0 and current_member and GuildManager:
		GuildManager.unequip_to_bank(current_member, slot)
		_refresh()

# ==================== DÉPLACEMENT / FERMETURE ====================

func _on_header_drag(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag_active = event.pressed
	elif event is InputEventMouseMotion and _drag_active:
		position += event.relative

func _on_close_pressed() -> void:
	queue_free()

func _center() -> void:
	var vp: Vector2 = get_viewport_rect().size
	position = (vp - custom_minimum_size) * 0.5
	position.y = maxf(20.0, position.y)
