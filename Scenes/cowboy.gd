extends CharacterBody2D

@export var speed: float = 300.0
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	
func _physics_process(_delta: float) -> void:
	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	velocity = input_vector * speed
	
	move_and_slide()
	
	# animation shoot prioritaire
	if Input.is_action_just_pressed("shoot"):
		anim.play("Shoot")
		return

	update_animation(input_vector)

func update_animation(input_vector: Vector2) -> void:
	if input_vector == Vector2.ZERO:
		anim.play("Idle")
		return

	anim.play("Walk")

	if abs(input_vector.x) > abs(input_vector.y):
		anim.flip_h = input_vector.x < 0
