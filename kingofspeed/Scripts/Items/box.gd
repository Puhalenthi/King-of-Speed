extends CharacterBody2D

@export var gravity: float = 980.0

func _physics_process(delta: float) -> void:
	velocity.y += gravity * delta
	move_and_slide()

func spawn(player: Node):
	global_position = player.global_position
	print(global_position)
	player.get_parent().add_child(self)
	await get_tree().create_timer(30.0).timeout
	queue_free()
