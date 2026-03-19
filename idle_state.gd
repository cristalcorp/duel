# idle_state.gd
class_name IdleState
extends State

@export var walk_state: State
@export var shoot_state: State

func enter(_msg := {}) -> void:
	actor.velocity = Vector2.ZERO
	
	if actor.has_node("AnimatedSprite2D"):
		actor.get_node("AnimatedSprite2D").play("Idle")

func physics_update(_delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if direction != Vector2.ZERO:
		machine.transition_to(walk_state)
		return

	if Input.is_action_just_pressed("shoot"):
		machine.transition_to(shoot_state)
		return

	actor.move_and_slide()
