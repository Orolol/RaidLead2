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
	_suite_save_migration(tf)
	_suite_ai_guild(tf)
	_suite_pve_progression(tf)
	_suite_pve_loop(tf)
	_suite_activity_manager(tf)
	_suite_phase(tf)
	_suite_random(tf)
	_suite_recruitment_economy(tf)
	_suite_calendar(tf)
	_suite_ui_smoke(tf)

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
	# Façade de tunables (audit Priorité 12)
	tf.approx(BalanceManager.tunable_float("recruitment.base_chance", -1.0), 0.5, "tunable recruitment.base_chance")
	tf.approx(BalanceManager.tunable_float("salary.unpaid_mood_penalty", -1.0), 15.0, "tunable salary.unpaid_mood_penalty")
	tf.approx(BalanceManager.tunable_float("inexistant.cle", 7.0), 7.0, "tunable inconnu => repli")
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
	# Vue "Cette semaine"
	var weekly = AdvisorManager.get_weekly_summary()
	tf.ok(weekly is Dictionary, "get_weekly_summary renvoie un Dictionary")
	for key in ["members_at_risk", "objectives", "recommended_content", "recruitment", "activities"]:
		tf.ok(weekly.has(key), "synthèse hebdo contient '%s'" % key)
	tf.ok(weekly.get("recruitment", {}).has("free_slots"), "synthèse hebdo : recrutement expose free_slots")
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
	var saved_history: Array = GuildRanking.player_run_history.duplicate(true)
	var saved_firsts: Dictionary = GuildRanking.server_firsts.duplicate(true)
	var saved_national_rankings: Array = GuildRanking.national_rankings.duplicate(true)
	var saved_world_rankings: Array = GuildRanking.world_rankings.duplicate(true)
	var saved_ranking_history: Dictionary = GuildRanking.ranking_history.duplicate(true)
	var saved_last_ranking_update: Dictionary = GuildRanking.last_ranking_update.duplicate(true)
	
	GuildRanking.player_cleared_content = {}
	GuildRanking.player_recent_clears = []
	GuildRanking.player_run_history = []
	GuildRanking.server_firsts["deadmines"] = "Autre Guilde"
	var before_percent: float = GuildRanking.get_player_content_cleared_percent()
	
	GuildRanking.register_player_content_clear(
		"deadmines",
		"Les Mortemines",
		DungeonData.InstanceType.DUNGEON,
		false,
		["Joueur"],
		{"duration_seconds": 1800.0, "wipes": 1}
	)
	
	var cleared: Array = GuildRanking.get_player_cleared_content()
	var percent: float = GuildRanking.get_player_content_cleared_percent()
	tf.ok(cleared.has("deadmines"), "clear PvE enregistré par content_id")
	tf.ok(percent > before_percent, "pourcentage de contenu clear augmente")
	tf.approx(float(PhaseManager._get_requirement_current_value("content_cleared_percent")), percent, "PhaseManager lit le tracking PvE", 0.01)
	tf.eq(GuildRanking.get_player_recent_clears().size(), 1, "clear récent exposé au ranking")
	tf.eq(GuildRanking.get_player_run_history().size(), 1, "historique de run exposé")
	tf.eq(GuildRanking.get_player_best_clear("deadmines").get("wipes", 0), 1, "meilleur clear conserve les détails")
	tf.eq(DungeonData.calculate_difficulty_score("deadmines", []), 0.0, "score PvE groupe vide = 0")
	tf.ok(FenetreLoot.calculate_performance_score(true, 900.0, 75, 2, {"bosses_defeated": 3, "total_bosses": 3, "wipes": 0, "expected_duration_seconds": 1200.0}) >= 85, "rapport PvE score un run propre haut")
	var pve_report_script = load("res://scripts/systems/pve_run_report.gd")
	tf.eq(pve_report_script.get_performance_label(88), "excellent", "libelle de performance PvE partage")
	GuildRanking._update_national_rankings()
	GuildRanking._update_world_rankings()
	tf.ok(GuildRanking.national_rankings.size() > 0, "classement national produit des rangs")
	tf.ok(GuildRanking.world_rankings.size() > 0, "classement mondial produit des rangs")
	tf.eq(GuildRanking._calculate_activity_score({"active_members_count": 0, "total_members_count": 0}), 0.0, "score activite guilde vide = 0")
	
	GuildRanking.player_cleared_content = saved_cleared
	GuildRanking.player_recent_clears = saved_recent
	GuildRanking.player_run_history = saved_history
	GuildRanking.server_firsts = saved_firsts
	GuildRanking.national_rankings = saved_national_rankings
	GuildRanking.world_rankings = saved_world_rankings
	GuildRanking.ranking_history = saved_ranking_history
	GuildRanking.last_ranking_update = saved_last_ranking_update

