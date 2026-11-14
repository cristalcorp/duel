extends Node2D

## Selection screen: each player picks a character (up / down) and a colour
## (left / right) with their own game keys, then presses shoot to be ready.
## The game starts when both are ready. Rules: "Sélection des persos" table.

const ARENA_SCENE: String = "res://Scenes/arena.tscn"
const PLAYER_SUFFIXES: Array[String] = ["", "_p2"]
const SHOOT_KEY_NAMES: Array[String] = ["SPACE", "ENTER"]
## Horizontal centre of each player's column.
const COLUMN_X: Array[float] = [160.0, 480.0]
const TITLE_Y: float = 16.0
const CHARACTER_ARROW_UP_Y: float = 46.0
const CHARACTER_NAME_Y: float = 52.0
const CHARACTER_ARROW_DOWN_Y: float = 80.0
const PREVIEW_Y: float = 160.0
const COLOR_ROW_Y: float = 230.0
const COLOR_SWATCH_SIZE: float = 16.0
const COLOR_ARROW_X: float = 30.0
const READY_Y: float = 268.0
const ARROW_SIZE: float = 8.0
const SPRITE_SCALE: float = 5.0

var ready_flags: Array[bool] = [false, false]
var name_labels: Array[Label] = []
var previews: Array[AnimatedSprite2D] = []
var swatches: Array[ColorRect] = []
var ready_labels: Array[Label] = []
## Arrows are hidden while the player is ready, to show the choices are locked.
var arrows: Array[Array] = [[], []]
var starting: bool = false


func _ready() -> void:
	for player in 2:
		build_column(player)
		refresh(player)

func build_column(player: int) -> void:
	var x: float = COLUMN_X[player]
	add_label("PLAYER %d" % (player + 1), x, TITLE_Y, 16)
	add_arrow(player, Vector2(x, CHARACTER_ARROW_UP_Y), Vector2.UP)
	name_labels.append(add_label("", x, CHARACTER_NAME_Y, 14))
	add_arrow(player, Vector2(x, CHARACTER_ARROW_DOWN_Y), Vector2.DOWN)

	var preview := AnimatedSprite2D.new()
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.scale = Vector2.ONE * SPRITE_SCALE
	preview.position = Vector2(x, PREVIEW_Y)
	preview.flip_h = player == 1
	add_child(preview)
	previews.append(preview)

	var swatch := ColorRect.new()
	swatch.size = Vector2.ONE * COLOR_SWATCH_SIZE
	swatch.position = Vector2(x, COLOR_ROW_Y) - swatch.size / 2.0
	add_child(swatch)
	swatches.append(swatch)
	add_arrow(player, Vector2(x - COLOR_ARROW_X, COLOR_ROW_Y), Vector2.LEFT)
	add_arrow(player, Vector2(x + COLOR_ARROW_X, COLOR_ROW_Y), Vector2.RIGHT)

	ready_labels.append(add_label("", x, READY_Y, 14))

## A label horizontally centred on x, its top at y.
func add_label(text: String, x: float, y: float, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(300, font_size + 6)
	label.position = Vector2(x - label.size.x / 2.0, y)
	add_child(label)
	return label

## A small triangle centred on centre, pointing towards direction.
func add_arrow(player: int, centre: Vector2, direction: Vector2) -> void:
	var side := direction.orthogonal()
	var half: float = ARROW_SIZE / 2.0
	var arrow := Polygon2D.new()
	arrow.polygon = PackedVector2Array([
		centre + direction * half,
		centre - direction * half + side * half,
		centre - direction * half - side * half,
	])
	add_child(arrow)
	arrows[player].append(arrow)

func _unhandled_input(event: InputEvent) -> void:
	if starting or event.is_echo():
		return
	for player in 2:
		var suffix: String = PLAYER_SUFFIXES[player]
		if event.is_action_pressed("shoot" + suffix):
			ready_flags[player] = not ready_flags[player]
		elif ready_flags[player]:
			continue
		elif event.is_action_pressed("move_up" + suffix):
			change_character(player, -1)
		elif event.is_action_pressed("move_down" + suffix):
			change_character(player, 1)
		elif event.is_action_pressed("move_left" + suffix):
			change_color(player, -1)
		elif event.is_action_pressed("move_right" + suffix):
			change_color(player, 1)
		else:
			continue
		refresh(player)
	if ready_flags.all(func(r: bool) -> bool: return r):
		start_game()

func change_character(player: int, step: int) -> void:
	var count: int = GameSettings.CHARACTERS.size()
	GameSettings.set_character(player, posmod(GameSettings.get_character(player) + step, count))

## Next colour in the palette, skipping the other player's colour.
func change_color(player: int, step: int) -> void:
	var palette: Array[Color] = GameSettings.PALETTE
	var other: Color = GameSettings.get_color(1 - player)
	var index: int = palette.find(GameSettings.get_color(player))
	index = posmod(index + step, palette.size())
	if palette[index] == other:
		index = posmod(index + step, palette.size())
	GameSettings.set_color(player, palette[index])

func refresh(player: int) -> void:
	var character: Dictionary = GameSettings.CHARACTERS[GameSettings.get_character(player)]
	var color: Color = GameSettings.get_color(player)
	name_labels[player].text = character["name"]
	var preview: AnimatedSprite2D = previews[player]
	preview.sprite_frames = get_sprite_frames(character["scene"])
	preview.play("Idle")
	preview.modulate = color
	swatches[player].color = color
	for arrow in arrows[player]:
		arrow.visible = not ready_flags[player]
	ready_labels[player].text = "READY" if ready_flags[player] \
		else "%s: READY" % SHOOT_KEY_NAMES[player]
	ready_labels[player].modulate = color if ready_flags[player] else Color(1, 1, 1, 0.6)

## The character's animations, read from its scene without running it.
func get_sprite_frames(scene: PackedScene) -> SpriteFrames:
	var character: Node = scene.instantiate()
	var frames: SpriteFrames = character.get_node("AnimatedSprite2D").sprite_frames
	character.free()
	return frames

func start_game() -> void:
	starting = true
	# Wait until the shoot key is released, so it does not fire a shot as soon
	# as the game starts.
	while Input.is_action_pressed("shoot") or Input.is_action_pressed("shoot_p2"):
		await get_tree().process_frame
	get_tree().change_scene_to_file(ARENA_SCENE)
