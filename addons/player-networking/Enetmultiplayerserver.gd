extends PanelContainer

@onready var NetworkGateway = find_parent("NetworkGateway")
@onready var PlayerConnections = NetworkGateway.get_node("PlayerConnections")

func _on_StartENetmultiplayer_toggled(button_pressed):
	if button_pressed:
		var portnumber = int(NetworkGateway.NetworkOptions_portnumber.text)
		var multiplayerpeer = ENetMultiplayerPeer.new()
		var E = multiplayerpeer.create_server(portnumber)
		if E != OK:
			$StartENetmultiplayer.button_pressed = false
			print("Failed ", error_string(E))
			PlayerConnections.connectionlog("Server error: %d\n" % E)
			print("networkedmultiplayer createserver Error: ", E)
			print("*** is there a server running on this port already? ", portnumber)
			NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS.NETWORK_OFF)
			return
		multiplayer.multiplayer_peer = multiplayerpeer
		assert (multiplayer.server_relay)
		assert (multiplayer.get_unique_id() == 1)
		assert (get_tree().multiplayer_poll)
		PlayerConnections._connected_to_server()
		
	else:
		PlayerConnections._server_disconnected()
		
