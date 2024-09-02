extends Control

@onready var NetworkGateway = find_parent("NetworkGateway")

func _on_StartWebSocketmultiplayer_toggled(button_pressed):
	if button_pressed:
		var portnumber = int(NetworkGateway.NetworkOptions_portnumber.text)
		var ns = NetworkGateway.NetworkOptions.selected
		var serverIPnumber = NetworkGateway.NetworkOptions.get_item_text(ns).split(" ", 1)[0]
		var url = "ws://%s:%d" % [serverIPnumber, portnumber]
		print("Websocketclient connect to: ", url)
		var multiplayerpeer = WebSocketMultiplayerPeer.new();
		var E = multiplayerpeer.create_client(url)
		if E != OK:
			print("Bad start websocket")
			NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS.NETWORK_OFF)
			return

		multiplayer.multiplayer_peer = multiplayerpeer
		
		NetworkGateway.PlayerConnections.deferred_playerconnections = [ ]
		assert (get_tree().multiplayer_poll)
			
	else:
		NetworkGateway.PlayerConnections._server_disconnected()