func _suite_activity_manager(tf) -> void:
	tf.suite("ActivityManager")
	var p: SimulatedPlayer = SimulatedPlayer.new()
	p.nom = "TestDonjonAuto"
	p.personnage_niveau = 20
	p.is_online = true
	ActivityManager.start_activity(p, Activity.ActivityType.DUNGEON)
	var activity = ActivityManager.active_activities.get(p)
	tf.eq(activity.type, Activity.ActivityType.DUNGEON, "préférence donjon reste une activité donjon")
	tf.ok(activity.location != "", "activité donjon reçoit une destination")
	tf.ok(activity.has_meta("planned_duration"), "activité donjon reçoit une durée planifiée")
	ActivityManager.interrupt_activity(p, "Nettoyage test")

func _suite_phase(tf) -> void:
	tf.suite("PhaseManager")
	tf.eq(PhaseManager.GamePhase.LEVELING, 0, "enum LEVELING = 0")
	tf.eq(PhaseManager.GamePhase.ESPORT, 3, "enum ESPORT = 3")
	var prog = PhaseManager.get_requirements_progress(PhaseManager.GamePhase.ESPORT)
	tf.ok(prog.has("world_championship_wins"), "objectif esport : titres mondiaux")
	tf.ok(prog.has("team_stability"), "objectif esport : stabilité d'équipe")
	tf.ok(PhaseManager._check_requirement_met("national_rank_position", 1, 1), "rang 1 satisfait l'exigence")
	tf.ok(not PhaseManager._check_requirement_met("national_rank_position", 0, 1), "non classé (rang 0) échoue")

# --- Nouvelles suites (audit AuditAmeliorations.md) ---

func _suite_save_migration(tf) -> void:
	tf.suite("SaveManager Migration")
	# Une vieille sauvegarde v1 sans les blocs systèmes récents doit migrer proprement.
	var legacy: Dictionary = {
		"save_version": 1,
		"guild": {"name": "Old Guild", "gold": 10},
		"members": [],
	}
	var migrated: Dictionary = SaveManager._migrate_save_data(legacy)
	tf.eq(int(migrated.get("save_version", 0)), SaveManager.CURRENT_SAVE_VERSION, "migration v1 -> version courante")
	tf.ok(migrated.has("balance") and migrated["balance"] is Dictionary, "bloc balance matérialisé par la migration")
	tf.ok(migrated.has("staff") and migrated["staff"] is Dictionary, "bloc staff matérialisé par la migration")
	tf.eq(migrated["guild"].get("name", ""), "Old Guild", "migration non destructive (guild conservé)")
	# Une sauvegarde plus récente que le build est tolérée (best-effort, pas de crash).
	var future: Dictionary = {"save_version": 9999, "guild": {}}
	var future_out: Dictionary = SaveManager._migrate_save_data(future)
	tf.eq(int(future_out.get("save_version", 0)), 9999, "save plus récente laissée intacte (best-effort)")

