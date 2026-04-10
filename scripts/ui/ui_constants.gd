class_name UIConstants

## Constantes UI centralisées — remplace les magic numbers éparpillés dans les composants.

# --- Couleurs ---
const COLOR_BG_DARK := Color(0.1, 0.1, 0.15)
const COLOR_BG_PANEL := Color(0.12, 0.12, 0.18, 0.95)
const COLOR_BG_HEADER := Color(0.15, 0.15, 0.22, 0.95)

const COLOR_PRIMARY := Color(0.2, 0.6, 0.9)
const COLOR_SUCCESS := Color(0.3, 0.8, 0.3)
const COLOR_WARNING := Color(0.9, 0.7, 0.2)
const COLOR_ERROR := Color(0.9, 0.3, 0.3)
const COLOR_INFO := Color(0.4, 0.7, 0.9)
const COLOR_ACHIEVEMENT := Color(0.8, 0.4, 0.9)

const COLOR_TEXT := Color(0.9, 0.9, 0.9)
const COLOR_TEXT_DIM := Color(0.6, 0.6, 0.6)
const COLOR_TEXT_HIGHLIGHT := Color(1.0, 0.9, 0.5)

# Couleurs de rareté (WoW style)
const COLOR_RARITY_COMMON := Color.WHITE
const COLOR_RARITY_UNCOMMON := Color.GREEN
const COLOR_RARITY_RARE := Color(0.3, 0.5, 1.0)
const COLOR_RARITY_EPIC := Color(0.7, 0.3, 0.9)

# --- Dimensions ---
const BUTTON_HEIGHT := 50
const BUTTON_MIN_WIDTH := 150
const HEADER_HEIGHT := 40
const TITLE_BAR_HEIGHT := 30
const CORNER_RADIUS := 4
const MARGIN_SMALL := 5
const MARGIN_MEDIUM := 10
const MARGIN_LARGE := 20
const SPACING_SMALL := 5
const SPACING_MEDIUM := 10
const SPACING_LARGE := 20

# --- Fonts ---
const FONT_SIZE_SMALL := 12
const FONT_SIZE_NORMAL := 14
const FONT_SIZE_LARGE := 16
const FONT_SIZE_TITLE := 20
const FONT_SIZE_HEADER := 24

# --- Animation ---
const ANIM_DURATION_FAST := 0.15
const ANIM_DURATION_NORMAL := 0.3
const ANIM_DURATION_SLOW := 0.5

# --- Windows ---
const WINDOW_DEFAULT_SIZE := Vector2(800, 600)
const WINDOW_MIN_SIZE := Vector2(400, 300)

# --- Z-index layers ---
const Z_BACKGROUND := 0
const Z_PANELS := 10
const Z_WINDOWS := 100
const Z_POPUPS := 500
const Z_NOTIFICATIONS := 1000

# --- Helpers ---

static func create_panel_stylebox(bg_color: Color = COLOR_BG_PANEL, radius: int = CORNER_RADIUS) -> StyleBoxFlat:
	"""Crée un StyleBoxFlat standard pour les panneaux."""
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = MARGIN_MEDIUM
	style.content_margin_right = MARGIN_MEDIUM
	style.content_margin_top = MARGIN_MEDIUM
	style.content_margin_bottom = MARGIN_MEDIUM
	return style

static func create_button_stylebox(bg_color: Color = COLOR_PRIMARY, radius: int = CORNER_RADIUS) -> StyleBoxFlat:
	"""Crée un StyleBoxFlat standard pour les boutons."""
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = MARGIN_LARGE
	style.content_margin_right = MARGIN_LARGE
	style.content_margin_top = MARGIN_SMALL
	style.content_margin_bottom = MARGIN_SMALL
	return style
