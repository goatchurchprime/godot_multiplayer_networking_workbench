extends Control

@onready var serversignalling = get_parent()
@onready var NetworkGateway = find_parent("NetworkGateway")


func _on_StartWebRTCmultiplayer_toggled(button_pressed):
	if button_pressed:
		var multiplayerpeer = WebRTCMultiplayerPeer.new()
		var E = multiplayerpeer.create_server()
		if E != OK:
			$StartWebRTCmultiplayer.button_pressed = false
			print("Failed ", error_string(E))
			return
		multiplayer.multiplayer_peer = multiplayerpeer
		NetworkGateway.emit_signal("webrtc_multiplayerpeer_set", true)

		assert(multiplayer.multiplayer_peer.is_server_relay_supported())
		assert (multiplayer.server_relay)
		assert (multiplayer.get_unique_id() == 1)
		assert (get_tree().multiplayer_poll)
		NetworkGateway.PlayerConnections._connected_to_server()

		serversignalling.mqttsig_client_connected.connect(server_client_connected) 
		serversignalling.mqttsig_client_disconnected.connect(server_client_disconnected) 
		serversignalling.mqttsig_packet_received.connect(server_packet_received) 
			
	else:
		serversignalling.mqttsig_client_connected.disconnect(server_client_connected) 
		serversignalling.mqttsig_client_disconnected.disconnect(server_client_disconnected) 
		serversignalling.mqttsig_packet_received.disconnect(server_packet_received) 
		NetworkGateway.PlayerConnections._server_disconnected()


func server_ice_candidate_created(mid_name, index_name, sdp_name, id):
	serversignalling.sendpacket_toclient(id, {"subject":"ice_candidate", "mid_name":mid_name, "index_name":index_name, "sdp_name":sdp_name})

func server_session_description_created(type, data, id):
	print("we got server_session_description_created ", type)
	assert (type == "offer")
	var peerconnection = multiplayer.multiplayer_peer.get_peer(id)
	peerconnection["connection"].set_local_description(type, data)
	serversignalling.sendpacket_toclient(id, {"subject":"offer", "data":data})
	NetworkGateway.PlayerConnections.connectionlog("send offer %s" %id)

func server_client_connected(id):
	print("server client connected ", id)

func server_client_disconnected(id):
	print("server client_disconnected ", id)

func Ddata_channel_created(channel):
	print("DDDdata_channel_created ", channel)

func server_packet_received(id, v):
	#print("server packet_received ", id, v["subject"])
	if v["subject"] == "request_offer":
		var peerconnection = WebRTCPeerConnection.new()
		peerconnection.session_description_created.connect(server_session_description_created.bind(id))
		peerconnection.ice_candidate_created.connect(server_ice_candidate_created.bind(id))
		peerconnection.data_channel_received.connect(Ddata_channel_created)

		peerconnection.initialize({"iceServers": [ { "urls": ["stun:stun.l.google.com:19302"] } ] })
		print("serverpacket peer.get_connection_state() ", peerconnection.get_connection_state())
		multiplayer.multiplayer_peer.add_peer(peerconnection, id)
		var webrtcpeererror = peerconnection.create_offer()
		print("peer create offer ", peerconnection, "id ", id, " Error:", webrtcpeererror, " connstate")
		NetworkGateway.PlayerConnections.connectionlog("create offer %s" %id)
		
	elif v["subject"] == "answer":
		print("Check equal multiplayer ", multiplayer, " vs ", multiplayer)
		assert (multiplayer.multiplayer_peer.is_class("WebRTCMultiplayerPeer"))
		var peerconnection = multiplayer.multiplayer_peer.get_peer(id)
		peerconnection["connection"].set_remote_description("answer", v["data"])
		NetworkGateway.PlayerConnections.connectionlog("receive answer %s" %id)

	elif v["subject"] == "ice_candidate":
		var peerconnection = multiplayer.multiplayer_peer.get_peer(id)
		peerconnection["connection"].add_ice_candidate(v["mid_name"], v["index_name"], v["sdp_name"])
		NetworkGateway.PlayerConnections.connectionlog("receive ice_candidate %s" %id)
