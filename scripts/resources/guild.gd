class_name Guild
extends Resource
const Singletons = preload("res://scripts/utils/singletons.gd")

@export var name: String = "Ma Guilde"
@export var xp: int = 0
@export var gold: int = 0
@export var bank_items: Array = []
@export var reputation: float = 50.0  # Réputation de base (0-100)
@export var reputation_history: Array = []  # Historique des événements de réputation

# Système d'effets
@export var active_effects: Array = []  # Array[EffectInstance] - duck typing pour éviter dépendance circulaire

signal xp_gained(amount: int, source: String)
signal level_up(new_level: int)
signal perk_unlocked(perk_name: String, level: int)
signal reputation_changed(old_reputation: float, new_reputation: float, reason: String)

func _init():
	name = "Ma Guilde"
	xp = 0
	gold = 0
	bank_items = []
	reputation = 50.0
	reputation_history = []

func gain_xp(amount: int, source: String = "") -> void:
	var old_level = get_level()
	xp += amount
	xp_gained.emit(amount, source)
	
	var new_level = get_level()
	if new_level > old_level:
		level_up.emit(new_level)
		if new_level in GuildPerksData.PERKS:
			var perk = GuildPerksData.PERKS[new_level]
			perk_unlocked.emit(perk["name"], new_level)

func get_level() -> int:
	return GuildPerksData.get_level_from_xp(xp)

func get_xp_progress() -> Dictionary:
	return GuildPerksData.get_xp_progress(xp)

func get_active_perks() -> Array:
	return GuildPerksData.get_active_perks(get_level())

func get_guild_effects() -> Dictionary:
	return GuildPerksData.get_combined_effects(get_level())

func can_recruit() -> bool:
	return get_guild_effects()["can_recruit"]

func get_max_members() -> int:
	return get_guild_effects()["max_members"]

func has_farming() -> bool:
	return get_guild_effects()["unlock_farming"]

func get_integration_bonus() -> float:
	return get_guild_effects()["integration_bonus"]

func get_raid_success_bonus() -> float:
	return get_guild_effects()["raid_success_bonus"]

func get_loot_conflict_reduction() -> float:
	return get_guild_effects()["loot_conflict_reduction"]

func get_recruitment_pool_bonus() -> int:
	return get_guild_effects()["recruitment_pool_bonus"]

func get_availability_bonus() -> float:
	return get_guild_effects()["availability_bonus"]

func get_recruitment_quality_bonus() -> float:
	return get_guild_effects()["recruitment_quality_bonus"]

func add_gold(amount: int) -> void:
	var max_gold = get_guild_effects()["gold_storage"]
	if max_gold > 0:
		var new_gold: int = gold + amount
		if new_gold > max_gold:
			_notify_gold_overflow(new_gold - max_gold, max_gold)
			gold = max_gold
		else:
			gold = new_gold
	else:
		# Avant le palier de stockage (bas niveau), trésorerie non plafonnée.
		gold += amount

func _notify_gold_overflow(lost: int, cap: int) -> void:
	"""Signale (best-effort) l'or perdu par débordement de la trésorerie."""
	if lost <= 0:
		return
	var nm = Singletons.get_autoload("NotificationManager")
	if nm and nm.has_method("show_warning"):
		nm.show_warning("Trésorerie pleine (%d or) : %d or perdus. Montez le niveau de guilde pour agrandir le stockage." % [cap, lost], "Stockage d'or")

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		return true
	return false

func add_item_to_bank(item: Dictionary) -> void:
	bank_items.append(item)

# Méthodes pour le système d'effets
func get_modified_stat(stat_name: String, base_value: float) -> float:
	var effect_system = Singletons.get_autoload("EffectSystem")
	if not effect_system:
		return base_value
	
	var flat_modifier = effect_system.get_stat_modifier(self, stat_name)
	var percentage_modifier = effect_system.get_percentage_modifier(self, stat_name)
	
	var modified_value = base_value + flat_modifier
	modified_value *= (1.0 + percentage_modifier / 100.0)
	
	return modified_value

func get_modified_gold() -> int:
	return int(get_modified_stat("gold", float(gold)))

func get_modified_xp() -> int:
	return int(get_modified_stat("xp", float(xp)))

func has_effect(effect_id: String) -> bool:
	var effect_system = Singletons.get_autoload("EffectSystem")
	if not effect_system:
		return false
	return effect_system.has_effect(self, effect_id)

func get_effects() -> Array:
	var effect_system = Singletons.get_autoload("EffectSystem")
	if not effect_system:
		return []
	return effect_system.get_effects(self)

func get_effective_max_members() -> int:
	return int(get_modified_stat("max_members", float(get_max_members())))

func get_effective_recruitment_pool_bonus() -> int:
	return int(get_modified_stat("recruitment_pool_bonus", float(get_recruitment_pool_bonus())))

func get_effective_raid_success_bonus() -> float:
	return get_modified_stat("raid_success_bonus", get_raid_success_bonus())

func get_effective_integration_bonus() -> float:
	return get_modified_stat("integration_bonus", get_integration_bonus())

func get_effective_reputation() -> float:
	return get_modified_stat("reputation", reputation)

# === SYSTÈME DE RÉPUTATION ===

func get_reputation() -> float:
	return reputation

func get_reputation_tier() -> String:
	"""Retourne le niveau de réputation sous forme de texte"""
	if reputation >= 90:
		return "Légendaire"
	elif reputation >= 80:
		return "Excellente"
	elif reputation >= 70:
		return "Très bonne"
	elif reputation >= 60:
		return "Bonne"
	elif reputation >= 40:
		return "Correcte"
	elif reputation >= 30:
		return "Médiocre"
	elif reputation >= 20:
		return "Mauvaise"
	else:
		return "Désastreuse"
