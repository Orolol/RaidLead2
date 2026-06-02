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

# Moteur de scoring d'utilité (référencé par preload pour éviter le cache de classes périmé).
const ChatScoring = preload("res://scripts/systems/chat/chat_scoring.gd")
# Température du tirage ambient : haute = variété/surprise (temps mort).
const AMBIENT_TEMPERATURE: float = 0.7

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

func _ready() -> void:
	_load_corpus()
	if GameTime and not GameTime.minute_changed.is_connected(_on_minute_changed):
		GameTime.minute_changed.connect(_on_minute_changed)
	_next_interval = _compute_interval()

# ==================== CORPUS ====================

func _load_corpus() -> void:
	_lines = _load_lines(AMBIENT_LINES_PATH)
	if _lines.is_empty():
		push_warning("ChatDirector : corpus ambient vide ou introuvable (%s)" % AMBIENT_LINES_PATH)

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

# ==================== TICK AMBIENT ====================

func _on_minute_changed(_minute: int, _hour: int) -> void:
	if not enabled:
		return
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
	# Garde-fou temps-réel (anti-flood haute vitesse / fast-forward instantané).
	var now_ms: int = Time.get_ticks_msec()
	if not ignore_floor and now_ms - _last_emit_ms < REALTIME_FLOOR_MS:
		return
	var online: Array = _online_members()
	if online.is_empty():
		return
	var speaker: Variant = _pick_speaker(online)
	if speaker == null:
		return
	var line: Variant = _pick_line(speaker, "ambient")
	if line == null:
		return
	_emit_line(speaker, line)

func _emit_line(speaker: Variant, line: Variant) -> void:
	var text: String = _expand(String(line.get("text", "")))
	if text.strip_edges() == "":
		return
	_line_cooldowns[String(line.get("id", ""))] = _now_total_minutes()
	_last_speaker_id = String(speaker.player_id)
	_last_emit_ms = Time.get_ticks_msec()
	_emitted_count += 1
	line_emitted.emit(String(speaker.nom), text, "guild")

# ==================== SÉLECTION (version Phase A — généralisée en Phase B) ====================

func _pick_speaker(online: Array) -> Variant:
	var opts: Array = []
	var weights: Array = []
	for m in online:
		var w: float = _talkativeness(m)
		if String(m.player_id) == _last_speaker_id:
			w *= 0.3   # évite le monologue
		opts.append(m)
		weights.append(w)
	return GameRandom.weighted_pick(opts, weights)

func _pick_line(speaker: Variant, pool: String, subject: Variant = null) -> Variant:
	# Moteur de scoring (Phase B) : chaque ligne éligible est scorée (gates × Σbonus),
	# puis tirage softmax à température (variété sans répétition).
	var ctx: Dictionary = _build_ctx(speaker, subject)
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
		if r["score"] <= 0.0:
			continue
		lines.append(line)
		scores.append(r["score"])
	return ChatScoring.softmax_sample(lines, scores, AMBIENT_TEMPERATURE)

func _on_cooldown(line: Variant, now: int) -> bool:
	var cd: float = float(line.get("cooldown_min", 0))
	if cd <= 0.0:
		return false
	var last: float = float(_line_cooldowns.get(String(line.get("id", "")), -1000000))
	return float(now) - last < cd

func _build_ctx(speaker: Variant, subject: Variant) -> Dictionary:
	# Contexte de scoring : valeurs lues une fois ici (le moteur reste pur/testable).
	return {
		"speaker": speaker,
		"subject": subject,
		"salience": 0.0,
		"hour": GameTime.current_hour if GameTime else 0,
		"guild_morale": GuildCultureManager.guild_morale if GuildCultureManager else 50.0,
		"phase": int(PhaseManager.current_phase) if PhaseManager else 0,
	}

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

# ==================== GRAMMAIRE (inline {a|b|c} — étendue en Phase B/F) ====================

func _expand(s: String) -> String:
	var result: String = s
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

# ==================== API DEBUG / TEST ====================

func debug_force_ambient() -> bool:
	## Force une tentative d'émission ambient (ignore la cadence ET le plancher temps-réel,
	## garde les vetos/cooldowns). Utilisé par le harnais de test et le menu debug.
	var before: int = _emitted_count
	_try_ambient(true)
	return _emitted_count > before

func get_corpus_size() -> int:
	return _lines.size()

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
