extends PanelContainer

@onready var NetworkGateway = find_parent("NetworkGateway")

func _on_StartENetmultiplayer_toggled(button_pressed):
	if button_pressed:
		var portnumber = int(NetworkGateway.NetworkOptions_portnumber.text)
		var ns = NetworkGateway.NetworkOptions.selected
		var serverIPnumber = NetworkGateway.NetworkOptions.get_item_text(ns).split(" ", 1)[0]

		var multiplayerpeer = ENetMultiplayerPeer.new()
		var E = multiplayerpeer.create_client(serverIPnumber, portnumber, 0, 0)
		if E != OK:
			print("Error ", E)
			return
		
		multiplayer.multiplayer_peer = multiplayerpeer
		NetworkGateway.PlayerConnections.deferred_playerconnections = [ ]
		assert (get_tree().multiplayer_poll)


	else:
		NetworkGateway.PlayerConnections._server_disconnected()
		
