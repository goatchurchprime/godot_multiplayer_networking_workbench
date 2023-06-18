extends Control

@onready var NetworkGateway = get_node("../..")
@onready var PlayerConnections = NetworkGateway.get_node("PlayerConnections")

func _on_StartENetmultiplayer_toggled(button_pressed):
	if button_pressed:
		var portnumber = int(NetworkGateway.get_node("NetworkOptions/portnumber").text)
		var ns = NetworkGateway.get_node("NetworkOptions").selected
		var serverIPnumber = NetworkGateway.get_node("NetworkOptions").get_item_text(ns).split(" ", 1)[0]
		var networkedmultiplayerclient = ENetMultiplayerPeer.new()
		var clienterror = networkedmultiplayerclient.create_client(serverIPnumber, portnumber, 0, 0)
		if clienterror == 0:
			PlayerConnections.SetNetworkedMultiplayerPeer(networkedmultiplayerclient)

	else:
		if not (get_tree().get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer):
			PlayerConnections.force_server_disconnect()
		
