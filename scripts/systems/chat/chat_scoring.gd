extends RefCounted
## ChatScoring — moteur de scoring d'utilité pour le chat vivant (Phase B).
##
## API statique et PURE (ne lit pas les autoloads : tout passe par `ctx`) → testable
## et déterministe. Voir docs/design/2026-06-02-chat-guilde-vivant.md §1.
##
## Modèle retenu (décision du dev) :  score = (base_weight + Σ bonus) × (Π veto)
##  - veto  ∈ [0,1] (surtout {0,1}) : un seul 0 élimine le candidat.
##  - bonus ≥ 0 : contributions additives, lisibles dans le breakdown.
##
## Une « considération » = un axe (d'où vient la valeur) + une courbe (valeur→[0,1])
## + un kind (bonus|veto) + un poids. Référencée par ChatDirector via preload.

# ==================== SCORING ====================

static func score_line(line: Dictionary, ctx: Dictionary) -> Dictionary:
	## Retourne {score, bonus, veto, breakdown}. breakdown = liste de contributions
	## (pour l'explicateur de score debug).
	var bonus: float = float(line.get("weight", 1.0))   # le poids de base amorce la somme
	var veto: float = 1.0
	var breakdown: Array = [{"label": "base_weight", "kind": "bonus", "value": bonus}]

	var considerations: Variant = line.get("considerations", [])
	if considerations is Array:
		for cons in considerations:
			if not (cons is Dictionary):
				continue
			var axis: String = String(cons.get("axis", ""))
			var curve: String = String(cons.get("curve", "boolean"))
			var kind: String = String(cons.get("kind", "bonus"))
			var w: float = float(cons.get("weight", 1.0))

			var raw: Variant = read_axis(axis, cons.get("param", null), ctx)
			# Égalité explicite via "value" (classe/rôle/relation) → booléen.
			var input: Variant = raw
			if cons.has("value"):
				input = (raw == cons["value"])
			var s: float = apply_curve(input, curve, cons)

			if kind == "veto":
				veto *= s
				breakdown.append({"label": _cons_label(cons), "kind": "veto", "value": s})
			else:
				var contrib: float = w * s
				bonus += contrib
				breakdown.append({"label": _cons_label(cons), "kind": "bonus", "value": contrib})

	var score: float = bonus * veto
	return {"score": score, "bonus": bonus, "veto": veto, "breakdown": breakdown}

static func _cons_label(cons: Dictionary) -> String:
	var label: String = String(cons.get("axis", "?"))
	if cons.has("param") and cons["param"] != null:
		label += "(" + String(cons["param"]) + ")"
	elif cons.has("value"):
		label += "=" + String(cons["value"])
	return label

# ==================== LECTEURS D'AXES ====================
# Seul endroit qui touche le modèle (membre + contexte). Pur : lit `ctx`, pas les autoloads.

static func read_axis(axis: String, param: Variant, ctx: Dictionary) -> Variant:
	var sp: Variant = ctx.get("speaker", null)
	match axis:
		"speaker.class":
			return String(sp.personnage_classe) if sp else ""
		"speaker.role":
			return String(sp.get_role()) if sp else ""
		"speaker.has_trait":
			return sp != null and String(param) in _traits(sp)
		"speaker.mood":
			return float(sp.mood) if sp else 0.0
		"speaker.energy":
			return float(sp.energy) if sp else 0.0
		"speaker.stress":
			return float(sp.stress_level) if sp else 0.0
		"speaker.burnout":
			return float(sp.burnout_level) if sp else 0.0
		"speaker.integration":
			return float(sp.integration) if sp else 0.0
		"speaker.days_in_guild":
			return float(sp.days_in_guild) if sp else 0.0
		"relation":
			# Relation locuteur→sujet, résolue en amont par le ChatDirector (accès SocialDynamics)
			# et passée dans ctx pour garder ce moteur pur. "" pour l'ambient (pas de sujet).
			return String(ctx.get("relation", ""))
		"relation_to_role":
			# Relation candidat→rôle déjà casté (scènes). ctx["role_relations"] = {role: relation}.
			var rr: Variant = ctx.get("role_relations", {})
			if rr is Dictionary:
				return String(rr.get(String(param), ""))
			return ""
		"context.event_magnitude":
			return float(ctx.get("salience", 0.0))
		"context.time_of_day":
			return float(ctx.get("hour", 0))
		"context.guild_morale":
			return float(ctx.get("guild_morale", 50.0))
		"context.phase":
			return float(ctx.get("phase", 0))
		_:
			return null

# ==================== COURBES (valeur → [0,1]) ====================

static func apply_curve(value: Variant, curve: String, cons: Dictionary) -> float:
	match curve:
		"boolean":
			if value is bool:
				return 1.0 if value else 0.0
			return 1.0 if float(value) > 0.0 else 0.0
		"linear":
			return _linear(float(value), cons)
		"inverse":
			return 1.0 - _linear(float(value), cons)
		"gaussian":
			var center: float = float(cons.get("center", 50.0))
			var sigma: float = float(cons.get("sigma", 20.0))
			if sigma == 0.0:
				return 0.0
			var d: float = (float(value) - center) / sigma
			return exp(-0.5 * d * d)
		"threshold":
			return 1.0 if float(value) >= float(cons.get("t", 50.0)) else 0.0
		_:
			return 1.0

static func _linear(value: float, cons: Dictionary) -> float:
	var lo: float = float(cons.get("in_min", 0.0))
	var hi: float = float(cons.get("in_max", 100.0))
	if hi == lo:
		return 0.0
	return clampf((value - lo) / (hi - lo), 0.0, 1.0)

# ==================== TIRAGE SOFTMAX À TEMPÉRATURE ====================

static func softmax_weights(scores: Array, temperature: float) -> Array:
	## Convertit des scores en poids softmax (stabilisé par soustraction du max).
	## T→0 : greedy (le meilleur écrase) ; T grand : quasi-uniforme.
	var out: Array = []
	if scores.is_empty():
		return out
	var t: float = maxf(0.0001, temperature)
	var mx: float = -INF
	for s in scores:
		mx = maxf(mx, float(s))
	for s in scores:
		out.append(exp((float(s) - mx) / t))
	return out

static func softmax_sample(items: Array, scores: Array, temperature: float) -> Variant:
	## Tire un item proportionnellement à exp(score/T). Déterministe via GameRandom global.
	if items.is_empty():
		return null
	if items.size() == 1:
		return items[0]
	var weights: Array = softmax_weights(scores, temperature)
	return GameRandom.weighted_pick(items, weights)

# ==================== HELPERS MODÈLE ====================

static func _traits(m: Variant) -> Array:
	var t: Array = []
	if m == null:
		return t
	if m.tags_comportement is Array:
		t.append_array(m.tags_comportement)
	if m.tags_caches is Array:
		t.append_array(m.tags_caches)
	return t
