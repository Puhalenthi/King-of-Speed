extends Node2D

func _ready():
	$fade/Timer.start()
	$fade/AnimationPlayer.play("fadeout")


func _on_timer_timeout() -> void:
	$fade.hide()
