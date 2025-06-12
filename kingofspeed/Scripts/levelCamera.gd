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

var game_end : bool

func _ready() -> void:
	player1 = $Player/CharacterBody2D
	player2 = $Player2/CharacterBody2D
	
	player1.get_node("Camera2D").enabled = false
	player2.get_node("Camera2D").enabled = false
	
	# Automatically find and sort checkpoints
	checkpoints = get_sorted_checkpoints()
	
	# Initialize all checkpoints to not passed
	for checkpoint in checkpoints:
		checkpoint.is_passed = false

func get_sorted_checkpoints() -> Array:
	var checkpoint_nodes = []
	
	# Find all nodes with "checkpoint" in their name
	find_checkpoint_nodes(self, checkpoint_nodes)
	
	# Sort by the number at the end of their name
	checkpoint_nodes.sort_custom(func(a, b): return get_checkpoint_number(a.name) < get_checkpoint_number(b.name))
	
	return checkpoint_nodes

func find_checkpoint_nodes(node: Node, checkpoint_list: Array) -> void:
	# Check if current node has "checkpoint" in its name (case insensitive)
	if "checkpoint" in node.name.to_lower():
		checkpoint_list.append(node)
	
	# Recursively search children
	for child in node.get_children():
		find_checkpoint_nodes(child, checkpoint_list)

func get_checkpoint_number(node_name: String) -> int:
	# Extract number from the end of the checkpoint name
	var regex = RegEx.new()
	regex.compile("checkpoint(\\d+)")
	var result = regex.search(node_name.to_lower())
	
	if result:
		return result.get_string(1).to_int()
	else:
		# If no number found, treat as checkpoint 0 or handle special case
		# This handles cases like just "checkpoint" without a number
		if node_name.to_lower() == "checkpoint":
			return 1  # Treat bare "checkpoint" as checkpoint1
		return 0

func _physics_process(delta: float) -> void:
	# Check if players are still on screen and destroy if not
	check_players_on_screen()
	
	# Track the latest checkpoint that has is_passed = true
	update_current_checkpoint()
	
	# Get the latest passed checkpoint
	var latest_checkpoint = get_latest_passed_checkpoint()
	
	#print(latest_checkpoint)
	
	var target_player = latest_checkpoint.passed_player
	
	if target_player and player1 and player2:
		#print(target_player.get_parent().name)
		
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
		checkpoint.passed_player = null
	
	# Reset current checkpoint back to starting one
	current_checkpoint_index = 0
	
	print("All checkpoints completed! Resetting to start.")

func check_players_on_screen():
	# Get camera viewport rect in world coordinates
	var camera = $Camera2D
	var viewport_size = get_viewport().get_visible_rect().size
	var camera_pos = camera.global_position + camera.offset
	
	# Account for camera zoom - the actual visible area is larger when zoomed out
	var actual_visible_size = viewport_size / camera.zoom
	
	# Calculate screen bounds with zoom consideration
	var screen_bounds = Rect2(
		camera_pos - actual_visible_size / 2,
		actual_visible_size
	)
	
	# Add a buffer around the screen (so players don't get destroyed immediately when they go slightly off-screen)
	var buffer = 100.0
	screen_bounds = screen_bounds.grow(buffer)
	
	# Check player1
	if player1 and is_instance_valid(player1) and not game_end:
		if not screen_bounds.has_point(player1.global_position):
			print("Player 1 went off-screen, destroying...")
			player1.queue_free()
			player1 = null
			$"win screen".visible = true
			$"win screen"/Label.text = "PLAYER 2"
			game_end = true
	
	# Check player2
	if player2 and is_instance_valid(player2) and not game_end:
		if not screen_bounds.has_point(player2.global_position):
			print("Player 2 went off-screen, destroying...")
			player2.queue_free()
			player2 = null
			$"win screen".visible = true
			$"win screen"/Label.text = "PLAYER 1"
			game_end = true
