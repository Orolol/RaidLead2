extends Node

## Harnais de tests automatisés (Milestone 6, US 6.5).
##
## Lancer en headless (scène principale, autoloads disponibles) :
##   Godot_v4.6.2-stable_win64_console.exe --headless --path . res://tests/TestRunner.tscn
## Ou dans l'éditeur via le MCP (play_scene). Code de sortie : 0 si tout passe, 1 sinon.

func _ready() -> void:
	# Laisser une frame aux autoloads (et à leurs call_deferred) pour s'initialiser.
	await get_tree().process_frame
	_run_all()

func _run_all() -> void:
	var TF = load("res://tests/test_framework.gd")
	var tf = TF.new()

	_suite_time(tf)
	_suite_item_equipment(tf)
	_suite_player(tf)
	_suite_balance(tf)
	_suite_advisor(tf)
	_suite_save(tf)
	_suite_ai_guild(tf)
	_suite_pve_progression(tf)
	_suite_phase(tf)

	print("\n========== RAIDLEAD - TESTS AUTOMATISES ==========")
	print(tf.summary())
	print("==================================================")
	get_tree().quit(1 if tf.failed > 0 else 0)

# --- Suites ---

func _suite_time(tf) -> void:
	tf.suite("GameTime")
	var saved: Dictionary = GameTime.save_time_data()
	var saved_paused: bool = GameTime.is_paused
	var saved_accumulated: float = GameTime.accumulated_time

	GameTime.current_year = 1
	GameTime.current_week = 1
	GameTime.current_day = 1
	tf.eq(GameTime.get_total_days_elapsed(), 0, "jour initial = 0")

	GameTime.current_year = 1
	GameTime.current_week = 2
	GameTime.current_day = 1
	tf.eq(GameTime.get_total_days_elapsed(), 7, "semaine 2 commence au jour absolu 7")

	GameTime.current_year = 2
	GameTime.current_week = 1
	GameTime.current_day = 1
	tf.eq(GameTime.get_total_days_elapsed(), 364, "annee 2 commence apres 52 semaines")

	GameTime.load_time_data(saved)
	GameTime.is_paused = saved_paused
	GameTime.accumulated_time = saved_accumulated

func _suite_item_equipment(tf) -> void:
	tf.suite("Item/Equipment")
	var helm = Item.new("Casque test", Item.EquipmentSlot.HELMET, 10, Item.Rarity.RARE, 5, 0, 0)
	tf.eq(helm.ilvl, 10, "Item ilvl conservé")
	tf.eq(helm.strength, 5, "Item FOR conservé")
	tf.eq(helm.get_slot_name(), "Casque", "Nom de slot")
	var chest = Item.new("Armure test", Item.EquipmentSlot.CHEST, 20, Item.Rarity.EPIC, 8, 0, 0)
	# Equipment vierge (SimulatedPlayer.new() arrive avec un équipement de départ).
	var eq = Equipment.new()
	eq.equip_item(helm)
	eq.equip_item(chest)
	tf.eq(eq.get_total_ilvl(), 30, "iLvl total = somme des slots")
	var stats = eq.get_total_stats()
	tf.eq(int(stats.get("strength", 0)), 13, "FOR cumulée des 2 pièces")

func _suite_player(tf) -> void:
	tf.suite("SimulatedPlayer")
	var p = SimulatedPlayer.new()
	p.stress_level = 0.0
	p.add_stress(30.0)
	tf.approx(p.stress_level, 30.0, "add_stress")
	p.add_stress(200.0)
	tf.approx(p.stress_level, 100.0, "add_stress plafonné à 100")
	p.reduce_stress(1000.0)
	tf.approx(p.stress_level, 0.0, "reduce_stress plancher à 0")
	p.stress_level = 20.0
	tf.eq(p.get_stress_tier(), "Maîtrisé", "tier stress bas")
	p.stress_level = 85.0
	tf.eq(p.get_stress_tier(), "Critique", "tier stress critique")
	tf.between(p.get_burnout_risk(), 0.0, 1.0, "risque de burnout borné [0,1]")
	p.stress_level = 100.0
	tf.approx(p.get_esport_performance_factor(), 0.7, "perf esport au stress max", 0.01)
	p.stress_level = 20.0
	tf.approx(p.get_esport_performance_factor(), 1.0, "perf esport au stress bas", 0.01)
	tf.ok(typeof(p.get_role()) == TYPE_STRING, "get_role renvoie une String")

func _suite_balance(tf) -> void:
	tf.suite("BalanceManager")
	tf.eq(BalanceManager.DIFFICULTY_PRESETS.size(), 3, "3 presets de difficulté")
	BalanceManager.set_difficulty(BalanceManager.Difficulty.HARD)
	tf.eq(BalanceManager.get_difficulty(), BalanceManager.Difficulty.HARD, "set/get difficulté")
	BalanceManager.set_difficulty(BalanceManager.Difficulty.NORMAL)
	tf.between(BalanceManager.get_recruit_chance_mult(), 0.5, 1.8, "mult recrutement borné")
	BalanceManager.weeks_dominating = 0
	tf.approx(BalanceManager.get_ai_progression_mult(), 1.0, "progression IA Normal sans domination")
	BalanceManager.weeks_dominating = 4
	BalanceManager.last_dominance = 1.0
	BalanceManager.set_difficulty(BalanceManager.Difficulty.HARD)
	tf.ok(BalanceManager.get_ai_progression_mult() > 1.15, "rubber-band augmente la progression IA")
	BalanceManager.set_difficulty(BalanceManager.Difficulty.NORMAL)
	BalanceManager.weeks_dominating = 0
	if GuildManager and GuildManager.guild:
		var before = GuildManager.guild.gold
		BalanceManager._apply_catchup({"struggle": 0.8, "dominance": 0.0})
		tf.ok(GuildManager.guild.gold > before, "catch-up ajoute de l'or si struggle élevé")
	var data = BalanceManager.serialize()
	BalanceManager.set_difficulty(BalanceManager.Difficulty.RELAXED)
	BalanceManager.deserialize(data)
	tf.eq(BalanceManager.get_difficulty(), BalanceManager.Difficulty.NORMAL, "serialize/deserialize difficulté")

