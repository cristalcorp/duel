extends CharacterBody2D

# Collision layers: Body (layer 3) covers the whole cowboy and bumps into trees
# (layer 2) and the other cowboy. Bullets hit the Hurtbox (layer 1), same shape.

signal ammo_changed(ammo: int)
signal died

@export var speed: float = 300.0
## Appended to every input action name, e.g. "_p2" reads "move_left_p2".
@export var action_suffix: String = ""
@export var facing_left: bool = false
## Tints the cowboy and its bullets; trees of this colour reload its gun.
@export var player_color: Color = Color.WHITE
@export var max_ammo: int = 5
## Height of the band at the bottom of the screen the cowboy cannot enter.
@export var bottom_margin: float = 0.0
@export var shoot_duration: float = 1.0
## Frame of the "Shoot" animation where the arm is raised (the next one lowers it).
const SHOOT_HOLD_FRAME: int = 1
## Bullet speed in pixels per second.
@export var bullet_speed: float = 350.0
## Bullet side length, in game pixels (a sprite pixel is 5 game pixels).
@export var bullet_size: float = 8.0
## Gun muzzle, in sprite pixels from the sprite centre (facing right): right edge
## of the barrel tip, vertically centred on the barrel row of the arm-raised frame.
const MUZZLE_OFFSET := Vector2(6.0, -2.5)
const BULLET_SCENE: PackedScene = preload("res://Scenes/bullet.tscn")
## Side length of bullet.tscn at scale 1, in game pixels.
const BULLET_BASE_SIZE: float = 5.0
var shoot_time_left: float = 0.0
var dead: bool = false
var ammo: int
var start_position: Vector2
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	anim.flip_h = facing_left
	modulate = player_color
	ammo = max_ammo
	start_position = position
	
func _physics_process(delta: float) -> void:
	if dead:
		return

	# Shooting freezes the cowboy; movement and shoot inputs are ignored meanwhile.
	if shoot_time_left > 0.0:
		shoot_time_left -= delta
		# Stop on the arm-raised frame and hold it until the end; the next
		# frame lowers the arm and would look like a second shot.
		if anim.frame >= SHOOT_HOLD_FRAME and anim.is_playing():
			anim.pause()
			anim.frame = SHOOT_HOLD_FRAME
			fire_bullet()
		return

	if Input.is_action_just_pressed("shoot" + action_suffix) and ammo > 0:
		shoot_time_left = shoot_duration
		velocity = Vector2.ZERO
		anim.play("Shoot")
		return

	var input_vector: Vector2 = Input.get_vector(
		"move_left" + action_suffix, "move_right" + action_suffix,
		"move_up" + action_suffix, "move_down" + action_suffix)

	velocity = input_vector * speed

	move_and_slide()
	stay_on_screen()
	reload_at_own_tree()

	update_animation(input_vector)

## Keeps the whole body inside the screen.
func stay_on_screen() -> void:
	var half_extents: Vector2 = $Hurtbox/CollisionShape2D.shape.get_rect().size / 2.0 * scale
	var area: Rect2 = get_viewport_rect().grow_side(SIDE_BOTTOM, -bottom_margin)
	position = position.clamp(area.position + half_extents, area.end - half_extents)

## Refills the gun when the cowboy walks into a tree of its own colour.
func reload_at_own_tree() -> void:
	for i in get_slide_collision_count():
		var tree := get_slide_collision(i).get_collider() as Node
		if tree and tree.is_in_group("trees") and tree.color == player_color:
			set_ammo(max_ammo)

func set_ammo(value: int) -> void:
	if value == ammo:
		return
	ammo = value
	ammo_changed.emit(ammo)

func update_animation(input_vector: Vector2) -> void:
	if input_vector == Vector2.ZERO:
		anim.play("Idle")
		return

	anim.play("Walk")

	if abs(input_vector.x) > abs(input_vector.y):
		anim.flip_h = input_vector.x < 0

func fire_bullet() -> void:
	set_ammo(ammo - 1)
	var direction: float = -1.0 if anim.flip_h else 1.0
	var bullet: Area2D = BULLET_SCENE.instantiate()
	bullet.shooter = self
	bullet.direction = Vector2(direction, 0.0)
	bullet.speed = bullet_speed
	bullet.modulate = player_color
	bullet.scale = Vector2.ONE * bullet_size / BULLET_BASE_SIZE
	# The bullet's back edge touches the muzzle (offsets are in sprite pixels).
	var centre_x: float = MUZZLE_OFFSET.x + bullet_size / 2.0 / scale.x
	bullet.position = to_global(Vector2(centre_x * direction, MUZZLE_OFFSET.y))
	get_parent().add_child(bullet)

## Called by a bullet. Plays the death animation once; the cowboy then lies still,
## ignores input, and no longer collides with bullets, trees or the other cowboy.
func hit() -> void:
	if dead:
		return
	dead = true
	shoot_time_left = 0.0
	velocity = Vector2.ZERO
	$Body.set_deferred("disabled", true)
	$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
	anim.play("Death")
	died.emit()

## Back to the start of a round: alive, at the start position, gun full.
func reset() -> void:
	dead = false
	shoot_time_left = 0.0
	velocity = Vector2.ZERO
	position = start_position
	anim.flip_h = facing_left
	anim.play("Idle")
	$Body.set_deferred("disabled", false)
	$Hurtbox/CollisionShape2D.set_deferred("disabled", false)
	set_ammo(max_ammo)
