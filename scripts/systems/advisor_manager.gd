extends Node

## Système de Conseils & Alertes adaptatifs (Milestone 6, US 6.1).
## Analyse l'état courant de la guilde (trésorerie/salaires, burnout/stress, moral,
## tensions, recrutement, équipement, progression de phase) et produit une liste de
## conseils priorisés. Pousse l'alerte la plus critique en notification chaque semaine.
##
## L'UI (Fenetre_Conseils) appelle get_advice() ; rien n'est mis en cache pour rester
## toujours synchrone avec l'état réel.

signal advice_pushed(advice: Dictionary)

enum Severity { ALERT, WARNING, TIP, OPPORTUNITY }

# Métadonnées d'affichage par sévérité (libellé + couleur), partagées avec l'UI.
const SEVERITY_META := {
	Severity.ALERT: {"label": "Alerte", "color": Color(0.90, 0.36, 0.36)},
	Severity.WARNING: {"label": "Attention", "color": Color(0.96, 0.71, 0.30)},
	Severity.TIP: {"label": "Conseil", "color": Color(0.42, 0.70, 0.96)},
	Severity.OPPORTUNITY: {"label": "Opportunité", "color": Color(0.55, 0.82, 0.55)},
}

const MAX_ADVICE := 10

# Anti-spam : ne pas repousser deux fois de suite la même alerte hebdomadaire.
var _last_pushed_title: String = ""

func _ready() -> void:
	if GameTime and GameTime.has_signal("week_changed"):
		GameTime.week_changed.connect(_on_week_changed)

func _on_week_changed(_week: int, _year: int) -> void:
	"""Pousse l'élément le plus prioritaire (alerte ou avertissement) en notification."""
	var advice: Array = get_advice()
	for a in advice:
		if a.get("severity", Severity.TIP) <= Severity.WARNING:
			if a.get("title", "") != _last_pushed_title:
				_last_pushed_title = a.get("title", "")
				_push_notification(a)
			return
	# Aucune alerte cette semaine : on réarme l'anti-spam.
	_last_pushed_title = ""

func _push_notification(advice: Dictionary) -> void:
	advice_pushed.emit(advice)
	var nm: Node = get_node_or_null("/root/NotificationManager")
	if not nm:
		return
	var title: String = advice.get("title", "Conseil")
	var text: String = advice.get("text", "")
	if advice.get("severity", Severity.TIP) == Severity.ALERT:
		nm.show_warning(text, title)
	else:
		nm.show_info(text, title)

# --- Génération des conseils ---

func get_advice() -> Array:
	"""Retourne la liste des conseils {severity, title, text}, triée par priorité."""
	var out: Array = []
	if not GuildManager or not GuildManager.guild:
		return out

	_analyze_finances(out)
	_analyze_burnout(out)
	_analyze_morale(out)
	_analyze_tensions(out)
	_analyze_roster(out)
	_analyze_equipment(out)
	_analyze_phase_progress(out)

	out.sort_custom(func(a, b): return a.get("severity", 99) < b.get("severity", 99))
	if out.size() > MAX_ADVICE:
		out = out.slice(0, MAX_ADVICE)
	return out

func _add(out: Array, severity: int, title: String, text: String) -> void:
	out.append({"severity": severity, "title": title, "text": text})

# --- Analyses individuelles ---

func _analyze_finances(out: Array) -> void:
	var salaries: int = GuildManager.get_total_weekly_salaries()
	if salaries <= 0:
		return
	var gold: int = GuildManager.guild.gold
	if gold < salaries:
		_add(out, Severity.ALERT, "Trésorerie insuffisante",
			"Vous n'avez pas de quoi payer les salaires cette semaine (%d or requis, %d disponibles). Le moral chutera si les salaires ne sont pas versés." % [salaries, gold])
	elif gold < salaries * 3:
		_add(out, Severity.WARNING, "Trésorerie tendue",
			"Votre trésorerie couvre à peine la masse salariale (%d or/sem). Enchaînez farm et donjons pour vous constituer une marge." % salaries)

func _analyze_burnout(out: Array) -> void:
	var burnout_count: int = 0
	var high_stress: int = 0
	for m in GuildManager.guild_members:
		if m.burnout_level >= 2:
			burnout_count += 1
		if m.stress_level >= 60.0:
			high_stress += 1
	if burnout_count > 0:
		_add(out, Severity.WARNING, "Risque de burnout",
			"%d membre(s) en burnout avancé. Accordez du repos à l'équipe (Esport → Bien-être) ou allégez la pression compétitive." % burnout_count)
	elif high_stress >= 3:
		_add(out, Severity.TIP, "Stress en hausse",
			"%d membres accusent un stress élevé. Un psychologue dans le staff ou un repos d'équipe ferait baisser la pression." % high_stress)

