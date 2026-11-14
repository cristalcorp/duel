extends Area2D

## Pixels per second; set by the shooter.
var speed: float = 400.0
## Unit vector; set by the shooter, changed by tree bounces.
var direction: Vector2 = Vector2.RIGHT
## The cowboy who fired; safe from its own bullet until the first bounce.
var shooter: Node2D
var bounced: bool = false


func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	if not get_viewport_rect().has_point(position):
		queue_free()

## Bounces on a tree's hitbox; kills a cowboy through its hurtbox.
func _on_area_entered(area: Area2D) -> void:
	var owner_node: Node = area.get_parent()
	if owner_node.is_in_group("trees"):
		bounce()
		return
	if owner_node == shooter and not bounced:
		return
	if owner_node.has_method("hit"):
		owner_node.hit()
		queue_free()

## Leaves in a random direction on the side the bullet came from.
func bounce() -> void:
	bounced = true
	var back: Vector2 = -direction
	direction = back.rotated(randf_range(-PI / 2.0 * 0.9, PI / 2.0 * 0.9))
