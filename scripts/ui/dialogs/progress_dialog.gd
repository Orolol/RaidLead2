extends BaseDialog
class_name ProgressDialog

# Dialogue de progression pour opérations longues avec possibilité d'annulation
# Utilisé pour chargement, traitement, export, etc.

# Configuration
@export var progress_text: String = "Processing..." : set = set_progress_text
@export var show_percentage: bool = true : set = set_show_percentage
@export var show_cancel_button: bool = true : set = set_show_cancel_button
@export var show_details: bool = false : set = set_show_details
@export var auto_close_on_complete: bool = false
@export var close_delay: float = 1.5  # Délai avant fermeture auto

# Éléments UI
var content_container: VBoxContainer
var main_label: Label
var progress_bar: CustomProgressBar
var percentage_label: Label
var details_label: RichTextLabel
var details_scroll: ScrollContainer
var cancel_button: Button

# État de progression
var current_progress: float = 0.0
var is_complete: bool = false
var is_cancelled: bool = false
var operation_id: String = ""
var start_time: float = 0.0

# Callbacks
var cancel_callback: Callable
var complete_callback: Callable
var progress_callback: Callable

# Signaux
signal progress_updated(progress: float, text: String)
signal operation_cancelled()
signal operation_completed()

func _ready() -> void:
	super._ready()
	_setup_progress_dialog()

func _setup_progress_dialog() -> void:
	"""Configure le dialogue de progression"""
	
	# Taille et propriétés
	dialog_size = Vector2(450, 350 if show_details else 180)
	set_dialog_size(dialog_size)
	
	# Pas redimensionnable par défaut
	set_resizable(false)
	
	# Pas de bouton fermer standard
	set_closable(false)
	
	# Créer le contenu
	_create_content()
	
	# Créer les boutons si nécessaire
	if show_cancel_button:
		_create_cancel_button()
	
	# Démarrer le chrono
	start_time = Time.get_ticks_msec() / 1000.0

func _create_content() -> void:
	"""Crée le contenu du dialogue"""

	content_container = VBoxContainer.new()
	content_container.add_theme_constant_override("separation", 15)
	set_content(content_container)
	
	# Label principal
	main_label = Label.new()
	main_label.text = progress_text
	main_label.add_theme_font_size_override("font_size", 14)
	main_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_container.add_child(main_label)
	
	# Barre de progression
	progress_bar = CustomProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(400, 20)
	progress_bar.show_text = false  # On gère le texte séparément
	progress_bar.animate_changes = true
	progress_bar.set_range(0, 100)
	content_container.add_child(progress_bar)
	
	# Label de pourcentage
	if show_percentage:
		percentage_label = Label.new()
		percentage_label.text = "0%"
		percentage_label.add_theme_font_size_override("font_size", 12)
		percentage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content_container.add_child(percentage_label)
	
	# Zone de détails
	if show_details:
		var details_header := Label.new()
		details_header.text = "Détails :"
		details_header.add_theme_font_size_override("font_size", 12)
		content_container.add_child(details_header)
		
		details_scroll = ScrollContainer.new()
		details_scroll.custom_minimum_size = Vector2(0, 100)
		content_container.add_child(details_scroll)
		
		details_label = RichTextLabel.new()
		details_label.bbcode_enabled = true
		details_label.scroll_following = true
		details_label.fit_content = true
		details_scroll.add_child(details_label)

func _create_cancel_button() -> void:
	"""Crée le bouton d'annulation"""
	cancel_button = add_button("Annuler", _on_cancel_pressed, ButtonStyle.SECONDARY)

# ==================== SETTERS ====================

func set_progress_text(text: String) -> void:
	progress_text = text
	if main_label:
		main_label.text = text

func set_show_percentage(should_show: bool) -> void:
	show_percentage = should_show
	if percentage_label:
		percentage_label.visible = should_show

func set_show_cancel_button(should_show: bool) -> void:
	show_cancel_button = should_show
	if cancel_button:
		cancel_button.visible = should_show

func set_show_details(should_show: bool) -> void:
	show_details = should_show
	if is_inside_tree():
		_setup_progress_dialog()

# ==================== API PUBLIQUE ====================

func set_progress(progress: float, text: String = "") -> void:
	"""Met à jour le progrès (0.0 à 1.0)"""
	current_progress = clamp(progress, 0.0, 1.0)

	# Mettre à jour la barre
	progress_bar.set_value(current_progress * 100.0)

	# Mettre à jour le pourcentage
	if percentage_label:
		percentage_label.text = "%.1f%%" % (current_progress * 100.0)

	# Mettre à jour le texte si fourni
	if text != "":
		set_progress_text(text)

	# Vérifier si terminé
	if current_progress >= 1.0 and not is_complete:
		_on_progress_complete()

	progress_updated.emit(current_progress, text)

