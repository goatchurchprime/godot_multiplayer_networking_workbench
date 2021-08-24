extends Control

onready var NetworkGateway = get_node("../..")

func _on_StartENetmultiplayer_toggled(button_pressed):
	print(" _on_StartENetmultiplayer_toggled ", button_pressed, " !!!")
	if button_pressed:
		var portnumber = int(NetworkGateway.get_node("NetworkOptions/portnumber").text)
		var networkedmultiplayerserver = NetworkedMultiplayerENet.new()
		var servererror = networkedmultiplayerserver.create_server(portnumber)
		if servererror == 0:
			NetworkGateway.SetNetworkedMultiplayerPeer(networkedmultiplayerserver)
		else:
			print("networkedmultiplayer createserver Error: ", servererror)
			print("*** is there a server running on this port already? ", portnumber)
			#$ColorRect.color = Color.red
			NetworkGateway.get_node("NetworkOptions").select(NetworkGateway.NETWORK_OPTIONS.NETWORK_OFF)

	else:
		if get_tree().get_network_peer() != null:
			NetworkGateway._server_disconnected()
		
