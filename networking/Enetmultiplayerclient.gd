extends Control

onready var NetworkGateway = get_node("../..")

func _on_StartENetmultiplayer_toggled(button_pressed):
	print(" _on_StartENetmultiplayer_toggled ", button_pressed, " !!!")
	if button_pressed:
		var portnumber = int(NetworkGateway.get_node("NetworkOptions/portnumber").text)
		var ns = NetworkGateway.get_node("NetworkOptions").selected
		var serverIPnumber = NetworkGateway.get_node("NetworkOptions").get_item_text(ns).split(" ", 1)[0]
		var networkedmultiplayerclient = NetworkedMultiplayerENet.new()
		var clienterror = networkedmultiplayerclient.create_client(serverIPnumber, portnumber, 0, 0)
		if clienterror == 0:
			NetworkGateway.SetNetworkedMultiplayerPeer(networkedmultiplayerclient)

	else:
		if get_tree().get_network_peer() != null:
			NetworkGateway._server_disconnected()
		
