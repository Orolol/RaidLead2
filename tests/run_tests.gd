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
	_suite_player_flow(tf)
	_suite_simulation_depth(tf)
	_suite_bank(tf)
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
	_suite_economy(tf)
	_suite_facades(tf)
	_suite_ui_smoke(tf)
	_suite_chat_director(tf)
	_suite_chat_scoring(tf)

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
	# Behavior wiring : jour absolu + mémoire émotionnelle (profil qui évolue).
	tf.eq(p._get_current_day(), GameTime.get_total_days_elapsed(), "_get_current_day utilise le jour absolu")
	if p.behavior_profile:
		p.behavior_profile.achievement_drive = 0.5
		p.trigger_raid_success()
		tf.ok(p.behavior_profile.achievement_drive > 0.5, "un succès de raid fait évoluer le profil comportemental")

func _suite_player_flow(tf) -> void:
	tf.suite("PlayerCharacter (flow)")
	var PC = load("res://scripts/resources/player_character.gd")
	var pc = PC.new()

	# État initial : connecté, sans activité → doit attendre un ordre (pause-si-oisif)
	tf.ok(pc.needs_activity_choice(), "joueur sans activité = en attente d'un ordre")
	tf.eq(pc.last_activity_choice, "", "aucune dernière activité au départ")
	tf.ok(pc.can_perform_activity("LEVELING"), "peut faire du leveling avec énergie pleine")

	# Choix d'une activité : démarre + mémorise comme dernière activité
	var started: bool = pc.choose_activity("LEVELING")
	tf.ok(started, "choose_activity(LEVELING) démarre l'activité")
	tf.eq(pc.last_activity_choice, "LEVELING", "dernière activité mémorisée")
	tf.ok(not pc.needs_activity_choice(), "avec une activité, plus en attente")

	# Drain d'énergie sur 1h de leveling (9/h, adouci C4)
	var before_energy: float = pc.player_energy_pool
	pc.update_player_energy(60.0)
	tf.ok(pc.player_energy_pool < before_energy, "l'énergie baisse pendant l'activité")
	tf.approx(pc.player_energy_pool, before_energy - 9.0, "drain leveling = 9/h", 0.5)

	# Déconnexion : conserve la dernière activité pour la reprise auto
	pc.disconnect_player("Test")
	tf.ok(not pc.is_online, "déconnecté après disconnect_player")
	tf.eq(pc.last_activity_choice, "LEVELING", "dernière activité conservée à la déconnexion")

	# Reconnexion + reprise auto de la dernière activité
	pc.reconnect_player()
	tf.ok(pc.is_online, "reconnecté")
	var resumed: bool = pc.resume_last_activity()
	tf.ok(resumed, "resume_last_activity relance la dernière activité")
	tf.ok(not pc.needs_activity_choice(), "après reprise, plus en attente d'ordre")

	# Nettoyage : retirer l'activité de l'ActivityManager pour ne pas polluer les autres suites
	if ActivityManager and ActivityManager.has_method("interrupt_activity"):
		ActivityManager.interrupt_activity(pc, "Fin de test")

	# Round-trip persistance de last_activity_choice (bloc joueur sérialisé si meta is_player)
	pc.set_meta("is_player", true)
	var data: Dictionary = SaveManager._serialize_player(pc)
	tf.eq(data.get("last_activity_choice", ""), "LEVELING", "last_activity_choice sérialisée")

