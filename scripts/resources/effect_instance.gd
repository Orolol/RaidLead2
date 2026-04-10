class_name EffectInstance
extends Resource

const EffectResource = preload("res://scripts/resources/effect.gd")

@export var effect: EffectResource = null
@export var remaining_duration: float = 0.0  # Durée restante en heures
@export var stack_count: int = 1
@export var source: String = ""  # Source de l'effet (événement, action, etc.)
@export var start_time: float = 0.0  # Timestamp de début
@export var target: Resource = null  # Référence vers la cible (SimulatedPlayer ou Guild)

signal expired(effect_instance: EffectInstance)
signal stack_changed(effect_instance: EffectInstance, new_count: int)

func _init(p_effect: EffectResource = null, p_source: String = "", p_target: Resource = null):
	if p_effect:
		effect = p_effect
		remaining_duration = p_effect.duration
		source = p_source
		target = p_target
		start_time = _get_game_time()

func update(delta_hours: float) -> void:
	if effect.duration <= 0.0:  # Effet permanent
		return
		
	remaining_duration -= delta_hours
	
	if remaining_duration <= 0.0:
		expired.emit(self)

func add_stack() -> bool:
	if not effect.can_stack:
		return false
		
	if stack_count >= effect.max_stacks:
		return false
		
	stack_count += 1
	stack_changed.emit(self, stack_count)
	return true

func remove_stack() -> bool:
	if stack_count <= 1:
		return false
		
	stack_count -= 1
	stack_changed.emit(self, stack_count)
	return true

func refresh_duration() -> void:
	remaining_duration = effect.duration
	start_time = _get_game_time()

func is_expired() -> bool:
	if effect.duration <= 0.0:  # Effet permanent
		return false
	return remaining_duration <= 0.0

func get_total_stat_modifier(stat_name: String) -> float:
	var base_value = effect.stat_modifiers.get(stat_name, 0.0)
	return base_value * stack_count

func get_total_percentage_modifier(stat_name: String) -> float:
	var base_value = effect.percentage_modifiers.get(stat_name, 0.0)
	return base_value * stack_count

func get_remaining_time_string() -> String:
	if effect.duration <= 0.0:
		return "Permanent"
	
	if remaining_duration < 1.0:
		return "%.0f min" % (remaining_duration * 60)
	else:
		return "%.1f h" % remaining_duration

func get_tooltip() -> String:
	var tooltip = effect.get_tooltip()
	
	if stack_count > 1:
		tooltip += "\n[color=yellow]Cumul: x%d[/color]" % stack_count
	
	if not is_expired() and effect.duration > 0.0:
		tooltip += "\n[color=gray]Temps restant: %s[/color]" % get_remaining_time_string()
	
	if source != "":
		tooltip += "\n[color=gray]Source: %s[/color]" % source
	
	return tooltip

func _get_game_time() -> float:
	var game_time = Engine.get_singleton("GameTime")
	if game_time:
		return game_time.get_current_timestamp()
	return 0.0