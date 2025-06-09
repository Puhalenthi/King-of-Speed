extends CharacterBody2D

# Movement variables
@export var speed: float = 800.0
@export var jump_velocity: float = -600.0
@export var acceleration: float = 1500.0
@export var friction: float = 1200.0
var jumps = 2

# Player facing direction
var facing_right: bool = true
@onready var sprite: Sprite2D = $Sprite2D

# Slope handling
@export var max_slope_angle: float = 50.0
@export var slope_stop_min_velocity: float = 5.0

# Momentum buffer system
var momentum_buffer: float = 0.0
@export var momentum_decay_rate: float = 0.95  # How quickly momentum decays when not falling

# Super speed state
@export var super_speed_threshold: float = 800.0
@export var super_speed_friction: float = 200.0  # Reduced friction when in super speed
var is_super_speed: bool = false

# Ground penetration detection
var previous_velocity: Vector2 = Vector2.ZERO
var was_airborne: bool = false

# Get the gravity from the project settings to be synced with RigidBody nodes
var gravity: int = 1500

func _ready():
	# Set up floor detection for slopes
	floor_max_angle = deg_to_rad(max_slope_angle)
	floor_snap_length = 8.0
	floor_stop_on_slope = false

func _physics_process(delta):
	# Store previous state for ground penetration detection
	previous_velocity = velocity
	was_airborne = not is_on_floor()
	
	handle_gravity(delta)
	handle_jump()
	update_super_speed_state()
	handle_movement(delta)
	update_momentum_buffer()
	move_and_slide()
	
	# Fix ground penetration after move_and_slide()
	handle_ground_penetration()

func handle_gravity(delta):
	# Add gravity when not on floor
	if not is_on_floor():
		velocity.y += gravity * delta

func handle_jump():
	if is_on_floor():
		jumps = 2
	# Handle jump input
	if Input.is_action_just_pressed("ui_accept") and jumps > 0:
		jumps -= 1
		velocity.y = jump_velocity

func handle_movement(delta):
	# Get input direction
	var direction = Input.get_axis("ui_left", "ui_right")
	
	# Update facing direction and flip sprite
	if direction > 0:
		facing_right = true
		sprite.flip_h = false
	elif direction < 0:
		facing_right = false
		sprite.flip_h = true
	
	if direction != 0:
		# Apply acceleration when moving
		velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
	else:
		# Handle friction based on super speed state
		if is_on_floor():
			var friction_to_use = super_speed_friction if is_super_speed else friction
			velocity.x = move_toward(velocity.x, 0, friction_to_use * delta)
		else:
			# Reduced air friction
			var air_friction = (super_speed_friction if is_super_speed else friction) * 0.3
			velocity.x = move_toward(velocity.x, 0, air_friction * delta)
	
	# Handle slope stopping - only when not in super speed state
	if is_on_floor() and direction == 0 and not is_super_speed:
		var floor_normal = get_floor_normal()
		if floor_normal != Vector2.UP and abs(velocity.x) < slope_stop_min_velocity:
			velocity.x = 0
	
	# Downslope sliding mechanic
	handle_downslope_sliding(direction)

func handle_ground_penetration():
	# Check if we just landed from being airborne
	if was_airborne and is_on_floor():
		# Check if horizontal velocity was drastically reduced (indicating penetration/overcorrection)
		var velocity_loss_ratio = abs(velocity.x) / max(abs(previous_velocity.x), 1.0)
		
		# If we lost significant horizontal velocity and were falling fast
		if velocity_loss_ratio < 0.5 and previous_velocity.y > 200:
			# Restore horizontal velocity and zero vertical velocity
			velocity.x = previous_velocity.x
			velocity.y = 0
			
			# Optional: Add a small upward nudge to prevent getting stuck
			position.y -= 2

func update_super_speed_state():
	# Enter super speed state when velocity exceeds threshold
	if abs(velocity.x) >= super_speed_threshold:
		is_super_speed = true
	
	# Exit super speed state when velocity drops below threshold
	if abs(velocity.x) < super_speed_threshold:
		is_super_speed = false

func update_momentum_buffer():
	# Track the highest downward velocity achieved
	if velocity.y > momentum_buffer:
		momentum_buffer = velocity.y
	
	# Decay momentum buffer when on ground or moving upward
	if is_on_floor() or velocity.y < 0:
		momentum_buffer *= momentum_decay_rate
		
		# Reset buffer when it gets very small
		if momentum_buffer < 1.0:
			momentum_buffer = 0.0

func _input(event):
	# Optional: Add coyote time or buffer jump here
	pass

func handle_downslope_sliding(input_direction):
	# Only apply downslope sliding when on floor and have sufficient momentum
	if not is_on_floor() or momentum_buffer <= 12:
		return
	
	var floor_normal = get_floor_normal()
	if floor_normal == Vector2.UP:
		return  # Not on a slope
	
	# Determine slope direction (which way is downhill)
	var slope_direction = 1 if floor_normal.x < 0 else -1
	
	# Check if player is facing the same direction as the downslope
	var player_direction = 1 if facing_right else -1
	
	#if player_direction == slope_direction:
		# Use momentum buffer for transfer instead of current velocity.y
	#	transferMomentum(player_direction)

# Helper functions for extended functionality
func get_movement_direction() -> float:
	return Input.get_axis("ui_left", "ui_right")

func is_moving() -> bool:
	return abs(velocity.x) > 1.0

func is_falling() -> bool:
	return velocity.y > 0 and not is_on_floor()

func is_facing_right() -> bool:
	return facing_right

func get_facing_direction() -> int:
	return 1 if facing_right else -1

func get_momentum_buffer() -> float:
	return momentum_buffer

func is_in_super_speed() -> bool:
	return is_super_speed

# Optional: Add sound/animation triggers
func _on_landed():
	# Called when landing - useful for sound effects or animations
	pass

func _on_jumped():
	# Called when jumping - useful for sound effects or animations
	pass
	
func transferMomentum(direction):
	velocity.x += momentum_buffer * direction