func set_progress_percentage(percentage: float, text: String = "") -> void:
	"""Met à jour le progrès (0 à 100)"""
	set_progress(percentage / 100.0, text)

func add_progress(delta: float, text: String = "") -> void:
	"""Ajoute au progrès actuel"""
	set_progress(current_progress + delta, text)

func add_detail(detail: String, color: Color = Color.WHITE) -> void:
	"""Ajoute une ligne de détail"""
	if not details_label:
		return

	var timestamp: String = Time.get_time_string_from_system()
	var color_hex: String = "#%02x%02x%02x" % [int(color.r * 255), int(color.g * 255), int(color.b * 255)]
	var formatted_detail: String = "[color=#666666][%s][/color] [color=%s]%s[/color]\n" % [timestamp, color_hex, detail]

	details_label.append_text(formatted_detail)

func add_error_detail(error: String) -> void:
	"""Ajoute un détail d'erreur"""
	add_detail("ERREUR: " + error, Color.RED)

func add_warning_detail(warning: String) -> void:
	"""Ajoute un détail d'avertissement"""
	add_detail("ATTENTION: " + warning, Color.YELLOW)

func add_info_detail(info: String) -> void:
	"""Ajoute un détail d'information"""
	add_detail(info, Color.CYAN)

func add_success_detail(success: String) -> void:
	"""Ajoute un détail de succès"""
	add_detail("SUCCÈS: " + success, Color.GREEN)

func set_indeterminate(is_indeterminate: bool = true) -> void:
	"""Mode indéterminé (barre animée sans valeur fixe)"""
	if is_indeterminate:
		# Créer une animation de barre indéterminée
		var tween := create_tween()
		tween.set_loops()
		tween.tween_property(progress_bar, "value", 100.0, 1.5)
		tween.tween_property(progress_bar, "value", 0.0, 1.5)

		if percentage_label:
			percentage_label.text = "Processing..."

func complete_operation(final_text: String = "Terminé !") -> void:
	"""Marque l'opération comme terminée"""
	set_progress(1.0, final_text)

func cancel_operation() -> void:
	"""Annule l'opération"""
	if is_cancelled or is_complete:
		return

	is_cancelled = true

	if cancel_callback.is_valid():
		cancel_callback.call()

	set_progress_text("Annulation en cours...")
	add_warning_detail("Opération annulée par l'utilisateur")

	operation_cancelled.emit()

	# Fermer après un délai
	await get_tree().create_timer(1.0).timeout
	close_dialog({"cancelled": true})

func set_callbacks(on_cancel: Callable = Callable(), on_complete: Callable = Callable(), on_progress: Callable = Callable()) -> void:
	"""Définit les callbacks"""
	cancel_callback = on_cancel
	complete_callback = on_complete
	progress_callback = on_progress

func get_elapsed_time() -> float:
	"""Retourne le temps écoulé depuis le début"""
	return (Time.get_ticks_msec() / 1000.0) - start_time

func get_estimated_time_remaining() -> float:
	"""Estime le temps restant basé sur le progrès"""
	if current_progress <= 0.0:
		return 0.0

	var elapsed: float = get_elapsed_time()
	var total_estimated: float = elapsed / current_progress
	return total_estimated - elapsed

func update_time_display() -> void:
	"""Met à jour l'affichage du temps"""
	var elapsed: float = get_elapsed_time()
	var remaining: float = get_estimated_time_remaining()

	var time_text: String = "Temps écoulé: %s" % _format_time(elapsed)

	if current_progress > 0.0 and current_progress < 1.0:
		time_text += " | Estimé restant: %s" % _format_time(remaining)

	add_info_detail(time_text)

func _format_time(seconds: float) -> String:
	"""Formate le temps en format lisible"""
	var mins: int = int(seconds) / 60
	var secs: int = int(seconds) % 60
	return "%02d:%02d" % [mins, secs]

# ==================== GESTION DES ÉVÉNEMENTS ====================

func _on_cancel_pressed() -> void:
	"""Bouton annuler pressé"""
	cancel_operation()

func _on_progress_complete() -> void:
	"""Progression terminée"""
	if is_complete:
		return

	is_complete = true

	var elapsed: float = get_elapsed_time()
	add_success_detail("Opération terminée en %s" % _format_time(elapsed))

	if complete_callback.is_valid():
		complete_callback.call()

	operation_completed.emit()

	# Masquer le bouton annuler
	if cancel_button:
		cancel_button.visible = false

	# Ajouter bouton fermer
	add_button("Fermer", func(): close_dialog({"completed": true}), ButtonStyle.PRIMARY)

	# Fermeture automatique
	if auto_close_on_complete:
		await get_tree().create_timer(close_delay).timeout
		if not is_cancelled:
			close_dialog({"completed": true})

