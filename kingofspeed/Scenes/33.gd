extends ColorRect


func _on_back_to_main_mouse_entered() -> void:
	$AnimationPlayer.play("333")


func _on_back_to_main_mouse_exited() -> void:
	$AnimationPlayer.play("3333")