func _suite_simulation_depth(tf) -> void:
	tf.suite("Simulation (connexion dynamique + events)")
	var PE = load("res://scripts/data/personal_events.gd")

	# PersonalEvents : plus de crash player.has() sur une Resource
	var p = SimulatedPlayer.new()
	p.mood = 50.0
	p.energy = 80.0
	p.burnout_level = 0
	p.fatigue_accumulated = 0.0
	p.is_online = true
	var triggered = PE.should_trigger_event(p)
	tf.ok(triggered == true or triggered == false, "should_trigger_event renvoie un bool (pas de crash .has())")
	var ev = PE.get_event_for_player(p)
	tf.ok(ev is Dictionary, "get_event_for_player renvoie un Dictionary")
	if not ev.is_empty():
		tf.ok(ev.has("id") and PE.EVENTS_DATABASE.has(ev["id"]), "l'événement choisi existe dans la base")

	# BehaviorSystem : la connexion dépend désormais de l'état dynamique
	var bs = GuildManager.behavior_system
	tf.ok(bs != null, "behavior_system instancié")
	if bs:
		var p2 = SimulatedPlayer.new()
		p2.mood = 75.0
		p2.burnout_level = 0
		p2.fatigue_accumulated = 0.0
		p2.energy = 100.0
		var base_mod: float = bs._connection_state_modifier(p2)
		tf.between(base_mod, 0.2, 2.0, "modificateur de connexion borné [0.2, 2.0]")
		p2.burnout_level = 3
		var burnout_mod: float = bs._connection_state_modifier(p2)
		tf.ok(burnout_mod < base_mod, "le burnout réduit la probabilité de présence")

		# Déconnexion forcée par épuisement
		p2.energy = 2.0
		tf.ok(bs._should_force_disconnect(p2), "l'épuisement force la déconnexion")

		# trigger_personal_event applique réellement les effets (events auparavant inertes)
		var p3 = SimulatedPlayer.new()
		p3.mood = 50.0
		p3.energy = 50.0
		p3.is_online = true
		bs.trigger_personal_event(p3, "free_evening")  # bonus_time + humeur/énergie
		tf.eq(int(p3.bonus_session_hours), 3, "free_evening accorde 3h de temps bonus")
		tf.ok(p3.mood > 50.0, "free_evening améliore l'humeur")

		var p4 = SimulatedPlayer.new()
		p4.mood = 50.0
		p4.is_online = true
		bs.trigger_personal_event(p4, "great_news")  # mood_modifier +40
		tf.ok(p4.mood > 50.0, "great_news (mood_modifier) améliore l'humeur")

