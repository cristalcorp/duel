extends Label

## "Press R to restart" line. Listens for the restart key only while visible,
## and keeps listening while the game is paused.

signal restart_requested


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("restart"):
		get_viewport().set_input_as_handled()
		restart_requested.emit()
