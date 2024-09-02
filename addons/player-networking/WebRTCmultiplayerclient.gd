extends Control


@onready var clientsignalling = get_parent()
@onready var NetworkGateway = find_parent("NetworkGateway")


func client_ice_candidate_created(mid_name, index_name, sdp_name):
	clientsignalling.sendpacket_toserver({"subject":"ice_candidate", "mid_name":mid_name, "index_name":index_name, "sdp_name":sdp_name})

func client_session_description_created(type, data):
	assert (type == "answer")
	var peer = multiplayer.multiplayer_peer.get_peer(1)
	peer["connection"].set_local_description("answer", data)
	clientsignalling.sendpacket_toserver({"subject":"answer", "data":data})
	NetworkGateway.PlayerConnections.connectionlog("answer")
	$statuslabel.text = "answer"
		
func client_connection_established(lwclientid):
	print("server client connected ", lwclientid)
	if $StartWebRTCmultiplayer.button_pressed:
		clientsignalling.sendpacket_toserver({"subject":"request_offer"})
		NetworkGateway.PlayerConnections.connectionlog("request_offer")
		$statuslabel.text = "request offer"
		
func client_connection_closed():
	if not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		var peer = multiplayer.multiplayer_peer.get_peer(1)
		if peer:
			peer["connection"].close()
	print("server client_disconnected ")

func client_packet_received(v):
	print("client packet_received ", v["subject"])
	if v["subject"] == "offer":
		var peerconnection = WebRTCPeerConnection.new()
		peerconnection.session_description_created.connect(client_session_description_created)
		peerconnection.ice_candidate_created.connect(client_ice_candidate_created)

		peerconnection.initialize({"iceServers": [ { "urls": ["stun:stun.l.google.com:19302"] } ] })
		var E = multiplayer.multiplayer_peer.add_peer(peerconnection, 1)
		if E != 0:	print("Errrr3 ", E)
		E = peerconnection.set_remote_description("offer", v["data"])
		if E != 0:	print("Errrr ", E)
		assert (multiplayer.get_unique_id() == clientsignalling.wclientid)
		NetworkGateway.PlayerConnections.connectionlog("receive offer")
		$statuslabel.text = "receive offer"

	elif v["subject"] == "ice_candidate":
		var peer = multiplayer.multiplayer_peer.get_peer(1)
		peer["connection"].add_ice_candidate(v["mid_name"], v["index_name"], v["sdp_name"])
		NetworkGateway.PlayerConnections.connectionlog("receive ice_candidate")
		$statuslabel.text = "ice candidate"

func _on_StartWebRTCmultiplayer_toggled(button_pressed):
	if button_pressed:
		var multiplayerpeer = WebRTCMultiplayerPeer.new()
		var E = multiplayerpeer.create_client(clientsignalling.wclientid)
		if E != OK:
			print("bad")
			return
		multiplayer.multiplayer_peer = multiplayerpeer
		NetworkGateway.emit_signal("webrtc_multiplayerpeer_set", false)

		assert (get_tree().multiplayer_poll)
		
		clientsignalling.mqttsig_connection_established.connect(client_connection_established) 
		clientsignalling.mqttsig_connection_closed.connect(client_connection_closed) 
		clientsignalling.mqttsig_packet_received.connect(client_packet_received) 
		if clientsignalling.isconnectedtosignalserver():
			clientsignalling.sendpacket_toserver({"subject":"request_offer"})
		NetworkGateway.PlayerConnections.connectionlog("request offer")
		$statuslabel.text = "request offer"
		
	else:
		clientsignalling.mqttsig_connection_established.disconnect(client_connection_established) 
		clientsignalling.mqttsig_connection_closed.disconnect(client_connection_closed) 
		clientsignalling.mqttsig_packet_received.disconnect(client_packet_received) 
		NetworkGateway.PlayerConnections._server_disconnected()
