extends Control
class_name GameMenuBar

signal guild_hub_button_pressed
signal competition_hub_button_pressed
signal business_hub_button_pressed
signal recruitment_hub_button_pressed
signal advice_hub_button_pressed

var _buttons: Dictionary = {}

const PHASE_LOCKS := {"hub_business": 2}

const ACTIVE_WINDOW_TO_HUB := {
	"hub_guild": "hub_guild",
	"hub_competition": "hub_competition",
	"hub_business": "hub_business",
	"hub_recruitment": "hub_recruitment",
	"hub_advice": "hub_advice",
	"personnage": "hub_guild",
	"guilde": "hub_guild",
	"cohesion": "hub_guild",
	"organisation": "hub_competition",
	"monde": "hub_competition",
	"national": "hub_business",
	"esport": "hub_business",
	"conseils": "hub_advice",
}

const SHORTCUTS := {
	"hub_guild": "G",
	"hub_competition": "C",
	"hub_business": "B",
	"hub_recruitment": "R",
	"hub_advice": "A",
}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	custom_minimum_size.y = 80

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	panel.add_child(hbox)

	hbox.add_child(_create_menu_button("Guilde", "hub_guild", _on_guild_hub_pressed))
	hbox.add_child(_create_menu_button("Competition", "hub_competition", _on_competition_hub_pressed))
	hbox.add_child(_create_menu_button("Business", "hub_business", _on_business_hub_pressed))
	hbox.add_child(_create_menu_button("Recrutement", "hub_recruitment", _on_recruitment_hub_pressed))
	hbox.add_child(_create_menu_button("Conseil", "hub_advice", _on_advice_hub_pressed))

	if PhaseManager and not PhaseManager.phase_changed.is_connected(_on_phase_changed_lock):
		PhaseManager.phase_changed.connect(_on_phase_changed_lock)
	_update_phase_locks()

func _on_phase_changed_lock(_new_phase, _old_phase) -> void:
	_update_phase_locks()

func _update_phase_locks() -> void:
	if not PhaseManager:
		return
	var current: int = PhaseManager.get_current_phase()
	for wname in PHASE_LOCKS:
		if not _buttons.has(wname):
			continue
		var btn: Button = _buttons[wname]
		var locked: bool = current < int(PHASE_LOCKS[wname])
		btn.disabled = locked
		btn.visible = not locked
		btn.tooltip_text = "Debloque en %s" % PhaseManager.get_phase_name(PHASE_LOCKS[wname]) if locked else _shortcut_tooltip(wname, btn.text)

func _shortcut_tooltip(window_name: String, text: String) -> String:
	if SHORTCUTS.has(window_name):
		return "%s (Ctrl+%s)" % [text, SHORTCUTS[window_name]]
	return text

func _create_menu_button(text: String, window_name: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(160, 50)
	button.tooltip_text = _shortcut_tooltip(window_name, text)
	button.pressed.connect(callback)
	button.toggle_mode = true
	_buttons[window_name] = button
	return button

func set_active_window(window_name: String) -> void:
	var active_button_name: String = ACTIVE_WINDOW_TO_HUB.get(window_name, window_name)
	for wname in _buttons:
		var btn: Button = _buttons[wname]
		var is_active: bool = wname == active_button_name
		btn.button_pressed = is_active
		btn.modulate = Color(1, 1, 1, 1) if is_active else Color(0.60, 0.63, 0.70, 1.0)

func _is_window_locked(window_name: String) -> bool:
	if not PHASE_LOCKS.has(window_name):
		return false
	if not PhaseManager:
		return false
	return PhaseManager.get_current_phase() < int(PHASE_LOCKS[window_name])

func _on_guild_hub_pressed() -> void:
	guild_hub_button_pressed.emit()

func _on_competition_hub_pressed() -> void:
	competition_hub_button_pressed.emit()

func _on_business_hub_pressed() -> void:
	if _is_window_locked("hub_business"):
		return
	business_hub_button_pressed.emit()

func _on_recruitment_hub_pressed() -> void:
	recruitment_hub_button_pressed.emit()

func _on_advice_hub_pressed() -> void:
	advice_hub_button_pressed.emit()

# Compatibility aliases for old shortcuts/tests while the legacy windows still exist.
func _on_personnage_pressed() -> void:
	_on_guild_hub_pressed()

func _on_guilde_pressed() -> void:
	_on_guild_hub_pressed()

func _on_monde_pressed() -> void:
	_on_competition_hub_pressed()

func _on_organisation_pressed() -> void:
	_on_competition_hub_pressed()

func _on_national_pressed() -> void:
	_on_business_hub_pressed()

func _on_esport_pressed() -> void:
	_on_business_hub_pressed()

func _on_cohesion_pressed() -> void:
	_on_guild_hub_pressed()

func _on_conseils_pressed() -> void:
	_on_advice_hub_pressed()
