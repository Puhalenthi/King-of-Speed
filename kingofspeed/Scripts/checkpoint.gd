extends Node2D

@export var is_passed : bool
@export var passed_player : CharacterBody2D
@export var checkpoint_num : int

func _on_body_entered(body: Node2D) -> void:
	if not is_passed and body.is_in_group("player"):
		print("FOUND PLAYER:" + body.get_parent().name + " at " + name)
		passed_player = body
		is_passed = true
