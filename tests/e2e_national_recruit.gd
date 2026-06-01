extends SceneTree

## e2e US 3.5 : force la phase Nationale, régénère le pool (recrues semi-pro),
## ouvre Monde > Recrutement, sélectionne une recrue nationale, capture l'UI de
## négociation, puis teste recrutement + versement de salaire.

var _main: Node
var _monde: Node
var _frames: int = 0
var _state: int = 0

func _process(_delta: float) -> bool:
	_frames += 1
	match _state:
		0:
			if _frames >= 20:
				change_scene_to_file("res://scenes/Main.tscn")
				_state = 1; _frames = 0
		1:
			if _frames >= 160:
				_main = current_scene
				var pm = root.get_node_or_null("/root/PhaseManager")
				if pm: pm.force_phase_change(2)
				var rp = root.get_node_or_null("/root/RecruitmentPool")
				if rp:
					rp._generate_initial_pool()
					var nat := 0
					for p in rp.available_players:
						if p.get_meta("is_national", false): nat += 1
					print("NATIONAL in pool: %d / %d" % [nat, rp.available_players.size()])
				_main.window_manager.show_window("monde")
				_state = 2; _frames = 0
		2:
			if _frames >= 60:
				_monde = _main.window_manager.get_window_instance("monde")
				if _monde and _monde.advanced_tabs:
					_monde.advanced_tabs.select_tab(1)
				_state = 3; _frames = 0
		3:
			if _frames >= 60:
				_select_national_recruit()
				_state = 4; _frames = 0
		4:
			if _frames >= 60:
				_shoot("user://shot_recruit_national.png")
				_test_recruit_and_salary()
				_state = 5; _frames = 0
		5:
			if _frames >= 10:
				print("E2E_DONE")
				return true
	return false

func _select_national_recruit() -> void:
	var rp = root.get_node_or_null("/root/RecruitmentPool")
	if not rp or not _monde:
		print("no rp/monde"); return
	for p in rp.available_players:
		if p.get_meta("is_national", false):
			_monde.selected_recruit = p
			_monde._update_recruit_details()
			print("Selected national recruit: %s (skill demande %d or/sem)" % [p.nom, p.salary_demand])
			return
	print("No national recruit in pool")

func _test_recruit_and_salary() -> void:
	var rp = root.get_node_or_null("/root/RecruitmentPool")
	var gm = root.get_node_or_null("/root/GuildManager")
	if not rp or not gm or not _monde or not _monde.selected_recruit:
		print("SALARY TEST skipped"); return
	# 1) Exercer le flux de négociation via l'UI (offre = demande -> acceptation)
	if _monde.salary_spinbox:
		_monde.salary_spinbox.value = _monde.selected_recruit.salary_demand
	_monde._on_negotiate_pressed()
	print("Membres: %d / max %d" % [gm.guild_members.size(), gm.guild.get_max_members() if gm.guild else 0])

	# 2) Test direct du versement de salaire (indépendant de la capacité)
	if gm.guild_members.size() > 0 and gm.guild:
		gm.guild_members[0].set_meta("salary", 50)
		gm.guild.gold = 5000
		var before = gm.guild.gold
		gm._pay_salaries()
		print("SALAIRE: masse=%d or/sem ; or %d -> %d (attendu -50)" % [gm.get_total_weekly_salaries(), before, gm.guild.gold])
		gm.guild_members[0].remove_meta("salary")

func _shoot(path: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	if img:
		img.save_png(path)
		print("SAVED ", ProjectSettings.globalize_path(path))
