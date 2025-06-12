extends Node2D
var player1
var player2
var current_checkpoint_index = 0
@export var checkpoints : Array

# Camera smoothing variables
@export var camera_smoothing_speed = 5.0
@export var max_focus_distance = 500.0  # Distance at which camera fully focuses on lead player
@export var min_focus_distance = 100.0  # Distance below which camera stays at midpoint
var target_camera_position = Vector2.ZERO

func _ready() -> void:
	player1 = $Player/CharacterBody2D
	player2 = $Player2/CharacterBody2D
	
	checkpoints = [$checkpoint, $checkpoint2, $checkpoint3, $checkpoint4, $checkpoint5, $checkpoint6, $checkpoint7, $checkpoint8, $checkpoint9, $checkpoint10]
	
	# Initialize all checkpoints to not passed
	for checkpoint in checkpoints:
		checkpoint.is_passed = false

func _physics_process(delta: float) -> void:
	# Track the latest checkpoint that has is_passed = true
	update_current_checkpoint()
	
	# Get the latest passed checkpoint
	var latest_checkpoint = get_latest_passed_checkpoint()
	
	var target_player = latest_checkpoint.passed_player
	
	if target_player and player1 and player2:
		print(target_player.get_parent().name)
		
		# Calculate distance between players
		var distance = player1.global_position.distance_to(player2.global_position)
		
		# Calculate focus factor based on distance
		var focus_factor = calculate_focus_factor(distance)
		
		# Get positions
		var lead_player_pos = target_player.global_position
		var midpoint = (player1.global_position + player2.global_position) / 2
		
		# Interpolate between midpoint and lead player based on focus factor
		target_camera_position = midpoint.lerp(lead_player_pos, focus_factor)
		
		# Smoothly move camera to target position
		$Camera2D.offset = $Camera2D.offset.lerp(target_camera_position, camera_smoothing_speed * delta)
		$Camera2D.force_update_scroll()

func calculate_focus_factor(distance: float) -> float:
	# Returns a value between 0 and 1
	# 0 = focus on midpoint, 1 = focus on lead player
	if distance <= min_focus_distance:
		return 0.0
	elif distance >= max_focus_distance:
		return 1.0
	else:
		# Linear interpolation between min and max distance
		return (distance - min_focus_distance) / (max_focus_distance - min_focus_distance)

func update_current_checkpoint():
	# Find the highest index checkpoint that is passed
	var highest_passed = -1
	for i in range(checkpoints.size()):
		if checkpoints[i].is_passed:
			highest_passed = i
	
	if highest_passed >= 0:
		current_checkpoint_index = highest_passed
	
	# Check if all checkpoints are passed
	if all_checkpoints_passed():
		reset_checkpoints()

func get_latest_passed_checkpoint():
	var latest = checkpoints[-1]
	# Return the checkpoint with the highest index that has is_passed = true
	for i in range(checkpoints.size() - 1, -1, -1):
		if checkpoints[i].is_passed:
			latest = checkpoints[i]
			return latest
	return latest
		
func all_checkpoints_passed() -> bool:
	for checkpoint in checkpoints:
		if not checkpoint.is_passed:
			return false
	return true

func reset_checkpoints():
	# Set all checkpoints is_passed to false
	for checkpoint in checkpoints:
		checkpoint.is_passed = false
	
	# Reset current checkpoint back to starting one
	current_checkpoint_index = 0
	
	print("All checkpoints completed! Resetting to start.")
