extends SceneTree

## Script e2e : charge Main.tscn, ouvre la fenêtre National, amorce des données
## (célébrité, streamer, sponsor, drama) et capture chaque onglet. Lancé via xvfb-run.

var _main: Node
var _win: Node
var _frames: int = 0
var _state: int = 0

func _process(_delta: float) -> bool:
	_frames += 1
	match _state:
		0:
			if _frames >= 20:
				change_scene_to_file("res://scenes/Main.tscn")
				_state = 1
				_frames = 0
		1:
			if _frames >= 180:
				_main = current_scene
				_shoot("user://shot_main.png")
				# Régression : ouvrir Guilde + sélectionner un membre construit les
				# StatDisplay (skill = VALUE_PERCENTAGE) — déclenchait le bug Container.
				_main.window_manager.show_window("guilde")
				var g = _main.window_manager._get_existing_instance("guilde")
				if g and g.has_method("_on_member_selected"):
					g._on_member_selected(0)
					print("Guilde: membre 0 sélectionné")
				_shoot("user://shot_guilde.png")
				_open_national()
				_seed()
				_state = 2
				_frames = 0
		2:
			if _frames >= 60:
				_win = _main.window_manager._get_existing_instance("national")
				if _win and _win.has_method("_refresh_all"):
					_win._refresh_all()
				_shoot("user://shot_national_celebrity.png")
				_select_tab(2)  # Sponsors
				_state = 3
				_frames = 0
		3:
			if _frames >= 50:
				_shoot("user://shot_national_sponsors.png")
				_select_tab(3)  # Dramas
				_state = 4
				_frames = 0
		4:
			if _frames >= 50:
				_shoot("user://shot_national_dramas.png")
				_state = 5
				_frames = 0
		5:
			if _frames >= 5:
				print("E2E_DONE")
				return true
	return false

func _open_national() -> void:
	if _main and _main.has_method("_on_national_button_pressed"):
		_main._on_national_button_pressed()
		print("Opened national window")

func _select_tab(idx: int) -> void:
	if _win and _win.advanced_tabs:
		_win.advanced_tabs.select_tab(idx)

func _seed() -> void:
	var gm = root.get_node_or_null("/root/GuildManager")
	var sm = root.get_node_or_null("/root/SponsorshipManager")
	var dm = root.get_node_or_null("/root/DramaManager")
	if not gm:
		print("SEED: no GuildManager")
		return
	var members: Array = gm.guild_members
	print("SEED members=", members.size())
	for i in range(members.size()):
		members[i].celebrity_level = clampf(88.0 - i * 9.0, 4.0, 96.0)
	if members.size() > 0:
		members[0].set_meta("is_streamer", true)
		members[0].set_meta("audience_size", 4200)
		members[0].set_meta("stream_revenue", 42.0)
	if sm and sm.available_sponsors.size() > 0:
		sm.active_sponsors.append(sm.available_sponsors[0])
	if dm and dm.has_method("create_loot_rage_drama"):
		dm.create_loot_rage_drama("Thrall", "Marteau du Destin")

func _shoot(path: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	if img:
		img.save_png(path)
		print("SAVED ", ProjectSettings.globalize_path(path), " size=", img.get_size())
	else:
		print("SHOT FAILED for ", path)
