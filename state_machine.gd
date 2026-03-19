# state_machine.gd
class_name StateMachine
extends Node

@export var initial_state: State
var current_state: State

func _ready() -> void:
	for child in get_children():
		if child is State:
			child.machine = self
			child.actor = get_parent()
	current_state = initial_state
	current_state.enter()

func transition_to(new_state: State, msg := {}) -> void:
	if current_state == new_state:
		return
	current_state.exit()
	current_state = new_state
	current_state.enter(msg)

func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)
