extends Node
## SceneRunner — joue une scène scriptée multi-acteurs (Phase D).
##
## Pipeline : casting (réutilise ChatScoring) → beats joués dans le temps avec des
## PAUSES (délais temps-réel) → branches résolues par rolls pondérés sur les traits
## de l'acteur → effets sur la sim. Une seule scène active à la fois.
##
## Une scène est de la DONNÉE (data/chat/scenes.json) ; ce runner est générique :
## ajouter une scène = un objet JSON, zéro code. Voir docs/design §6.

const ChatScoring = preload("res://scripts/systems/chat/chat_scoring.gd")

const CAST_TEMPERATURE: float = 0.6     # variété de casting
const BRANCH_TEMPERATURE: float = 0.4   # la branche la mieux assortie gagne souvent
const DEFAULT_BEAT_DELAY: float = 2.0   # secondes réelles entre deux répliques (la "pause")

var director: Node = null
var active: bool = false

var _cast: Dictionary = {}              # role_name -> membre
var _extra_vars: Dictionary = {}        # variables de stimulus (#boss#...) pour une scène réactive

# ==================== ENTRÉE ====================

func try_play_scene(scene: Dictionary, seed_subject: Variant = null, extra_vars: Dictionary = {}) -> bool:
	## Tente de caster puis de jouer la scène. Renvoie false si une scène tourne déjà
	## ou si un rôle requis ne peut être casté.
	if active or director == null:
		return false
	var cast: Variant = _cast_scene(scene, seed_subject)
	if cast == null:
		return false
	_cast = cast
	_extra_vars = extra_vars
	active = true
	director.set_scene_active(true)
	_run_beats(scene)   # coroutine fire-and-forget
	return true

# ==================== CASTING (réutilise le scoring) ====================

func _cast_scene(scene: Dictionary, seed_subject: Variant) -> Variant:
	var roles: Dictionary = scene.get("cast", {})
	if roles.is_empty():
		return {}
	var online: Array = director._online_members()
	var cast: Dictionary = {}
	for role_name in _ordered_roles(roles):
		var role_def: Dictionary = roles[role_name]
		var optional: bool = bool(role_def.get("optional", false))
		# Rôle pré-assigné par le sujet du stimulus (scène réactive).
		if String(role_def.get("seed", "")) == "subject" and seed_subject != null:
			cast[role_name] = seed_subject
			continue
		var excluded: Array = _resolve_excludes(role_def, cast)
		var candidates: Array = []
		for m in online:
			if m in cast.values() or m in excluded:
				continue
			candidates.append(m)
		if candidates.is_empty():
			if optional:
				continue
			return null   # rôle requis non castable → scène avortée
		var member: Variant = _pick_cast(candidates, role_def, cast)
		if member == null:
			if optional:
				continue
			return null
		cast[role_name] = member
	return cast

func _ordered_roles(roles: Dictionary) -> Array:
	# Rôles requis d'abord (ils peuvent être référencés par exclude/relation_to_role).
	var required: Array = []
	var optional: Array = []
	for role_name in roles:
		if bool(roles[role_name].get("optional", false)):
			optional.append(role_name)
		else:
			required.append(role_name)
	required.append_array(optional)
	return required

func _resolve_excludes(role_def: Dictionary, cast: Dictionary) -> Array:
	var out: Array = []
	var ex: Variant = role_def.get("exclude", [])
	if ex is Array:
		for role_name in ex:
			if cast.has(String(role_name)):
				out.append(cast[String(role_name)])
	return out

func _pick_cast(candidates: Array, role_def: Dictionary, cast: Dictionary) -> Variant:
	var cons: Variant = role_def.get("considerations", [])
	var items: Array = []
	var scores: Array = []
	for c in candidates:
		var ctx: Dictionary = director.build_cast_ctx(c, cast)
		var r: Dictionary = ChatScoring.score_line({"weight": 1.0, "considerations": cons}, ctx)
		if r["score"] <= 0.0:
			continue   # un veto exclut ce candidat
		items.append(c)
		scores.append(r["score"])
	if items.is_empty():
		return null
	return ChatScoring.softmax_sample(items, scores, CAST_TEMPERATURE)

# ==================== BEATS (avec pauses) ====================

