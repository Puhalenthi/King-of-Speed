extends CharacterBody2D

# Player State System
enum PlayerState {
	IDLE,
	RUNNING,
	FALLING,
	SUPERSPEED_FALLING,
	SUPERSPEED_GROUND,
	GRAPPLING,
	GRAPPLED
}

var current_state: PlayerState = PlayerState.IDLE
var previous_state: PlayerState = PlayerState.IDLE

#visual variables
@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var sprite_2d = %Sprite2D

# Movement variables
@export var speed: float = 800.0
@export var jump_velocity: float = -600.0
@export var acceleration: float = 1500.0
@export var friction: float = 1200.0
var jumps = 2

# Player facing direction
var facing_right: bool = true
@onready var sprite: Sprite2D = $Sprite2D
@onready var camera = $Camera2D

# Slope handling
@export var max_slope_angle: float = 50.0
@export var slope_stop_min_velocity: float = 5.0

# Momentum buffer system
var momentum_buffer: float = 0.0
@export var momentum_decay_rate: float = 0.95

# Super speed state
@export var super_speed_threshold: float = 800.0
@export var super_speed_friction: float = 200.0

# Ground penetration detection
var previous_velocity: Vector2 = Vector2.ZERO
var was_airborne: bool = false

# Boost system
@export var max_boost: float = 100.0
var current_boost: float = 100.0
@export var boost_consumption_rate: float = 50.0
@export var boost_speed_multiplier: float = 1.5
var is_boosting: bool = false

# Grapple system
@export var grapple_scene_path: String = "res://Scenes/grapple.tscn"
var grapple_instance: Area2D = null
var is_grapple_input_held: bool = false
var grapple_input_just_pressed: bool = false  # Track fresh grapple input

# Grapple distance constraint system
var grapple_distance: float = 0.0
var grapple_anchor_point: Vector2 = Vector2.ZERO
@export var grapple_swing_damping: float = 0.98  # Reduces swing oscillation over time
@export var grapple_tension_strength: float = 2000.0  # How strongly the rope pulls back

# Grapple velocity system
@export var minimum_grapple_velocity: float = 700.0

# Get the gravity from the project settings to be synced with RigidBody nodes
var gravity: int = 1500

@rpc("any_peer", "call_remote", "unreliable", 0)
func _rpc_sync_transform(pos: Vector2, vel: Vector2) -> void:
	if not is_multiplayer_authority():
		global_position = pos
		velocity        = vel

func _ready():
	if not is_multiplayer_authority(): return
	# Set up floor detection for slopes
	floor_max_angle = deg_to_rad(max_slope_angle)
	floor_snap_length = 8.0
	floor_stop_on_slope = false

func _physics_process(delta):
	if not is_multiplayer_authority(): return
	# Store previous state for ground penetration detection
	previous_velocity = velocity
	was_airborne = not is_on_floor()
	
	handle_gravity(delta)
	handle_jump()
	handle_boost(delta)
	handle_grapple()
	update_player_state()
	handle_movement(delta)
	handle_grapple_physics(delta)  # New function for grapple constraint
	update_momentum_buffer()
	move_and_slide()
	
	# Check for ground landing while grappled (must be after move_and_slide)
	handle_grapple_ground_exit()
	
	# Fix ground penetration after move_and_slide()
	handle_ground_penetration()
	
	# Update state after physics
	previous_state = current_state
	rpc("_rpc_sync_transform", global_position, velocity)


func handle_grapple():
	# Check if grapple input is being held
	var grapple_input = Input.is_action_pressed("grapple2")
	var grapple_just_pressed = Input.is_action_just_pressed("grapple2")
	
	# Update grapple_input_just_pressed flag
	if grapple_just_pressed:
		grapple_input_just_pressed = true
	
	# If grapple input just started being held AND we have a fresh press
	if grapple_input and not is_grapple_input_held and grapple_input_just_pressed:
		is_grapple_input_held = true
		
		# Remove any existing grapple instance
		if grapple_instance != null:
			grapple_instance.queue_free()
			grapple_instance = null
		
		# Load and instantiate the grapple scene
		var grapple_scene = load(grapple_scene_path)
		if grapple_scene:
			grapple_instance = grapple_scene.instantiate()
			add_child(grapple_instance)
			
			# Set rotation based on facing direction
			if facing_right:
				grapple_instance.rotation_degrees = -45
			else:
				grapple_instance.rotation_degrees = -135
	
	# If grapple input is no longer being held
	elif not grapple_input and is_grapple_input_held:
		is_grapple_input_held = false
		grapple_input_just_pressed = false  # Reset the fresh press flag
		
		# Clear grapple constraint data
		grapple_distance = 0.0
		grapple_anchor_point = Vector2.ZERO
		
		# Remove grapple instance
		if grapple_instance != null:
			grapple_instance.queue_free()
			grapple_instance = null
	
	# Update grapple input state
	is_grapple_input_held = grapple_input

