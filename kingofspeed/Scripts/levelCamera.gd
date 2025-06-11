extends Node2D

var player1
var player2

func _ready() -> void:
	player1 = $Player/CharacterBody2D
	player2 = $Player2/CharacterBody2D

func _physics_process(delta: float) -> void:
	if player1 and player2:
		#print(player1.global_position)
		#print(player2.global_position)
		var midpoint = (player1.global_position + player2.global_position) / 2
		$Camera2D.offset = midpoint
		$Camera2D.force_update_scroll()
		#print(midpoint)
