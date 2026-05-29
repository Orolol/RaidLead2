extends SceneTree

## e2e : vérifie que les compteurs de progression Phase 2->3 (National) du
## PhaseManager lisent de vraies valeurs (sponsors, dramas, world firsts,
## réputation média, rang) au lieu des anciens placeholders.

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
				_run_test()
				_state = 2; _frames = 0
		2:
			if _frames >= 5:
				print("E2E_DONE")
				return true
	return false

func _run_test() -> void:
	var pm = root.get_node_or_null("/root/PhaseManager")
	var sm = root.get_node_or_null("/root/SponsorshipManager")
	var dm = root.get_node_or_null("/root/DramaManager")
	var gm = root.get_node_or_null("/root/GuildManager")
	var rank = root.get_node_or_null("/root/GuildRanking")
	if not pm:
		print("NO PhaseManager"); return

	pm.force_phase_change(2)  # NATIONAL

	# Amorcer un état National réaliste
	if sm and sm.available_sponsors.size() > 0:
		sm.active_sponsors.append(sm.available_sponsors[0])
	if dm:
		dm._create_drama(0, 2, "TestMember", "drama majeur de test")  # SCANDAL, MEDIUM
	if rank and gm and gm.guild:
		rank.register_server_first(gm.guild.name, "Onyxia")
		rank.register_server_first(gm.guild.name, "MoltenCore")
	if gm:
		for m in gm.guild_members:
			m.celebrity_level = 70.0
	pm.days_at_rank_1 = 12

	print("=== Compteurs progression NATIONAL ===")
	print("active_sponsors      = ", pm._get_requirement_current_value("active_sponsors"), " (placeholder=0)")
	print("world_first_count    = ", pm._get_requirement_current_value("world_first_count"), " (placeholder=0)")
	print("max_dramas_per_year  = ", pm._get_requirement_current_value("max_dramas_per_year"), " (placeholder=0)")
	print("media_reputation     = ", pm._get_requirement_current_value("media_reputation"), " (placeholder=50)")
	print("national_rank_pos    = ", pm._get_requirement_current_value("national_rank_position"))
	print("national_rank_durat. = ", pm._get_requirement_current_value("national_rank_duration"), " (seeded 12)")
