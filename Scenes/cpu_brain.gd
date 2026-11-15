extends Node

## Drives a cowboy in SOLO mode through the same virtual keys as a player
## (4 directions + shoot): no extra speed, no extra ammo. Decides every
## reaction_time seconds and keeps the same keys held in between.
## Rules: "Adversaire ordinateur, mode SOLO" table in 05-Etats-et-flux.

## Seconds between two decisions.
@export var reaction_time: float = 0.3
## Shoots when the vertical gap with the target is below this, in game pixels.
@export var aim_tolerance: float = 20.0
## Horizontal distance kept with the target, in game pixels.
@export var min_distance: float = 150.0
@export var max_distance: float = 400.0
## How long a detour (around a tree, or when stuck) lasts, in seconds.
@export var detour_time: float = 0.5
## Moved less than this between two decisions while walking = stuck, in game pixels.
const STUCK_DISTANCE: float = 3.0
## Height of the band checked for trees between the gun and the target.
const SHOT_BAND_HEIGHT: float = 8.0
## Heights tried around the target's, nearest first, to find a line with no tree.
const AIM_OFFSETS: Array[float] = [0.0, -10.0, 10.0, -20.0, 20.0]

var me: Node2D
var foe: Node2D
var decision_left: float = 0.0
var detour_left: float = 0.0
var last_position: Vector2


func setup(cowboy: Node2D, target: Node2D) -> void:
	me = cowboy
	foe = target
	me.is_driven = true
	last_position = me.position

func _physics_process(delta: float) -> void:
	decision_left -= delta
	detour_left -= delta
	if decision_left > 0.0:
		return
	decision_left = reaction_time
	decide()
	last_position = me.position

## One decision; the first matching rule wins (same order as the table).
func decide() -> void:
	if me.dead or foe.dead:
		me.driven_move = Vector2.ZERO
		detour_left = 0.0
		return
	if me.shoot_time_left > 0.0:
		return
	if is_stuck():
		# Sideways to the blocked direction, to one side at random.
		var side: Vector2 = me.driven_move.orthogonal().normalized()
		start_detour(side if randf() < 0.5 else -side)
		return
	if detour_left > 0.0:
		return

	if me.ammo == 0:
		walk_to_own_tree()
		return

	var gap: Vector2 = foe.position - me.position
	var aim_y: float = clear_aim_height()
	if is_nan(aim_y):
		# Every line to the target crosses a tree: walk around it.
		aim_y = foe.position.y
	var aim_gap := Vector2(gap.x, aim_y - me.position.y)
	if absf(aim_gap.y) < aim_tolerance:
		var tree: Node2D = tree_between(me.position.y)
		if tree:
			# Diagonally towards the target, away from the tree's middle: a
			# purely vertical step would bring it back onto the same line.
			var away: float = signf(me.position.y - tree_footprint(tree).get_center().y)
			if away == 0.0:
				away = 1.0 if randf() < 0.5 else -1.0
			start_detour(Vector2(signf(gap.x), away).normalized())
		elif (gap.x < 0.0) == me.anim.flip_h:
			me.driven_move = Vector2.ZERO
			# One bullet at a time: a second one would fly through the dead
			# target, cross the edge and come back at the CPU.
			me.driven_shoot = not has_bullet_in_play()
		else:
			# One step towards the target turns the cowboy round.
			me.driven_move = Vector2(signf(gap.x), 0.0)
		return

	approach(aim_gap)

## Walked into something (a tree, the other cowboy, an edge) since last decision.
func is_stuck() -> bool:
	return me.driven_move != Vector2.ZERO \
		and me.position.distance_to(last_position) < STUCK_DISTANCE

func start_detour(direction: Vector2) -> void:
	me.driven_move = direction
	detour_left = detour_time

## Up to the target's height; back off or close in to stay between
## min_distance and max_distance horizontally.
func approach(gap: Vector2) -> void:
	# Slower when close, so a 0.3 s step does not overshoot the target's height.
	var vertical: float = clampf(gap.y / (me.speed * reaction_time), -1.0, 1.0)
	var horizontal: float = 0.0
	if absf(gap.x) < min_distance:
		horizontal = -signf(gap.x)
	elif absf(gap.x) > max_distance:
		horizontal = signf(gap.x)
	me.driven_move = Vector2(horizontal, vertical).limit_length(1.0)

func walk_to_own_tree() -> void:
	var tree: Node2D = find_own_tree()
	if tree == null:
		me.driven_move = Vector2.ZERO
		return
	var centre: Vector2 = tree_footprint(tree).get_center()
	me.driven_move = (centre - me.position).normalized()

func find_own_tree() -> Node2D:
	for tree in get_tree().get_nodes_in_group("trees"):
		if tree.color == me.player_color and not tree.is_queued_for_deletion():
			return tree
	return null

## Height to stand at, near the target's, with no tree on the bullet's path
## (NAN if there is none).
func clear_aim_height() -> float:
	var best: float = NAN
	for offset in AIM_OFFSETS:
		var y: float = foe.position.y + offset
		if tree_between(y) == null and (is_nan(best) \
				or absf(y - me.position.y) < absf(best - me.position.y)):
			best = y
	return best

## The tree crossing the bullet's path between the gun (cowboy standing at
## height y) and the target, if any.
func tree_between(y: float) -> Node2D:
	var gun_y: float = y + me.MUZZLE_OFFSET.y * me.scale.y
	var left: float = minf(me.position.x, foe.position.x)
	var right: float = maxf(me.position.x, foe.position.x)
	var path := Rect2(left, gun_y - SHOT_BAND_HEIGHT / 2.0, right - left, SHOT_BAND_HEIGHT)
	for tree in get_tree().get_nodes_in_group("trees"):
		if not tree.is_queued_for_deletion() and tree_footprint(tree).intersects(path):
			return tree
	return null

func tree_footprint(tree: Node2D) -> Rect2:
	var footprint: Rect2 = get_parent().TREE_FOOTPRINT
	return Rect2(tree.position + footprint.position, footprint.size)

func has_bullet_in_play() -> bool:
	return get_tree().get_nodes_in_group("bullets").any(
		func(b: Node) -> bool: return b.shooter == me and not b.is_queued_for_deletion())
