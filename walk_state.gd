class_name WalkState
extends State

@export var idle_state: State
@export var speed: float = 300.0

func enter(_msg := {}) -> void:
	if actor.has_node("AnimatedSprite2D"):
		actor.get_node("AnimatedSprite2D").play("Walk")

func physics_update(_delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if direction == Vector2.ZERO:
		machine.transition_to(idle_state)
		return

	actor.velocity = direction * speed

	if direction.x < 0:
		actor.get_node("AnimatedSprite2D").flip_h = true
	elif direction.x > 0:
		actor.get_node("AnimatedSprite2D").flip_h = false

	actor.move_and_slide()

func exit() -> void:
	actor.velocity.x = 0
