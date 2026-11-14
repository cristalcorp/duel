extends Node2D

## Videopac sprite colours, black excluded (invisible on the background).
## Exact RGB values of the console are unknown: pure colours are used.
const PALETTE: Array[Color] = [
	Color(1, 1, 1), Color(1, 0, 0), Color(0, 1, 0), Color(0, 0, 1),
	Color(1, 1, 0), Color(0, 1, 1), Color(1, 0, 1),
]
## Band at the bottom of the screen holding the ammo display.
const HUD_HEIGHT: float = 16.0
const AMMO_ICON_SIZE: float = 8.0
const AMMO_ICON_GAP: float = 4.0
## Space between the lives counter and the first ammo square.
const LIVES_GAP: float = 16.0
## Extra stroke thickness of the bold lives counter (0 = regular font).
const LIVES_EMBOLDEN: float = 1.0
## Raises the lives counter so its digit is centred on the ammo squares: Label
## centres the whole line (with room below the baseline), not the digit itself.
## Measured on a rendered frame.
const LIVES_Y_OFFSET: float = -2.0
## Tree footprint (visible pixels) relative to the tree's position, in game pixels.
const TREE_FOOTPRINT := Rect2(-20, 5, 40, 35)
## Free space kept around each tree and around each cowboy's start position.
## Two trees end up at least 2 × TREE_GAP apart, wider than a cowboy's body (40 px).
const TREE_GAP: float = 25.0
const START_GAP: float = 30.0
const MAX_PLACEMENT_TRIES: int = 1000
const TREE_SCENE: PackedScene = preload("res://Scenes/tree.tscn")

@export var tree_count: int = 8
@export var lives: int = 5
## Wait after a death before the next round starts, in seconds.
@export var round_end_delay: float = 2.0

@onready var players: Array[Node] = [$Player1, $Player2]
var lives_left: Array[int] = []
var lives_labels: Array[Label] = []
var round_ending: bool = false
var sudden_death: bool = false
var banner: Label


func _ready() -> void:
	banner = make_label(Color.WHITE, 16)
	banner.size = Vector2(get_viewport_rect().size.x, 20)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.z_index = 1
	add_child(banner)
	for i in players.size():
		var player: Node = players[i]
		player.bottom_margin = HUD_HEIGHT
		add_ammo_display(player)
		lives_left.append(lives)
		player.died.connect(_on_player_died.bind(i))
	spawn_trees()

## A death costs a life; the round ends round_end_delay later, so the survivor
## can still play (and die) meanwhile.
func _on_player_died(index: int) -> void:
	lives_left[index] = maxi(lives_left[index] - 1, 0)
	lives_labels[index].text = str(lives_left[index])
	if round_ending:
		return
	round_ending = true
	await get_tree().create_timer(round_end_delay).timeout
	round_ending = false
	end_round()

## Winner when exactly one player is out of lives (or, in sudden death, when
## exactly one died); sudden death when both are out; otherwise a new round.
func end_round() -> void:
	var out: Array[int] = []
	for i in players.size():
		var lost: bool = players[i].dead if sudden_death else lives_left[i] == 0
		if lost:
			out.append(i)
	if out.size() == 1:
		var winner: int = 1 - out[0]
		banner.text = "PLAYER %d WINS" % (winner + 1)
		banner.position.y = get_viewport_rect().size.y / 2.0 - 10.0
		get_tree().paused = true
		return
	if out.size() == 2:
		sudden_death = true
		banner.text = "Mort subite !"
		banner.position.y = 4.0
	start_round()

func start_round() -> void:
	for node in get_tree().get_nodes_in_group("bullets") + get_tree().get_nodes_in_group("trees"):
		node.queue_free()
	for player in players:
		player.reset()
	await get_tree().process_frame
	spawn_trees()

func make_label(color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

## Places tree_count trees at random, not overlapping each other or a cowboy's
## start. Exactly one tree per player colour; the others never take a player colour.
func spawn_trees() -> void:
	var play_area: Rect2 = get_viewport_rect().grow_side(SIDE_BOTTOM, -HUD_HEIGHT)
	var taken: Array[Rect2] = []
	for player in players:
		var body: Rect2 = player.get_node("Hurtbox/CollisionShape2D").shape.get_rect()
		taken.append(Rect2(player.position + body.position * player.scale,
			body.size * player.scale).grow(START_GAP))

	var colors: Array[Color] = []
	for player in players:
		colors.append(player.player_color)
	var others: Array[Color] = PALETTE.filter(func(c: Color) -> bool: return not c in colors)
	while colors.size() < tree_count:
		colors.append(others.pick_random())

	var tries := 0
	for color in colors:
		while tries < MAX_PLACEMENT_TRIES:
			tries += 1
			var pos := Vector2(
				randf_range(play_area.position.x - TREE_FOOTPRINT.position.x,
					play_area.end.x - TREE_FOOTPRINT.end.x),
				randf_range(play_area.position.y - TREE_FOOTPRINT.position.y,
					play_area.end.y - TREE_FOOTPRINT.end.y))
			var footprint := Rect2(pos + TREE_FOOTPRINT.position, TREE_FOOTPRINT.size).grow(TREE_GAP)
			if taken.any(func(r: Rect2) -> bool: return r.intersects(footprint)):
				continue
			taken.append(footprint)
			var tree: Node2D = TREE_SCENE.instantiate()
			tree.position = pos
			tree.color = color
			add_child(tree)
			break
	if get_tree_count() < tree_count:
		push_warning("Only %d of %d trees fit on screen." % [get_tree_count(), tree_count])

func get_tree_count() -> int:
	return get_tree().get_nodes_in_group("trees").filter(
		func(t: Node) -> bool: return not t.is_queued_for_deletion()).size()

## Row of ammo squares at the bottom of the screen, centred under the player's start.
func add_ammo_display(player: Node) -> void:
	var row := Node2D.new()
	add_child(row)
	var width: float = player.max_ammo * AMMO_ICON_SIZE + (player.max_ammo - 1) * AMMO_ICON_GAP
	var top: float = get_viewport_rect().end.y - HUD_HEIGHT + (HUD_HEIGHT - AMMO_ICON_SIZE) / 2.0
	row.position = Vector2(player.position.x - width / 2.0, top)
	for i in player.max_ammo:
		var icon := ColorRect.new()
		icon.color = player.player_color
		icon.size = Vector2.ONE * AMMO_ICON_SIZE
		icon.position.x = i * (AMMO_ICON_SIZE + AMMO_ICON_GAP)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
	var counter := make_label(player.player_color, 14)
	counter.text = str(lives)
	# Bold: the default font has no bold face, so thicken its strokes instead.
	var bold := FontVariation.new()
	bold.base_font = ThemeDB.fallback_font
	bold.variation_embolden = LIVES_EMBOLDEN
	counter.add_theme_font_override("font", bold)
	counter.size = Vector2(16, HUD_HEIGHT)
	counter.position = Vector2(-16 - LIVES_GAP,
		(AMMO_ICON_SIZE - HUD_HEIGHT) / 2.0 + LIVES_Y_OFFSET)
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(counter)
	lives_labels.append(counter)
	player.ammo_changed.connect(func(ammo: int) -> void:
		for i in player.max_ammo:
			row.get_child(i).visible = i < ammo)
