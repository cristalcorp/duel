# idle_state.gd
class_name IdleState
extends State

@export var run_state: State
@export var shoot_state: State

func enter(_msg := {}) -> void:
	actor.velocity.x = 0
	actor.anim.play("idle")

func physics_update(_delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")

	if dir != 0:
		machine.transition_to(run_state)
		return

	if Input.is_action_just_pressed("shoot"):
		machine.transition_to(shoot_state)
		return

	actor.move_and_slide()