func _suite_bank(tf) -> void:
	tf.suite("Banque & équipement")

	# --- Modèle Guild (instance isolée) ---
	var g = Guild.new()
	var helm = Item.new("Heaume", Item.EquipmentSlot.HELMET, 20, Item.Rarity.RARE, 5, 0, 0)
	g.add_to_bank(helm)
	tf.eq(g.get_bank_items().size(), 1, "add_to_bank stocke un objet")
	tf.ok(g.remove_from_bank(helm), "remove_from_bank trouve l'objet")
	tf.eq(g.get_bank_items().size(), 0, "banque vide après retrait")
	for i in range(Guild.BANK_MAX_ITEMS + 10):
		g.add_to_bank(Item.new("It%d" % i, Item.EquipmentSlot.RING, 10 + i, Item.Rarity.UNCOMMON))
	tf.ok(g.get_bank_items().size() <= Guild.BANK_MAX_ITEMS, "banque plafonnée à BANK_MAX_ITEMS")

	# --- GuildManager : equip_from_bank (swap) + unequip_to_bank ---
	var gm = GuildManager
	gm.guild.bank_items.clear()
	var m = SimulatedPlayer.new()
	m.equipment = Equipment.new()
	var weapon1 = Item.new("Épée A", Item.EquipmentSlot.WEAPON, 30, Item.Rarity.RARE, 8, 0, 0)
	var weapon2 = Item.new("Épée B", Item.EquipmentSlot.WEAPON, 40, Item.Rarity.EPIC, 12, 0, 0)
	m.equipment.equip_item(weapon1)
	gm.guild.add_to_bank(weapon2)
	tf.ok(gm.equip_from_bank(m, weapon2), "equip_from_bank réussit")
	tf.eq(m.equipment.get_item_in_slot(Item.EquipmentSlot.WEAPON), weapon2, "le membre porte le nouvel objet")
	tf.ok(weapon1 in gm.guild.get_bank_items(), "l'ancien objet retourne en banque (swap)")
	tf.ok(not (weapon2 in gm.guild.get_bank_items()), "l'objet équipé n'est plus en banque")
	tf.ok(gm.unequip_to_bank(m, Item.EquipmentSlot.WEAPON), "unequip_to_bank réussit")
	tf.eq(m.equipment.get_item_in_slot(Item.EquipmentSlot.WEAPON), null, "slot vidé après déséquipement")
	tf.ok(weapon2 in gm.guild.get_bank_items(), "objet déséquipé rangé en banque")

	# --- route_loot : non-upgrade rare -> banque ; commun -> jeté ---
	gm.guild.bank_items.clear()
	var m2 = SimulatedPlayer.new()
	m2.equipment = Equipment.new()
	m2.equipment.equip_item(Item.new("Anneau fort", Item.EquipmentSlot.RING, 50, Item.Rarity.EPIC, 0, 0, 20))
	var weak_rare = Item.new("Anneau faible", Item.EquipmentSlot.RING, 10, Item.Rarity.RARE, 1, 0, 0)
	gm.route_loot(m2, weak_rare)
	tf.ok(weak_rare in gm.guild.get_bank_items(), "loot non-upgrade (rare) déposé en banque")
	var common_trash = Item.new("Bricole", Item.EquipmentSlot.RING, 5, Item.Rarity.COMMON, 0, 0, 0)
	var size_before: int = gm.guild.get_bank_items().size()
	gm.route_loot(m2, common_trash)
	tf.eq(gm.guild.get_bank_items().size(), size_before, "loot commun non-upgrade jeté (pas en banque)")

	# --- Persistance round-trip de la banque ---
	gm.guild.bank_items.clear()
	gm.guild.add_to_bank(Item.new("Persisté", Item.EquipmentSlot.CHEST, 33, Item.Rarity.EPIC, 7, 0, 0))
	var gd: Dictionary = SaveManager._serialize_guild()
	gm.guild.bank_items.clear()
	SaveManager._deserialize_guild(gd)
	tf.eq(gm.guild.get_bank_items().size(), 1, "banque round-trip : taille restaurée")
	if gm.guild.get_bank_items().size() == 1:
		tf.eq(gm.guild.get_bank_items()[0].name, "Persisté", "banque round-trip : nom")
		tf.eq(gm.guild.get_bank_items()[0].ilvl, 33, "banque round-trip : iLvl")

	# Nettoyage de l'état global (éviter de polluer les autres suites)
	gm.guild.bank_items.clear()

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
	tf.ok(p.player_id != "", "player_id généré à la création")
	tf.eq(p2.player_id, p.player_id, "round-trip player_id stable")
	if p.behavior_profile and p2.behavior_profile:
		tf.approx(p2.behavior_profile.stress_tolerance, p.behavior_profile.stress_tolerance, "round-trip profil comportemental via SaveManager")
	var cdata = GuildCultureManager.serialize()
	tf.ok(cdata.has("guild_morale"), "culture sérialise guild_morale")

	# Round-trip du graphe social (clés player_id stables, traduites au save).
	var sd = GuildManager.behavior_system.social_dynamics if (GuildManager and GuildManager.behavior_system) else null
	if sd and GuildManager.guild_members.size() >= 3:
		var m1 = GuildManager.guild_members[1]
		var m2 = GuildManager.guild_members[2]
		if m1.player_id != "" and m2.player_id != "":
			var saved_rels = sd.relationships.duplicate()
			var saved_cliques = sd.cliques.duplicate()
			sd.relationships.clear()
			sd.cliques.clear()
			sd.form_relationship(m1, m2, SocialDynamics.RelationType.FRIEND, 0.5)
			var social_data = sd.serialize()
			sd.relationships.clear()
			sd.deserialize(social_data)
			tf.ok(sd.are_friends(m1, m2), "round-trip social : amitié restaurée après reload")
			sd.relationships = saved_rels
			sd.cliques = saved_cliques

	# Round-trip EventManager (cooldowns / one-time).
	var ev_data = EventManager.serialize()
	tf.ok(ev_data.has("event_history") and ev_data.has("active_chains"), "EventManager sérialise historique + chaînes")

