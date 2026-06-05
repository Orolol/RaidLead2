extends Node

# Gestionnaire central des effets actifs sur les joueurs et guildes

const EffectInstanceResource = preload("res://scripts/resources/effect_instance.gd")
const EffectResource = preload("res://scripts/resources/effect.gd")

var active_effects: Dictionary = {}  # target_id -> Array[EffectInstanceResource]
# Callables des lambdas connectées par instance, pour pouvoir déconnecter
# exactement le même Callable. instance -> { "expired": Callable, "stack_changed": Callable }
var _effect_callables: Dictionary = {}

signal effect_applied(target, effect_instance: EffectInstanceResource)
signal effect_removed(target, effect_instance: EffectInstanceResource)
signal effect_expired(target, effect_instance: EffectInstanceResource)
signal effect_stack_changed(target, effect_instance: EffectInstanceResource, new_count: int)

func _ready() -> void:
	# S'abonner aux signaux de GameTime pour mettre à jour les effets
	var game_time = GameTime
	if game_time:
		game_time.hour_changed.connect(_on_hour_changed)

func _on_hour_changed(_hour: int) -> void:
	update_all_effects(1.0)  # 1 heure s'est écoulée

func update_all_effects(delta_hours: float) -> void:
	for target_id in active_effects.keys():
		var effects_list: Array = active_effects[target_id]
		var expired_effects: Array = []

		for effect_instance in effects_list:
			effect_instance.update(delta_hours)
			if effect_instance.is_expired():
				expired_effects.append(effect_instance)
		
		# Supprimer les effets expirés
		for expired in expired_effects:
			_remove_effect_internal(target_id, expired, true)

func apply_effect(target, effect: EffectResource, source: String = "") -> EffectInstanceResource:
	if not effect or not target:
		return null
	
	if not effect.applies_to(target):
		GameLog.d("Effet %s ne peut pas être appliqué à %s" % [effect.name, target])
		return null
	
	var target_id: String = _get_target_id(target)

	# Vérifier si l'effet existe déjà
	var existing_effect: EffectInstanceResource = get_effect_by_id(target, effect.id)

	if existing_effect:
		if effect.can_stack:
			if existing_effect.add_stack():
				effect_stack_changed.emit(target, existing_effect, existing_effect.stack_count)
				return existing_effect
			else:
				# Max stacks atteint, rafraîchir la durée
				existing_effect.refresh_duration()
				return existing_effect
		else:
			# Effet non stackable, rafraîchir la durée
			existing_effect.refresh_duration()
			return existing_effect
	
	# Créer une nouvelle instance de l'effet
	var effect_instance: EffectInstanceResource = EffectInstanceResource.new(effect, source, target)
	# Connexion via lambdas à signature exacte (le signal émet l'instance émettrice ;
	# on capture target_id / target pour les handlers internes).
	var expired_cb: Callable = func(emitted_inst: EffectInstanceResource) -> void:
		_on_effect_expired(target_id, emitted_inst)
	var stack_changed_cb: Callable = func(emitted_inst: EffectInstanceResource, new_count: int) -> void:
		_on_effect_stack_changed(target, emitted_inst, new_count)
	effect_instance.expired.connect(expired_cb)
	effect_instance.stack_changed.connect(stack_changed_cb)
	_effect_callables[effect_instance] = {
		"expired": expired_cb,
		"stack_changed": stack_changed_cb,
	}
	
	# Ajouter à la liste des effets actifs
	if not active_effects.has(target_id):
		active_effects[target_id] = []
	
	active_effects[target_id].append(effect_instance)
	
	# Notifier l'application de l'effet
	effect_applied.emit(target, effect_instance)
	
	GameLog.d("Effet appliqué: %s sur %s (source: %s)" % [effect.name, target_id, source])
	
	return effect_instance

func remove_effect(target, effect_id: String) -> bool:
	var target_id: String = _get_target_id(target)

	if not active_effects.has(target_id):
		return false

	var effects_list: Array = active_effects[target_id]

	for i in range(effects_list.size()):
		var effect_instance = effects_list[i]
		if effect_instance.effect.id == effect_id:
			return _remove_effect_internal(target_id, effect_instance, false)

	return false

func remove_effect_instance(target, effect_instance: EffectInstanceResource) -> bool:
	var target_id: String = _get_target_id(target)
	return _remove_effect_internal(target_id, effect_instance, false)

