extends Node
## ChatDirector — cerveau du chat de guilde vivant.
##
## Phase A : banter ambient data-driven. Le Director décide *qui* dit *quoi* *quand*
## et émet `line_emitted` ; le ChatPanel (vue passive) se contente d'afficher.
##
## Principes (cf. docs/design/2026-06-02-chat-guilde-vivant.md) :
##  - contenu = données (res://data/chat/), pas de `if` par réplique ;
##  - cadence ambient proportionnelle au nombre de joueurs en ligne (et à leur bavardise) ;
##  - plancher temps-réel : à haute vitesse / fast-forward instantané, le chat ne déborde pas ;
##  - déterminisme : tout tirage passe par GameRandom (rejouable avec seed_rng).
##
## Phases suivantes : moteur de scoring complet (B), stimuli réactifs (C), scènes (D).

signal line_emitted(speaker_name: String, text: String, channel: String)

const AMBIENT_LINES_PATH: String = "res://data/chat/lines/ambient_banter.json"
const REACTIVE_LINES_PATH: String = "res://data/chat/lines/reactive.json"

# Moteur de scoring d'utilité (référencé par preload pour éviter le cache de classes périmé).
const ChatScoring = preload("res://scripts/systems/chat/chat_scoring.gd")
# Température du tirage ambient : haute = variété/surprise (temps mort).
const AMBIENT_TEMPERATURE: float = 0.7
# Température du tirage réactif : plus basse = on reste sur le sujet de l'événement.
const REACTIVE_TEMPERATURE: float = 0.45
const SCENES_PATH: String = "res://data/chat/scenes.json"
const SceneRunnerScript = preload("res://scripts/systems/chat/scene_runner.gd")
# Probabilité de jouer une SCÈNE multi-acteurs plutôt qu'un one-liner lors d'un tick ambient.
const AMBIENT_SCENE_CHANCE: float = 0.25

# Anti-répétition & équité de parole (Phase E).
const RECENT_LINES_MAX: int = 8         # mémoire courte des dernières répliques
const REPEAT_PENALTY: float = 0.3       # pénalité de score si la réplique est récente
const EQUITY_WINDOW_MIN: float = 120.0  # fenêtre (min de jeu) pour redonner la parole
const EQUITY_BONUS: float = 1.0         # bonus max de poids pour un membre longtemps muet

# Cadence ambient (en minutes de JEU).
const BASE_INTERVAL_MIN: float = 22.0   # avant division par sqrt(online) × bavardise
const MIN_GAP_MIN: float = 4.0
const MAX_GAP_MIN: float = 90.0
# Plancher temps-réel : au plus ~1 émission toutes les REALTIME_FLOOR_MS millisecondes.
const REALTIME_FLOOR_MS: int = 1500

var enabled: bool = true

var _lines: Array = []
var _ig_minutes_since_last: float = 0.0
var _next_interval: float = BASE_INTERVAL_MIN
var _last_emit_ms: int = 0
var _line_cooldowns: Dictionary = {}   # id -> minute de jeu absolue de dernière utilisation
var _last_speaker_id: String = ""
var _emitted_count: int = 0            # total de lignes émises (debug / test)
var _blackboard: Array = []            # stimuli réactifs en attente {kind,salience,subject,vars,ttl,born}
var _scene_runner: Node = null
var _scenes: Array = []
var _scene_cooldowns: Dictionary = {}  # scene id -> minute de jeu de dernière utilisation
var scene_active: bool = false         # une scène multi-acteurs occupe le chat
var scenes_enabled: bool = true        # désactivable (soak/tests one-liner)
var _recent_line_ids: Array = []       # ring buffer anti-répétition (ids de one-liners)
var _last_spoke: Dictionary = {}       # player_id -> minute de jeu de dernière prise de parole

func _ready() -> void:
	_load_corpus()
	_load_scenes()
	_scene_runner = SceneRunnerScript.new()
	_scene_runner.name = "SceneRunner"
	_scene_runner.director = self
	add_child(_scene_runner)
	if GameTime and not GameTime.minute_changed.is_connected(_on_minute_changed):
		GameTime.minute_changed.connect(_on_minute_changed)
	_connect_event_signals()
	_next_interval = _compute_interval()

