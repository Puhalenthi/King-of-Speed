extends Node2D
func _ready():
	$Lfade/Ltimer.start()
	$Lfade/AnimationPlayer.play("fadeout")


func _on_ltimer_timeout() -> void:
	$Lfade.hide()
