extends CharacterBody2D

# Movement variables
@export var speed: float = 800.0
@export var jump_velocity: float = -400.0
@export var acceleration: float = 1500.0
@export var friction: float = 1200.0

# Slope handling
@export var max_slope_angle: float = 50.0
@export var slope_stop_min_velocity: float = 5.0

# Get the gravity from the project settings to be synced with RigidBody nodes
var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready():
	# Set up floor detection for slopes
	floor_max_angle = deg_to_rad(max_slope_angle)
	floor_snap_length = 8.0
	floor_stop_on_slope = true

func _physics_process(delta):
	handle_gravity(delta)
	handle_jump()
	handle_movement(delta)
	move_and_slide()

func handle_gravity(delta):
	# Add gravity when not on floor
	if not is_on_floor():
		velocity.y += gravity * delta

func handle_jump():
	# Handle jump input
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

func handle_movement(delta):
	# Get input direction
	var direction = Input.get_axis("ui_left", "ui_right")
	
	if direction != 0:
		# Apply acceleration when moving
		velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
	else:
		# Apply friction when not pressing movement keys
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0, friction * delta)
		else:
			# Reduced air friction
			velocity.x = move_toward(velocity.x, 0, friction * 0.3 * delta)
	
	# Handle slope stopping - prevent sliding down slopes when not moving
	if is_on_floor() and direction == 0:
		var floor_normal = get_floor_normal()
		if floor_normal != Vector2.UP and abs(velocity.x) < slope_stop_min_velocity:
			velocity.x = 0

func _input(event):
	# Optional: Add coyote time or buffer jump here
	pass

# Helper functions for extended functionality
func get_movement_direction() -> float:
	return Input.get_axis("ui_left", "ui_right")

func is_moving() -> bool:
	return abs(velocity.x) > 1.0

func is_falling() -> bool:
	return velocity.y > 0 and not is_on_floor()

func is_rising() -> bool:
	return velocity.y < 0

# Optional: Add sound/animation triggers
func _on_landed():
	# Called when landing - useful for sound effects or animations
	pass

func _on_jumped():
	# Called when jumping - useful for sound effects or animations
	pass
