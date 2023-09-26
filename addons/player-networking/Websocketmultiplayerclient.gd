extends Control

@onready var NetworkGateway = get_node("../..")
@onready var PlayerConnections = NetworkGateway.get_node("PlayerConnections")

func _on_StartWebSocketmultiplayer_toggled(button_pressed):
	if button_pressed:
		var portnumber = int(NetworkGateway.get_node("NetworkOptions/portnumber").text)
		var ns = NetworkGateway.get_node("NetworkOptions").selected
		var serverIPnumber = NetworkGateway.get_node("NetworkOptions").get_item_text(ns).split(" ", 1)[0]
		var url = "ws://%s:%d" % [serverIPnumber, portnumber]
		print("Websocketclient connect to: ", url)
		var multiplayerpeer = WebSocketMultiplayerPeer.new();
		var E = multiplayerpeer.create_client(url)
		if E != OK:
			print("Bad start websocket")
			NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS.NETWORK_OFF)
			return

		multiplayer.multiplayer_peer = multiplayerpeer
		PlayerConnections.network_player_notyetconnected()
		assert (get_tree().multiplayer_poll)
			
	else:
		PlayerConnections._server_disconnected()


