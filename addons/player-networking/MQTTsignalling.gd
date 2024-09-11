extends Control

@onready var NetworkGateway = find_parent("NetworkGateway")

var playername = ""

var selectasserver = false
var selectasclient = false

var Hselectedserver = ""
var Hserverconnected = false

var Wserveractive = false

var xclientstatuses = { }
var xclientopenservers = [ ]
var xclienttreeitems = { }
var xclientclosedlist = [ ]


@onready var Roomplayertree = $VBox/HBoxM/HSplitContainer/Roomplayers/Tree
var Roomplayertreecaboosereached = false

@onready var Roomnametext = $VBox/HBoxM/HSplitContainer/Msettings/HBox/roomname
@onready var Clientidtext = $VBox/HBoxM/HSplitContainer/Msettings/HBox2/client_id
@onready var StatusMQTT = $VBox/HBoxM/HSplitContainer/Msettings/HBox4/StatusMQTT
@onready var StatusWebRTC = $VBox/HBoxM/HSplitContainer/Msettings/HBox5/StatusWebRTC

@onready var treenodeicon1 = ImageTexture.create_from_image(Image.load_from_file("res://addons/player-networking/AudioStreamPlayer3D.svg"))

func clearallstatuses():
	Roomplayertree.clear()
	Roomplayertree.create_item()
	xclienttreeitems.clear()
	xclientstatuses.clear()
	xclientclosedlist.clear()
	Roomplayertreecaboosereached = false
	Hselectedserver = ""
	Hserverconnected = false

func _ready():
	clearallstatuses()
	StatusMQTT.select(0)

var Dns = -1
func _on_NetworkOptionsMQTTWebRTC_item_selected(ns):
	Dns = ns
	selectasserver = (ns == NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_SERVER)
	selectasclient = (ns == NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_CLIENT)
	if ns == NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.NETWORK_OFF:
		NetworkGateway.ProtocolOptions.disabled = false
		stop_mqtt()
		return
		
	assert (NetworkGateway.ProtocolOptions.selected == NetworkGateway.NETWORK_PROTOCOL.WEBRTC_MQTTSIGNAL)
	NetworkGateway.ProtocolOptions.disabled = true
	NetworkGateway.PlayerConnections.clearconnectionlog()
	if StatusMQTT.selected == 0:
		if not start_mqtt():
			NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.NETWORK_OFF)
			return

	statuschange_chooseserverifnecessary(false)

	if selectasserver and StatusMQTT.selected == 2:
		startwebrtc_server()
	if not selectasserver and Wserveractive:
		stopwebrtc_server()
	
func publishstatus(status, Dselectedserver="", Dnconnections=null):
	StatusWebRTC.text = status 
	var v = {"subject":status, "playername":playername}
	if Dselectedserver:
		v["selectedserver"] = Dselectedserver
	if Dnconnections != null:
		v["nconnections"] = Dnconnections
	$MQTT.publish("%s/%s/status" % [Roomnametext.text, $MQTT.client_id], 
				  JSON.stringify(v), true)

func establishtreeitemparent(mclientid, par):
	if xclienttreeitems.has(mclientid) and is_instance_valid(xclienttreeitems[mclientid]):
		if xclienttreeitems[mclientid].get_parent() == par:
			return
		xclienttreeitems[mclientid].free()
	xclienttreeitems[mclientid] = Roomplayertree.create_item(par)

func clearclosedtopics():
	while xclientclosedlist:
		$MQTT.publish("%s/%s/status" % [Roomnametext.text, xclientclosedlist.pop_back()], "", true)

func processothermclientstatus(mclientid, v):
	var mstatus = v["subject"]

	if xclientopenservers.has(mclientid) and mstatus != "serveropen":
		if mclientid == Hselectedserver:
			print("Must disconnect webrtc here")
		xclientopenservers.erase(mclientid)

	if mstatus == "closed":
		if xclienttreeitems.has(mclientid):
			if is_instance_valid(xclienttreeitems[mclientid]):
				xclienttreeitems[mclientid].free()
			xclienttreeitems.erase(mclientid)
		xclientclosedlist.append(mclientid)
		if xclientstatuses.has(mclientid):
			xclientstatuses[mclientid] = mstatus
		return

	xclientstatuses[mclientid] = mstatus

	if mstatus == "unconnected":
		establishtreeitemparent(mclientid, Roomplayertree.get_root())
	if mstatus == "connecting":
		pass
	if mstatus == "connectto":
		var mselectedserver = v["selectedserver"]
		establishtreeitemparent(mclientid, xclienttreeitems[mselectedserver])

	if mstatus == "serveropen":
		if not xclientopenservers.has(mclientid):
			xclientopenservers.append(mclientid)
		clearclosedtopics()
		establishtreeitemparent(mclientid, Roomplayertree.get_root())
		xclienttreeitems[mclientid].set_icon(2, treenodeicon1)
	else:
		xclienttreeitems[mclientid].set_icon(2, null)
		
	xclienttreeitems[mclientid].set_text(0, "%s" % mclientid)
	if v.has("playername"):
		xclienttreeitems[mclientid].set_text(1, v["playername"])
		