func reset_all() -> void:
	"""Vide complètement l'état du système : déconnecte les signaux des instances
	encore actives et purge active_effects ET _effect_callables. Utilisé au chargement
	d'une sauvegarde pour repartir d'un état propre sans fuir les Callables des effets
	créés au boot (un simple active_effects.clear() laisserait _effect_callables orphelin)."""
	for effect_instance in _effect_callables.keys():
		var callables: Dictionary = _effect_callables[effect_instance]
		var expired_cb: Callable = callables["expired"]
		var stack_changed_cb: Callable = callables["stack_changed"]
		if effect_instance.expired.is_connected(expired_cb):
			effect_instance.expired.disconnect(expired_cb)
		if effect_instance.stack_changed.is_connected(stack_changed_cb):
			effect_instance.stack_changed.disconnect(stack_changed_cb)
	_effect_callables.clear()
	active_effects.clear()

func _remove_effect_internal(target_id: String, effect_instance: EffectInstanceResource, is_expired: bool) -> bool:
	if not active_effects.has(target_id):
		return false
	
	var effects_list: Array = active_effects[target_id]
	var index: int = effects_list.find(effect_instance)

	if index == -1:
		return false
	
	effects_list.remove_at(index)
	
	# Si plus d'effets, supprimer la clé
	if effects_list.is_empty():
		active_effects.erase(target_id)
	
	# Déconnecter les signaux : on déconnecte exactement les Callables stockés
	# à la connexion (les lambdas), sinon la déconnexion échoue silencieusement.
	if _effect_callables.has(effect_instance):
		var callables: Dictionary = _effect_callables[effect_instance]
		var expired_cb: Callable = callables["expired"]
		var stack_changed_cb: Callable = callables["stack_changed"]
		if effect_instance.expired.is_connected(expired_cb):
			effect_instance.expired.disconnect(expired_cb)
		if effect_instance.stack_changed.is_connected(stack_changed_cb):
			effect_instance.stack_changed.disconnect(stack_changed_cb)
		_effect_callables.erase(effect_instance)
	
	# Notifier la suppression
	var target = effect_instance.target
	if is_expired:
		effect_expired.emit(target, effect_instance)
	else:
		effect_removed.emit(target, effect_instance)
	
	GameLog.d("Effet supprimé: %s de %s" % [effect_instance.effect.name, target_id])
	
	return true

func get_effects(target) -> Array:
	var target_id: String = _get_target_id(target)

	if not active_effects.has(target_id):
		return []

	return active_effects[target_id].duplicate()

func get_effect_by_id(target, effect_id: String) -> EffectInstanceResource:
	var target_id: String = _get_target_id(target)

	if not active_effects.has(target_id):
		return null
	
	for effect_instance in active_effects[target_id]:
		if effect_instance.effect.id == effect_id:
			return effect_instance
	
	return null

func has_effect(target, effect_id: String) -> bool:
	return get_effect_by_id(target, effect_id) != null

func get_stat_modifier(target, stat_name: String) -> float:
	var total_modifier: float = 0.0

	for effect_instance in get_effects(target):
		total_modifier += effect_instance.get_total_stat_modifier(stat_name)

	return total_modifier

func get_percentage_modifier(target, stat_name: String) -> float:
	var total_modifier: float = 0.0

	for effect_instance in get_effects(target):
		total_modifier += effect_instance.get_total_percentage_modifier(stat_name)

	return total_modifier

func clear_effects(target) -> void:
	var target_id: String = _get_target_id(target)

	if not active_effects.has(target_id):
		return

	var effects_to_remove: Array = active_effects[target_id].duplicate()

	for effect_instance in effects_to_remove:
		_remove_effect_internal(target_id, effect_instance, false)

func _get_target_id(target) -> String:
	if target.has_method("get_role"):  # SimulatedPlayer
		return "player_" + target.nom
	elif target.has_method("get_level"):  # Guild
		return "guild_" + target.name
	else:
		return str(target.get_instance_id())

func _on_effect_expired(target_id: String, effect_instance: EffectInstanceResource) -> void:
	_remove_effect_internal(target_id, effect_instance, true)

func _on_effect_stack_changed(target, effect_instance: EffectInstanceResource, new_count: int) -> void:
	effect_stack_changed.emit(target, effect_instance, new_count)
