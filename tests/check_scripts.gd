extends Node

## Validateur de syntaxe terminant — alternative fiable à `--check-only` (qui peut
## rester suspendu sous Windows). Tourne comme scène principale pour que les autoloads
## soient enregistrés (sinon les scripts référençant GameTime/GuildManager/... échouent
## à tort). Charge tous les scripts .gd via load() : un script avec erreur de
## compilation renvoie null. Sort 0 si tout compile, 1 sinon.
##
## Lancer : godot --headless res://tests/CheckScripts.tscn

func _ready() -> void:
	var failures: Array[String] = []
	var checked: int = 0
	var dir_queue: Array[String] = ["res://scripts", "res://tests"]

	while not dir_queue.is_empty():
		var path: String = dir_queue.pop_back()
		var dir: DirAccess = DirAccess.open(path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var fname: String = dir.get_next()
		while fname != "":
			var full: String = path + "/" + fname
			if dir.current_is_dir():
				if not fname.begins_with("."):
					dir_queue.append(full)
			elif fname.ends_with(".gd") and full != "res://tests/check_scripts.gd":
				checked += 1
				var res: Resource = load(full)
				if res == null:
					failures.append(full)
			fname = dir.get_next()
		dir.list_dir_end()

	print("==================================================")
	if failures.is_empty():
		print("SCRIPT_CHECK_OK : %d scripts compilés sans erreur" % checked)
	else:
		print("SCRIPT_CHECK_FAIL : %d/%d scripts en échec :" % [failures.size(), checked])
		for f in failures:
			print("  FAIL: ", f)
	print("==================================================")
	get_tree().quit(0 if failures.is_empty() else 1)
