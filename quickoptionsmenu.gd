extends HBoxContainer

@onready var NetworkGateway = $"../NetworkGateway"

# Need to find how to map the clicks from the mouse to the window

func _ready():
	set_as_top_level(true)
	$ShowNetworkGateway.set_pressed_no_signal(NetworkGateway.visible)
	if OS.has_feature("Server"):
		await get_tree().create_timer(1.5).timeout
		NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS.AS_SERVER)
	get_node("../SubViewportContainer/SubViewport").size = get_window().size
	
func _on_show_network_gateway_toggled(toggled_on):
	NetworkGateway.visible = toggled_on

func _on_connect_toggled(toggled_on):
	NetworkGateway.simple_webrtc_connect($Roomname.text if toggled_on else "")

func _on_cs_button_toggled(toggled_on):
	if toggled_on:
		NetworkGateway.ProtocolOptions.selected = NetworkGateway.NETWORK_PROTOCOL.ENET
		NetworkGateway._on_ProtocolOptions_item_selected(NetworkGateway.NETWORK_PROTOCOL.ENET)
		NetworkGateway.UDPipdiscovery.get_node("udpenabled").button_pressed = false
		NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS.AS_SERVER)
		NetworkGateway.set_vox_on()
	else:
		NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS.NETWORK_OFF)

func _on_cc_button_toggled(toggled_on):
	if toggled_on:
		NetworkGateway.ProtocolOptions.selected = NetworkGateway.NETWORK_PROTOCOL.ENET
		NetworkGateway._on_ProtocolOptions_item_selected(NetworkGateway.NETWORK_PROTOCOL.ENET)
		NetworkGateway.UDPipdiscovery.get_node("udpenabled").button_pressed = false
		NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS.FIXED_URL)
		#NetworkGateway.set_vox_on()
	else:
		NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS.NETWORK_OFF)

func _process(delta):
	$PlayerCount.value = NetworkGateway.Dconnectedplayerscount
	#print(get_viewport().canvas_transform.origin, get_viewport().global_canvas_transform.origin)

func _on_new_card_pressed():
	var multiplayerauthority = NetworkGateway.get_node(NetworkGateway.playersnodepath).get_node("../SyncObjects/MultiplayerSpawner")
	var data = { }
	var jj = get_node("../SubViewportContainer/SubViewport").canvas_transform.affine_inverse()
	data["gpos"] = jj*get_global_mouse_position() + Vector2(0,80)
	data["letter"] = "*next"
	var sid = multiplayerauthority.get_multiplayer_authority()
	multiplayerauthority.rpc_id(sid, "spawn", data)



var subviewpointcontainerhasmouse = false
func _on_sub_viewport_container_mouse_entered():
	subviewpointcontainerhasmouse = true
func _on_sub_viewport_container_mouse_exited():
	subviewpointcontainerhasmouse = false


func _on_physics_toggled(toggled_on):
	var spawnobjects = get_node("../SubViewportContainer/SubViewport/SyncObjects/SpawnedObjects")
	for c in spawnobjects.get_children():
		c.freeze = not toggled_on
	pass # Replace with function body.