func handle_grapple_physics(delta):
	# Only apply grapple physics when grappled
	if current_state != PlayerState.GRAPPLED:
		return
	
	# Make sure we have a grapple instance and anchor point
	if grapple_instance == null:
		return
	
	# Get the grapple anchor point (assuming it has a global_position)
	if "global_position" in grapple_instance:
		grapple_anchor_point = grapple_instance.global_position
	else:
		# Fallback to grapple instance position
		grapple_anchor_point = grapple_instance.position + global_position
	
	# Calculate current distance to anchor
	var to_anchor = grapple_anchor_point - global_position
	var current_distance = to_anchor.length()
	
	# Set grapple distance when first grappled (only once)
	if grapple_distance <= 0:
		grapple_distance = current_distance
		return
	
	# If we're beyond the grapple distance, apply constraint
	if current_distance > grapple_distance:
		# Calculate the direction to pull the player back
		var direction_to_anchor = to_anchor.normalized()
		
		# Calculate how much we've exceeded the rope length
		var excess_distance = current_distance - grapple_distance
		
		# Apply tension force to pull player back to rope length
		var tension_force = direction_to_anchor * grapple_tension_strength * excess_distance
		
		# Apply the tension as acceleration
		velocity += tension_force * delta
		
		# Also directly adjust position to maintain constraint (for stability)
		var correction = direction_to_anchor * excess_distance * 0.5
		global_position += correction
	
	# Apply swinging physics - project velocity perpendicular to rope
	if grapple_distance > 0:
		var rope_direction = (grapple_anchor_point - global_position).normalized()
		var velocity_along_rope = velocity.dot(rope_direction)
		
		# If moving away from anchor, reduce that component of velocity
		if velocity_along_rope > 0:
			velocity -= rope_direction * velocity_along_rope * 0.8
	
	# Apply damping to reduce wild swinging
	#velocity *= grapple_swing_damping

func update_player_state():
	var new_state: PlayerState
	var is_moving = abs(velocity.x) > 1.0
	var is_super_speed = abs(velocity.x) >= super_speed_threshold
	var is_grounded = is_on_floor()
	
	# Check grapple states first
	if is_grapple_input_held and grapple_instance != null:
		# Check if grapple instance has the is_grappled property and it's true
		if "is_grappled" in grapple_instance and grapple_instance.is_grappled:
			new_state = PlayerState.GRAPPLED
			
			# Initialize grapple distance when entering grappled state
			if current_state != PlayerState.GRAPPLED:
				if "global_position" in grapple_instance:
					grapple_anchor_point = grapple_instance.global_position
				else:
					grapple_anchor_point = grapple_instance.position + global_position
				grapple_distance = (grapple_anchor_point - global_position).length()
		else:
			new_state = PlayerState.GRAPPLING
	else:
		# Normal state logic - now includes transition from grapple to super speed
		if is_grounded:
			if is_super_speed:
				new_state = PlayerState.SUPERSPEED_GROUND
			elif is_moving:
				new_state = PlayerState.RUNNING
			else:
				new_state = PlayerState.IDLE
		else:
			if is_super_speed:
				new_state = PlayerState.SUPERSPEED_FALLING
			else:
				new_state = PlayerState.FALLING
	
	# Handle state transitions
	if new_state != current_state:
		_on_state_exit(current_state)
		current_state = new_state
		_on_state_enter(current_state)

func _on_state_enter(state: PlayerState):
	match state:
		PlayerState.IDLE:
			pass
		PlayerState.RUNNING:
			pass
		PlayerState.FALLING:
			pass
		PlayerState.SUPERSPEED_FALLING:
			pass
		PlayerState.SUPERSPEED_GROUND:
			pass
		PlayerState.GRAPPLING:
			# Could add grappling enter logic here
			pass
		PlayerState.GRAPPLED:
			# Initialize grapple constraint when entering grappled state
			print("Entered GRAPPLED state - rope length: ", grapple_distance)
			
			# Ensure minimum velocity when beginning grapple
			var current_velocity_magnitude = velocity.length()
			if current_velocity_magnitude < minimum_grapple_velocity:
				# If velocity is too low, set it to minimum magnitude
				if current_velocity_magnitude > 0:
					# Preserve direction but increase magnitude
					velocity = velocity.normalized() * minimum_grapple_velocity
				else:
					# If velocity is zero, give it a direction based on facing
					if facing_right:
						velocity = Vector2(minimum_grapple_velocity * 0.7, minimum_grapple_velocity * 0.7)
					else:
						velocity = Vector2(-minimum_grapple_velocity * 0.7, minimum_grapple_velocity * 0.7)
				
				print("Velocity boosted to minimum grapple velocity: ", velocity.length())
				

	
	

