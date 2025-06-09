extends Node2D
var button_type = null
func _ready():
	$Lfade/Ltimer.start()
	$Lfade/AnimationPlayer.play("fadeout")


func _on_ltimer_timeout() -> void:
	$Lfade.hide()


func _on_back_to_main_pressed() -> void:
	button_type = "back1"
	$LLfade.show()
	$LLfade/LLtimer.start()
	$LLfade/AnimationPlayer.play("fadein")


func _on_l_ltimer_timeout() -> void:
	if button_type == "back1":
		get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
