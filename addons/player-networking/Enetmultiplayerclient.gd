extends Control

@onready var NetworkGateway = get_node("../..")
@onready var PlayerConnections = NetworkGateway.get_node("PlayerConnections")

func _on_StartENetmultiplayer_toggled(button_pressed):
	if button_pressed:
		var portnumber = int(NetworkGateway.get_node("NetworkOptions/portnumber").text)
		var ns = NetworkGateway.get_node("NetworkOptions").selected
		var serverIPnumber = NetworkGateway.get_node("NetworkOptions").get_item_text(ns).split(" ", 1)[0]

		var multiplayerpeer = ENetMultiplayerPeer.new()
		var E = multiplayerpeer.create_client(serverIPnumber, portnumber, 0, 0)
		if E != OK:
			print("Error ", E)
			return
		
		multiplayer.multiplayer_peer = multiplayerpeer
		PlayerConnections.network_player_notyetconnected()
		assert (get_tree().multiplayer_poll)


	else:
		PlayerConnections._server_disconnected()
		