func _on_state_exit(state: PlayerState):
	match state:
		PlayerState.IDLE:
			pass
		PlayerState.RUNNING:
			pass
		PlayerState.FALLING:
			pass
		PlayerState.SUPERSPEED_FALLING:
			pass
		PlayerState.SUPERSPEED_GROUND:
			pass
		PlayerState.GRAPPLING:
			pass
		PlayerState.GRAPPLED:
			# Reset grapple constraint when exiting grappled state
			print("Exited GRAPPLED state")
			
			# Check if we should transition to super speed after grappling
			if abs(velocity.x) >= super_speed_threshold:
				print("Transitioning from grapple to super speed - velocity: ", velocity.x)
			pass

func handle_gravity(delta):
	# Apply modified gravity when grappled (lighter feel for swinging)
	if current_state == PlayerState.GRAPPLED:
		#velocity.y += gravity * delta
		# Remove the old minimum velocity check here since it's now handled in state enter
		return
		
	# Add gravity when not on floor
	if not is_on_floor():
		velocity.y += gravity * delta

func handle_jump():
	# Don't allow jumping when grappling or grappled
	if current_state == PlayerState.GRAPPLING:
		return
	if current_state == PlayerState.GRAPPLED:
		jumps = 1
		return
		
	# Handle jump input
	if is_on_floor():
		jumps = 2
	if Input.is_action_just_pressed("jump2") and jumps > 0:
		jumps -= 1
		velocity.y = jump_velocity
		if is_on_floor():
			animated_sprite_2d.play("jump")
		else:
			animated_sprite_2d.play("double jump")

func handle_boost(delta):
	# Don't allow boosting when grappled
	if current_state == PlayerState.GRAPPLED:
		is_boosting = false
		return
		
	# Check if boost input is pressed and we have boost available
	is_boosting = Input.is_action_pressed("boost2") and current_boost > 0
	
	if is_boosting:
		# Consume boost (no regeneration)
		current_boost -= boost_consumption_rate * delta
		print("BOOSTING: " + str(current_boost))
		current_boost = max(current_boost, 0.0)

func handle_movement(delta):
	# No movement control when grappled - player cannot influence direction
	if current_state == PlayerState.GRAPPLED:
		# Still update facing direction for visual consistency (sprite flipping)
		# but don't allow any movement influence
		if velocity.x > 0:
			facing_right = true
			sprite.flip_h = false
			animated_sprite_2d.flip_h = false
		elif velocity.x < 0:
			facing_right = false
			sprite.flip_h = true
			animated_sprite_2d.flip_h = true
		return
	
	# Get input direction
	var direction = Input.get_axis("move_left2", "move_right2")
	
	# Update facing direction and flip sprite
	if direction > 0:
		facing_right = true
		sprite.flip_h = false
		animated_sprite_2d.flip_h = false
	elif direction < 0:
		facing_right = false
		sprite.flip_h = true
		animated_sprite_2d.flip_h = true
	
	if direction != 0:
		# Calculate effective speed with boost multiplier
		var effective_speed = speed
		if is_boosting:
			effective_speed *= boost_speed_multiplier
			animated_sprite_2d.play("boost run")
		else:
			animated_sprite_2d.play("running")
		
		# Apply acceleration when moving
		velocity.x = move_toward(velocity.x, direction * effective_speed, acceleration * delta)
	else:
		# Handle friction based on current state
		if is_on_floor():
			var friction_to_use = get_current_friction()
			velocity.x = move_toward(velocity.x, 0, friction_to_use * delta)
			animated_sprite_2d.play("stop run")
		else:
			# Reduced air friction
			var air_friction = get_current_friction() * 0.3
			velocity.x = move_toward(velocity.x, 0, air_friction * delta)
	
	# Handle slope stopping - only when not in super speed states
	if is_on_floor() and direction == 0 and not is_super_speed_state():
		var floor_normal = get_floor_normal()
		if floor_normal != Vector2.UP and abs(velocity.x) < slope_stop_min_velocity:
			velocity.x = 0
	
	# Downslope sliding mechanic
	handle_downslope_sliding(direction)

