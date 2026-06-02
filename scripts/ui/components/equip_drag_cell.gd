extends PanelContainer
class_name EquipDragCell

## Cellule polyvalente pour le drag & drop d'équipement (D&D natif Godot).
## Trois modes :
##   "slot"      : un slot d'équipement d'un membre (source de drag + cible de drop d'un objet de banque)
##   "bank_item" : un objet de la banque (source de drag + cible de rangement)
##   "bank_drop" : la zone de banque (cible de rangement uniquement, pas de visuel propre)
##
## Le transfert réel passe par la fenêtre propriétaire (owner_window), qui appelle
## GuildManager.equip_from_bank / unequip_to_bank.

var mode: String = "slot"
var slot: int = -1
var item = null
var owner_window = null
var _label: Label = null

const SLOT_NAMES := {0: "Casque", 1: "Épaulières", 2: "Armure", 3: "Arme", 4: "Anneau"}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func configure(p_mode: String, p_slot: int, p_item, p_owner) -> void:
	mode = p_mode
	slot = p_slot
	item = p_item
	owner_window = p_owner
	if mode != "bank_drop":
		if _label == null:
			_label = Label.new()
			_label.add_theme_font_size_override("font_size", 12)
			_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			add_child(_label)
		_refresh_visual()

func _refresh_visual() -> void:
	if _label == null:
		return
	custom_minimum_size = Vector2(0, 46)
	if item != null:
		var stat: String = item.get_stat_summary()
		_label.text = "%s  (iLvl %d)%s" % [item.name, item.ilvl, ("\n" + stat if stat != "" else "")]
		_label.modulate = item.get_rarity_color()
		var style := StyleBoxFlat.new()
		var bg: Color = item.get_rarity_color()
		bg.a = 0.16
		style.bg_color = bg
		var border: Color = item.get_rarity_color()
		border.a = 0.6
		style.border_color = border
		style.set_border_width_all(1)
		style.set_corner_radius_all(3)
		style.set_content_margin_all(6)
		add_theme_stylebox_override("panel", style)
	else:
		_label.text = "%s : vide" % SLOT_NAMES.get(slot, "?")
		_label.modulate = Color(0.55, 0.57, 0.62)
		remove_theme_stylebox_override("panel")

# ==================== DRAG & DROP NATIF ====================

func _get_drag_data(_pos):
	if item == null or mode == "bank_drop":
		return null
	var preview := PanelContainer.new()
	var pl := Label.new()
	pl.text = "  %s  " % item.name
	pl.add_theme_color_override("font_color", item.get_rarity_color())
	preview.add_child(pl)
	preview.modulate.a = 0.9
	set_drag_preview(preview)
	var data: Dictionary = {"source": ("slot" if mode == "slot" else "bank"), "item": item}
	if mode == "slot":
		data["slot"] = slot
	return data

func _can_drop_data(_pos, data) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if mode == "slot":
		# Un slot n'accepte qu'un objet de banque du bon type
		var it = data.get("item", null)
		return data.get("source", "") == "bank" and it != null and it.slot == slot
	# bank_item / bank_drop : range un objet venant d'un slot
	return data.get("source", "") == "slot"

func _drop_data(_pos, data) -> void:
	if owner_window == null:
		return
	if mode == "slot":
		owner_window._on_equip_dropped(data.get("item", null))
	else:
		owner_window._on_unequip_dropped(int(data.get("slot", -1)))
