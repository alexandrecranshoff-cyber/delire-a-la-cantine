class_name SavePanel
extends ColorRect
## Fenêtre des sauvegardes : choisir un emplacement pour sauvegarder la partie, ou une
## sauvegarde à reprendre. Se ferme d'un clic à côté, avec Échap ou par le bouton FERMER.

signal chosen(key: String)

var saving := true
var _status: Label


func _init(p_saving: bool) -> void:
	saving = p_saving


func _ready() -> void:
	color = Color(0, 0, 0, 0.55)
	z_index = 50  # au-dessus du menu et du bandeau
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			queue_free())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var sheet := BD.paper_panel(26)
	sheet.custom_minimum_size = Vector2(900, 0)
	center.add_child(sheet)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	BD.content(sheet).add_child(col)
	col.add_child(BD.label("SAUVEGARDER LA PARTIE" if saving else "REPRENDRE UNE PARTIE", 46, BD.RED, true))
	var slots := SaveSlots.all()
	for key in SaveSlots.KEYS:
		# La reprise automatique ne s'écrit pas à la main.
		if saving and key == "auto":
			continue
		var entry: Dictionary = slots.get(key, {})
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		col.add_child(row)
		var b := BD.sticker(SaveSlots.title(key), Color("2f7fe6") if key != "auto" else Color("7a5fc0"), 24)
		b.custom_minimum_size = Vector2(260, 0)
		b.disabled = not saving and entry.is_empty()
		var k: String = key
		b.pressed.connect(func(): chosen.emit(k))
		row.add_child(b)
		var info := BD.label(SaveSlots.describe(entry), 24)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
	_status = BD.label("Clique sur un emplacement : une sauvegarde déjà là est remplacée." if saving else "La partie reprend là où elle a été sauvegardée.", 22, Color("3a5fb0"))
	col.add_child(_status)
	var close := BD.sticker("FERMER", Color("6b6b6b"), 22)
	close.pressed.connect(queue_free)
	col.add_child(close)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		queue_free()
