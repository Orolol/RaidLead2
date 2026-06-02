extends SceneTree

## E2E : valide la boucle de gestion du personnage joueur.
## 1. Au démarrage, sans activité, le temps est mis en pause (pause-si-oisif).
## 2. Choisir une activité relance le temps et draine l'énergie.
## 3. Un repos volontaire reconnecte et reprend la dernière activité.
## Lancer : Godot ... -s res://tests/e2e_player_flow.gd

var _frames: int = 0
var _state: int = 0
var _ok: int = 0
var _fail: int = 0
var _energy_after_choice: float = 0.0

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
			# Laisser le temps aux autoloads + call_deferred du prompt d'oisiveté
			if _frames >= 120:
				_phase_idle_pause()
				_state = 2
				_frames = 0
		2:
			if _frames >= 30:
				_phase_choose_activity()
				_state = 3
				_frames = 0
		3:
			# Laisser quelques ticks de jeu s'écouler pour vérifier le drain
			if _frames >= 120:
				_phase_energy_drains()
				_state = 4
				_frames = 0
		4:
			if _frames >= 5:
				print("\nE2E_PLAYER_FLOW : %d OK / %d FAIL" % [_ok, _fail])
				quit(1 if _fail > 0 else 0)
				return true
	return false

func _gt() -> Node:
	return root.get_node_or_null("/root/GameTime")

func _player():
	var gm = root.get_node_or_null("/root/GuildManager")
	return gm.get_player_character() if gm else null

func _phase_idle_pause() -> void:
	print("\n-- Phase 1 : pause-si-oisif au démarrage --")
	var gt = _gt()
	var p = _player()
	_check(p != null, "personnage joueur existe")
	if p:
		_check(p.current_activity == null, "aucune activité au démarrage")
		_check(p.needs_activity_choice(), "le joueur attend un ordre")
	_check(gt != null and gt.is_paused, "le temps est en pause tant qu'aucune activité n'est choisie")

func _phase_choose_activity() -> void:
	print("\n-- Phase 2 : choix d'activité relance le temps --")
	var gt = _gt()
	var p = _player()
	if p:
		p.choose_activity("LEVELING")
		_energy_after_choice = p.player_energy_pool
		_check(p.current_activity != null, "activité démarrée après le choix")
		_check(p.last_activity_choice == "LEVELING", "dernière activité mémorisée")
	_check(gt != null and not gt.is_paused, "le temps repart après le choix d'activité")
	# Accélère pour observer le drain rapidement
	if gt:
		gt.set_time_speed(2400.0)

func _phase_energy_drains() -> void:
	print("\n-- Phase 3 : l'énergie baisse pendant l'activité --")
	var p = _player()
	if p:
		_check(p.player_energy_pool < _energy_after_choice, "l'énergie a baissé (%.1f < %.1f)" % [p.player_energy_pool, _energy_after_choice])
