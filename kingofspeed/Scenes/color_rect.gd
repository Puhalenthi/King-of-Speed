extends ColorRect


func _on_play_online_mouse_entered() -> void:
	$AnimationPlayer.play("1")


func _on_play_online_mouse_exited() -> void:
	$AnimationPlayer.play("11")
