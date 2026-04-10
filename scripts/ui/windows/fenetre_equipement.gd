extends AcceptDialog

const ItemScript = preload("res://scripts/resources/item.gd")

var current_member = null
var equipment_labels: Dictionary = {}
var total_ilvl_label: Label
var total_stats_label: Label

func _ready():
	# AcceptDialog se centre automatiquement
	_setup_ui()

func _setup_ui():
	# Container principal
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	add_child(vbox)
	
	# Titre avec iLvl total
	total_ilvl_label = Label.new()
	total_ilvl_label.text = "iLvl Total: 0"
	total_ilvl_label.add_theme_font_size_override("font_size", 20)
	total_ilvl_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(total_ilvl_label)

	total_stats_label = Label.new()
	total_stats_label.text = "Stats: FOR 0 / AGI 0 / INT 0"
	total_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_stats_label.add_theme_font_size_override("font_size", 14)
	total_stats_label.modulate = Color(0.85, 0.85, 0.85)
	vbox.add_child(total_stats_label)
	
	vbox.add_child(HSeparator.new())
	
	# ScrollContainer pour gérer le contenu si besoin
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 280)
	vbox.add_child(scroll)
	
	var equipment_container = VBoxContainer.new()
	equipment_container.add_theme_constant_override("separation", 10)
	scroll.add_child(equipment_container)
	
	# Créer les slots d'équipement
	_create_equipment_slots(equipment_container)

func _create_equipment_slots(parent: VBoxContainer):
	var slot_names: Dictionary = {
		ItemScript.EquipmentSlot.HELMET: "Casque",
		ItemScript.EquipmentSlot.SHOULDERS: "Épaulières",
		ItemScript.EquipmentSlot.CHEST: "Armure",
		ItemScript.EquipmentSlot.WEAPON: "Arme",
		ItemScript.EquipmentSlot.RING: "Anneau"
	}

	for slot in slot_names:
		var slot_container: HBoxContainer = HBoxContainer.new()
		slot_container.add_theme_constant_override("separation", 10)
		parent.add_child(slot_container)

		var slot_icon: Texture2D = AssetLoader.get_slot_icon(slot)
		if slot_icon:
			var icon_rect: TextureRect = TextureRect.new()
			icon_rect.texture = slot_icon
			icon_rect.custom_minimum_size = Vector2(36, 36)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			slot_container.add_child(icon_rect)

		var slot_label: Label = Label.new()
		slot_label.text = slot_names[slot] + ":"
		slot_label.custom_minimum_size = Vector2(80, 0)
		slot_label.add_theme_font_size_override("font_size", 14)
		slot_container.add_child(slot_label)

		# Panneau pour l'item équipé
		var item_panel: PanelContainer = PanelContainer.new()
		item_panel.custom_minimum_size = Vector2(360, 52)
		slot_container.add_child(item_panel)

		var item_content: VBoxContainer = VBoxContainer.new()
		item_content.add_theme_constant_override("separation", 2)
		item_panel.add_child(item_content)

		var item_label: Label = Label.new()
		item_label.text = "Aucun objet équipé"
		item_label.modulate = Color(0.6, 0.6, 0.6)
		item_label.add_theme_font_size_override("font_size", 12)
		item_content.add_child(item_label)

		var stats_label: Label = Label.new()
		stats_label.text = "Statistiques : —"
		stats_label.modulate = Color(0.65, 0.65, 0.65)
		stats_label.add_theme_font_size_override("font_size", 11)
		item_content.add_child(stats_label)

		var delta_label: Label = Label.new()
		delta_label.text = ""
		delta_label.add_theme_font_size_override("font_size", 10)
		item_content.add_child(delta_label)

		# Stocker la référence pour mise à jour
		equipment_labels[slot] = {
			"label": item_label,
			"stats_label": stats_label,
			"delta_label": delta_label,
			"panel": item_panel,
		}

