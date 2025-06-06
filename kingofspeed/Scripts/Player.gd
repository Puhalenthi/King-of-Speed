extends CharacterBody2D

@export var acceleration := 2000.0
@export var friction := 1200.0
@export var max_speed := 300.0
@export var air_control := 0.5
@export var jump_velocity := -500.0
@export var gravity := 1200.0
@export var slope_boost_factor := 0.4

var jumps_left := 2

func _physics_process(delta):
	var input_dir := Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	var is_on_ground := is_on_floor()
	var ground_normal := get_floor_normal()

	# --- Horizontal Movement with Momentum ---
	var target_accel = acceleration if is_on_ground else acceleration * air_control
	if input_dir != 0:
		velocity.x += input_dir * target_accel * delta
	elif is_on_ground:
		# Apply ground friction
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	# --- Clamp Speed on Ground ---
	if is_on_ground:
		velocity.x = clamp(velocity.x, -max_speed, max_speed)

	# --- Gravity and Jumping ---
	if not is_on_ground:
		velocity.y += gravity * delta

	if Input.is_action_just_pressed("ui_accept"):
		if is_on_ground or jumps_left > 0:
			velocity.y = jump_velocity
			if not is_on_ground:
				jumps_left -= 1

	if is_on_ground:
		jumps_left = 1  # reset for double jump

	# --- Slope Movement and Rotation ---
	if is_on_ground and ground_normal.angle() != 0.0:
		rotation = ground_normal.angle() - PI / 2

		# Convert downward velocity into horizontal motion on downslope
		var slope_dir := ground_normal.orthogonal().normalized()
		if velocity.y > 0.0 and sign(velocity.x) == sign(slope_dir.x):
			velocity.x += slope_dir.x * velocity.y * slope_boost_factor
			velocity.y = 0.0
	else:
		rotation = lerp_angle(rotation, 0.0, 6.0 * delta)

	# --- Final Movement ---
	set_up_direction(Vector2.UP)
	move_and_slide()
