extends Area2D

@export var direction: int


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		var player = area.get_parent()
		print("found player: " + str(player.velocity))
		if player.velocity.y > 50:
			player.transferMomentum()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var player = body
		print("found player: " + str(player.velocity) + " " + str(player.get_facing_direction()) + " slope: " + str(direction))
		if player.velocity.y > 50 and player.get_facing_direction() == direction:
			player.transferMomentum(direction)
