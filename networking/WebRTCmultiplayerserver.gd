extends Control

onready var serversignalling = get_parent()
onready var PlayerConnections = get_node("../../../PlayerConnections")
var enable_experimental_server_relay = true

func server_ice_candidate_created(mid_name, index_name, sdp_name, id):
	serversignalling.sendpacket_toclient(id, {"subject":"ice_candidate", "mid_name":mid_name, "index_name":index_name, "sdp_name":sdp_name})

func server_session_description_created(type, data, id):
	assert (type == "offer")
	var peer = get_tree().network_peer.get_peer(id)
	peer["connection"].set_local_description(type, data)
	serversignalling.sendpacket_toclient(id, {"subject":"offer", "data":data})
	$statuslabel.text = "offer"
		
func server_client_connected(id):
	print("server client connected ", id)

func server_client_disconnected(id):
	print("server client_disconnected ", id)

func server_packet_received(id, v):
	#print("server packet_received ", id, v["subject"])
	if v["subject"] == "request_offer":
		var peer = WebRTCPeerConnection.new()
		peer.initialize({"iceServers": [ { "urls": ["stun:stun.l.google.com:19302"] } ] })
		peer.connect("session_description_created", self, "server_session_description_created", [id])
		peer.connect("ice_candidate_created", self, "server_ice_candidate_created", [id])
		get_tree().network_peer.add_peer(peer, id)
		var webrtcpeererror = peer.create_offer()
		print("peer create offer ", peer, "Error:", webrtcpeererror)
		$statuslabel.text = "create offer"
				
	elif v["subject"] == "answer":
		assert (get_tree().network_peer.is_class("WebRTCMultiplayer"))
		var peer = get_tree().network_peer.get_peer(id)
		peer["connection"].set_remote_description("answer", v["data"])
		$statuslabel.text = "answer"

	elif v["subject"] == "ice_candidate":
		var peer = get_tree().network_peer.get_peer(id)
		peer["connection"].add_ice_candidate(v["mid_name"], v["index_name"], v["sdp_name"])
		$statuslabel.text = "ice_candidate"

func _on_StartWebRTCmultiplayer_toggled(button_pressed):
	if button_pressed:
		var networkedmultiplayerserver = WebRTCMultiplayer.new()
		var servererror = networkedmultiplayerserver.initialize(1, true)
		assert (servererror == 0)
		if enable_experimental_server_relay and networkedmultiplayerserver.has_method("set_server_relay_enabled"):
			print("!!! enabling server relay !!!")
			networkedmultiplayerserver.set_server_relay_enabled(true)
			PlayerConnections.server_relay_player_connections = true
		PlayerConnections.SetNetworkedMultiplayerPeer(networkedmultiplayerserver)
			
		assert (get_tree().get_network_unique_id() == 1)
		serversignalling.connect("mqttsig_client_connected", self, "server_client_connected") 
		serversignalling.connect("mqttsig_client_disconnected", self, "server_client_disconnected") 
		serversignalling.connect("mqttsig_packet_received", self, "server_packet_received") 
			
	else:
		serversignalling.disconnect("mqttsig_client_connected", self, "server_client_connected") 
		serversignalling.disconnect("mqttsig_client_disconnected", self, "server_client_disconnected") 
		serversignalling.disconnect("mqttsig_packet_received", self, "server_packet_received") 
		PlayerConnections.server_relay_player_connections = false
		if get_tree().get_network_peer() != null:
			PlayerConnections.force_server_disconnect()


