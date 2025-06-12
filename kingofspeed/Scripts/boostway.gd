extends Area2D

@export var direction : Vector2
@export var speed : int

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.velocity = speed * direction
