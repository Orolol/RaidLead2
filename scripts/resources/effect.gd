class_name Effect
extends Resource

enum EffectType {
	BUFF,
	DEBUFF,
	NEUTRAL
}

enum TargetType {
	PLAYER,
	GUILD,
	ALL_PLAYERS
}

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var duration: float = 0.0  # Durée en heures de jeu (0 = permanent)
@export var effect_type: EffectType = EffectType.NEUTRAL
@export var target_type: TargetType = TargetType.PLAYER
@export var can_stack: bool = false
@export var max_stacks: int = 1
@export var icon: Texture2D = null

# Modifications appliquées par l'effet
@export var stat_modifiers: Dictionary = {}  # stat_name -> modification
@export var percentage_modifiers: Dictionary = {}  # stat_name -> pourcentage

# Conditions pour maintenir l'effet
@export var maintain_conditions: Array = []  # Array[String]

# Effets spéciaux
@export var blocks_actions: Array = []  # Array[String] - Actions bloquées par l'effet
@export var enables_actions: Array = []  # Array[String] - Actions activées par l'effet

func _init() -> void:
	pass

func get_tooltip() -> String:
	var tooltip: String = "[b]%s[/b]\n%s" % [name, description]

	if duration > 0:
		tooltip += "\n[color=gray]Durée: %.1f heures[/color]" % duration
	else:
		tooltip += "\n[color=gray]Permanent[/color]"

	if can_stack and max_stacks > 1:
		tooltip += "\n[color=yellow]Peut se cumuler (max %d)[/color]" % max_stacks

	if stat_modifiers.size() > 0 or percentage_modifiers.size() > 0:
		tooltip += "\n[b]Effets:[/b]"

		for stat in stat_modifiers:
			var value = stat_modifiers[stat]
			var sign_str: String = "+" if value > 0 else ""
			tooltip += "\n  %s %s%s" % [stat, sign_str, str(value)]

		for stat in percentage_modifiers:
			var value = percentage_modifiers[stat]
			var sign_str: String = "+" if value > 0 else ""
			tooltip += "\n  %s %s%d%%" % [stat, sign_str, value]

	return tooltip

func is_compatible_with(other_effect: Effect) -> bool:
	# Deux effets sont compatibles s'ils peuvent coexister
	if id == other_effect.id:
		return can_stack
	
	# Logique personnalisée pour incompatibilités
	return true

func applies_to(target) -> bool:
	match target_type:
		TargetType.PLAYER:
			return target.has_method("get_role")  # SimulatedPlayer
		TargetType.GUILD:
			return target.has_method("get_level")  # Guild
		TargetType.ALL_PLAYERS:
			return target.has_method("get_role")  # SimulatedPlayer
		_:
			return false