extends ColorRect


func _on_canvas_layer_ready() -> void:
	$AnimationPlayer.play("1")