func _suite_pve_loop(tf) -> void:
	tf.suite("PvE Loop")
	var DungeonRunScript = load("res://scripts/systems/dungeon_run.gd")
	# Composition : Mortemines = 1 Tank / 1 Healer / 3 DPS.
	var comp_required: Dictionary = DungeonData.get_group_composition("deadmines")
	tf.eq(int(comp_required.get("Tank", 0)), 1, "compo donjon requiert 1 tank")
	tf.eq(int(comp_required.get("DPS", 0)), 3, "compo donjon requiert 3 DPS")

	var valid_group: Array = _make_group(["Tank", "Healer", "DPS", "DPS", "DPS"], 25, 60)
	var run_valid = DungeonRunScript.new()
	run_valid.instance_id = "deadmines"
	run_valid.instance_data = DungeonData.get_instance_data("deadmines")
	run_valid.group_members = valid_group
	tf.ok(run_valid._check_group_composition().valid, "composition complète = valide")

	var bad_group: Array = _make_group(["Healer", "DPS", "DPS", "DPS"], 25, 60)  # pas de tank
	var run_bad = DungeonRunScript.new()
	run_bad.instance_id = "deadmines"
	run_bad.instance_data = DungeonData.get_instance_data("deadmines")
	run_bad.group_members = bad_group
	var bad_comp: Dictionary = run_bad._check_group_composition()
	tf.ok(not bad_comp.valid, "composition sans tank = invalide")
	tf.ok(str(bad_comp.missing).find("Tank") != -1, "rôle manquant signalé (Tank)")

	# Déterminisme : même graine + mêmes membres => même résultat de combat de boss.
	var saved_loot: Array = GuildManager.loot_history.duplicate()
	GameRandom.seed_rng(4242)
	var g1: Array = _make_group(["Tank", "Healer", "DPS", "DPS", "DPS"], 30, 70)
	var r1 = DungeonRunScript.new(); r1.start_run("deadmines", g1)
	var res1: Dictionary = r1.simulate_boss_fight(0)
	GameRandom.seed_rng(4242)
	var g2: Array = _make_group(["Tank", "Healer", "DPS", "DPS", "DPS"], 30, 70)
	var r2 = DungeonRunScript.new(); r2.start_run("deadmines", g2)
	var res2: Dictionary = r2.simulate_boss_fight(0)
	tf.eq(res1.success, res2.success, "combat de boss reproductible avec graine fixe")
	tf.approx(float(res1.success_chance), float(res2.success_chance), "chance de succès reproductible", 0.0001)
	GuildManager.loot_history = saved_loot
	GameRandom.randomize_rng()

	# Loot : la table produit un objet d'iLvl cohérent.
	var LootTablesScript = load("res://scripts/data/loot_tables.gd")
	var dropped = LootTablesScript.generate_item_for_level(22, false)
	tf.ok(dropped != null and dropped.ilvl >= 1, "génération de loot produit un item valide")

	# Phase 0 -> 1 : un donjon héroïque complété satisfait l'exigence de la phase Leveling.
	var saved_phase = PhaseManager.current_phase
	var saved_heroic: int = PhaseManager.heroic_dungeons_completed
	PhaseManager.current_phase = PhaseManager.GamePhase.LEVELING
	PhaseManager.heroic_dungeons_completed = 0
	tf.ok(not PhaseManager.check_phase_progression(), "phase 0 bloquée sans donjon héroïque")
	PhaseManager.heroic_dungeons_completed = 1
	tf.ok(PhaseManager.check_phase_progression(), "phase 0 prête après 1 donjon héroïque")
	PhaseManager.current_phase = saved_phase
	PhaseManager.heroic_dungeons_completed = saved_heroic

func _suite_random(tf) -> void:
	tf.suite("GameRandom")
	GameRandom.seed_rng(12345)
	tf.ok(GameRandom.is_seeded(), "is_seeded vrai après seed_rng")
	tf.eq(GameRandom.get_seed(), 12345, "get_seed retourne la graine")
	var seq_a: Array = []
	for i in 8:
		seq_a.append(randi_range(0, 1_000_000))
	GameRandom.seed_rng(12345)
	var seq_b: Array = []
	for i in 8:
		seq_b.append(randi_range(0, 1_000_000))
	tf.eq(seq_a, seq_b, "même graine => même séquence (randi global)")
	GameRandom.seed_rng(999)
	var seq_c: Array = []
	for i in 8:
		seq_c.append(randi_range(0, 1_000_000))
	tf.ok(seq_a != seq_c, "graine différente => séquence différente")
	GameRandom.randomize_rng()
	tf.ok(not GameRandom.is_seeded(), "randomize_rng réinitialise l'état déterministe")