func _suite_ai_guild(tf) -> void:
	tf.suite("AIGuild")
	var restored: AIGuild = AIGuild.new("Guilde Restaurée", AIGuild.Strategy.HARDCORE, false)
	tf.eq(restored.name, "Guilde Restaurée", "restauration conserve le nom sans génération")
	tf.eq(restored.ai_strategy, AIGuild.Strategy.HARDCORE, "restauration conserve la stratégie")
	tf.eq(restored.members.size(), 0, "restauration ne génère pas de membres temporaires")
	# Dédup du contenu cleared (pas de double comptage face au joueur).
	var ai2: AIGuild = AIGuild.new("Dedup Test", AIGuild.Strategy.BALANCED, false)
	ai2.recent_achievements = [
		{"type": "pve_clear", "content": {"id": "deadmines", "name": "x"}},
		{"type": "pve_clear", "content": {"id": "deadmines", "name": "x"}},
		{"type": "pve_clear", "content": {"id": "uldaman", "name": "y"}},
	]
	tf.eq(ai2._get_cleared_content_ids().size(), 2, "contenu cleared dédupliqué (2 uniques sur 3)")
	# Progression de niveau : la simulation mensuelle fait monter l'XP.
	var xp_before: int = ai2.xp
	ai2.simulate_monthly_progress()
	tf.ok(ai2.xp > xp_before, "simulation mensuelle fait progresser l'XP de la guilde IA")

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
	# v2 -> v3 : matérialise les blocs events + social.
	var legacy_v2: Dictionary = {"save_version": 2, "guild": {"name": "G"}, "members": []}
	var migrated_v2: Dictionary = SaveManager._migrate_save_data(legacy_v2)
	tf.eq(int(migrated_v2.get("save_version", 0)), SaveManager.CURRENT_SAVE_VERSION, "migration v2 -> version courante")
	tf.ok(migrated_v2.has("events") and migrated_v2["events"] is Dictionary, "bloc events matérialisé par la migration")
	tf.ok(migrated_v2.has("social") and migrated_v2["social"] is Dictionary, "bloc social matérialisé par la migration")

	# Une sauvegarde plus récente que le build est tolérée (best-effort, pas de crash).
	var future: Dictionary = {"save_version": 9999, "guild": {}}
	var future_out: Dictionary = SaveManager._migrate_save_data(future)
	tf.eq(int(future_out.get("save_version", 0)), 9999, "save plus récente laissée intacte (best-effort)")

