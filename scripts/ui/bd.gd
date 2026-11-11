class_name BD
extends RefCounted
## Charte de l'interface : couleurs, polices et habillages « cahier d'écolier ».

const INK := Color("1d1d1d")
const PAPER := Color("fbf6e6")
const RED := Color("e23b30")
const YELLOW := Color("ffd23c")
const TEAM_COLORS: Array[Color] = [Color("e8433a"), Color("2f7fe6"), Color("36b25a"), Color("f0a020")]
const TEACHER_COLOR := Color("8a3fd1")
const TEAM_NAMES := ["rouge", "bleue", "verte", "jaune"]

static var _fonts := {}


static func team_color(team: int) -> Color:
	return TEAM_COLORS[team % TEAM_COLORS.size()] if team >= 0 else Color("f4efe2")


static func team_name(team: int) -> String:
	return "Bande " + TEAM_NAMES[team % TEAM_NAMES.size()]


## Police de titre et d'onomatopée.
static func title_font() -> Font:
	return _font("res://assets/fonts/Bangers-Regular.ttf")


## Police manuscrite du texte courant.
static func hand_font() -> Font:
	return _font("res://assets/fonts/PatrickHand-Regular.ttf")


static func _font(p: String) -> Font:
	if not _fonts.has(p):
		_fonts[p] = load(p) if ResourceLoader.exists(p) else ThemeDB.fallback_font
	return _fonts[p]


static func label(text: String, size: int, color: Color = INK, title: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	style_label(l, size, color, title)
	return l


static func style_label(l: Label, size: int, color: Color = INK, title: bool = false) -> void:
	l.add_theme_font_override("font", title_font() if title else hand_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)


static func outline(l: Control, size: int, color: Color = INK) -> void:
	l.add_theme_color_override("font_outline_color", color)
	l.add_theme_constant_override("outline_size", size)


## Feuille de cahier : papier à carreaux, bord à l'encre, ombre portée.
static func paper_box(margin: int = 14, tint: Color = Color.WHITE) -> StyleBox:
	var tex := GameAssets.ui_texture("textures", "papier.png")
	if tex == null:
		return flat_box(PAPER, margin)
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.modulate_color = tint
	sb.set_content_margin_all(margin)
	return sb


static func flat_box(color: Color, margin: int = 10, radius: int = 10, border: int = 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = INK
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(3, 4)
	sb.anti_aliasing = true
	return sb


## Panneau « feuille de cahier » avec cadre à l'encre.
static func paper_panel(margin: int = 14) -> PanelContainer:
	var frame := PanelContainer.new()
	var border := flat_box(PAPER, 0, 6, 4)
	frame.add_theme_stylebox_override("panel", border)
	var inner := PanelContainer.new()
	inner.add_theme_stylebox_override("panel", paper_box(margin))
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(inner)
	frame.set_meta("inner", inner)
	return frame


static func content(panel: PanelContainer) -> PanelContainer:
	return panel.get_meta("inner")


## Bouton autocollant : couleur franche, bord à l'encre, s'enfonce au clic.
static func sticker(text: String, color: Color, size: int = 26, text_color: Color = Color.WHITE) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", title_font())
	b.add_theme_font_size_override("font_size", size)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, text_color)
	b.add_theme_color_override("font_disabled_color", Color(text_color, 0.5))
	b.add_theme_color_override("font_outline_color", INK)
	b.add_theme_constant_override("outline_size", 6 if text_color != INK else 0)
	var normal := flat_box(color, 10, 12, 4)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	var hover := normal.duplicate()
	hover.bg_color = color.lightened(0.18)
	var pressed := normal.duplicate()
	pressed.bg_color = color.darkened(0.15)
	pressed.shadow_size = 1
	pressed.shadow_offset = Vector2(1, 1)
	var disabled := normal.duplicate()
	disabled.bg_color = color.lerp(Color("9a9a9a"), 0.7)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b