# ==================== CORPUS ====================

func _load_corpus() -> void:
	_lines = []
	_lines.append_array(_load_lines(AMBIENT_LINES_PATH))
	_lines.append_array(_load_lines(REACTIVE_LINES_PATH))
	if _lines.is_empty():
		push_warning("ChatDirector : corpus vide ou introuvable (%s / %s)" % [AMBIENT_LINES_PATH, REACTIVE_LINES_PATH])

func _load_lines(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var raw: String = f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(raw)
	if typeof(data) == TYPE_DICTIONARY and data.has("lines") and data["lines"] is Array:
		return data["lines"]
	return []

func _load_scenes() -> void:
	_scenes = []
	if not FileAccess.file_exists(SCENES_PATH):
		return
	var f: FileAccess = FileAccess.open(SCENES_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) == TYPE_DICTIONARY and data.has("scenes") and data["scenes"] is Array:
		_scenes = data["scenes"]

# ==================== TICK AMBIENT ====================

func _on_minute_changed(_minute: int, _hour: int) -> void:
	if not enabled:
		return
	# Réactif d'abord : un stimulus en attente passe avant le banter.
	_process_blackboard()
	if GameTime and GameTime.is_paused:
		return
	_ig_minutes_since_last += 1.0
	if _ig_minutes_since_last >= _next_interval:
		_ig_minutes_since_last = 0.0
		_next_interval = _compute_interval()
		_try_ambient()

func _compute_interval() -> float:
	var online: Array = _online_members()
	var n: int = maxi(1, online.size())
	var talk: float = _talk_factor(online)
	var interval: float = BASE_INTERVAL_MIN / (sqrt(float(n)) * maxf(0.4, talk))
	interval = GameRandom.variance(interval, 25.0)   # jitter ±25%
	return clampf(interval, MIN_GAP_MIN, MAX_GAP_MIN)

func _try_ambient(ignore_floor: bool = false) -> void:
	if scene_active:
		return   # une scène occupe le chat
	# Garde-fou temps-réel (anti-flood haute vitesse / fast-forward instantané).
	var now_ms: int = Time.get_ticks_msec()
	if not ignore_floor and now_ms - _last_emit_ms < REALTIME_FLOOR_MS:
		return
	var online: Array = _online_members()
	if online.is_empty():
		return
	# Parfois, jouer une vraie scène multi-acteurs plutôt qu'un one-liner.
	if GameRandom.chance(AMBIENT_SCENE_CHANCE) and _try_scene("ambient"):
		return
	_emit_ambient_line(online)

func _emit_ambient_line(online: Array) -> void:
	var speaker: Variant = _pick_speaker(online)
	if speaker == null:
		return
	var line: Variant = _pick_line(speaker, "ambient")
	if line == null:
		return
	_emit_line(speaker, line)

func _emit_line(speaker: Variant, line: Variant, vars: Dictionary = {}) -> void:
	var text: String = _expand(String(line.get("text", "")), vars)
	if text.strip_edges() == "":
		return
	_line_cooldowns[String(line.get("id", ""))] = _now_total_minutes()
	_remember_line(String(line.get("id", "")))
	_last_spoke[String(speaker.player_id)] = _now_total_minutes()
	_last_speaker_id = String(speaker.player_id)
	_last_emit_ms = Time.get_ticks_msec()
	_emitted_count += 1
	line_emitted.emit(String(speaker.nom), text, "guild")

func _remember_line(id: String) -> void:
	if id == "":
		return
	_recent_line_ids.append(id)
	if _recent_line_ids.size() > RECENT_LINES_MAX:
		_recent_line_ids.pop_front()

# ==================== SÉLECTION (version Phase A — généralisée en Phase B) ====================

func _pick_speaker(online: Array) -> Variant:
	var opts: Array = []
	var weights: Array = []
	for m in online:
		var w: float = _talkativeness(m) * _equity_factor(m)
		if String(m.player_id) == _last_speaker_id:
			w *= 0.3   # évite le monologue
		opts.append(m)
		weights.append(w)
	return GameRandom.weighted_pick(opts, weights)

func _pick_line(speaker: Variant, pool: String, subject: Variant = null, temperature: float = AMBIENT_TEMPERATURE, salience: float = 0.0) -> Variant:
	# Moteur de scoring : chaque ligne éligible est scorée (gates × Σbonus),
	# puis tirage softmax à température (variété sans répétition).
	var ctx: Dictionary = _build_ctx(speaker, subject, salience)
	var lines: Array = []
	var scores: Array = []
	var now: int = _now_total_minutes()
	for line in _lines:
		if not _line_in_pool(line, pool):
			continue
		if not _passes_vetos(line, speaker):
			continue
		if _on_cooldown(line, now):
			continue
		var r: Dictionary = ChatScoring.score_line(line, ctx)
		var sc: float = r["score"]
		if sc <= 0.0:
			continue
		if String(line.get("id", "")) in _recent_line_ids:
			sc *= REPEAT_PENALTY   # anti-répétition douce, au-delà du cooldown dur
		lines.append(line)
		scores.append(sc)
	return ChatScoring.softmax_sample(lines, scores, temperature)

func _on_cooldown(line: Variant, now: int) -> bool:
	var cd: float = float(line.get("cooldown_min", 0))
	if cd <= 0.0:
		return false
	var last: float = float(_line_cooldowns.get(String(line.get("id", "")), -1000000))
	return float(now) - last < cd

func _build_ctx(speaker: Variant, subject: Variant, salience: float = 0.0) -> Dictionary:
	# Contexte de scoring : valeurs lues une fois ici (le moteur reste pur/testable).
	return {
		"speaker": speaker,
		"subject": subject,
		"relation": _relation_between(speaker, subject),
		"speaker_vibe": _speaker_vibe(speaker),
		"salience": salience,
		"hour": GameTime.current_hour if GameTime else 0,
		"guild_morale": GuildCultureManager.guild_morale if GuildCultureManager else 50.0,
		"phase": int(PhaseManager.current_phase) if PhaseManager else 0,
	}

func _speaker_vibe(m: Variant) -> Array:
	# Coords vibe du locuteur (serieux, toxicite, sweat) ∈ [-1,1], dérivées des traits + humeur.
	if m == null:
		return [0.0, 0.0, 0.0]
	var traits: Array = _traits(m)
	var serieux: float = 0.0
	var toxicite: float = 0.0
	var sweat: float = 0.0
	if "perfectionniste" in traits:
		serieux += 0.6
		sweat += 0.3
	if "solitaire" in traits:
		serieux += 0.3
	if "drama_queen" in traits:
		serieux -= 0.5
		toxicite += 0.5
	if "casual" in traits:
		serieux -= 0.4
		sweat -= 0.7
	if "social" in traits:
		serieux -= 0.2
	if "tryhard" in traits:
		sweat += 0.8
		serieux += 0.2
	if "greedy" in traits:
		toxicite += 0.3
	if "rage_quitter" in traits:
		toxicite += 0.4
	if "serviable" in traits:
		toxicite -= 0.5
	var mood: float = float(m.mood)
	if mood < 40.0:
		toxicite += 0.4
	elif mood > 75.0:
		toxicite -= 0.2
	return [clampf(serieux, -1.0, 1.0), clampf(toxicite, -1.0, 1.0), clampf(sweat, -1.0, 1.0)]

func _line_in_pool(line: Variant, pool: String) -> bool:
	var pools: Variant = line.get("pools", [])
	if pools is Array:
		return pools.is_empty() or pool in pools
	return true

func _passes_vetos(line: Variant, speaker: Variant) -> bool:
	var rc: String = String(line.get("requires_class", ""))
	if rc != "" and String(speaker.personnage_classe) != rc:
		return false
	var rr: String = String(line.get("requires_role", ""))
	if rr != "" and String(speaker.get_role()) != rr:
		return false
	var rt: String = String(line.get("requires_trait", ""))
	if rt != "" and not (rt in _traits(speaker)):
		return false
	return true

# ==================== BAVARDISE ====================

func _talk_factor(online: Array) -> float:
	if online.is_empty():
		return 1.0
	var total: float = 0.0
	for m in online:
		total += _talkativeness(m)
	return total / float(online.size())

func _talkativeness(m: Variant) -> float:
	var t: float = 1.0
	var traits: Array = _traits(m)
	if "social" in traits:
		t += 0.6
	if "drama_queen" in traits:
		t += 0.5
	if "solitaire" in traits:
		t -= 0.6
	if "perfectionniste" in traits:
		t -= 0.2
	# Humeur : plus on est de bonne humeur, plus on jase.
	t *= lerpf(0.6, 1.3, clampf(float(m.mood) / 100.0, 0.0, 1.0))
	return maxf(0.1, t)

func _equity_factor(m: Variant) -> float:
	# Équité de parole : un membre longtemps muet voit son poids monter (tout le monde a une voix).
	var last: float = float(_last_spoke.get(String(m.player_id), -1000000.0))
	var silent: float = float(_now_total_minutes()) - last
	return 1.0 + clampf(silent / EQUITY_WINDOW_MIN, 0.0, 1.0) * EQUITY_BONUS

# ==================== GRAMMAIRE (inline {a|b|c} — étendue en Phase B/F) ====================

func _expand(s: String, vars: Dictionary = {}) -> String:
	var result: String = s
	# 1) Injection des variables réelles du stimulus : #token# -> valeur.
	for key in vars:
		result = result.replace("#" + String(key) + "#", String(vars[key]))
	# 2) Choix inline {a|b|c}.
	var guard: int = 0
	while result.find("{") != -1 and result.find("}") != -1 and guard < 16:
		guard += 1
		var open_idx: int = result.find("{")
		var close_idx: int = result.find("}", open_idx)
		if close_idx == -1:
			break
		var inner: String = result.substr(open_idx + 1, close_idx - open_idx - 1)
		var choice: String = inner
		if inner.find("|") != -1:
			var parts: PackedStringArray = inner.split("|")
			choice = String(GameRandom.pick_random(parts))
		result = result.substr(0, open_idx) + choice + result.substr(close_idx + 1)
	return result

# ==================== HELPERS ====================

func _traits(m: Variant) -> Array:
	var t: Array = []
	if m.tags_comportement is Array:
		t.append_array(m.tags_comportement)
	if m.tags_caches is Array:
		t.append_array(m.tags_caches)
	return t

func _online_members() -> Array:
	if GuildManager and GuildManager.has_method("get_online_members"):
		return GuildManager.get_online_members()
	return []

func _now_total_minutes() -> int:
	if GameTime:
		return GameTime.get_total_days_elapsed() * 24 * 60 + GameTime.current_hour * 60 + GameTime.current_minute
	return 0

func _behavior_system() -> Variant:
	if GuildManager and GuildManager.behavior_system:
		return GuildManager.behavior_system
	return null

func _social_dynamics() -> Variant:
	var bs: Variant = _behavior_system()
	if bs and bs.social_dynamics:
		return bs.social_dynamics
	return null

func _relation_between(a: Variant, b: Variant) -> String:
	# Relation a→b via le vrai graphe social (SocialDynamics). "" si pas de sujet / pas de relation.
	if a == null or b == null or a == b:
		return ""
	var sd: Variant = _social_dynamics()
	if sd == null or not sd.has_method("get_relationship"):
		return ""
	var rel: Variant = sd.get_relationship(a, b)
	if rel == null:
		return ""
	return _relation_int_to_string(int(rel.type))

func _relation_int_to_string(t: int) -> String:
	match t:
		SocialDynamics.RelationType.FRIEND: return "friend"
		SocialDynamics.RelationType.MENTOR: return "mentor"
		SocialDynamics.RelationType.STUDENT: return "student"
		SocialDynamics.RelationType.RIVAL: return "rival"
		SocialDynamics.RelationType.ENEMY: return "enemy"
		_: return "neutral"

# ==================== STIMULI RÉACTIFS (blackboard) ====================

func _connect_event_signals() -> void:
	if GuildManager:
		_safe_connect(GuildManager, "member_leveled_up", _on_member_leveled_up)
		_safe_connect(GuildManager, "member_recruited", _on_member_recruited)
		_safe_connect(GuildManager, "member_left", _on_member_left)
		_safe_connect(GuildManager, "loot_conflict_occurred", _on_loot_conflict)
	if ActivityManager:
		_safe_connect(ActivityManager, "dungeon_started", _on_dungeon_started)
	if DramaManager:
		_safe_connect(DramaManager, "drama_occurred", _on_drama_occurred)
	if GuildCultureManager:
		_safe_connect(GuildCultureManager, "tension_detected", _on_tension_detected)
	# behavior_system est créé en différé → on s'y abonne après une frame.
	call_deferred("_connect_deferred_signals")

func _connect_deferred_signals() -> void:
	var bs: Variant = _behavior_system()
	if bs:
		_safe_connect(bs, "burnout_level_changed", _on_burnout_changed)

func _safe_connect(obj: Variant, sig_name: String, callable: Callable) -> void:
	if obj and obj.has_signal(sig_name) and not obj.is_connected(sig_name, callable):
		obj.connect(sig_name, callable)

func _push_stimulus(kind: String, salience: float, subject: Variant = null, vars: Dictionary = {}, ttl_min: float = 30.0) -> void:
	if not enabled:
		return
	_blackboard.append({
		"kind": kind, "salience": salience, "subject": subject,
		"vars": vars, "ttl": ttl_min, "born": _now_total_minutes(),
	})
	_process_blackboard()

func _process_blackboard() -> void:
	_expire_stimuli()
	if _blackboard.is_empty():
		return
	# Plancher temps-réel : on diffère (sans perdre le stimulus) si on vient d'émettre.
	if Time.get_ticks_msec() - _last_emit_ms < REALTIME_FLOOR_MS:
		return
	var best: int = 0
	for i in range(1, _blackboard.size()):
		if float(_blackboard[i]["salience"]) > float(_blackboard[best]["salience"]):
			best = i
	var stim: Dictionary = _blackboard[best]
	_blackboard.remove_at(best)
	_emit_reactive(stim)

func _expire_stimuli() -> void:
	var now: int = _now_total_minutes()
	var kept: Array = []
	for s in _blackboard:
		if float(now) - float(s["born"]) <= float(s["ttl"]):
			kept.append(s)
	_blackboard = kept

func _emit_reactive(stim: Dictionary) -> void:
	# Une scène réactive (plus riche) est préférée si elle peut être castée.
	if not scene_active and _try_scene(String(stim["kind"]), stim.get("subject"), stim.get("vars", {})):
		return
	_emit_reactive_line(stim)

func _emit_reactive_line(stim: Dictionary) -> void:
	var subject: Variant = stim.get("subject")
	var speaker: Variant = _pick_reactive_speaker(subject)
	if speaker == null:
		return
	var line: Variant = _pick_line(speaker, String(stim["kind"]), subject, REACTIVE_TEMPERATURE, float(stim["salience"]))
	if line == null:
		return
	_emit_line(speaker, line, stim.get("vars", {}))

func _pick_reactive_speaker(subject: Variant) -> Variant:
	# Les AUTRES réagissent au sujet. Un proche (ami/rival/ennemi...) chambre ou félicite plus.
	var online: Array = _online_members()
	var opts: Array = []
	var weights: Array = []
	for m in online:
		if subject != null and m == subject:
			continue
		var w: float = _talkativeness(m) * _equity_factor(m)
		if subject != null:
			var rel: String = _relation_between(m, subject)
			if rel != "" and rel != "neutral":
				w *= 1.7
		if String(m.player_id) == _last_speaker_id:
			w *= 0.4
		opts.append(m)
		weights.append(w)
	return GameRandom.weighted_pick(opts, weights)

# ==================== SCÈNES ====================

func _try_scene(pool: String, subject: Variant = null, extra_vars: Dictionary = {}) -> bool:
	if scene_active or _scene_runner == null or not scenes_enabled:
		return false
	var online_count: int = _online_members().size()
	var now: int = _now_total_minutes()
	var candidates: Array = []
	var weights: Array = []
	for sc in _scenes:
		var trig: Dictionary = sc.get("trigger", {})
		var pools: Variant = trig.get("pools", [])
		if not (pools is Array) or not (pool in pools):
			continue
		if online_count < int(trig.get("min_online", 1)):
			continue
		if _scene_on_cooldown(sc, now):
			continue
		candidates.append(sc)
		weights.append(float(trig.get("weight", 1.0)))
	# Essaie les scènes éligibles (ordre pondéré) jusqu'à ce qu'une caste avec succès.
	while not candidates.is_empty():
		var sc: Variant = GameRandom.weighted_pick(candidates, weights)
		var idx: int = candidates.find(sc)
		candidates.remove_at(idx)
		weights.remove_at(idx)
		if _scene_runner.try_play_scene(sc, subject, extra_vars):
			_scene_cooldowns[String(sc.get("id", ""))] = now
			return true
	return false

func _scene_on_cooldown(scene: Dictionary, now: int) -> bool:
	var trig: Dictionary = scene.get("trigger", {})
	var cd: float = float(trig.get("cooldown_min", 0))
	if cd <= 0.0:
		return false
	var last: float = float(_scene_cooldowns.get(String(scene.get("id", "")), -1000000))
	return float(now) - last < cd

# Méthodes appelées par le SceneRunner (enfant du Director) — il s'appuie sur les
# helpers du Director (online, relations, grammaire) plutôt que de les dupliquer.

func build_cast_ctx(candidate: Variant, cast: Dictionary) -> Dictionary:
	var ctx: Dictionary = _build_ctx(candidate, null, 0.0)
	var role_relations: Dictionary = {}
	for role_name in cast:
		role_relations[role_name] = _relation_between(candidate, cast[role_name])
	ctx["role_relations"] = role_relations
	return ctx

func emit_scene_line(speaker: Variant, text: String) -> void:
	if text.strip_edges() == "":
		return
	_last_spoke[String(speaker.player_id)] = _now_total_minutes()
	_last_speaker_id = String(speaker.player_id)
	_last_emit_ms = Time.get_ticks_msec()
	_emitted_count += 1
	line_emitted.emit(String(speaker.nom), text, "guild")

func expand_public(text: String, vars: Dictionary = {}) -> String:
	return _expand(text, vars)

func set_scene_active(value: bool) -> void:
	scene_active = value

# ==================== HANDLERS DE SIGNAUX ====================

func _on_member_leveled_up(player: Variant, new_level: int) -> void:
	var sal: float = 1.0 if new_level >= 60 else 0.35
	_push_stimulus("level_up", sal, player, {"subject": String(player.nom), "lvl": str(new_level)})

func _on_member_recruited(player: Variant) -> void:
	_push_stimulus("recruit", 0.5, player, {"subject": String(player.nom)})

func _on_loot_conflict(conflict: Variant) -> void:
	var vars: Dictionary = {}
	if conflict is Dictionary and conflict.has("item"):
		var it: Variant = conflict["item"]
		if it is Resource and "name" in it:
			vars["item"] = String(it.name)
	_push_stimulus("ninja", 0.9, null, vars)

func _on_member_left(player: Variant) -> void:
	_push_stimulus("member_left", 0.8, player, {"subject": String(player.nom)})

func _on_dungeon_started(dungeon_instance: Variant) -> void:
	if dungeon_instance == null:
		return
	_safe_connect(dungeon_instance, "loot_distributed", _on_loot_distributed)
	_safe_connect(dungeon_instance, "boss_failed", _on_boss_failed)
	_safe_connect(dungeon_instance, "boss_defeated", _on_boss_defeated)

func _on_loot_distributed(member: Variant, item: Variant) -> void:
	if member == null or item == null:
		return
	var is_epic: bool = false
	var item_name: String = str(item)
	if item is Resource:
		if "rarity" in item:
			is_epic = int(item.rarity) >= 2   # >= RARE (COMMON0, UNCOMMON1, RARE2, EPIC3)
		if "name" in item:
			item_name = String(item.name)
	var kind: String = "loot_epic" if is_epic else "loot"
	var sal: float = 0.9 if is_epic else 0.4
	_push_stimulus(kind, sal, member, {"subject": String(member.nom), "item": item_name})

func _on_boss_failed(_boss_index: int, boss_name: String, wipe_count: int) -> void:
	var sal: float = clampf(0.5 + 0.05 * float(wipe_count), 0.5, 0.85)
	_push_stimulus("wipe", sal, null, {"boss": boss_name, "wipes": str(wipe_count)})

func _on_boss_defeated(_boss_index: int, boss_name: String, _loot_winner: Variant) -> void:
	_push_stimulus("boss_kill", 0.5, null, {"boss": boss_name})

func _on_drama_occurred(_drama: Variant) -> void:
	_push_stimulus("drama", 1.0, null, {})

func _on_tension_detected(player1_name: String, player2_name: String, _reason: String) -> void:
	_push_stimulus("tension", 0.7, null, {"p1": player1_name, "p2": player2_name})

func _on_burnout_changed(player: Variant, new_level: int) -> void:
	if new_level <= 0:
		return
	_push_stimulus("burnout", 0.6, player, {"subject": String(player.nom)})

# ==================== API DEBUG / TEST ====================

func debug_force_ambient() -> bool:
	## Force une tentative d'émission ambient (ignore la cadence ET le plancher temps-réel,
	## garde les vetos/cooldowns). Utilisé par le harnais de test et le menu debug.
	## Émet un one-liner ambient (jamais une scène : forceur de ligne déterministe).
	var before: int = _emitted_count
	var online: Array = _online_members()
	if not online.is_empty():
		_emit_ambient_line(online)
	return _emitted_count > before

func debug_force_reactive(kind: String, subject: Variant = null, vars: Dictionary = {}, salience: float = 0.7) -> bool:
	## Force une réaction one-liner pour un type d'événement (jamais une scène).
	## Utilisé par le harnais de test et le menu debug.
	var before: int = _emitted_count
	_emit_reactive_line({"kind": kind, "salience": salience, "subject": subject, "vars": vars})
	return _emitted_count > before

func get_corpus_size() -> int:
	return _lines.size()

func debug_count_pool(pool: String) -> int:
	var c: int = 0
	for line in _lines:
		if _line_in_pool(line, pool):
			c += 1
	return c

func get_scene_count() -> int:
	return _scenes.size()

func debug_get_scene(scene_id: String) -> Dictionary:
	for sc in _scenes:
		if String(sc.get("id", "")) == scene_id:
			return sc
	return {}

func debug_play_scene(scene_id: String, subject: Variant = null, extra_vars: Dictionary = {}) -> bool:
	## Joue une scène précise (ignore pool/cooldown/chance). Pour le menu debug.
	var sc: Dictionary = debug_get_scene(scene_id)
	if sc.is_empty() or _scene_runner == null:
		return false
	return _scene_runner.try_play_scene(sc, subject, extra_vars)

func debug_play_scene_sync(scene_id: String, subject: Variant = null, extra_vars: Dictionary = {}) -> Array:
	## Joue une scène SANS délais ni lock et renvoie le transcript [[role, texte], ...] (tests).
	var sc: Dictionary = debug_get_scene(scene_id)
	if sc.is_empty() or _scene_runner == null:
		return []
	return _scene_runner.debug_play_sync(sc, subject, extra_vars)

func debug_explain_ambient(top_n: int = 5) -> Dictionary:
	## Pour un locuteur plausible (le plus bavard tiré), renvoie le top-N des répliques
	## ambient avec leur score et le détail par considération. Sert au menu debug et aux tests.
	var online: Array = _online_members()
	if online.is_empty():
		return {}
	var speaker: Variant = _pick_speaker(online)
	if speaker == null:
		return {}
	var ctx: Dictionary = _build_ctx(speaker, null)
	var now: int = _now_total_minutes()
	var rows: Array = []
	for line in _lines:
		if not _line_in_pool(line, "ambient"):
			continue
		if not _passes_vetos(line, speaker):
			continue
		if _on_cooldown(line, now):
			continue
		var r: Dictionary = ChatScoring.score_line(line, ctx)
		rows.append({"id": String(line.get("id", "")), "score": r["score"], "breakdown": r["breakdown"]})
	rows.sort_custom(func(a, b): return a["score"] > b["score"])
	return {"speaker": String(speaker.nom), "rows": rows.slice(0, top_n)}