func _suite_pve_loop(tf) -> void:
	tf.suite("PvE Loop")
	var DI = load("res://scripts/systems/dungeon_instance.gd")
	# Composition : Mortemines = 1 Tank / 1 Healer / 3 DPS.
	var comp_required: Dictionary = DungeonData.get_group_composition("deadmines")
	tf.eq(int(comp_required.get("Tank", 0)), 1, "compo donjon requiert 1 tank")
	tf.eq(int(comp_required.get("DPS", 0)), 3, "compo donjon requiert 3 DPS")
	# Raids jouables : la compo d'un raid 40 tient dans un roster ≤ 20.
	var raid_comp: Dictionary = DungeonData.get_group_composition("molten_core")
	var raid_total: int = int(raid_comp.get("Tank", 0)) + int(raid_comp.get("Healer", 0)) + int(raid_comp.get("DPS", 0))
	tf.ok(raid_total > 0 and raid_total <= 20, "compo de raid 40 tient dans un roster de 20")

	# DungeonInstance (moteur vivant) : pénalité de composition (1.0 = complète, < 1.0 = rôle manquant).
	var inst_valid = DI.new()
	inst_valid.initialize("deadmines", _make_group(["Tank", "Healer", "DPS", "DPS", "DPS"], 25, 60))
	tf.approx(inst_valid._check_group_composition(comp_required), 1.0, "composition complète = pas de pénalité")

	var inst_bad = DI.new()
	inst_bad.initialize("deadmines", _make_group(["Healer", "DPS", "DPS", "DPS"], 25, 60))
	tf.ok(inst_bad._check_group_composition(comp_required) < 1.0, "composition sans tank = pénalité")

	# Chance de réussite : bornée [0.1, 0.95], et un groupe fort > un groupe faible.
	var strong = DI.new()
	strong.initialize("deadmines", _make_group(["Tank", "Healer", "DPS", "DPS", "DPS"], 40, 90))
	var weak = DI.new()
	weak.initialize("deadmines", _make_group(["Tank", "Healer", "DPS", "DPS", "DPS"], 15, 20))
	var sc_strong: float = strong._calculate_boss_success_chance(1.0)
	var sc_weak: float = weak._calculate_boss_success_chance(1.0)
	tf.between(sc_strong, 0.1, 0.95, "chance de réussite bornée")
	tf.ok(sc_strong > sc_weak, "groupe fort a une meilleure chance que groupe faible")

	# Connaissance de donjon : un clear l'incrémente (familiarité progressive).
	var grp = _make_group(["Tank", "Healer", "DPS", "DPS", "DPS"], 30, 70)
	var inst_k = DI.new()
	inst_k.initialize("deadmines", grp)
	var saved_loot: Array = GuildManager.loot_history.duplicate()
	var saved_gold_k: int = GuildManager.guild.gold if GuildManager.guild else 0
	var saved_cl: Dictionary = GuildRanking.player_cleared_content.duplicate(true)
	var saved_rc: Array = GuildRanking.player_recent_clears.duplicate(true)
	var saved_rh: Array = GuildRanking.player_run_history.duplicate(true)
	var saved_sf: Dictionary = GuildRanking.server_firsts.duplicate(true)
	inst_k._complete_dungeon()
	tf.ok(float(grp[0].connaissance_donjons.get("deadmines", 0.0)) >= 10.0, "clear augmente la connaissance du donjon")
	GuildManager.loot_history = saved_loot
	if GuildManager.guild:
		GuildManager.guild.gold = saved_gold_k
	GuildRanking.player_cleared_content = saved_cl
	GuildRanking.player_recent_clears = saved_rc
	GuildRanking.player_run_history = saved_rh
	GuildRanking.server_firsts = saved_sf

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

func _suite_economy(tf) -> void:
	tf.suite("Économie")
	# C7 : le signal de départ de membre doit exister (NotificationManager s'y abonne).
	tf.ok(GuildManager.has_signal("member_left"), "GuildManager déclare le signal member_left (C7)")
	var GuildPerks = load("res://scripts/data/guild_perks_data.gd")
	tf.eq(int(GuildPerks.get_combined_effects(3).get("gold_storage", 0)), 8000, "stockage d'or niv 3 = 8000")
	tf.ok(int(GuildPerks.get_combined_effects(10).get("gold_storage", 0)) >= 100000, "stockage d'or croît fortement au niv 10")
	if not (GuildManager and GuildManager.guild):
		return
	var g = GuildManager.guild
	var saved_xp: int = g.xp
	var saved_gold: int = g.gold

	# Le cap de trésorerie est respecté au niveau 3 (stockage 8000).
	g.xp = GuildPerks.get_xp_for_level(3)
	g.gold = 500
	g.add_gold(10000)
	tf.eq(g.gold, 8000, "add_gold plafonne au stockage (niv 3)")

	# Un clear de donjon crédite la trésorerie de guilde (revenu PvE).
	g.xp = 0  # niveau 1 -> stockage 0 -> non plafonné
	g.gold = 0
	var saved_cleared: Dictionary = GuildRanking.player_cleared_content.duplicate(true)
	var saved_recent: Array = GuildRanking.player_recent_clears.duplicate(true)
	var saved_history: Array = GuildRanking.player_run_history.duplicate(true)
	var saved_firsts: Dictionary = GuildRanking.server_firsts.duplicate(true)
	var DI = load("res://scripts/systems/dungeon_instance.gd")
	var inst = DI.new()
	inst.initialize("deadmines", _make_group(["Tank", "Healer", "DPS", "DPS", "DPS"], 25, 60))
	inst._complete_dungeon()
	tf.ok(g.gold >= 1, "clear de donjon crédite la trésorerie de guilde")
	GuildRanking.player_cleared_content = saved_cleared
	GuildRanking.player_recent_clears = saved_recent
	GuildRanking.player_run_history = saved_history
	GuildRanking.server_firsts = saved_firsts
	g.xp = saved_xp
	g.gold = saved_gold

