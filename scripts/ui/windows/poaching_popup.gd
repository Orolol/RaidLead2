extends Window

# Popup pour gérer les tentatives de débauchage

signal counter_offer_made(member, counter_offer: Dictionary)
signal member_released(member)
signal poaching_ignored()

var target_member
var source_guild: AIGuild
var original_offer: Dictionary
var counter_offer_sent: bool = false

# Références UI
var member_info_label: Label
var source_guild_label: Label
var offer_description_label: Label
var counter_offer_container: VBoxContainer
var equipment_bonus_spinbox: SpinBox
var salary_increase_spinbox: SpinBox
var promotion_checkbox: CheckBox
var guarantee_raids_checkbox: CheckBox

func _ready():
	# Configuration de la fenêtre
	title = "Tentative de Débauchage"
	size = Vector2(600, 500)
	unresizable = false
	initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN

	# Le X natif d'une Window non-exclusive émet close_requested dont l'action par
	# défaut est de cacher (visible=false), pas de libérer : tree_exited ne se
	# déclencherait jamais et _pending_poaching fuiterait. On résout par défaut
	# « membre conservé » (poaching_ignored) puis on libère pour déclencher le nettoyage.
	close_requested.connect(_on_close_requested)

	_setup_ui()

func _on_close_requested() -> void:
	"""Fermeture via le X natif : résolution sûre (membre conservé) + libération."""
	poaching_ignored.emit()
	queue_free()

func _setup_ui():
	"""Configure l'interface utilisateur"""
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 15)
	add_child(main_vbox)
	
	# Header avec alerte
	var alert_container = HBoxContainer.new()
	main_vbox.add_child(alert_container)
	
	var alert_icon = Label.new()
	alert_icon.text = "⚠️"
	alert_icon.add_theme_font_size_override("font_size", 24)
	alert_container.add_child(alert_icon)
	
	var alert_label = Label.new()
	alert_label.text = "Une guilde concurrente tente de débaucher un de vos membres !"
	alert_label.add_theme_font_size_override("font_size", 16)
	alert_label.modulate = Color(1.0, 0.8, 0.2)
	alert_container.add_child(alert_label)
	
	main_vbox.add_child(HSeparator.new())
	
	# Informations sur le membre ciblé
	var member_section = VBoxContainer.new()
	main_vbox.add_child(member_section)
	
	var member_title = Label.new()
	member_title.text = "Membre ciblé :"
	member_title.add_theme_font_size_override("font_size", 14)
	member_section.add_child(member_title)
	
	member_info_label = Label.new()
	member_info_label.add_theme_font_size_override("font_size", 16)
	member_info_label.modulate = Color(0.9, 0.9, 1.0)
	member_section.add_child(member_info_label)
	
	# Informations sur la guilde source
	var guild_title = Label.new()
	guild_title.text = "Guilde concurrente :"
	guild_title.add_theme_font_size_override("font_size", 14)
	member_section.add_child(guild_title)
	
	source_guild_label = Label.new()
	source_guild_label.add_theme_font_size_override("font_size", 16)
	source_guild_label.modulate = Color(1.0, 0.8, 0.8)
	member_section.add_child(source_guild_label)
	
	main_vbox.add_child(HSeparator.new())
	
	# Description de l'offre
	var offer_title = Label.new()
	offer_title.text = "Leur offre :"
	offer_title.add_theme_font_size_override("font_size", 14)
	main_vbox.add_child(offer_title)
	
	offer_description_label = Label.new()
	offer_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	offer_description_label.add_theme_font_size_override("font_size", 14)
	offer_description_label.modulate = Color(0.9, 0.9, 0.7)
	main_vbox.add_child(offer_description_label)
	
	main_vbox.add_child(HSeparator.new())
	
	# Section contre-offre
	_setup_counter_offer_section(main_vbox)
	
	main_vbox.add_child(HSeparator.new())
	
	# Boutons d'action
	_setup_action_buttons(main_vbox)

