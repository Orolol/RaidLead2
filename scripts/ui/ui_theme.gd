class_name UITheme

## Construit un Theme global cohérent appliqué à toute l'UI.
## Évite la dispersion des styles inline dans chaque fenêtre.
## Appelé une fois depuis main.gd : get_tree().root.theme = UITheme.build()

# --- Palette ---
const BG_DEEP := Color(0.10, 0.11, 0.145)
const BG_PANEL := Color(0.145, 0.155, 0.205, 0.98)
const BG_RAISED := Color(0.19, 0.20, 0.25)
const BG_RAISED_HOVER := Color(0.24, 0.26, 0.32)
const BG_RAISED_PRESSED := Color(0.15, 0.16, 0.21)
const BORDER := Color(0.28, 0.30, 0.38)
const BORDER_SUBTLE := Color(0.22, 0.23, 0.29)
const ACCENT := Color(0.30, 0.64, 0.96)
const ACCENT_DIM := Color(0.30, 0.64, 0.96, 0.55)
const TEXT := Color(0.89, 0.91, 0.94)
const TEXT_DIM := Color(0.62, 0.65, 0.71)
const TEXT_DISABLED := Color(0.42, 0.44, 0.49)

const RADIUS := 5
const FONT_NORMAL := 14
const FONT_SMALL := 12


