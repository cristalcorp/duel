extends Label

## "Press R to restart / Press M for menu" lines. Listens for these keys only
## while visible, and keeps listening while the game is paused.

signal restart_requested
signal menu_requested


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("restart"):
		get_viewport().set_input_as_handled()
		restart_requested.emit()
	elif event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		menu_requested.emit()
