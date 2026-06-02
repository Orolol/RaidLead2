extends SceneTree

## E2E : ouvre la fenêtre Banque & Équipement, simule un drag&drop banque→slot
## puis slot→banque (en appelant les callbacks de drop), et vérifie le modèle.
## Lancer fenêtré pour aussi capturer un screenshot :
##   Godot ... --rendering-driver opengl3 --path . -s res://tests/e2e_equipment.gd --no-save-autoload

const ItemScript = preload("res://scripts/resources/item.gd")

var _f := 0
var _s := 0
var _ok := 0
var _fail := 0
var _win = null
var _bank_item = null

func _check(c: bool, l: String) -> void:
	if c:
		_ok += 1
		print("  [OK] ", l)
	else:
		_fail += 1
		print("  [FAIL] ", l)

func _process(_d: float) -> bool:
	_f += 1
	match _s:
		0:
			if _f >= 10:
				change_scene_to_file("res://scenes/Main.tscn")
				_s = 1; _f = 0
		1:
			if _f >= 120:
				var gm = root.get_node_or_null("/root/GuildManager")
				var p = gm.get_player_character()
				if p:
					p.choose_activity("LEVELING")
				# Amorcer la banque avec une arme épique (upgrade garanti)
				_bank_item = ItemScript.new("Lame de Test", ItemScript.EquipmentSlot.WEAPON, 90, ItemScript.Rarity.EPIC, 30, 0, 0)
				gm.guild.bank_items.clear()
				gm.guild.add_to_bank(_bank_item)
				# Ouvrir la fenêtre d'équipement pour le joueur
				var scene = load("res://scenes/Fenetre_Equipement.tscn")
				_win = scene.instantiate()
				current_scene.add_child(_win)
				_win.show_member_equipment(p)
				_s = 2; _f = 0
		2:
			if _f >= 40:
				var gm = root.get_node_or_null("/root/GuildManager")
				var p = gm.get_player_character()
				print("\n-- Drag banque -> slot (équiper) --")
				_check(_bank_item in gm.guild.get_bank_items(), "objet présent en banque avant équipement")
				_win._on_equip_dropped(_bank_item)
				_check(p.equipment.get_item_in_slot(ItemScript.EquipmentSlot.WEAPON) == _bank_item, "objet équipé après drop sur le slot")
				_check(not (_bank_item in gm.guild.get_bank_items()), "objet retiré de la banque après équipement")
				_shoot("user://shot_equipment.png")
				print("\n-- Drag slot -> banque (déséquiper) --")
				_win._on_unequip_dropped(ItemScript.EquipmentSlot.WEAPON)
				_check(p.equipment.get_item_in_slot(ItemScript.EquipmentSlot.WEAPON) == null, "slot vidé après déséquipement")
				_check(_bank_item in gm.guild.get_bank_items(), "objet de retour en banque après déséquipement")
				_s = 3; _f = 0
		3:
			if _f >= 5:
				print("\nE2E_EQUIPMENT : %d OK / %d FAIL" % [_ok, _fail])
				quit(1 if _fail > 0 else 0)
				return true
	return false

func _shoot(path: String) -> void:
	var tex = root.get_viewport().get_texture()
	if tex == null:
		return
	var img = tex.get_image()
	if img:
		img.save_png(path)
		print("SAVED ", ProjectSettings.globalize_path(path))
