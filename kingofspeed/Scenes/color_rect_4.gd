extends ColorRect


func _on_quit_mouse_entered() -> void:
	$AnimationPlayer.play("3")


func _on_quit_mouse_exited() -> void:
	$AnimationPlayer.play("33")