func show_member_equipment(member):
	if not member:
		return
		
	current_member = member
	
	# Mettre à jour le titre
	title = "Équipement de " + member.nom
	
	# Mettre à jour l'iLvl total
	var total_ilvl = member.get_total_ilvl()
	total_ilvl_label.text = "iLvl Total: %d" % total_ilvl
	
	# Mettre à jour les couleurs selon le niveau d'équipement
	if total_ilvl >= 200:
		total_ilvl_label.modulate = Color.PURPLE  # Épique
	elif total_ilvl >= 150:
		total_ilvl_label.modulate = Color.BLUE    # Rare
	elif total_ilvl >= 100:
		total_ilvl_label.modulate = Color.GREEN   # Peu commun
	else:
		total_ilvl_label.modulate = Color.WHITE   # Commun

	# Mettre à jour le résumé des statistiques
	var total_stats = member.get_equipment_stats()
	var stats_text = "Stats: FOR %d / AGI %d / INT %d" % [
		total_stats.get("strength", 0),
		total_stats.get("agility", 0),
		total_stats.get("intelligence", 0)
	]
	total_stats_label.text = stats_text

	# Mettre à jour chaque slot
	_update_equipment_display()
	
	# Afficher la fenêtre
	popup_centered()

func _update_equipment_display():
	if not current_member or not current_member.equipment:
		return

	var equipment = current_member.equipment

	for slot in equipment_labels:
		var slot_data: Dictionary = equipment_labels[slot]
		var item: Item = equipment.get_item_in_slot(slot)

		if item:
			# Objet équipé
			slot_data.label.text = "%s (iLvl %d)" % [item.name, item.ilvl]
			slot_data.label.modulate = item.get_rarity_color()
			var stat_summary: String = item.get_stat_summary()
			if stat_summary == "":
				slot_data.stats_label.text = "Statistiques : —"
				slot_data.stats_label.modulate = Color(0.8, 0.8, 0.8)
			else:
				slot_data.stats_label.text = stat_summary
				slot_data.stats_label.modulate = Color(0.95, 0.95, 0.95)

			# Afficher les deltas de stats (comparaison avec 0 = slot vide)
			var delta_parts: Array[String] = []
			if item.strength != 0:
				var color_tag: String = "green" if item.strength > 0 else "red"
				delta_parts.append("[color=%s]%+d FOR[/color]" % [color_tag, item.strength])
			if item.agility != 0:
				var color_tag: String = "green" if item.agility > 0 else "red"
				delta_parts.append("[color=%s]%+d AGI[/color]" % [color_tag, item.agility])
			if item.intelligence != 0:
				var color_tag: String = "green" if item.intelligence > 0 else "red"
				delta_parts.append("[color=%s]%+d INT[/color]" % [color_tag, item.intelligence])

			if delta_parts.size() > 0:
				slot_data.delta_label.text = "  ".join(delta_parts)
			else:
				slot_data.delta_label.text = ""

			# Style fond selon la rarete
			var style: StyleBoxFlat = StyleBoxFlat.new()
			var bg_color: Color = item.get_rarity_color()
			bg_color.a = 0.15
			style.bg_color = bg_color
			style.border_color = item.get_rarity_color()
			style.border_color.a = 0.6
			style.set_border_width_all(1)
			style.set_corner_radius_all(3)
			style.content_margin_left = 8
			style.content_margin_right = 8
			style.content_margin_top = 4
			style.content_margin_bottom = 4
			slot_data.panel.add_theme_stylebox_override("panel", style)
		else:
			# Slot vide
			slot_data.label.text = "Aucun objet équipé"
			slot_data.label.modulate = Color(0.6, 0.6, 0.6)
			slot_data.stats_label.text = "Statistiques : —"
			slot_data.stats_label.modulate = Color(0.65, 0.65, 0.65)
			slot_data.delta_label.text = ""

			# Réinitialiser le style
			slot_data.panel.remove_theme_stylebox_override("panel")