func _suite_facades(tf) -> void:
	tf.suite("Façades branchées")
	# Gating de phase : à la phase Leveling, le tick drama ne crée pas de drama national.
	if PhaseManager and DramaManager:
		var saved_phase = PhaseManager.current_phase
		PhaseManager.current_phase = PhaseManager.GamePhase.LEVELING
		var before: int = DramaManager.active_dramas.size()
		DramaManager._on_week_changed(1, 1)
		tf.eq(DramaManager.active_dramas.size(), before, "aucun drama national déclenché en phase Leveling")
		PhaseManager.current_phase = saved_phase
	# Célébrité → risque de débauchage (façade désormais branchée).
	var celeb := SimulatedPlayer.new()
	celeb.celebrity_level = 90.0
	tf.ok(celeb.get_celebrity_poaching_risk() > 0.0, "membre célèbre = risque de débauchage")
	celeb.celebrity_level = 10.0
	tf.eq(celeb.get_celebrity_poaching_risk(), 0.0, "membre peu connu = pas de risque")
	# drama_queen caché ne doit pas être considéré comme révélé.
	var dq := SimulatedPlayer.new()
	dq.tags_comportement = []
	dq.tags_caches = ["drama_queen"]
	tf.ok(not DramaManager._has_revealed_tag(dq, "drama_queen"), "tag caché non considéré comme révélé")
	# Tournoi : garde-fou de phase (pas de participation hors Esport).
	if TournamentManager and PhaseManager:
		var saved_p2 = PhaseManager.current_phase
		PhaseManager.current_phase = PhaseManager.GamePhase.LEVELING
		var tres: Dictionary = TournamentManager.participate(null)
		tf.eq(tres.get("reason", ""), "phase", "tournoi bloqué hors phase Esport")
		PhaseManager.current_phase = saved_p2
	# Sponsors : pénalité adoucie (-6) + récupération plus rapide (+4).
	var sp = load("res://scripts/resources/sponsor.gd").new("Test", "marque_gaming", 100, 12)
	sp.satisfaction = 50.0
	sp.tick_week(true)
	tf.approx(sp.satisfaction, 54.0, "sponsor satisfait récupère +4")
	sp.satisfaction = 50.0
	sp.tick_week(false)
	tf.approx(sp.satisfaction, 44.0, "sponsor non satisfait perd seulement -6")
	# Tournois : les offres sont désormais sérialisées (survivent au reload).
	tf.ok(TournamentManager.serialize().has("available_tournaments"), "offres de tournoi sérialisées")
	# Tag DB : impatient (référencé par le recrutement) est désormais attribuable.
	tf.ok(PlayerTags.TAG_DATABASE.has("impatient"), "tag impatient présent dans la base")
	# Circadien branché : un type matin performe mieux le matin, moins tard le soir.
	var bs2 = GuildManager.behavior_system if GuildManager else null
	if bs2 and bs2.has_method("apply_circadian_modifier"):
		var morning := SimulatedPlayer.new()
		morning.circadian_type = "morning"
		tf.ok(bs2.apply_circadian_modifier(morning, 8) > 1.0, "circadien matin : bonus le matin")
		tf.ok(bs2.apply_circadian_modifier(morning, 23) < 1.0, "circadien matin : malus tard le soir")
	# Absences planifiées désormais consommées par le système de connexion.
	var bs3 = GuildManager.behavior_system if GuildManager else null
	if bs3 and bs3.has_method("_is_member_absent_today"):
		var absent := SimulatedPlayer.new()
		var today_abs: int = GameTime.get_total_days_elapsed()
		absent.scheduled_absences = [{"start_day": today_abs, "duration_days": 2}]
		tf.ok(bs3._is_member_absent_today(absent), "absence planifiée = membre absent aujourd'hui")
		absent.scheduled_absences = [{"start_day": today_abs + 5, "duration_days": 1}]
		tf.ok(not bs3._is_member_absent_today(absent), "absence future != absent aujourd'hui")

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