func _on_mqtt_broker_disconnected():
	StatusMQTT.select(0)
	NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.NETWORK_OFF)
	clearallstatuses()

func _on_mqtt_broker_connected():
	assert (Roomnametext.text)
	StatusMQTT.select(2)
	$MQTT.subscribe("%s/+/status" % Roomnametext.text)
	$MQTT.subscribe("%s/+/packet/%s" % [Roomnametext.text, $MQTT.client_id])
	publishstatus("unconnected")  # this becomes the caboose
	if selectasserver:
		startwebrtc_server()

func start_mqtt():
	if not Roomnametext.text:  # check validity
		return false
	Roomnametext.editable = false
	clearallstatuses()
	randomize()
	$MQTT.client_id = "x%d" % (2 + (randi()%0x7ffffff8))
	Clientidtext.text = $MQTT.client_id
	playername = NetworkGateway.PlayerConnections.LocalPlayer.playername()
	StatusMQTT.select(1)
	$MQTT.set_last_will("%s/%s/status" % [Roomnametext.text, $MQTT.client_id], 
						JSON.stringify({"subject":"closed", "comment":"by_will"}), true)
	var brokerurl = $VBox/HBox/brokeraddress.text
	$VBox/HBox/brokeraddress.disabled = true
	$MQTT.connect_to_broker(brokerurl)
	return true

func stop_mqtt():
	print("Disconnecting MQTT")
	publishstatus("closed")
	$MQTT.disconnect_from_server()
	Roomnametext.editable = true
	Clientidtext.text = ""
	$VBox/HBox/brokeraddress.disabled = false
	if selectasclient:
		client_connection_closed()
		Hselectedserver = ""
		Hserverconnected = false

func sendpacket_toserver(v):
	assert (selectasclient)
	assert (Hselectedserver != "")
	var t = "%s/%s/packet/%s" % [Roomnametext.text, $MQTT.client_id, Hselectedserver]
	$MQTT.publish(t, JSON.stringify(v))

func sendpacket_toclient(wclientid, v):
	assert (selectasserver)
	var t = "%s/%s/packet/x%d" % [Roomnametext.text, $MQTT.client_id, wclientid]
	$MQTT.publish(t, JSON.stringify(v))


func statuschange_chooseserverifnecessary(caboosejustreached):
	if Dns == NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_NECESSARY:
		if Roomplayertreecaboosereached and xclientopenservers:
			NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_CLIENT)
		if caboosejustreached and not xclientopenservers:
			NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_SERVER)
	
	elif selectasclient and not Hselectedserver and xclientopenservers and Roomplayertreecaboosereached:
		print("choosefromopenservers_gochoosefromopenservers_go")
		assert (not selectasserver)
		assert (Hselectedserver == "")
		assert (Roomplayertreecaboosereached)
		var sel = Roomplayertree.get_selected()
		var selxid = sel.get_text(0) if sel else ""
		if xclientopenservers:
			Hselectedserver = selxid if selxid and xclientopenservers.has(selxid) else xclientopenservers[-1]
			sendpacket_toserver({"subject":"request_connection"})


func _on_mqtt_received_message(topic, msg):
	var stopic = topic.split("/")
	if msg == "":
		if len(stopic) >= 3 and stopic[-1] == "status":
			var mclientid = stopic[-2]
			if xclientstatuses.has(mclientid):
				assert (xclientstatuses[mclientid] == "closed")
				xclientstatuses.erase(mclientid)
			return

	var v = JSON.parse_string(msg)

	if len(stopic) >= 3: 
		if stopic[-1] == "status" and v.has("subject"):
			var mclientid = stopic[-2]
			processothermclientstatus(mclientid, v)
			if mclientid == $MQTT.client_id:
				Roomplayertreecaboosereached = true
				statuschange_chooseserverifnecessary(true)
			if v["subject"] == "serveropen":
				statuschange_chooseserverifnecessary(false)

	if len(stopic) >= 4 and stopic[-2] == "packet" and stopic[-1] == $MQTT.client_id:
		var sendingclientid = stopic[-3]
		if selectasserver:
			server_packet_received(sendingclientid, v)
		if selectasclient and sendingclientid == Hselectedserver:
			client_packet_received(v)