func _suite_advisor(tf) -> void:
	tf.suite("AdvisorManager")
	var advice = AdvisorManager.get_advice()
	tf.ok(advice is Array, "get_advice renvoie un Array")
	tf.ok(AdvisorManager.get_severity_label(AdvisorManager.Severity.ALERT) != "", "libellé de sévérité non vide")
	var sorted_ok = true
	for i in range(1, advice.size()):
		if int(advice[i - 1].get("severity", 0)) > int(advice[i].get("severity", 0)):
			sorted_ok = false
	tf.ok(sorted_ok, "conseils triés par priorité croissante")
	if GuildManager and GuildManager.guild and GuildManager.guild_members.size() > 1:
		var m = GuildManager.guild_members[1]
		m.set_meta("salary", 500)
		var saved_gold = GuildManager.guild.gold
		GuildManager.guild.gold = 0
		var has_alert = false
		for a in AdvisorManager.get_advice():
			if int(a.get("severity", 99)) == AdvisorManager.Severity.ALERT:
				has_alert = true
		tf.ok(has_alert, "alerte trésorerie quand salaires impayables")
		m.set_meta("salary", 0)
		GuildManager.guild.gold = saved_gold

func _suite_save(tf) -> void:
	tf.suite("SaveManager")
	var p = SimulatedPlayer.new()
	p.nom = "TestRoundTrip"
	p.personnage_niveau = 42
	p.stress_level = 55.0
	p.skill = 77
	var data = SaveManager._serialize_player(p)
	var p2 = SimulatedPlayer.new()
	SaveManager._deserialize_player(p2, data)
	tf.eq(p2.nom, "TestRoundTrip", "round-trip nom")
	tf.eq(p2.personnage_niveau, 42, "round-trip niveau")
	tf.approx(p2.stress_level, 55.0, "round-trip stress")
	tf.eq(p2.skill, 77, "round-trip skill")
	var cdata = GuildCultureManager.serialize()
	tf.ok(cdata.has("guild_morale"), "culture sérialise guild_morale")

func _suite_ai_guild(tf) -> void:
	tf.suite("AIGuild")
	var restored: AIGuild = AIGuild.new("Guilde Restaurée", AIGuild.Strategy.HARDCORE, false)
	tf.eq(restored.name, "Guilde Restaurée", "restauration conserve le nom sans génération")
	tf.eq(restored.ai_strategy, AIGuild.Strategy.HARDCORE, "restauration conserve la stratégie")
	tf.eq(restored.members.size(), 0, "restauration ne génère pas de membres temporaires")

func _suite_pve_progression(tf) -> void:
	tf.suite("PvE Progression")
	var saved_cleared: Dictionary = GuildRanking.player_cleared_content.duplicate(true)
	var saved_recent: Array = GuildRanking.player_recent_clears.duplicate(true)
	var saved_firsts: Dictionary = GuildRanking.server_firsts.duplicate(true)
	
	GuildRanking.player_cleared_content = {}
	GuildRanking.player_recent_clears = []
	GuildRanking.server_firsts["deadmines"] = "Autre Guilde"
	var before_percent: float = GuildRanking.get_player_content_cleared_percent()
	
	GuildRanking.register_player_content_clear(
		"deadmines",
		"Les Mortemines",
		DungeonData.InstanceType.DUNGEON,
		false,
		["Joueur"]
	)
	
	var cleared: Array = GuildRanking.get_player_cleared_content()
	var percent: float = GuildRanking.get_player_content_cleared_percent()
	tf.ok(cleared.has("deadmines"), "clear PvE enregistré par content_id")
	tf.ok(percent > before_percent, "pourcentage de contenu clear augmente")
	tf.approx(float(PhaseManager._get_requirement_current_value("content_cleared_percent")), percent, "PhaseManager lit le tracking PvE", 0.01)
	tf.eq(GuildRanking.get_player_recent_clears().size(), 1, "clear récent exposé au ranking")
	
	GuildRanking.player_cleared_content = saved_cleared
	GuildRanking.player_recent_clears = saved_recent
	GuildRanking.server_firsts = saved_firsts

func _suite_phase(tf) -> void:
	tf.suite("PhaseManager")
	tf.eq(PhaseManager.GamePhase.LEVELING, 0, "enum LEVELING = 0")
	tf.eq(PhaseManager.GamePhase.ESPORT, 3, "enum ESPORT = 3")
	var prog = PhaseManager.get_requirements_progress(PhaseManager.GamePhase.ESPORT)
	tf.ok(prog.has("world_championship_wins"), "objectif esport : titres mondiaux")
	tf.ok(prog.has("team_stability"), "objectif esport : stabilité d'équipe")
	tf.ok(PhaseManager._check_requirement_met("national_rank_position", 1, 1), "rang 1 satisfait l'exigence")
	tf.ok(not PhaseManager._check_requirement_met("national_rank_position", 0, 1), "non classé (rang 0) échoue")