func _setup_counter_offer_section(parent: VBoxContainer):
	"""Configure la section de contre-offre"""
	var counter_title = Label.new()
	counter_title.text = "Votre contre-offre (optionnel) :"
	counter_title.add_theme_font_size_override("font_size", 14)
	parent.add_child(counter_title)
	
	counter_offer_container = VBoxContainer.new()
	counter_offer_container.add_theme_constant_override("separation", 10)
	parent.add_child(counter_offer_container)
	
	# Bonus d'équipement
	var equipment_container = HBoxContainer.new()
	counter_offer_container.add_child(equipment_container)
	
	var equipment_label = Label.new()
	equipment_label.text = "Bonus d'équipement :"
	equipment_label.custom_minimum_size = Vector2(180, 0)
	equipment_container.add_child(equipment_label)
	
	equipment_bonus_spinbox = SpinBox.new()
	equipment_bonus_spinbox.min_value = 0
	equipment_bonus_spinbox.max_value = 100
	equipment_bonus_spinbox.step = 5
	equipment_bonus_spinbox.value = 0
	equipment_container.add_child(equipment_bonus_spinbox)
	
	# Augmentation de salaire (concept abstrait)
	var salary_container = HBoxContainer.new()
	counter_offer_container.add_child(salary_container)
	
	var salary_label = Label.new()
	salary_label.text = "Prime de fidélité :"
	salary_label.custom_minimum_size = Vector2(180, 0)
	salary_container.add_child(salary_label)
	
	salary_increase_spinbox = SpinBox.new()
	salary_increase_spinbox.min_value = 0
	salary_increase_spinbox.max_value = 1000
	salary_increase_spinbox.step = 50
	salary_increase_spinbox.value = 0
	salary_increase_spinbox.suffix = " or"
	salary_container.add_child(salary_increase_spinbox)
	
	# Promotion / rôle spécial
	promotion_checkbox = CheckBox.new()
	promotion_checkbox.text = "Promouvoir à un rôle de leadership"
	counter_offer_container.add_child(promotion_checkbox)
	
	# Garantie de place en raid
	guarantee_raids_checkbox = CheckBox.new()
	guarantee_raids_checkbox.text = "Garantir une place en raid prioritaire"
	counter_offer_container.add_child(guarantee_raids_checkbox)

func _setup_action_buttons(parent: VBoxContainer):
	"""Configure les boutons d'action"""
	var button_container = HBoxContainer.new()
	button_container.add_theme_constant_override("separation", 10)
	parent.add_child(button_container)
	
	# Accepter le départ
	var release_button = Button.new()
	release_button.text = "Laisser partir"
	release_button.custom_minimum_size = Vector2(120, 40)
	release_button.modulate = Color(1.0, 0.6, 0.6)
	release_button.pressed.connect(_on_release_pressed)
	button_container.add_child(release_button)
	
	button_container.add_spacer(false)
	
	# Faire une contre-offre
	var counter_offer_button = Button.new()
	counter_offer_button.text = "Faire une contre-offre"
	counter_offer_button.custom_minimum_size = Vector2(150, 40)
	counter_offer_button.modulate = Color(0.8, 0.8, 1.0)
	counter_offer_button.pressed.connect(_on_counter_offer_pressed)
	button_container.add_child(counter_offer_button)
	
	# Ignorer (ne rien faire)
	var ignore_button = Button.new()
	ignore_button.text = "Ignorer"
	ignore_button.custom_minimum_size = Vector2(100, 40)
	ignore_button.modulate = Color(0.7, 0.7, 0.7)
	ignore_button.pressed.connect(_on_ignore_pressed)
	button_container.add_child(ignore_button)

func show_poaching_attempt(member, guild: AIGuild, offer: Dictionary):
	"""Affiche la tentative de débauchage"""
	target_member = member
	source_guild = guild
	original_offer = offer
	counter_offer_sent = false
	
	# Mettre à jour les informations affichées
	_update_member_info()
	_update_guild_info()
	_update_offer_info()
	
	# Afficher la fenêtre
	popup_centered()

func _update_member_info():
	"""Met à jour les informations du membre"""
	if not target_member:
		return
	
	var info_text = "%s - %s Niveau %d\n" % [
		target_member.nom,
		target_member.personnage_classe,
		target_member.personnage_niveau
	]
	info_text += "Équipement: %d | Skill: %.0f | Intégration: %.0f%%" % [
		target_member.get_total_ilvl(),
		target_member.skill,
		target_member.integration
	]
	
	member_info_label.text = info_text

