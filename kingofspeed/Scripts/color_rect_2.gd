extends ColorRect


func _on_play_local_mouse_entered() -> void:
	$AnimationPlayer.play("2")


func _on_play_local_mouse_exited() -> void:
	$AnimationPlayer.play("22")