func stopwebrtc_server():
	NetworkGateway.PlayerConnections._server_disconnected()
	Wserveractive = false

func startwebrtc_server():
	publishstatus("serveropen", "", 0)
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
	Wserveractive = true

func server_ice_candidate_created(mid_name, index_name, sdp_name, id):
	sendpacket_toclient(id, {"subject":"ice_candidate", "mid_name":mid_name, "index_name":index_name, "sdp_name":sdp_name})

func server_session_description_created(type, data, id):
	print("we got server_session_description_created ", type)
	assert (type == "offer")
	var peerconnection = multiplayer.multiplayer_peer.get_peer(id)
	peerconnection["connection"].set_local_description(type, data)
	sendpacket_toclient(id, {"subject":"offer", "data":data})
	NetworkGateway.PlayerConnections.connectionlog("send offer %s" %id)

func Ddata_channel_created(channel):
	print("DDDdata_channel_created ", channel)

func server_packet_received(sendingclientid, v):
	var id = int(sendingclientid)
	if v["subject"] == "request_connection":
		var t = "%s/%s/packet/%s" % [Roomnametext.text, $MQTT.client_id, sendingclientid]
		$MQTT.publish(t, JSON.stringify({"subject":"connection_accepted"}))
		publishstatus("serveropen", "", 0)

	elif v["subject"] == "request_offer":
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

func client_ice_candidate_created(mid_name, index_name, sdp_name):
	sendpacket_toserver({"subject":"ice_candidate", "mid_name":mid_name, "index_name":index_name, "sdp_name":sdp_name})

func client_session_description_created(type, data):
	assert (type == "answer")
	var peer = multiplayer.multiplayer_peer.get_peer(1)
	peer["connection"].set_local_description("answer", data)
	sendpacket_toserver({"subject":"answer", "data":data})
	NetworkGateway.PlayerConnections.connectionlog("answer")
		
		
func client_connection_closed():
	if not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		var peer = multiplayer.multiplayer_peer.get_peer(1)
		if peer:
			peer["connection"].close()
	print("server client_disconnected ")

func client_packet_received(v):
	if v["subject"] == "connection_accepted":
		if not Hserverconnected:
			Hserverconnected = true
			publishstatus("connectto", Hselectedserver)
			startwebrtc_client()
	
	elif v["subject"] == "offer":
		var peerconnection = WebRTCPeerConnection.new()
		peerconnection.session_description_created.connect(client_session_description_created)
		peerconnection.ice_candidate_created.connect(client_ice_candidate_created)

		peerconnection.initialize({"iceServers": [ { "urls": ["stun:stun.l.google.com:19302"] } ] })
		var E = multiplayer.multiplayer_peer.add_peer(peerconnection, 1)
		if E != 0:	print("Errrr3 ", E)
		E = peerconnection.set_remote_description("offer", v["data"])
		if E != 0:	print("Errrr ", E)
		assert (multiplayer.get_unique_id() == int($MQTT.client_id))
		NetworkGateway.PlayerConnections.connectionlog("receive offer")
		StatusWebRTC.text = "receive offer"

	elif v["subject"] == "ice_candidate":
		var peer = multiplayer.multiplayer_peer.get_peer(1)
		peer["connection"].add_ice_candidate(v["mid_name"], v["index_name"], v["sdp_name"])
		NetworkGateway.PlayerConnections.connectionlog("receive ice_candidate")
		StatusWebRTC.text = "ice candidate"

func startwebrtc_client():
	var multiplayerpeer = WebRTCMultiplayerPeer.new()
	print("*** clientsignalling.wclientid ", $MQTT.client_id)
	var E = multiplayerpeer.create_client(int($MQTT.client_id))
	if E != OK:
		print("bad")
		return
	multiplayer.multiplayer_peer = multiplayerpeer
	NetworkGateway.emit_signal("webrtc_multiplayerpeer_set", false)
	assert (get_tree().multiplayer_poll)
	assert (Hserverconnected)
	sendpacket_toserver({"subject":"request_offer"})
	StatusWebRTC.text = "request offer"
	NetworkGateway.PlayerConnections.connectionlog("request offer")
		
func stopwebrtc_client():
	NetworkGateway.PlayerConnections._server_disconnected()