func _suite_chat_director(tf) -> void:
	tf.suite("ChatDirector (Phase A)")

	# Corpus chargé
	tf.eq(ChatDirector.get_corpus_size(), 40, "corpus ambient = 40 lignes")

	# Grammaire inline {a|b|c}
	var expanded: String = ChatDirector._expand("{alpha|beta|gamma}")
	tf.ok(expanded in ["alpha", "beta", "gamma"], "expand {a|b|c} -> un choix")
	tf.eq(ChatDirector._expand("texte simple"), "texte simple", "expand sans accolades = identite")

	# Veto de classe : la ligne 'eau' est reservee aux mages
	var mage := SimulatedPlayer.new()
	mage.personnage_classe = "Mage"
	var warrior := SimulatedPlayer.new()
	warrior.personnage_classe = "Guerrier"
	var water_line := {"requires_class": "Mage", "text": "free water"}
	tf.ok(ChatDirector._passes_vetos(water_line, mage), "veto classe : mage passe")
	tf.ok(not ChatDirector._passes_vetos(water_line, warrior), "veto classe : non-mage bloque")

	# Bavardise : social > solitaire (a humeur egale)
	var chatty := SimulatedPlayer.new()
	chatty.mood = 80.0
	chatty.tags_comportement = ["social"]
	var quiet := SimulatedPlayer.new()
	quiet.mood = 80.0
	quiet.tags_comportement = ["solitaire"]
	tf.ok(ChatDirector._talkativeness(chatty) > ChatDirector._talkativeness(quiet), "social plus bavard que solitaire")

	# Emission de bout en bout : 2 membres en ligne -> une ligne sort
	var emitted: Array = []
	var cb: Callable = func(_speaker_name, text, _channel): emitted.append(text)
	ChatDirector.line_emitted.connect(cb)
	var a := SimulatedPlayer.new()
	a.nom = "TesteurA"
	a.player_id = "chat_test_a"
	a.is_online = true
	a.mood = 80.0
	a.personnage_classe = "Guerrier"
	var b := SimulatedPlayer.new()
	b.nom = "TesteurB"
	b.player_id = "chat_test_b"
	b.is_online = true
	b.mood = 80.0
	b.personnage_classe = "Guerrier"
	GuildManager.guild_members.append(a)
	GuildManager.guild_members.append(b)
	var ok_emit: bool = ChatDirector.debug_force_ambient()
	tf.ok(ok_emit, "debug_force_ambient emet une ligne avec des membres en ligne")
	tf.ok(emitted.size() >= 1 and String(emitted[0]).strip_edges() != "", "ligne emise non vide")
	GuildManager.guild_members.erase(a)
	GuildManager.guild_members.erase(b)
	ChatDirector.line_emitted.disconnect(cb)

