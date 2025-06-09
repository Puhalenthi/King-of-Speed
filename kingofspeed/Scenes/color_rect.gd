extends ColorRect


func _on_host_button_mouse_entered() -> void:
	$AnimationPlayer.play("111")




func _on_host_button_mouse_exited() -> void:
	$AnimationPlayer.play("1111")