# ==================== GESTION CLAVIER ====================

func _unhandled_key_input(event: InputEvent) -> void:
	"""Gère les raccourcis clavier"""
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				if show_cancel_button and not is_complete:
					cancel_operation()
			KEY_ENTER:
				if is_complete:
					close_dialog({"completed": true})

# ==================== MÉTHODES STATIQUES ====================

static func show_loading(title: String = "Chargement", text: String = "Chargement en cours...", parent: Node = null) -> ProgressDialog:
	"""Affiche un dialogue de chargement indéterminé"""
	var dialog := ProgressDialog.new()
	dialog.dialog_title = title
	dialog.set_progress_text(text)
	dialog.set_show_cancel_button(false)
	dialog.set_indeterminate(true)
	
	if parent:
		parent.add_child(dialog)
	else:
		Engine.get_main_loop().root.add_child(dialog)
	
	dialog.open_dialog()
	return dialog

static func show_progress(title: String, text: String = "Processing...", cancellable: bool = true, show_details_panel: bool = false, parent: Node = null) -> ProgressDialog:
	"""Affiche un dialogue de progression"""
	var dialog := ProgressDialog.new()
	dialog.dialog_title = title
	dialog.set_progress_text(text)
	dialog.set_show_cancel_button(cancellable)
	dialog.set_show_details(show_details_panel)
	
	if parent:
		parent.add_child(dialog)
	else:
		Engine.get_main_loop().root.add_child(dialog)
	
	dialog.open_dialog()
	return dialog

static func show_export_progress(filename: String, parent: Node = null) -> ProgressDialog:
	"""Dialogue spécialisé pour l'export"""
	var dialog := show_progress("Export en cours", "Export de %s..." % filename, true, true, parent)
	dialog.auto_close_on_complete = true
	return dialog

static func show_import_progress(filename: String, parent: Node = null) -> ProgressDialog:
	"""Dialogue spécialisé pour l'import"""
	var dialog := show_progress("Import en cours", "Import de %s..." % filename, true, true, parent)
	return dialog

static func show_download_progress(url: String, parent: Node = null) -> ProgressDialog:
	"""Dialogue spécialisé pour le téléchargement"""
	var dialog := show_progress("Téléchargement", "Téléchargement de %s..." % url.get_file(), true, true, parent)
	return dialog

# ==================== INTÉGRATION AVEC HTTPDOWNLOADER ====================

func connect_to_http_request(http_request: HTTPRequest) -> void:
	"""Connecte le dialogue à un HTTPRequest pour téléchargement"""
	if not http_request:
		return

	http_request.request_completed.connect(_on_http_completed)
	# Note: HTTPRequest n'a pas de signal de progression natif
	# Il faudrait utiliser un HTTPDownloader personnalisé

func _on_http_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	"""Requête HTTP terminée"""
	if response_code == 200:
		add_success_detail("Téléchargement réussi (%d bytes)" % body.size())
		complete_operation("Téléchargement terminé")
	else:
		add_error_detail("Erreur HTTP: %d" % response_code)
		set_progress_text("Erreur de téléchargement")

# ==================== INTÉGRATION AVEC THREAD ====================

func connect_to_worker_thread(_worker_thread: Thread, _progress_callback_func: Callable) -> void:
	"""Connecte le dialogue à un thread de travail"""
	# Cette méthode nécessiterait un système de communication thread-safe
	# avec des signaux ou un mutex pour les updates de progression
	pass

# ==================== TEMPLATES D'UTILISATION ====================

func setup_for_dungeon_simulation() -> void:
	"""Configuration pour simulation de donjon"""
	dialog_title = "Simulation de donjon"
	set_progress_text("Préparation du groupe...")
	set_show_details(true)
	set_show_cancel_button(true)
	
	# Étapes typiques
	add_info_detail("Vérification de la composition du groupe")
	add_info_detail("Calcul des statistiques")
	add_info_detail("Initialisation des combats de boss")

func setup_for_guild_analysis() -> void:
	"""Configuration pour analyse de guilde"""
	dialog_title = "Analyse de la guilde"
	set_progress_text("Analyse des membres en cours...")
	set_show_details(true)
	set_show_cancel_button(false)

	add_info_detail("Collecte des données des membres")
	add_info_detail("Calcul des statistiques de performance")
	add_info_detail("Génération du rapport")

func setup_for_save_operation() -> void:
	"""Configuration pour sauvegarde"""
	dialog_title = "Sauvegarde"
	set_progress_text("Sauvegarde en cours...")
	set_show_cancel_button(false)
	auto_close_on_complete = true