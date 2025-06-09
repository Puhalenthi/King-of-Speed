extends ColorRect


func _on_join_button_mouse_entered() -> void:
	$AnimationPlayer.play("222")


func _on_join_button_mouse_exited() -> void:
	$AnimationPlayer.play("2222")
