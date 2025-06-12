extends CanvasLayer




func _on_back_to_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/LocalMenu.tscn")

func _on_rematch_pressed() -> void:
	get_tree().reload_current_scene()
