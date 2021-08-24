extends Control

onready var NetworkGateway = get_node("../..")
onready var PlayerConnections = NetworkGateway.get_node("PlayerConnections")

func _on_StartENetmultiplayer_toggled(button_pressed):
	if button_pressed:
		var portnumber = int(NetworkGateway.get_node("NetworkOptions/portnumber").text)
		var networkedmultiplayerserver = NetworkedMultiplayerENet.new()
		var servererror = networkedmultiplayerserver.create_server(portnumber)
		if servererror == 0:
			PlayerConnections.SetNetworkedMultiplayerPeer(networkedmultiplayerserver)
		else:
			PlayerConnections.connectionlog("Server error: %d\n" % servererror)
			print("networkedmultiplayer createserver Error: ", servererror)
			print("*** is there a server running on this port already? ", portnumber)
			#$ColorRect.color = Color.red
			NetworkGateway.get_node("NetworkOptions").select(NetworkGateway.NETWORK_OPTIONS.NETWORK_OFF)

	else:
		if get_tree().get_network_peer() != null:
			PlayerConnections.force_server_disconnect()
		
