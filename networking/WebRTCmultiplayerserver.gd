extends Control

onready var serversignalling = get_parent()
	
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
	print("server packet_received ", id, v["subject"])
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
		get_tree().set_network_peer(networkedmultiplayerserver)
		assert (get_tree().get_network_unique_id() == 1)
		serversignalling.connect("client_connected", self, "server_client_connected") 
		serversignalling.connect("client_disconnected", self, "server_client_disconnected") 
		serversignalling.connect("packet_received", self, "server_packet_received") 
		get_node("../../..")._connected_to_server()
			
	else:
		get_tree().set_network_peer(null)
		serversignalling.disconnect("client_connected", self, "server_client_connected") 
		serversignalling.disconnect("client_disconnected", self, "server_client_disconnected") 
		serversignalling.disconnect("packet_received", self, "server_packet_received") 
		get_node("../../..")._server_disconnected()