func get_current_friction() -> float:
	match current_state:
		PlayerState.SUPERSPEED_FALLING, PlayerState.SUPERSPEED_GROUND:
			return super_speed_friction
		_:
			return friction

func is_super_speed_state() -> bool:
	return current_state == PlayerState.SUPERSPEED_FALLING or current_state == PlayerState.SUPERSPEED_GROUND

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

func handle_grapple_ground_exit():
	# If player is grappled and hits the ground, exit grapple state
	if current_state == PlayerState.GRAPPLED and is_on_floor():
		print("Player hit ground while grappled - exiting grapple state")
		
		# Force exit grapple state by clearing input and destroying grapple
		is_grapple_input_held = false
		grapple_input_just_pressed = false  # Reset fresh press flag to prevent re-entry
		
		# Clear grapple constraint data
		grapple_distance = 0.0
		grapple_anchor_point = Vector2.ZERO
		
		# Remove grapple instance
		if grapple_instance != null:
			grapple_instance.queue_free()
			grapple_instance = null
		
		# The state will be updated in the next update_player_state() call

# Helper functions for extended functionality
func get_movement_direction() -> float:
	return Input.get_axis("move_left2", "move_right2")

func is_moving() -> bool:
	return current_state == PlayerState.RUNNING or current_state == PlayerState.SUPERSPEED_GROUND

func is_falling() -> bool:
	return current_state == PlayerState.FALLING or current_state == PlayerState.SUPERSPEED_FALLING

func is_facing_right() -> bool:
	return facing_right

func get_facing_direction() -> int:
	return 1 if facing_right else -1

func get_momentum_buffer() -> float:
	return momentum_buffer

func is_in_super_speed() -> bool:
	return is_super_speed_state()

func get_boost_percentage() -> float:
	return (current_boost / max_boost) * 100.0

func get_current_boost() -> float:
	return current_boost

func is_boost_active() -> bool:
	return is_boosting

# State-specific helper functions
func is_idle() -> bool:
	return current_state == PlayerState.IDLE

func is_running() -> bool:
	return current_state == PlayerState.RUNNING

func is_grounded() -> bool:
	return current_state == PlayerState.IDLE or current_state == PlayerState.RUNNING or current_state == PlayerState.SUPERSPEED_GROUND

func get_current_state() -> PlayerState:
	return current_state

func get_previous_state() -> PlayerState:
	return previous_state

func get_state_name() -> String:
	match current_state:
		PlayerState.IDLE:
			return "IDLE"
		PlayerState.RUNNING:
			return "RUNNING"
		PlayerState.FALLING:
			return "FALLING"
		PlayerState.SUPERSPEED_FALLING:
			return "SUPERSPEED_FALLING"
		PlayerState.SUPERSPEED_GROUND:
			return "SUPERSPEED_GROUND"
		PlayerState.GRAPPLING:
			return "GRAPPLING"
		PlayerState.GRAPPLED:
			return "GRAPPLED"
		_:
			return "UNKNOWN"

# Grapple-specific helper functions
func is_grappling() -> bool:
	return current_state == PlayerState.GRAPPLING

func is_grappled() -> bool:
	return current_state == PlayerState.GRAPPLED

func get_grapple_instance() -> Area2D:
	return grapple_instance

func get_grapple_distance() -> float:
	return grapple_distance

func get_grapple_anchor_point() -> Vector2:
	return grapple_anchor_point

func get_minimum_grapple_velocity() -> float:
	return minimum_grapple_velocity

# Optional: Add sound/animation triggers based on state changes
func _on_landed():
	# Called when landing - useful for sound effects or animations
	pass

func _on_jumped():
	# Called when jumping - useful for sound effects or animations
	animated_sprite_2d.play("jump")
	
#func update_player_anim():
	#if current_state != PlayerState.IDLE: #not idling update, hide sprite 2d
		#animated_sprite_2d.hide = false
		#sprite.hide = true
	#if current_state == PlayerState.RUNNING: #animation handling for diff states
		#animated_sprite_2d.play("running")
	#elif is_super_speed_state():
		#animated_sprite_2d.play("boost run")
	#elif current_state == PlayerState.IDLE:
		#animated_sprite_2d.hide = true
		#sprite.hide = false
	
func transferMomentum(direction):
	velocity.x += momentum_buffer * direction
