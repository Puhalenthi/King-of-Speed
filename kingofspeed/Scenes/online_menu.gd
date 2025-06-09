extends Node2D
var button_type = null
func _ready():
	$fade/Timer.start()
	$fade/AnimationPlayer.play("fadeout")


func _on_timer_timeout() -> void:
	$fade.hide()


func _on_back_to_main_pressed() -> void:
	button_type = "back"
	$fade2.show()
	$fade2/Timer2.start()
	$fade2/AnimationPlayer.play("fadein")


func _on_timer_2_timeout() -> void:
	if button_type == "back":
		get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