static func _flat(bg: Color, radius: int = RADIUS, border_w: int = 0, border_col: Color = BORDER, margin: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	if border_w > 0:
		s.border_width_left = border_w
		s.border_width_right = border_w
		s.border_width_top = border_w
		s.border_width_bottom = border_w
		s.border_color = border_col
	if margin > 0:
		s.content_margin_left = margin
		s.content_margin_right = margin
		s.content_margin_top = margin
		s.content_margin_bottom = margin
	return s


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT_NORMAL

	_apply_label(t)
	_apply_rich_text(t)
	_apply_panels(t)
	_apply_buttons(t)
	_apply_inputs(t)
	_apply_lists(t)
	_apply_separators(t)
	_apply_progress(t)
	_apply_popups(t)
	_apply_windows(t)
	_apply_tooltip(t)
	return t


static func _apply_label(t: Theme) -> void:
	t.set_color("font_color", "Label", TEXT)
	t.set_font_size("font_size", "Label", FONT_NORMAL)


static func _apply_rich_text(t: Theme) -> void:
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font_size("normal_font_size", "RichTextLabel", FONT_NORMAL)


static func _apply_panels(t: Theme) -> void:
	# PanelContainer : conteneur principal des fenêtres
	t.set_stylebox("panel", "PanelContainer", _flat(BG_PANEL, RADIUS, 1, BORDER_SUBTLE, 12))
	# Panel brut
	t.set_stylebox("panel", "Panel", _flat(BG_PANEL, RADIUS, 1, BORDER_SUBTLE))


static func _apply_buttons(t: Theme) -> void:
	for type_name in ["Button", "OptionButton", "MenuButton"]:
		var normal := _flat(BG_RAISED, RADIUS, 1, BORDER, 0)
		normal.content_margin_left = 14
		normal.content_margin_right = 14
		normal.content_margin_top = 7
		normal.content_margin_bottom = 7
		var hover := _flat(BG_RAISED_HOVER, RADIUS, 1, ACCENT, 0)
		hover.content_margin_left = 14
		hover.content_margin_right = 14
		hover.content_margin_top = 7
		hover.content_margin_bottom = 7
		var pressed := _flat(BG_RAISED_PRESSED, RADIUS, 1, ACCENT, 0)
		pressed.content_margin_left = 14
		pressed.content_margin_right = 14
		pressed.content_margin_top = 7
		pressed.content_margin_bottom = 7
		var disabled := _flat(BG_RAISED.darkened(0.35), RADIUS, 1, BORDER_SUBTLE, 0)
		disabled.content_margin_left = 14
		disabled.content_margin_right = 14
		disabled.content_margin_top = 7
		disabled.content_margin_bottom = 7
		var focus := _flat(Color(0, 0, 0, 0), RADIUS, 1, ACCENT_DIM, 0)

		t.set_stylebox("normal", type_name, normal)
		t.set_stylebox("hover", type_name, hover)
		t.set_stylebox("pressed", type_name, pressed)
		t.set_stylebox("disabled", type_name, disabled)
		t.set_stylebox("focus", type_name, focus)
		t.set_color("font_color", type_name, TEXT)
		t.set_color("font_hover_color", type_name, Color.WHITE)
		t.set_color("font_pressed_color", type_name, ACCENT.lightened(0.3))
		t.set_color("font_disabled_color", type_name, TEXT_DISABLED)
		t.set_font_size("font_size", type_name, FONT_NORMAL)


static func _apply_inputs(t: Theme) -> void:
	var normal := _flat(BG_DEEP, RADIUS, 1, BORDER, 0)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 5
	normal.content_margin_bottom = 5
	var focus := _flat(BG_DEEP, RADIUS, 1, ACCENT, 0)
	focus.content_margin_left = 8
	focus.content_margin_right = 8
	focus.content_margin_top = 5
	focus.content_margin_bottom = 5
	t.set_stylebox("normal", "LineEdit", normal)
	t.set_stylebox("focus", "LineEdit", focus)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("caret_color", "LineEdit", ACCENT)


static func _apply_lists(t: Theme) -> void:
	t.set_stylebox("panel", "ItemList", _flat(BG_DEEP, RADIUS, 1, BORDER_SUBTLE, 4))
	t.set_stylebox("focus", "ItemList", _flat(Color(0, 0, 0, 0)))
	var selected := _flat(ACCENT_DIM, 3)
	var hovered := _flat(Color(1, 1, 1, 0.06), 3)
	t.set_stylebox("selected", "ItemList", selected)
	t.set_stylebox("selected_focus", "ItemList", selected)
	t.set_stylebox("hovered", "ItemList", hovered)
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_selected_color", "ItemList", Color.WHITE)
	t.set_constant("v_separation", "ItemList", 4)

	# TabContainer (utilisé par certaines fenêtres)
	t.set_stylebox("panel", "TabContainer", _flat(BG_PANEL, RADIUS, 1, BORDER_SUBTLE, 8))
	t.set_stylebox("tab_selected", "TabContainer", _flat(BG_RAISED, RADIUS, 0))
	t.set_stylebox("tab_unselected", "TabContainer", _flat(BG_DEEP, RADIUS, 0))
	t.set_stylebox("tab_hovered", "TabContainer", _flat(BG_RAISED_HOVER, RADIUS, 0))
	t.set_color("font_selected_color", "TabContainer", Color.WHITE)
	t.set_color("font_unselected_color", "TabContainer", TEXT_DIM)


static func _apply_separators(t: Theme) -> void:
	var line := StyleBoxLine.new()
	line.color = BORDER_SUBTLE
	line.thickness = 1
	t.set_stylebox("separator", "HSeparator", line)
	t.set_constant("separation", "HSeparator", 8)
	var vline := StyleBoxLine.new()
	vline.color = BORDER_SUBTLE
	vline.thickness = 1
	vline.vertical = true
	t.set_stylebox("separator", "VSeparator", vline)


static func _apply_progress(t: Theme) -> void:
	t.set_stylebox("background", "ProgressBar", _flat(BG_DEEP, RADIUS, 1, BORDER_SUBTLE))
	t.set_stylebox("fill", "ProgressBar", _flat(ACCENT, RADIUS))
	t.set_color("font_color", "ProgressBar", TEXT)


static func _apply_popups(t: Theme) -> void:
	t.set_stylebox("panel", "PopupMenu", _flat(BG_RAISED, RADIUS, 1, BORDER, 6))
	t.set_stylebox("hover", "PopupMenu", _flat(ACCENT_DIM, 3))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_color("font_separator_color", "PopupMenu", TEXT_DIM)


static func _apply_windows(t: Theme) -> void:
	for type_name in ["Window", "AcceptDialog", "ConfirmationDialog"]:
		t.set_stylebox("panel", type_name, _flat(BG_PANEL, RADIUS, 1, BORDER, 12))
		t.set_stylebox("embedded_border", type_name, _flat(BG_PANEL, RADIUS, 2, BORDER, 12))
		t.set_color("title_color", type_name, TEXT)


static func _apply_tooltip(t: Theme) -> void:
	t.set_stylebox("panel", "TooltipPanel", _flat(BG_DEEP, RADIUS, 1, ACCENT_DIM, 8))
	t.set_color("font_color", "TooltipLabel", TEXT)
