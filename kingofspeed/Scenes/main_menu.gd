extends Node2D
var button_type = null


func _on_play_online_pressed() -> void:
	button_type = "online"
	$fade.show()
	$fade/Timer.start()
	$fade/AnimationPlayer.play("fadein")
	


func _on_play_local_pressed() -> void:
	button_type = "local"
	$fade.show()
	$fade/Timer.start()
	$fade/AnimationPlayer.play("fadein")


func _on_timer_timeout() -> void:
	if button_type == "online":
		get_tree().change_scene_to_file("res://Scenes/OnlineMenu.tscn")
	if button_type == "local":
		get_tree().change_scene_to_file("res://Scenes/LocalMenu.tscn")