func _analyze_morale(out: Array) -> void:
	var gcm: Node = get_node_or_null("/root/GuildCultureManager")
	if not gcm or not gcm.has_method("get_guild_morale"):
		return
	var morale: float = gcm.get_guild_morale()
	if morale < 35.0:
		_add(out, Severity.WARNING, "Ambiance toxique",
			"Le moral de guilde est au plus bas (%d/100). Organisez un team-building et établissez des traditions (Cohésion) avant que des membres ne partent." % int(morale))
	elif morale < 55.0:
		_add(out, Severity.TIP, "Moral en berne",
			"Le moral de guilde s'effrite (%d/100). Un événement de team-building remonterait l'ambiance (Cohésion)." % int(morale))

func _analyze_tensions(out: Array) -> void:
	var gcm: Node = get_node_or_null("/root/GuildCultureManager")
	if not gcm or not gcm.has_method("get_tensions"):
		return
	var tensions: Array = gcm.get_tensions()
	var enemies: int = 0
	for t in tensions:
		if t.get("is_enemy", false):
			enemies += 1
	if enemies > 0:
		_add(out, Severity.WARNING, "Conflits ouverts",
			"%d inimitié(s) franche(s) dégradent la cohésion. Tentez une médiation dans l'onglet Cohésion → Conflits." % enemies)
	elif tensions.size() >= 3:
		_add(out, Severity.TIP, "Rivalités à surveiller",
			"%d rivalités couvent dans la guilde. Surveillez-les avant qu'elles ne dégénèrent (Cohésion)." % tensions.size())

func _analyze_roster(out: Array) -> void:
	var guild = GuildManager.guild
	if not guild.can_recruit():
		return
	var count: int = GuildManager.guild_members.size()
	var max_members: int = guild.get_max_members()
	var free: int = max_members - count
	if free >= 3 and count < 20:
		_add(out, Severity.OPPORTUNITY, "Places à pourvoir",
			"Il reste %d place(s) libre(s) dans la guilde (%d/%d). Recrutez de nouveaux membres dans la fenêtre Monde pour renforcer vos rangs." % [free, count, max_members])

func _analyze_equipment(out: Array) -> void:
	var underequipped: int = 0
	for m in GuildManager.guild_members:
		if m.get_meta("is_player", false):
			continue
		if m.personnage_niveau >= 60 and m.get_total_ilvl() < 120:
			underequipped += 1
	if underequipped >= 3:
		_add(out, Severity.TIP, "Équipement à améliorer",
			"%d membres au niveau max restent peu équipés. Enchaînez des donjons (héroïques de préférence) pour faire monter leur iLvl." % underequipped)

func _analyze_phase_progress(out: Array) -> void:
	if not PhaseManager:
		return
	var phase: int = PhaseManager.get_current_phase()
	var config: Dictionary = PhaseManager.get_current_phase_config()
	if config.get("next_phase") == null:
		# Phase finale : guider vers les objectifs de maîtrise non atteints.
		_advise_unmet_requirements(out, phase, "Asseyez votre légende",
			"Objectifs de maîtrise Esport restants : %s.")
		return

	if phase == PhaseManager.GamePhase.LEVELING:
		if PhaseManager.heroic_dungeons_completed < 1:
			_add(out, Severity.OPPORTUNITY, "Débloquez la Phase Serveur",
				"Objectif actuel : compléter un donjon héroïque. Montez vos membres au niveau requis, formez un groupe (Organisation) et lancez un héroïque.")
		return

	_advise_unmet_requirements(out, phase, "Vers la phase suivante",
		"Conditions encore non remplies : %s.")

func _advise_unmet_requirements(out: Array, phase: int, title: String, template: String) -> void:
	if not PhaseManager.has_method("get_requirements_progress"):
		return
	var progress: Dictionary = PhaseManager.get_requirements_progress(phase)
	var unmet: Array = []
	for req_name in progress:
		if not progress[req_name].get("met", false):
			unmet.append(_requirement_label(req_name))
	if unmet.is_empty():
		_add(out, Severity.OPPORTUNITY, "Phase prête à avancer",
			"Toutes les conditions de progression sont remplies — la transition se déclenchera automatiquement.")
	else:
		var sev: int = Severity.TIP if phase != PhaseManager.GamePhase.ESPORT else Severity.OPPORTUNITY
		_add(out, sev, title, template % ", ".join(unmet))

func _requirement_label(req_name: String) -> String:
	match req_name:
		"server_rank_position": return "atteindre la 1re place serveur"
		"national_rank_position": return "atteindre la 1re place nationale"
		"server_rank_duration", "national_rank_duration": return "tenir le rang 1 dans la durée"
		"active_members_min": return "recruter assez de membres actifs"
		"integration_threshold": return "améliorer l'intégration moyenne"
		"content_cleared_percent": return "clear davantage de contenu"
		"max_dramas_per_year": return "limiter les dramas"
		"active_sponsors": return "signer un sponsor"
		"world_first_count": return "décrocher des world firsts"
		"media_reputation": return "monter la réputation médiatique"
		"world_championship_wins": return "remporter un Championnat du Monde"
		"professional_staff_count": return "compléter le staff professionnel"
		"international_reputation": return "monter la réputation internationale"
		"team_stability": return "stabiliser l'équipe"
		_: return req_name

