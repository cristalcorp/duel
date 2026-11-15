extends Node2D

## Main menu: SOLO, LOCAL VS, ONLINE VS, SETTINGS, QUIT. Either player moves the
## cursor and validates with their shoot key. Rules: "Menu principal" table.

const SELECTION_SCENE: String = "res://Scenes/menu.tscn"
const ONLINE_SCENE: String = "res://Scenes/online.tscn"
const SERVER_SCENE: String = "res://Scenes/server.tscn"
const PLAYER_SUFFIXES: Array[String] = ["", "_p2"]
## Entries in display order; disabled ones are greyed and skipped by the cursor.
const ENTRIES: Array[Dictionary] = [
	{"label": "SOLO", "action": "solo", "enabled": true},
	{"label": "LOCAL VS", "action": "local_vs", "enabled": true},
	{"label": "ONLINE VS", "action": "online", "enabled": true},
	{"label": "SETTINGS", "action": "", "enabled": false},
	{"label": "QUIT", "action": "quit", "enabled": true},
]
const TITLE_Y: float = 36.0
const FIRST_ENTRY_Y: float = 120.0
const ENTRY_STEP: float = 32.0
const ENTRY_FONT_SIZE: int = 16
const CURSOR_SIZE: float = 8.0
const CURSOR_GAP: float = 16.0
const SELECTED_COLOR := Color(1.0, 0.84, 0.0)
const ENABLED_COLOR := Color.WHITE
const DISABLED_COLOR := Color(1, 1, 1, 0.3)

## Index in ENTRIES of the entry under the cursor.
static var selected: int = 1
var labels: Array[Label] = []
var cursor: Polygon2D


func _ready() -> void:
	# "godot --headless --path . -- --server" starts the ONLINE VS server.
	if "--server" in OS.get_cmdline_user_args():
		get_tree().change_scene_to_file.call_deferred(SERVER_SCENE)
		return
	var width: float = get_viewport_rect().size.x
	var title := make_label("DUEL", 32, width)
	title.position.y = TITLE_Y
	for i in ENTRIES.size():
		var label := make_label(ENTRIES[i]["label"], ENTRY_FONT_SIZE, width)
		label.position.y = FIRST_ENTRY_Y + i * ENTRY_STEP
		labels.append(label)
	cursor = Polygon2D.new()
	var half: float = CURSOR_SIZE / 2.0
	cursor.polygon = PackedVector2Array([Vector2(half, 0), Vector2(-half, -half), Vector2(-half, half)])
	cursor.color = SELECTED_COLOR
	add_child(cursor)
	refresh()

func make_label(text: String, font_size: int, width: float) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(width, font_size + 6)
	add_child(label)
	return label

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	for suffix in PLAYER_SUFFIXES:
		if event.is_action_pressed("move_up" + suffix):
			move_cursor(-1)
		elif event.is_action_pressed("move_down" + suffix):
			move_cursor(1)
		elif event.is_action_pressed("shoot" + suffix):
			activate(ENTRIES[selected]["action"])

## Next enabled entry in that direction, wrapping around.
func move_cursor(step: int) -> void:
	var index: int = selected
	for i in ENTRIES.size():
		index = posmod(index + step, ENTRIES.size())
		if ENTRIES[index]["enabled"]:
			break
	selected = index
	refresh()

func activate(action: String) -> void:
	match action:
		"solo":
			GameSettings.solo = true
			get_tree().change_scene_to_file(SELECTION_SCENE)
		"local_vs":
			GameSettings.solo = false
			get_tree().change_scene_to_file(SELECTION_SCENE)
		"online":
			get_tree().change_scene_to_file(ONLINE_SCENE)
		"quit":
			get_tree().quit()

func refresh() -> void:
	for i in labels.size():
		var label: Label = labels[i]
		if not ENTRIES[i]["enabled"]:
			label.modulate = DISABLED_COLOR
		elif i == selected:
			label.modulate = SELECTED_COLOR
		else:
			label.modulate = ENABLED_COLOR
	var label: Label = labels[selected]
	var text_width: float = label.get_theme_font("font").get_string_size(
		label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, ENTRY_FONT_SIZE).x
	cursor.position = Vector2(
		(label.size.x - text_width) / 2.0 - CURSOR_GAP,
		label.position.y + label.size.y / 2.0)