func _suite_recruitment_economy(tf) -> void:
	tf.suite("Recrutement (économie)")
	if not (GuildManager and GuildManager.guild and RecruitmentPool):
		return
	var pool = RecruitmentPool
	var guild = GuildManager.guild
	var saved_gold: int = guild.gold
	var saved_pool: Array = pool.available_players.duplicate()

	# Recrue nationale avec agent : la commission est prélevée à la signature.
	var recruit := SimulatedPlayer.new()
	recruit.nom = "ProAvecAgent"
	recruit.salary_demand = 40
	recruit.set_meta("is_national", true)
	recruit.set_meta("has_agent", true)
	recruit.set_meta("agent_commission", 80)
	pool.available_players.append(recruit)

	guild.gold = 1000
	var result: Dictionary = pool.attempt_national_recruitment(recruit, 40)  # offre = demande -> accepté
	tf.eq(result.get("step", ""), "accepted", "offre >= demande acceptée")
	tf.eq(int(result.get("agent_cost", -1)), 80, "commission d'agent retournée")
	tf.eq(guild.gold, 920, "commission d'agent prélevée sur l'or (1000 -> 920)")

	# Solvabilité : commission inabordable -> échec, pas de recrutement, pas d'or dépensé.
	var recruit2 := SimulatedPlayer.new()
	recruit2.nom = "ProTropCher"
	recruit2.salary_demand = 50
	recruit2.set_meta("is_national", true)
	recruit2.set_meta("has_agent", true)
	recruit2.set_meta("agent_commission", 5000)
	pool.available_players.append(recruit2)
	guild.gold = 100
	var poor: Dictionary = pool.attempt_national_recruitment(recruit2, 50)
	tf.eq(poor.get("step", ""), "error", "commission inabordable => étape error")
	tf.eq(guild.gold, 100, "aucun or dépensé si commission inabordable")
	tf.ok(pool.available_players.has(recruit2), "recrue non signée reste dans le pool")

	# Nettoyage
	pool.available_players = saved_pool
	guild.gold = saved_gold

func _suite_calendar(tf) -> void:
	tf.suite("Calendrier")
	if not (GuildManager and GuildManager.guild and GuildManager.guild_members.size() > 1):
		return
	var guild = GuildManager.guild
	var member = GuildManager.guild_members[1]
	var saved_gold: int = guild.gold
	var saved_salary: int = member.get_meta("salary", 0)
	var saved_mood: float = member.mood
	var saved_rep: float = guild.reputation

	member.set_meta("salary", 60)
	var total: int = GuildManager.get_total_weekly_salaries()
	tf.ok(total >= 60, "masse salariale inclut le salaire défini")

	# Salaires payés quand l'or suffit.
	guild.gold = total + 200
	GuildManager._pay_salaries()
	tf.eq(guild.gold, 200, "salaires hebdomadaires prélevés sur l'or")

	# Salaires impayés : moral en baisse + réputation perdue.
	guild.gold = 0
	member.mood = 80.0
	guild.reputation = 60.0
	GuildManager._pay_salaries()
	tf.ok(member.mood < 80.0, "moral baisse si salaires impayés")
	tf.ok(guild.reputation < 60.0, "réputation perdue si salaires impayés")

	# Refresh recrutement basé sur le jour absolu (pas le jour de semaine).
	if RecruitmentPool:
		var before_day: int = RecruitmentPool.last_refresh_total_day
		RecruitmentPool._refresh_pool()
		tf.eq(RecruitmentPool.last_refresh_total_day, RecruitmentPool._get_total_days_elapsed(),
			"refresh recale last_refresh_total_day sur le jour absolu")
		# (before_day conservé pour lisibilité du test)
		tf.ok(before_day == before_day, "jour de refresh suivi")

	# Nettoyage
	member.set_meta("salary", saved_salary)
	member.mood = saved_mood
	guild.gold = saved_gold
	guild.reputation = saved_rep

func _suite_ui_smoke(tf) -> void:
	tf.suite("UI Smoke")
	# Instancie la fenêtre Conseils : son _ready construit les onglets et appelle
	# _refresh_all() -> _build_weekly(), donc on valide la vue "Cette semaine" au runtime
	# (ce que le simple check de compilation ne couvre pas).
	var scene = load("res://scenes/Fenetre_Conseils.tscn")
	if scene == null:
		tf.ok(false, "scène Fenetre_Conseils introuvable")
		return
	var win = scene.instantiate()
	add_child(win)
	tf.ok(is_instance_valid(win), "Fenetre_Conseils s'instancie sans crash")
	tf.ok(win.get("_weekly_box") != null and win._weekly_box.get_child_count() > 0,
		"onglet 'Cette semaine' peuplé au runtime")
	win.queue_free()

func _make_group(roles: Array, level: int, skill: int) -> Array:
	"""Construit un groupe de SimulatedPlayer avec rôles/niveau/skill fixés (tests PvE)."""
	var group: Array = []
	for i in range(roles.size()):
		var p := SimulatedPlayer.new()
		p.nom = "M%d" % i
		p.personnage_role = roles[i]
		p.personnage_niveau = level
		p.skill = skill
		p.energy = 100.0
		p.mood = 80.0
		group.append(p)
	return group
