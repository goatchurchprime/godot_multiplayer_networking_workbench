extends Control


onready var clientsignalling = get_parent()


func client_ice_candidate_created(mid_name, index_name, sdp_name):
	clientsignalling.sendpacket_toserver({"subject":"ice_candidate", "mid_name":mid_name, "index_name":index_name, "sdp_name":sdp_name})

func client_session_description_created(type, data):
	assert (type == "answer")
	var peer = get_tree().get_network_peer().get_peer(1)
	peer["connection"].set_local_description("answer", data)
	clientsignalling.sendpacket_toserver({"subject":"answer", "data":data})
	$statuslabel.text = "answer"
		
func client_connection_established(lwclientid):
	print("server client connected ", lwclientid)
	if $StartWebRTCmultiplayer.pressed:
		clientsignalling.sendpacket_toserver({"subject":"request_offer"})
		$statuslabel.text = "request_offer"

func client_connection_closed():
	if get_tree().get_network_peer() == null:
		var peer = get_tree().get_network_peer().get_peer(1)
		peer.close()
	print("server client_disconnected ")

func client_packet_received(v):
	print("client packet_received ", v["subject"])
	if v["subject"] == "offer":
		var peer = WebRTCPeerConnection.new()
		peer.initialize({"iceServers": [ { "urls": ["stun:stun.l.google.com:19302"] } ] })
		peer.connect("session_description_created", self, "client_session_description_created")
		peer.connect("ice_candidate_created", self, "client_ice_candidate_created")
		var E = peer.set_remote_description("offer", v["data"])
		if E != 0:	print("Errrr ", E)

		var networkedmultiplayerclient = WebRTCMultiplayer.new()
		E = networkedmultiplayerclient.initialize(clientsignalling.wclientid, true)
		if E != 0:	print("Errrr2 ", E)
		E = networkedmultiplayerclient.add_peer(peer, 1)
		if E != 0:	print("Errrr3 ", E)
		get_tree().set_network_peer(networkedmultiplayerclient)
		assert (get_tree().get_network_unique_id() == clientsignalling.wclientid)
		$statuslabel.text = "recieve offer"
		get_node("../../../..").LocalPlayer.networkID = -1
			
	elif v["subject"] == "ice_candidate":
		assert (get_tree().network_peer.is_class("WebRTCMultiplayer"))
		var peer = get_tree().get_network_peer().get_peer(1)
		peer["connection"].add_ice_candidate(v["mid_name"], v["index_name"], v["sdp_name"])
		$statuslabel.text = "rec ice_candidate"

func _on_StartWebRTCmultiplayer_toggled(button_pressed):
	if button_pressed:
		clientsignalling.connect("connection_established", self, "client_connection_established") 
		clientsignalling.connect("connection_closed", self, "client_connection_closed") 
		clientsignalling.connect("packet_received", self, "client_packet_received") 
		if $StartWebRTCmultiplayer.pressed:
			clientsignalling.sendpacket_toserver({"subject":"request_offer"})
			$statuslabel.text = "request_offer"
	else:
		get_tree().set_network_peer(null)
		clientsignalling.disconnect("connection_established", self, "client_connection_established") 
		clientsignalling.disconnect("connection_closed", self, "client_connection_closed") 
		clientsignalling.disconnect("packet_received", self, "client_packet_received") 
