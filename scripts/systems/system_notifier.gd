extends Node
class_name SystemNotifier

## Relaie les signaux des managers (National / Esport / Cohésion) vers le chat et
## les notifications toast. Extrait de `main.gd` pour séparer le simple
## « forwarding » de l'orchestration. Le seul cas couplé à l'état de `main`
## (popup modal de drama, qui met le jeu en pause) est ré-émis via le signal
## `drama_response_needed`, que `main` écoute pour afficher le popup.

signal drama_response_needed(drama)

var _chat_panel = null

func setup(chat_panel) -> void:
	_chat_panel = chat_panel
	_connect_national()
	_connect_esport()
	_connect_culture()

# === National (médias, sponsors, dramas) ===

func _connect_national() -> void:
	if MediaManager:
		MediaManager.media_incident.connect(_on_media_incident)
		MediaManager.streamer_started.connect(_on_streamer_started)
	if SponsorshipManager:
		SponsorshipManager.sponsor_acquired.connect(_on_sponsor_acquired)
		SponsorshipManager.sponsor_lost.connect(_on_sponsor_lost)
	if DramaManager:
		DramaManager.drama_occurred.connect(_on_drama_occurred)
		DramaManager.drama_response_needed.connect(_on_drama_response_needed)
		DramaManager.drama_resolved.connect(_on_drama_resolved)

func _on_media_incident(_member_name: String, _incident_type: String, description: String) -> void:
	if _chat_panel:
		_chat_panel.add_message("[Média] %s" % description, "warning")

func _on_streamer_started(member_name: String) -> void:
	if _chat_panel:
		_chat_panel.add_message("[Stream] %s commence à streamer !" % member_name, "activity")
	if NotificationManager:
		NotificationManager.show_info("%s est désormais streamer" % member_name, "Nouveau streamer")

func _on_sponsor_acquired(sponsor) -> void:
	if NotificationManager:
		NotificationManager.show_success(
			"Contrat signé avec %s (+%d or/sem.)" % [sponsor.sponsor_name, sponsor.weekly_revenue],
			"Sponsor")
	if _chat_panel:
		_chat_panel.add_message("[Sponsor] Nouveau contrat : %s" % sponsor.sponsor_name, "loot")

func _on_sponsor_lost(sponsor, reason: String) -> void:
	if NotificationManager:
		NotificationManager.show_warning("%s : %s" % [sponsor.sponsor_name, reason], "Sponsor perdu")

func _on_drama_occurred(drama) -> void:
	if _chat_panel:
		_chat_panel.add_message("[Drama] %s" % drama.description, "error")
	if NotificationManager:
		NotificationManager.show_warning(
			drama.description,
			"%s (%s)" % [drama.get_type_name(), drama.get_severity_name()])

func _on_drama_resolved(drama) -> void:
	if _chat_panel:
		_chat_panel.add_message("[Drama] Crise résolue : %s" % drama.get_type_name(), "info")

func _on_drama_response_needed(drama) -> void:
	# Le popup modal vit dans main (couplé à la pause/file) : on ré-émet.
	drama_response_needed.emit(drama)

# === Esport (staff, tournois, transferts, legacy) ===

func _connect_esport() -> void:
	if TournamentManager:
		TournamentManager.tournament_completed.connect(_on_tournament_completed)
	if StaffManager:
		StaffManager.staff_hired.connect(_on_staff_hired)
	if TransferManager:
		TransferManager.transfer_completed.connect(_on_transfer_completed)
		TransferManager.transfer_window_opened.connect(_on_transfer_window_opened)
	if LegacyManager:
		LegacyManager.title_unlocked.connect(_on_legacy_title_unlocked)

func _on_tournament_completed(_tournament, _stage_reached: int, is_champion: bool, results: Dictionary) -> void:
	if _chat_panel:
		if is_champion:
			_chat_panel.add_message("[Esport] Victoire au %s ! (+%d or)" % [results.get("tournament", ""), results.get("gold", 0)], "loot")
		else:
			_chat_panel.add_message("[Esport] Éliminé : %s (tour %d/%d)" % [results.get("tournament", ""), results.get("stage_reached", 0), results.get("rounds", 0)], "info")
	if NotificationManager:
		if is_champion:
			NotificationManager.show_achievement("Champion : %s" % results.get("tournament", ""), "Tournoi")
		else:
			NotificationManager.show_info("Tournoi terminé (tour %d/%d)" % [results.get("stage_reached", 0), results.get("rounds", 0)], "Esport")

func _on_staff_hired(staff) -> void:
	if _chat_panel:
		_chat_panel.add_message("[Staff] %s rejoint le staff (%s)" % [staff.staff_name, staff.get_role_name()], "activity")

func _on_transfer_completed(player) -> void:
	if NotificationManager:
		NotificationManager.show_success("%s rejoint la guilde (transfert international)" % player.nom, "Transfert")
	if _chat_panel:
		_chat_panel.add_message("[Transfert] %s arrive de %s" % [player.nom, player.get_meta("region", "?")], "loot")

func _on_transfer_window_opened() -> void:
	if NotificationManager:
		NotificationManager.show_info("La fenêtre de transfert internationale est ouverte", "Transferts")

func _on_legacy_title_unlocked(title) -> void:
	if _chat_panel:
		_chat_panel.add_message("[Legacy] Nouveau titre débloqué : %s" % title, "loot")

# === Cohésion (moral, social, team-building, traditions) ===

func _connect_culture() -> void:
	if GuildCultureManager:
		GuildCultureManager.tension_detected.connect(_on_tension_detected)
		GuildCultureManager.team_building_done.connect(_on_team_building_done)
		GuildCultureManager.tradition_established.connect(_on_tradition_established)

func _on_tension_detected(player1_name: String, player2_name: String, reason: String) -> void:
	if _chat_panel:
		_chat_panel.add_message("[Cohésion] Tension entre %s et %s (%s)" % [player1_name, player2_name, reason], "warning")

func _on_team_building_done(activity_name: String, _morale_gain: float) -> void:
	if _chat_panel:
		_chat_panel.add_message("[Cohésion] Team-building : %s" % activity_name, "activity")

func _on_tradition_established(tradition_name: String) -> void:
	if _chat_panel:
		_chat_panel.add_message("[Cohésion] Nouvelle tradition établie : %s" % tradition_name, "loot")
