class_name EffectsData
extends Resource

# Base de données des effets disponibles dans le jeu

const EffectResource = preload("res://scripts/resources/effect.gd")

static func get_all_effects() -> Array:
	var effects: Array = []
	
	effects.append(_create_morale_boost())
	effects.append(_create_morale_penalty())
	effects.append(_create_energy_boost())
	effects.append(_create_energy_drain())
	effects.append(_create_skill_bonus())
	effects.append(_create_integration_bonus())
	effects.append(_create_guild_xp_bonus())
	effects.append(_create_recruitment_bonus())
	effects.append(_create_injured_member())
	effects.append(_create_lucky_streak())
	
	return effects

static func get_effect_by_id(effect_id: String) -> EffectResource:
	var all_effects = get_all_effects()
	
	for effect in all_effects:
		if effect.id == effect_id:
			return effect
	
	return null

# Effets individuels

static func _create_morale_boost() -> EffectResource:
	var effect = EffectResource.new()
	effect.id = "morale_boost"
	effect.name = "Moral élevé"
	effect.description = "Les membres de la guilde sont de bonne humeur et plus motivés."
	effect.duration = 48.0  # 48 heures
	effect.effect_type = EffectResource.EffectType.BUFF
	effect.target_type = EffectResource.TargetType.ALL_PLAYERS
	effect.can_stack = false
	
	effect.stat_modifiers = {
		"mood": 15.0,
		"energy": 10.0
	}
	
	return effect

static func _create_morale_penalty() -> EffectResource:
	var effect = EffectResource.new()
	effect.id = "morale_penalty"
	effect.name = "Moral bas"
	effect.description = "Un événement récent a affecté le moral de la guilde."
	effect.duration = 24.0  # 24 heures
	effect.effect_type = EffectResource.EffectType.DEBUFF
	effect.target_type = EffectResource.TargetType.ALL_PLAYERS
	effect.can_stack = false
	
	effect.stat_modifiers = {
		"mood": -20.0,
		"integration": -5.0
	}
	
	return effect

static func _create_energy_boost() -> EffectResource:
	var effect = EffectResource.new()
	effect.id = "energy_boost"
	effect.name = "Regain d'énergie"
	effect.description = "Les membres récupèrent plus rapidement leur énergie."
	effect.duration = 72.0  # 72 heures
	effect.effect_type = EffectResource.EffectType.BUFF
	effect.target_type = EffectResource.TargetType.ALL_PLAYERS
	effect.can_stack = false
	
	effect.percentage_modifiers = {
		"energy": 25.0  # +25% d'énergie
	}
	
	return effect

static func _create_energy_drain() -> EffectResource:
	var effect = EffectResource.new()
	effect.id = "energy_drain"
	effect.name = "Épuisement"
	effect.description = "Les activités récentes ont épuisé les membres."
	effect.duration = 36.0  # 36 heures
	effect.effect_type = EffectResource.EffectType.DEBUFF
	effect.target_type = EffectResource.TargetType.ALL_PLAYERS
	effect.can_stack = false
	
	effect.stat_modifiers = {
		"energy": -25.0
	}
	
	return effect

static func _create_skill_bonus() -> EffectResource:
	var effect = EffectResource.new()
	effect.id = "skill_bonus"
	effect.name = "Formation intensive"
	effect.description = "Amélioration temporaire des compétences suite à une formation."
	effect.duration = 168.0  # 1 semaine
	effect.effect_type = EffectResource.EffectType.BUFF
	effect.target_type = EffectResource.TargetType.ALL_PLAYERS
	effect.can_stack = false
	
	effect.stat_modifiers = {
		"skill": 10.0
	}
	
	return effect

static func _create_integration_bonus() -> EffectResource:
	var effect = EffectResource.new()
	effect.id = "integration_bonus"
	effect.name = "Esprit d'équipe"
	effect.description = "Les membres s'entendent particulièrement bien."
	effect.duration = 120.0  # 5 jours
	effect.effect_type = EffectResource.EffectType.BUFF
	effect.target_type = EffectResource.TargetType.ALL_PLAYERS
	effect.can_stack = false
	
	effect.stat_modifiers = {
		"integration": 20.0
	}
	
	return effect

static func _create_guild_xp_bonus() -> EffectResource:
	var effect = EffectResource.new()
	effect.id = "guild_xp_bonus"
	effect.name = "Boost d'XP guilde"
	effect.description = "La guilde gagne plus d'expérience pendant un certain temps."
	effect.duration = 96.0  # 4 jours
	effect.effect_type = EffectResource.EffectType.BUFF
	effect.target_type = EffectResource.TargetType.GUILD
	effect.can_stack = false
	
	effect.percentage_modifiers = {
		"xp": 50.0  # +50% XP guilde
	}
	
	return effect

static func _create_recruitment_bonus() -> EffectResource:
	var effect = EffectResource.new()
	effect.id = "recruitment_bonus"
	effect.name = "Réputation attrayante"
	effect.description = "La guilde attire plus facilement de nouveaux membres."
	effect.duration = 336.0  # 2 semaines
	effect.effect_type = EffectResource.EffectType.BUFF
	effect.target_type = EffectResource.TargetType.GUILD
	effect.can_stack = false
	
	effect.stat_modifiers = {
		"recruitment_pool_bonus": 5.0,
		"recruitment_quality_bonus": 0.1
	}
	
	return effect

static func _create_injured_member() -> EffectResource:
	var effect = EffectResource.new()
	effect.id = "injured"
	effect.name = "Blessé"
	effect.description = "Ce membre est blessé et ne peut pas participer aux raids."
	effect.duration = 48.0  # 48 heures
	effect.effect_type = EffectResource.EffectType.DEBUFF
	effect.target_type = EffectResource.TargetType.PLAYER
	effect.can_stack = false
	
	effect.stat_modifiers = {
		"skill": -15.0,
		"energy": -30.0
	}
	
	effect.blocks_actions = ["raid", "dungeon"]
	
	return effect

static func _create_lucky_streak() -> EffectResource:
	var effect = EffectResource.new()
	effect.id = "lucky_streak"
	effect.name = "Série chanceuse"
	effect.description = "La guilde bénéficie d'une chance exceptionnelle."
	effect.duration = 24.0  # 24 heures
	effect.effect_type = EffectResource.EffectType.BUFF
	effect.target_type = EffectResource.TargetType.GUILD
	effect.can_stack = false
	
	effect.stat_modifiers = {
		"raid_success_bonus": 0.2,  # +20% de réussite aux raids
		"loot_conflict_reduction": 0.3  # -30% de conflits de loot
	}
	
	return effect