extends Node2D

var button_type = null

@onready var online_menu = $CanvasLayer
@onready var address_entry = $CanvasLayer/AddressEntry

const Player = preload("res://Scenes/player.tscn")
const PORT: int = 9999
var enet_peer = ENetMultiplayerPeer.new()
var nonlocal = false

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
	multiplayer.peer_disconnected.connect(remove_player)

	add_player(multiplayer.get_unique_id())
	
	if nonlocal:
		upnp_setup()

func _on_join_button_pressed() -> void:
	online_menu.hide()
	if address_entry.text == "":
		enet_peer.create_client("localhost", PORT)
	enet_peer.create_client(address_entry.text, PORT)
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

func remove_player(peer_id):
	var player = get_node_or_null(str(peer_id))
	if player:
		player.queue_free()
		
func upnp_setup():
	var upnp = UPNP.new()
	
	var discover_result = upnp.discover()
	assert(discover_result == UPNP.UPNP_RESULT_SUCCESS, \
		"UPNP Discover Failed! Error %s" % discover_result)
		
	assert(upnp.get_gateway() and upnp.get_gateway().is_valid_gateway(), \
		"UPNP Invalid Gateway!")
		
	var map_result = upnp.add_port_mapping(PORT)
	assert(map_result == UPNP.UPNP_RESULT_SUCCESS, \
		"UPNP Port Mapping Failed! Error %s" % map_result)
		
	print("Success! Join Address: %s" % upnp.query_external_address())

# when matous adds a UPNP checkbox to the menu
# func _on_check_button_toggled(toggled_on):
	# nonlocal = not(nonlocal)