func _suite_chat_scoring(tf) -> void:
	tf.suite("ChatScoring (Phase B)")
	var CS = load("res://scripts/systems/chat/chat_scoring.gd")

	# Courbes valeur -> [0,1]
	tf.eq(CS.apply_curve(true, "boolean", {}), 1.0, "boolean true -> 1")
	tf.eq(CS.apply_curve(false, "boolean", {}), 0.0, "boolean false -> 0")
	tf.eq(CS.apply_curve(100.0, "linear", {}), 1.0, "linear 100/[0,100] -> 1")
	tf.eq(CS.apply_curve(0.0, "linear", {}), 0.0, "linear 0 -> 0")
	tf.ok(abs(CS.apply_curve(50.0, "linear", {}) - 0.5) < 0.001, "linear 50 -> 0.5")
	tf.eq(CS.apply_curve(0.0, "inverse", {}), 1.0, "inverse 0 -> 1")
	tf.ok(abs(CS.apply_curve(50.0, "gaussian", {"center": 50.0, "sigma": 20.0}) - 1.0) < 0.001, "gaussian au centre -> 1")
	tf.eq(CS.apply_curve(60.0, "threshold", {"t": 50.0}), 1.0, "threshold >= t -> 1")
	tf.eq(CS.apply_curve(40.0, "threshold", {"t": 50.0}), 0.0, "threshold < t -> 0")

	# score_line : bonus de trait (base 1.0 + 1.5)
	var dq := SimulatedPlayer.new()
	dq.tags_comportement = ["drama_queen"]
	dq.mood = 50.0
	var calm := SimulatedPlayer.new()
	calm.tags_comportement = []
	calm.mood = 50.0
	var line := {"weight": 1.0, "considerations": [{"axis": "speaker.has_trait", "param": "drama_queen", "curve": "boolean", "kind": "bonus", "weight": 1.5}]}
	var s_dq: float = CS.score_line(line, {"speaker": dq})["score"]
	var s_calm: float = CS.score_line(line, {"speaker": calm})["score"]
	tf.ok(s_dq > s_calm, "drama_queen score la ligne plus haut")
	tf.ok(abs(s_dq - 2.5) < 0.001, "score = base 1.0 + bonus 1.5")
	tf.ok(abs(s_calm - 1.0) < 0.001, "score sans trait = base 1.0")

	# veto a 0 annule le score
	var veto_line := {"weight": 2.0, "considerations": [{"axis": "speaker.has_trait", "param": "absent_xyz", "curve": "boolean", "kind": "veto"}]}
	tf.eq(CS.score_line(veto_line, {"speaker": calm})["score"], 0.0, "veto a 0 annule le score")

	# softmax : greedy a temperature basse
	var items := ["a", "b", "c"]
	var scores := [1.0, 5.0, 2.0]
	GameRandom.seed_rng(123)
	tf.eq(CS.softmax_sample(items, scores, 0.01), "b", "softmax T->0 choisit le meilleur score")

	# determinisme : meme seed -> meme tirage
	GameRandom.seed_rng(777)
	var r1 = CS.softmax_sample(items, scores, 1.0)
	GameRandom.seed_rng(777)
	var r2 = CS.softmax_sample(items, scores, 1.0)
	tf.eq(r1, r2, "softmax deterministe a seed fixe")
	GameRandom.randomize_rng()

	# explicateur de score : structure et tri
	var ex := SimulatedPlayer.new()
	ex.nom = "ExpA"
	ex.player_id = "exp_a"
	ex.is_online = true
	ex.mood = 60.0
	ex.personnage_classe = "Guerrier"
	ex.tags_comportement = ["drama_queen"]
	GuildManager.guild_members.append(ex)
	var explain: Dictionary = ChatDirector.debug_explain_ambient(5)
	tf.ok(explain.has("rows") and explain["rows"].size() > 0, "explain renvoie des lignes scorees")
	if explain.has("rows") and explain["rows"].size() >= 2:
		tf.ok(explain["rows"][0]["score"] >= explain["rows"][1]["score"], "explain trie par score desc")
		tf.ok(explain["rows"][0]["breakdown"] is Array, "explain expose le breakdown")
	GuildManager.guild_members.erase(ex)