func _update_guild_info():
	"""Met à jour les informations de la guilde concurrente"""
	if not source_guild:
		return
	
	var guild_text = "%s (Stratégie: %s)\n" % [
		source_guild.name,
		source_guild.get_strategy_name()
	]
	guild_text += "Réputation: %.0f | Membres: %d" % [
		source_guild.reputation,
		source_guild.get_active_members_count()
	]
	
	source_guild_label.text = guild_text

func _update_offer_info():
	"""Met à jour la description de l'offre"""
	if original_offer.is_empty():
		return
	
	var offer_text = ""
	
	if original_offer.get("equipment_bonus", 0) > 0:
		offer_text += "• Bonus d'équipement: +%d\n" % original_offer.equipment_bonus
	
	if original_offer.get("guaranteed_raid_spot", false):
		offer_text += "• Place garantie en raid\n"
	
	if original_offer.get("leadership_role", false):
		offer_text += "• Rôle de leadership offert\n"
	
	if original_offer.has("message"):
		offer_text += "\nMessage: \"%s\"" % original_offer.message
	
	if offer_text == "":
		offer_text = "Offre de recrutement standard"
	
	offer_description_label.text = offer_text

func _on_counter_offer_pressed():
	"""Appelé quand le joueur fait une contre-offre"""
	if counter_offer_sent:
		return
	
	var counter_offer = {
		"equipment_bonus": int(equipment_bonus_spinbox.value),
		"salary_increase": int(salary_increase_spinbox.value),
		"promotion": promotion_checkbox.button_pressed,
		"guarantee_raids": guarantee_raids_checkbox.button_pressed
	}
	
	# Vérifier si la contre-offre a du contenu
	var has_content = (
		counter_offer.equipment_bonus > 0 or
		counter_offer.salary_increase > 0 or
		counter_offer.promotion or
		counter_offer.guarantee_raids
	)
	
	if not has_content:
		_show_warning("Votre contre-offre doit contenir au moins un élément !")
		return
	
	counter_offer_sent = true
	counter_offer_made.emit(target_member, counter_offer)
	
	# Désactiver le bouton et changer le texte
	var button = get_children()[0].get_children()[-1].get_children()[1] # Un peu hacky mais fonctionnel
	if button is Button:
		button.text = "Contre-offre envoyée..."
		button.disabled = true
	
	# Simuler la réponse après un délai
	get_tree().create_timer(2.0).timeout.connect(_simulate_counter_offer_response)

func _simulate_counter_offer_response():
	"""Simule la réponse à la contre-offre"""
	if not source_guild or not target_member:
		return
	
	var response = AIGuildManager.simulate_counter_offer_response(source_guild, target_member, {
		"equipment_bonus": equipment_bonus_spinbox.value,
		"salary_increase": salary_increase_spinbox.value,
		"promotion": promotion_checkbox.button_pressed,
		"guarantee_raids": guarantee_raids_checkbox.button_pressed
	})
	
	if response:
		# La guilde IA abandonne : le membre reste et profite des bénéfices de la contre-offre.
		_apply_counter_offer_benefits()
		_show_result("✅ Succès ! La guilde concurrente a abandonné ses tentatives de débauchage.")
		get_tree().create_timer(3.0).timeout.connect(queue_free)
	else:
		# La guilde IA insiste
		_show_result("❌ La guilde concurrente maintient son offre. Le membre va probablement partir...")
		
		# Calculer si le membre part vraiment
		var leave_chance = _calculate_final_leave_probability()
		
		get_tree().create_timer(2.0).timeout.connect(func(): _resolve_final_decision(leave_chance))

