class_name GameRandom

## Utilitaires de probabilité centralisés.
## Remplace les appels `randf() < X` éparpillés dans le code.
##
## Déterminisme : les helpers ci-dessous s'appuient sur le générateur GLOBAL de Godot
## (les mêmes que `randf()`, `randi()`, `randf_range()`, `Array.pick_random()`,
## `Array.shuffle()`...). Appeler `GameRandom.seed_rng(graine)` fixe ce générateur
## global, ce qui rend reproductible TOUTE la simulation (pas seulement les appels
## passant par GameRandom). Les tests et scénarios E2E peuvent ainsi rejouer une
## séquence à l'identique ; une partie normale utilise `randomize_rng()`.

static var _current_seed: int = 0
static var _is_seeded: bool = false

static func seed_rng(new_seed: int) -> void:
	"""Fixe la graine du générateur global pour des séquences reproductibles."""
	_current_seed = new_seed
	_is_seeded = true
	seed(new_seed)

static func randomize_rng() -> void:
	"""Réinitialise le générateur global depuis l'entropie système (partie normale)."""
	_is_seeded = false
	_current_seed = 0
	randomize()

static func get_seed() -> int:
	"""Retourne la dernière graine fixée via seed_rng() (0 si non fixée)."""
	return _current_seed

static func is_seeded() -> bool:
	"""Vrai si une graine déterministe a été fixée via seed_rng()."""
	return _is_seeded

static func chance(probability: float) -> bool:
	"""Retourne true avec la probabilité donnée (0.0 à 1.0)."""
	return randf() < probability

static func chance_percent(percent: float) -> bool:
	"""Retourne true avec un pourcentage donné (0 à 100)."""
	return randf() < (percent / 100.0)

static func weighted_pick(options: Array, weights: Array):
	"""Choisit un élément basé sur des poids relatifs.
	Ex: weighted_pick(["a", "b"], [3.0, 1.0]) → 75% chance de "a"."""
	if options.is_empty() or weights.is_empty():
		return null

	var total_weight: float = 0.0
	for w in weights:
		total_weight += w

	var roll: float = randf() * total_weight
	var cumulative: float = 0.0
	for i in range(options.size()):
		cumulative += weights[i] if i < weights.size() else 0.0
		if roll < cumulative:
			return options[i]

	return options[-1]

static func range_float(min_val: float, max_val: float) -> float:
	"""Retourne un float aléatoire entre min et max."""
	return randf_range(min_val, max_val)

static func variance(base_value: float, variance_percent: float) -> float:
	"""Applique une variance en pourcentage à une valeur de base.
	Ex: variance(100.0, 20.0) → entre 80 et 120."""
	var delta: float = base_value * (variance_percent / 100.0)
	return randf_range(base_value - delta, base_value + delta)

static func pick_random(array: Array):
	"""Retourne un élément aléatoire d'un array, ou null si vide."""
	if array.is_empty():
		return null
	return array[randi() % array.size()]

static func shuffle(array: Array) -> Array:
	"""Retourne une copie mélangée de l'array."""
	var copy: Array = array.duplicate()
	copy.shuffle()
	return copy
