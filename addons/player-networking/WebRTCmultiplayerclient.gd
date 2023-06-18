extends Control


@onready var clientsignalling = get_parent()
@onready var PlayerConnections = get_node("../../../PlayerConnections")

func client_ice_candidate_created(mid_name, index_name, sdp_name):
	clientsignalling.sendpacket_toserver({"subject":"ice_candidate", "mid_name":mid_name, "index_name":index_name, "sdp_name":sdp_name})

func client_session_description_created(type, data):
	assert (type == "answer")
	var peer = get_tree().get_multiplayer().multiplayer_peer.get_peer(1)
	peer["connection"].set_local_description("answer", data)
	clientsignalling.sendpacket_toserver({"subject":"answer", "data":data})
	$statuslabel.text = "answer"
		
func client_connection_established(lwclientid):
	print("server client connected ", lwclientid)
	if $StartWebRTCmultiplayer.pressed:
		clientsignalling.sendpacket_toserver({"subject":"request_offer"})
		$statuslabel.text = "request_offer"

func client_connection_closed():
	if get_tree().get_multiplayer().multiplayer_peer != null:
		var peer = get_tree().get_multiplayer().multiplayer_peer.get_peer(1)
		peer["connection"].close()
	print("server client_disconnected ")

func client_packet_received(v):
	print("client packet_received ", v["subject"])
	if v["subject"] == "offer":
		var peer = WebRTCPeerConnection.new()
		peer.initialize({"iceServers": [ { "urls": ["stun:stun.l.google.com:19302"] } ] })
		peer.connect("session_description_created", Callable(self, "client_session_description_created"))
		peer.connect("ice_candidate_created", Callable(self, "client_ice_candidate_created"))

		var networkedmultiplayerclient = WebRTCMultiplayerPeer.new()
		print("Errr4A ", peer.get_connection_state())
		var E = networkedmultiplayerclient.initialize(clientsignalling.wclientid, true)
		if E != 0:	print("Errrr2 ", E)
		print("Errr4 ", peer.get_connection_state())
		E = networkedmultiplayerclient.add_peer(peer, 1)
		if E != 0:	print("Errrr3 ", E)
		E = peer.set_remote_description("offer", v["data"])
		if E != 0:	print("Errrr ", E)

		PlayerConnections.SetNetworkedMultiplayerPeer(networkedmultiplayerclient)
		get_tree().set_multiplayer_peer(networkedmultiplayerclient)
		assert (get_tree().get_multiplayer().get_unique_id() == clientsignalling.wclientid)
		$statuslabel.text = "receive offer"

	elif v["subject"] == "ice_candidate":
		assert (get_tree().network_peer.is_class("WebRTCMultiplayerPeer"))
		var peer = get_tree().get_multiplayer().multiplayer_peer.get_peer(1)
		peer["connection"].add_ice_candidate(v["mid_name"], v["index_name"], v["sdp_name"])
		$statuslabel.text = "rec ice_candidate"

func _on_StartWebRTCmultiplayer_toggled(button_pressed):
	if button_pressed:
		clientsignalling.connect("mqttsig_connection_established", Callable(self, "client_connection_established")) 
		clientsignalling.connect("mqttsig_connection_closed", Callable(self, "client_connection_closed")) 
		clientsignalling.connect("mqttsig_packet_received", Callable(self, "client_packet_received")) 
		if clientsignalling.isconnectedtosignalserver():
			clientsignalling.sendpacket_toserver({"subject":"request_offer"})
		$statuslabel.text = "request_offer"
		
	else:
		clientsignalling.disconnect("mqttsig_connection_established", Callable(self, "client_connection_established")) 
		clientsignalling.disconnect("mqttsig_connection_closed", Callable(self, "client_connection_closed")) 
		clientsignalling.disconnect("mqttsig_packet_received", Callable(self, "client_packet_received")) 
		if get_tree().get_multiplayer().multiplayer_peer != null:
			PlayerConnections.force_server_disconnect()