func gain_reputation(amount: float, reason: String) -> void:
	"""Augmente la réputation de la guilde"""
	var old_reputation = reputation
	reputation = clamp(reputation + amount, 0.0, 100.0)
	
	_add_reputation_event(amount, reason)
	reputation_changed.emit(old_reputation, reputation, reason)
	
	GameLog.d("Réputation: +%.1f (%s) - Nouvelle réputation: %.1f (%s)" % [amount, reason, reputation, get_reputation_tier()])

func lose_reputation(amount: float, reason: String) -> void:
	"""Diminue la réputation de la guilde"""
	var old_reputation = reputation
	reputation = clamp(reputation - amount, 0.0, 100.0)
	
	_add_reputation_event(-amount, reason)
	reputation_changed.emit(old_reputation, reputation, reason)
	
	GameLog.d("Réputation: -%.1f (%s) - Nouvelle réputation: %.1f (%s)" % [amount, reason, reputation, get_reputation_tier()])

func _add_reputation_event(change: float, reason: String) -> void:
	"""Ajoute un événement à l'historique de réputation"""
	var game_time = Singletons.get_autoload("GameTime")
	var current_date = {}
	if game_time:
		current_date = {
			"year": game_time.current_year,
			"week": game_time.current_week,
			"day": game_time.current_day
		}
	else:
		current_date = {"year": 1, "week": 1, "day": 1}
	
	var event = {
		"date": current_date,
		"change": change,
		"reason": reason,
		"reputation_after": reputation
	}
	
	reputation_history.append(event)
	
	# Garder seulement les 50 derniers événements
	if reputation_history.size() > 50:
		reputation_history.pop_front()

func get_reputation_history() -> Array:
	"""Retourne l'historique de réputation (copie)"""
	return reputation_history.duplicate()

func get_recent_reputation_events(count: int = 10) -> Array:
	"""Retourne les X derniers événements de réputation"""
	var recent_events = reputation_history.duplicate()
	recent_events.reverse()  # Plus récent en premier
	return recent_events.slice(0, min(count, recent_events.size()))

func get_recruitment_reputation_bonus() -> float:
	"""Calcule le bonus de réputation pour le recrutement"""
	# La réputation affecte les chances d'acceptation des recrues
	# 50 = neutre (0%), 100 = +50% de chances, 0 = -50% de chances
	return (reputation - 50.0) * 0.01  # Convertir en pourcentage

func get_reputation_recruitment_multiplier() -> float:
	"""Retourne le multiplicateur de recrutement basé sur la réputation"""
	return 1.0 + get_recruitment_reputation_bonus()

# Méthodes d'événements de réputation prédéfinis

func on_server_first(achievement_name: String) -> void:
	"""Appelé lors d'un server first"""
	gain_reputation(15.0, "Server First: " + achievement_name)

func on_world_first(achievement_name: String) -> void:
	"""Appelé lors d'un world first"""
	gain_reputation(25.0, "World First: " + achievement_name)

func on_successful_recruitment(player_name: String, player_skill: float) -> void:
	"""Appelé lors d'un recrutement réussi"""
	var reputation_gain = 2.0
	if player_skill > 80:
		reputation_gain = 5.0  # Recrutement de qualité
	elif player_skill > 60:
		reputation_gain = 3.0
	
	gain_reputation(reputation_gain, "Recrutement réussi: " + player_name)

func on_member_departure(player_name: String, was_voluntary: bool) -> void:
	"""Appelé lors du départ d'un membre"""
	if was_voluntary:
		lose_reputation(1.0, "Départ volontaire: " + player_name)
	else:
		lose_reputation(3.0, "Renvoi de membre: " + player_name)

func on_raid_success(raid_name: String, difficulty: String) -> void:
	"""Appelé lors d'un succès de raid"""
	var reputation_gain = 2.0
	if difficulty == "Héroïque":
		reputation_gain = 4.0
	elif difficulty == "Mythique":
		reputation_gain = 6.0
	
	gain_reputation(reputation_gain, "Succès de raid: " + raid_name + " (" + difficulty + ")")

func on_raid_failure(raid_name: String, wipe_count: int) -> void:
	"""Appelé lors d'un échec de raid"""
	if wipe_count >= 10:
		lose_reputation(3.0, "Échec de raid répété: " + raid_name)
	elif wipe_count >= 5:
		lose_reputation(1.5, "Difficultés en raid: " + raid_name)

func on_drama_event(drama_type: String, severity: String) -> void:
	"""Appelé lors d'un événement de drama"""
	var reputation_loss = 5.0
	if severity == "Majeur":
		reputation_loss = 10.0
	elif severity == "Mineur":
		reputation_loss = 2.0
	
	lose_reputation(reputation_loss, "Drama " + severity.to_lower() + ": " + drama_type)

func on_team_stability_bonus() -> void:
	"""Appelé mensuellement pour la stabilité d'équipe"""
	gain_reputation(1.0, "Stabilité d'équipe")

func on_high_turnover_penalty(turnover_rate: float) -> void:
	"""Appelé en cas de turnover élevé"""
	var penalty = turnover_rate * 5.0  # Plus le turnover est élevé, plus la pénalité est importante
	lose_reputation(penalty, "Turnover élevé (%.1f%%)" % (turnover_rate * 100))
