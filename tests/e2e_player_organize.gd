extends SceneTree

## E2E : le choix « Donjon / Raid » du prompt d'oisiveté ouvre la fenêtre
## d'organisation présélectionnée et relance le temps.
## Lancer : Godot ... --headless -s res://tests/e2e_player_organize.gd --no-save-autoload

var _frames: int = 0
var _state: int = 0
var _ok: int = 0
var _fail: int = 0

func _check(cond: bool, label: String) -> void:
	if cond:
		_ok += 1
		print("  [OK] ", label)
	else:
		_fail += 1
		print("  [FAIL] ", label)

func _process(_delta: float) -> bool:
	_frames += 1
	match _state:
		0:
			if _frames >= 10:
				change_scene_to_file("res://scenes/Main.tscn")
				_state = 1
				_frames = 0
		1:
			if _frames >= 120:
				var gt = root.get_node_or_null("/root/GameTime")
				_check(gt != null and gt.is_paused, "temps en pause à l'oisiveté")
				# Simule le clic « Donjon / Raid » du prompt (raid)
				if current_scene and current_scene.has_method("_on_prompt_organize_chosen"):
					current_scene._on_prompt_organize_chosen("raid")
				_state = 2
				_frames = 0
		2:
			# Laisser le call_deferred("preselect_activity") s'exécuter
			if _frames >= 30:
				var gt = root.get_node_or_null("/root/GameTime")
				var wm = current_scene.window_manager if current_scene else null
				_check(gt != null and not gt.is_paused, "le temps repart après le choix Donjon/Raid")
				_check(wm != null and wm.is_window_open("organisation"), "fenêtre d'organisation ouverte")
				var inst = wm.get_window_instance("organisation") if wm else null
				_check(inst != null and inst.selected_activity == "raid", "organisation présélectionnée sur 'raid'")
				_state = 3
				_frames = 0
		3:
			if _frames >= 5:
				print("\nE2E_PLAYER_ORGANIZE : %d OK / %d FAIL" % [_ok, _fail])
				quit(1 if _fail > 0 else 0)
				return true
	return false
