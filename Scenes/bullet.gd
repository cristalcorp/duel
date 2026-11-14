extends Area2D

## Pixels per second; set by the shooter.
var speed: float = 400.0
## Unit vector; set by the shooter, changed by tree bounces.
var direction: Vector2 = Vector2.RIGHT
## The cowboy who fired; safe from its own bullet until the first bounce or wrap.
var shooter: Node2D
var can_hit_shooter: bool = false
## Seconds before the bullet disappears; until then it crosses screen edges as
## often as needed, coming back on the opposite side.
@export var lifetime: float = 3.0
var wraps: int = 0


func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	position += direction * speed * delta
	var screen: Rect2 = get_viewport_rect()
	if screen.has_point(position):
		return
	# Out through one edge, in through the opposite one; direction is kept.
	wraps += 1
	can_hit_shooter = true
	position = Vector2(
		screen.position.x + fposmod(position.x - screen.position.x, screen.size.x),
		screen.position.y + fposmod(position.y - screen.position.y, screen.size.y))

## Bounces on a tree's hitbox; kills a cowboy through its hurtbox.
func _on_area_entered(area: Area2D) -> void:
	var owner_node: Node = area.get_parent()
	if owner_node.is_in_group("trees"):
		bounce()
		return
	if owner_node == shooter and not can_hit_shooter:
		return
	if owner_node.has_method("hit"):
		owner_node.hit()
		queue_free()

## Leaves in a random direction on the side the bullet came from.
func bounce() -> void:
	can_hit_shooter = true
	var back: Vector2 = -direction
	direction = back.rotated(randf_range(-PI / 2.0 * 0.9, PI / 2.0 * 0.9))
