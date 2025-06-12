extends Node2D

var button_type = null

@onready var online_menu = $CanvasLayer
@onready var address_entry = $CanvasLayer/AddressEntry
@onready var username_entry = $CanvasLayer/Username

const Player = preload("res://Scenes/player.tscn")
const PORT: int = 9999

var enet_peer = ENetMultiplayerPeer.new()

var nonlocal = true

func _ready():
	# Set this node to always process so it works when paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Hide pause menu and set it to always process
	$"pause menu".hide()
	$"pause menu".process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Your existing code
	$CanvasLayer/fade/Timer.start()
	$CanvasLayer/fade/AnimationPlayer.play("fadeout")
	$CanvasLayer/CurrentIP.text = get_local_ip()

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_P:
		var pause_menu = $"pause menu"
		if pause_menu.visible:
			pause_menu.hide()
			get_tree().paused = false
		else:
			pause_menu.show()
			get_tree().paused = true

		
		
		
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
	var host_addr = address_entry.text.strip_edges()
	if host_addr == "":
		host_addr = "localhost"
	enet_peer.create_client(host_addr, PORT)
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.connected_to_server.connect(_on_connection_succeeded)
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)

func _on_connection_succeeded() -> void:
	add_player(multiplayer.get_unique_id())

func add_player(peer_id: int) -> void:
	var player = Player.instantiate()
	player.name = str(peer_id)
	add_child(player)
	player.set_multiplayer_authority(peer_id)
	if not player.is_multiplayer_authority():
		return
	var entered = username_entry.text.strip_edges()
	if entered == "":
		entered = "Player " + str(peer_id)
	var name_label = player.get_node("CharacterBody2D/UsernameLabel") as Label
	name_label.text = entered

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


func _on_check_button_toggled(toggled_on):
	nonlocal = not(nonlocal)

func get_local_ip() -> String:
	var ip_addresses = IP.get_local_addresses()
	for ip_address in ip_addresses:
		if ip_address.begins_with("192.168.") or ip_address.begins_with("10.") or \
			(ip_address.begins_with("172.") and int(ip_address.split(".")[1]) >= 16 and int(ip_address.split(".")[1]) <= 31):
			return ip_address
	return "127.0.0.1"