# --- Helpers d'affichage (partagés avec l'UI) ---

func get_severity_label(severity: int) -> String:
	return SEVERITY_META.get(severity, {}).get("label", "Conseil")

func get_severity_color(severity: int) -> Color:
	return SEVERITY_META.get(severity, {}).get("color", Color.WHITE)

func get_advice_counts() -> Dictionary:
	"""Comptage par sévérité, pour un éventuel badge sur le bouton de menu."""
	var counts: Dictionary = {Severity.ALERT: 0, Severity.WARNING: 0, Severity.TIP: 0, Severity.OPPORTUNITY: 0}
	for a in get_advice():
		var s: int = a.get("severity", Severity.TIP)
		counts[s] = counts.get(s, 0) + 1
	return counts

# --- Vue "Cette semaine" (audit Priorité 9) ---

func get_weekly_summary() -> Dictionary:
	"""Synthèse actionnable de la semaine : membres à risque, objectifs accessibles,
	opportunités de recrutement, contenu conseillé et activités en cours. Toute la
	logique est ici (testable) ; l'UI (Fenetre_Conseils) ne fait que l'afficher."""
	var summary: Dictionary = {
		"members_at_risk": [],
		"objectives": [],
		"recommended_content": [],
		"recruitment": {},
		"activities": {},
	}
	if not GuildManager or not GuildManager.guild:
		return summary

	var members: Array = GuildManager.guild_members

	# Membres à risque : burnout, stress, moral bas, intégration faible, débauchage probable.
	for m in members:
		if m.get_meta("is_player", false):
			continue
		var reasons: Array[String] = []
		if m.burnout_level >= 2:
			reasons.append("burnout")
		if m.stress_level >= 65.0:
			reasons.append("stress %d" % int(m.stress_level))
		if m.mood < 35.0:
			reasons.append("moral %d" % int(m.mood))
		if m.integration < 30.0 and m.days_in_guild > 7:
			reasons.append("intégration %d%%" % int(m.integration))
		if not reasons.is_empty():
			summary.members_at_risk.append({"name": m.nom, "reasons": reasons})

	# Objectifs accessibles : exigences non remplies de la phase, triées par progression décroissante.
	if PhaseManager and PhaseManager.has_method("get_requirements_progress"):
		var prog: Dictionary = PhaseManager.get_requirements_progress(PhaseManager.get_current_phase())
		var unmet: Array = []
		for req in prog:
			if not prog[req].get("met", false):
				unmet.append({
					"label": _requirement_label(req),
					"percent": float(prog[req].get("progress_percent", 0.0)),
				})
		unmet.sort_custom(func(a, b): return a.percent > b.percent)
		summary.objectives = unmet

	# Contenu conseillé : instances adaptées au niveau moyen, marquées clear ou non.
	var avg_level: int = _average_level(members)
	var suitable: Array = DungeonData.get_instances_for_level(avg_level)
	var cleared_ids: Array = []
	if GuildRanking and GuildRanking.has_method("get_player_cleared_content"):
		cleared_ids = GuildRanking.get_player_cleared_content()
	for inst in suitable.slice(0, mini(3, suitable.size())):
		summary.recommended_content.append({
			"id": inst.id,
			"name": inst.data.get("name", inst.id),
			"level": int(inst.data.get("level_recommended", 0)),
			"cleared": cleared_ids.has(inst.id),
		})

	# Recrutement : places libres + taille du pool disponible.
	var guild = GuildManager.guild
	summary.recruitment = {
		"free_slots": maxi(0, guild.get_max_members() - members.size()),
		"pool_size": RecruitmentPool.available_players.size() if RecruitmentPool else 0,
		"can_recruit": guild.can_recruit(),
	}

	# Activités en cours des membres en ligne.
	var by_type: Dictionary = {}
	var online: Array = GuildManager.get_online_members()
	for m in online:
		var label: String = _activity_label(m.current_activity)
		by_type[label] = int(by_type.get(label, 0)) + 1
	summary.activities = {"online": online.size(), "by_type": by_type}

	return summary

func _average_level(members: Array) -> int:
	if members.is_empty():
		return 1
	var total: int = 0
	for m in members:
		total += m.personnage_niveau
	return int(round(float(total) / float(members.size())))

func _activity_label(activity) -> String:
	if activity == null:
		return "En attente"
	match activity.type:
		Activity.ActivityType.LEVELING: return "Leveling"
		Activity.ActivityType.FARMING: return "Farm"
		Activity.ActivityType.FUN: return "Détente"
		Activity.ActivityType.DUNGEON: return "Donjon"
		Activity.ActivityType.RAID: return "Raid"
		Activity.ActivityType.OFFLINE: return "Hors-ligne"
		_: return "En attente"
