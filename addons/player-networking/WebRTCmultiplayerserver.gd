extends Control

@onready var serversignalling = get_parent()
@onready var PlayerConnections = get_node("../../../PlayerConnections")


func _on_StartWebRTCmultiplayer_toggled(button_pressed):
	if button_pressed:
		var multiplayerpeer = WebRTCMultiplayerPeer.new()
		var E = multiplayerpeer.create_server()
		if E != OK:
			$StartWebRTCmultiplayer.button_pressed = false
			print("Failed ", error_string(E))
			return
		multiplayer.multiplayer_peer = multiplayerpeer
		assert(multiplayer.multiplayer_peer.is_server_relay_supported())
		assert (multiplayer.server_relay)
		assert (multiplayer.get_unique_id() == 1)
		assert (get_tree().multiplayer_poll)
		PlayerConnections.networkplayer_connected_to_server()

		serversignalling.mqttsig_client_connected.connect(server_client_connected) 
		serversignalling.mqttsig_client_disconnected.connect(server_client_disconnected) 
		serversignalling.mqttsig_packet_received.connect(server_packet_received) 
			
	else:
		serversignalling.mqttsig_client_connected.disconnect(server_client_connected) 
		serversignalling.mqttsig_client_disconnected.disconnect(server_client_disconnected) 
		serversignalling.mqttsig_packet_received.disconnect(server_packet_received) 
		PlayerConnections.force_server_disconnect()


func server_ice_candidate_created(mid_name, index_name, sdp_name, id):
	serversignalling.sendpacket_toclient(id, {"subject":"ice_candidate", "mid_name":mid_name, "index_name":index_name, "sdp_name":sdp_name})

func server_session_description_created(type, data, id):
	print("we got server_session_description_created ", type)
	assert (type == "offer")
	var peerconnection = multiplayer.multiplayer_peer.get_peer(id)
	peerconnection["connection"].set_local_description(type, data)
	serversignalling.sendpacket_toclient(id, {"subject":"offer", "data":data})
	$statuslabel.text = "offer"
		
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
		$statuslabel.text = "create offer"

	elif v["subject"] == "answer":
		print("Check equal multiplayer ", multiplayer, " vs ", multiplayer)
		assert (multiplayer.multiplayer_peer.is_class("WebRTCMultiplayerPeer"))
		var peerconnection = multiplayer.multiplayer_peer.get_peer(id)
		peerconnection["connection"].set_remote_description("answer", v["data"])
		$statuslabel.text = "answer"

	elif v["subject"] == "ice_candidate":
		var peerconnection = multiplayer.multiplayer_peer.get_peer(id)
		peerconnection["connection"].add_ice_candidate(v["mid_name"], v["index_name"], v["sdp_name"])
		$statuslabel.text = "ice_candidate"



