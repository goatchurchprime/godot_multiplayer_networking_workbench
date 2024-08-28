extends Control

@onready var NetworkGateway = get_node("../../../../../..")
@onready var PlayerConnections = NetworkGateway.get_node("PlayerConnections")

func _on_StartWebSocketmultiplayer_toggled(button_pressed):
	if button_pressed:
		var portnumber = int(NetworkGateway.NetworkOptions_portnumber.text)
		var multiplayerpeer = WebSocketMultiplayerPeer.new()
		var E = multiplayerpeer.create_server(portnumber)
		if E != OK:
			$StartWebSocketmultiplayer.button_pressed = false
			print("Failed code: [", error_string(E))
			PlayerConnections.connectionlog("Server error: %d\n" % E)
			print("networkedmultiplayer createserver Error: ", E)
			print("*** is there a server running on this port already? ", portnumber)
			NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS.NETWORK_OFF)

		multiplayer.multiplayer_peer = multiplayerpeer
		assert (multiplayer.server_relay)
		assert (multiplayer.get_unique_id() == 1)
		assert (get_tree().multiplayer_poll)
		PlayerConnections._connected_to_server()

	else:
		PlayerConnections._server_disconnected()
		