func _run_beats(scene: Dictionary) -> void:
	var beats: Variant = scene.get("beats", [])
	if beats is Array:
		var count: int = 0
		for beat in beats:
			count += 1
			if count > 64:
				break
			var delay: float = float(beat.get("delay", DEFAULT_BEAT_DELAY))
			if delay > 0.0:
				var actor: Variant = _cast.get(String(beat.get("actor", "")))
				if actor != null and director:
					director.notify_typing(String(actor.nom))   # "X est en train d'écrire…"
				await get_tree().create_timer(delay).timeout
			if not active:
				break
			_play_beat(beat)
	active = false
	if director:
		director.notify_typing("")
		director.set_scene_active(false)

func _play_beat(beat: Dictionary) -> void:
	var actor: Variant = _cast.get(String(beat.get("actor", "")))
	if actor == null:
		return   # acteur optionnel non casté
	var resolved: Dictionary = _resolve_beat_text(beat, actor)
	var text: String = resolved["text"]
	if text.strip_edges() == "":
		return
	director.emit_scene_line(actor, director.expand_public(text, _all_vars()))
	_apply_effects(resolved["effects"])

func _resolve_beat_text(beat: Dictionary, actor: Variant) -> Dictionary:
	if beat.has("branch"):
		var chosen: Variant = _resolve_branch(beat["branch"], actor)
		if chosen == null:
			return {"text": "", "effects": []}
		return {"text": String(chosen.get("text", "")), "effects": chosen.get("effects", [])}
	return {"text": String(beat.get("text", "")), "effects": beat.get("effects", [])}

func _resolve_branch(branch: Dictionary, actor: Variant) -> Variant:
	## Roll pondéré : chaque option est scorée sur les axes de l'acteur (traits/humeur/relation).
	var options: Variant = branch.get("options", [])
	if not (options is Array) or options.is_empty():
		return null
	var scorer: Variant = actor
	if branch.has("axis_actor"):
		scorer = _cast.get(String(branch["axis_actor"]), actor)
	var ctx: Dictionary = director.build_cast_ctx(scorer, _cast)
	var items: Array = []
	var scores: Array = []
	for opt in options:
		var r: Dictionary = ChatScoring.score_line({"weight": float(opt.get("weight", 1.0)), "considerations": opt.get("considerations", [])}, ctx)
		items.append(opt)
		scores.append(maxf(0.0001, r["score"]))   # une branche est toujours choisie
	return ChatScoring.softmax_sample(items, scores, BRANCH_TEMPERATURE)

func _apply_effects(effects: Variant) -> void:
	if not (effects is Array):
		return
	for e in effects:
		if not (e is Dictionary):
			continue
		var target: Variant = _cast.get(String(e.get("target", "")))
		if target == null:
			continue
		if e.has("mood") and target.has_method("update_mood"):
			target.update_mood(float(e["mood"]))
		if e.has("stress") and target.has_method("add_stress"):
			var d: float = float(e["stress"])
			if d >= 0.0:
				target.add_stress(d)
			elif target.has_method("reduce_stress"):
				target.reduce_stress(-d)

func _all_vars() -> Dictionary:
	# #role# -> nom du membre casté, + variables de stimulus (#boss#...).
	var v: Dictionary = {}
	for k in _extra_vars:
		v[k] = _extra_vars[k]
	for role_name in _cast:
		v[role_name] = String(_cast[role_name].nom)
	return v

# ==================== DEBUG / TEST (jeu synchrone sans délais) ====================

func debug_play_sync(scene: Dictionary, seed_subject: Variant = null, extra_vars: Dictionary = {}) -> Array:
	## Joue la scène SANS délais ni lock (tests/menu debug). Retourne [[role, texte], ...].
	var transcript: Array = []
	var cast: Variant = _cast_scene(scene, seed_subject)
	if cast == null:
		return transcript
	_cast = cast
	_extra_vars = extra_vars
	var beats: Variant = scene.get("beats", [])
	if beats is Array:
		for beat in beats:
			var actor: Variant = _cast.get(String(beat.get("actor", "")))
			if actor == null:
				continue
			var resolved: Dictionary = _resolve_beat_text(beat, actor)
			var text: String = resolved["text"]
			if text.strip_edges() == "":
				continue
			_apply_effects(resolved["effects"])
			transcript.append([String(beat.get("actor", "")), director.expand_public(text, _all_vars())])
	return transcript