func _calculate_final_leave_probability() -> float:
	"""Calcule la probabilité finale que le membre parte"""
	var base_prob = 0.6  # Probabilité de base élevée car la guilde IA insiste
	
	# La contre-offre réduit les chances de départ
	if equipment_bonus_spinbox.value > 0:
		base_prob -= 0.2
	if salary_increase_spinbox.value > 0:
		base_prob -= 0.15
	if promotion_checkbox.button_pressed:
		base_prob -= 0.25
	if guarantee_raids_checkbox.button_pressed:
		base_prob -= 0.2
	
	# Facteurs du membre
	if target_member.integration > 70:
		base_prob -= 0.3
	elif target_member.integration < 40:
		base_prob += 0.2
	
	return clamp(base_prob, 0.1, 0.9)

func _resolve_final_decision(leave_probability: float):
	"""Résout la décision finale du membre"""
	if randf() < leave_probability:
		# Le membre part
		_show_result("💔 Malgré vos efforts, %s a décidé de rejoindre %s." % [target_member.nom, source_guild.name])
		get_tree().create_timer(3.0).timeout.connect(func(): member_released.emit(target_member))
		get_tree().create_timer(3.5).timeout.connect(queue_free)
	else:
		# Le membre reste
		_show_result("🎉 %s a finalement décidé de rester dans la guilde !" % target_member.nom)
		
		# Appliquer les bénéfices de la contre-offre
		_apply_counter_offer_benefits()
		
		get_tree().create_timer(3.0).timeout.connect(queue_free)

func _apply_counter_offer_benefits():
	"""Applique les bénéfices de la contre-offre au membre"""
	if equipment_bonus_spinbox.value > 0:
		# TODO: Avec le nouveau système, donner des objets spécifiques plutôt qu'un bonus général
		# target_member.personnage_equipement += int(equipment_bonus_spinbox.value)
		pass
	
	if salary_increase_spinbox.value > 0:
		# Augmenter légèrement le moral
		target_member.mood = min(100.0, target_member.mood + 10.0)
	
	if promotion_checkbox.button_pressed:
		# Augmenter l'intégration et le moral
		target_member.integration = min(100.0, target_member.integration + 15.0)
		target_member.mood = min(100.0, target_member.mood + 15.0)
	
	if guarantee_raids_checkbox.button_pressed:
		# Marquer le membre comme prioritaire pour les raids
		target_member.set_meta("raid_priority", true)
		target_member.mood = min(100.0, target_member.mood + 10.0)
	
	print("Contre-offre appliquée à %s" % target_member.nom)

func _on_release_pressed():
	"""Appelé quand le joueur accepte le départ"""
	var confirmation = ConfirmationDialog.new()
	confirmation.dialog_text = "Êtes-vous sûr de vouloir laisser partir %s ?\nCette action est irréversible." % target_member.nom
	get_tree().root.add_child(confirmation)
	confirmation.popup_centered()
	
	confirmation.confirmed.connect(func():
		member_released.emit(target_member)
		confirmation.queue_free()
		queue_free()
	)
	
	confirmation.canceled.connect(confirmation.queue_free)

func _on_ignore_pressed():
	"""Appelé quand le joueur ignore la tentative"""
	# Probabilité que le membre parte quand même
	var leave_chance = 0.7  # Probabilité élevée si on ignore
	
	if randf() < leave_chance:
		_show_result("😕 En ignorant la situation, %s a fini par accepter l'offre concurrente..." % target_member.nom)
		get_tree().create_timer(3.0).timeout.connect(func(): member_released.emit(target_member))
		get_tree().create_timer(3.5).timeout.connect(queue_free)
	else:
		_show_result("😌 Heureusement, %s a décidé de rester malgré l'offre." % target_member.nom)
		get_tree().create_timer(3.0).timeout.connect(queue_free)

func _show_warning(message: String):
	"""Affiche un message d'avertissement"""
	var dialog = AcceptDialog.new()
	dialog.dialog_text = message
	get_tree().root.add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)

func _show_result(message: String):
	"""Affiche le résultat de l'action"""
	# Nettoyer l'interface et afficher seulement le résultat
	for child in get_children():
		child.queue_free()
	
	var result_vbox = VBoxContainer.new()
	result_vbox.add_theme_constant_override("separation", 20)
	add_child(result_vbox)
	
	var result_label = Label.new()
	result_label.text = message
	result_label.add_theme_font_size_override("font_size", 16)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_vbox.add_child(result_label)