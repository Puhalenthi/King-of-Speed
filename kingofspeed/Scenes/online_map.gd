extends Node2D

var button_type = null

@onready var online_menu      = $CanvasLayer
@onready var address_entry    = $CanvasLayer/AddressEntry

const Player = preload("res://Scenes/player.tscn")
const PORT   : int = 9999
var   enet_peer               = ENetMultiplayerPeer.new()

func _ready():
	# initial fade-in
	$CanvasLayer/fade/Timer.start()
	$CanvasLayer/fade/AnimationPlayer.play("fadeout")

func _on_timer_timeout() -> void:
	$CanvasLayer/fade.hide()

func _on_back_to_main_pressed() -> void:
	button_type = "back"
	$CanvasLayer/fade2.show()
	$CanvasLayer/fade2/Timer2.start()
	$CanvasLayer/fade2/AnimationPlayer.play("fadein")

func _on_timer_2_timeout() -> void:
	if button_type == "back":
		get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func _on_host_button_pressed() -> void:
	online_menu.hide()
	enet_peer.create_server(PORT)
	multiplayer.multiplayer_peer = enet_peer

	multiplayer.peer_connected.connect(add_player)

	add_player(multiplayer.get_unique_id())

func _on_join_button_pressed() -> void:
	online_menu.hide()
	enet_peer.create_client("localhost", PORT)
	multiplayer.multiplayer_peer = enet_peer

	multiplayer.connected_to_server.connect(_on_connection_succeeded)
	multiplayer.peer_connected.connect(add_player)

func _on_connection_succeeded() -> void:
	add_player(multiplayer.get_unique_id())

func add_player(peer_id: int) -> void:
	var player = Player.instantiate()
	player.name = str(peer_id)
	add_child(player)
	player.set_multiplayer_authority(peer_id)
