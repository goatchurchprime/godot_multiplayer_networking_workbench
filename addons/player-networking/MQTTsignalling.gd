extends Control

@onready var NetworkGateway = find_parent("NetworkGateway")

var playername = ""

var selectasserver = false
var selectasclient = false
var selectasnecessary = false

var Hselectedserver = ""
var Hserverconnected = false

var xclientstatuses = { }
var xclientopenservers = [ ]
var xclienttreeitems = { }
var xclientclosedlist = [ ]

func isconnectedtosignalserver():
	return Hserverconnected

@onready var Roomplayertree = $VBox/HBoxM/HSplitContainer/Roomplayers/Tree
var Roomplayertreecaboosereached = false

@onready var Roomnametext = $VBox/HBoxM/HSplitContainer/Msettings/HBox/roomname
@onready var Clientidtext = $VBox/HBoxM/HSplitContainer/Msettings/HBox2/client_id
@onready var StatusMQTT = $VBox/HBoxM/HSplitContainer/Msettings/HBox4/StatusMQTT
@onready var StatusWebRTC = $VBox/HBoxM/HSplitContainer/Msettings/HBox5/StatusWebRTC

@onready var treenodeicon1 = ImageTexture.create_from_image(Image.load_from_file("res://addons/player-networking/AudioStreamPlayer3D.svg"))

var wclientid = -1

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

	$VBox/Servermode.visible = selectasserver
	$VBox/Clientmode.visible = selectasclient

	statuschange_chooseserverifnecessary(false)

	if selectasserver and StatusMQTT.selected == 2:
		startwebrtc_server()
	else:
		$VBox/Servermode/WebRTCmultiplayerserver/StartWebRTCmultiplayer.button_pressed = false
		$VBox/Servermode/WebRTCmultiplayerserver/StartWebRTCmultiplayer.disabled = true
	
	if not selectasclient:
		$VBox/Clientmode/WebRTCmultiplayerclient/StartWebRTCmultiplayer.button_pressed = false
		$VBox/Clientmode/WebRTCmultiplayerclient/StartWebRTCmultiplayer.disabled = true

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
	if mstatus == "connected":
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
		

func clearclosedtopics():
	while xclientclosedlist:
		$MQTT.publish("%s/%s/status" % [Roomnametext.text, xclientclosedlist.pop_back()], "", true)


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

	if selectasserver:
		if len(stopic) >= 4 and stopic[-2] == "packet" and stopic[-1] == $MQTT.client_id:
			var sendingclientid = stopic[-3]
			if v["subject"] == "request_connection":
				var t = "%s/%s/packet/%s" % [Roomnametext.text, $MQTT.client_id, sendingclientid]
				$MQTT.publish(t, JSON.stringify({"subject":"connection_prepared", "wclientid":int(sendingclientid)}))
				publishstatus("serveropen", "", 0)
				$VBox/Servermode/WebRTCmultiplayerserver.server_client_connected(int(sendingclientid))
			else:
				$VBox/Servermode/WebRTCmultiplayerserver.server_packet_received(int(sendingclientid), v)
		
	if selectasclient:
		#$VBox/Clientmode.Dreceived_mqtt(stopic, v)
		if len(stopic) >= 4 and stopic[-2] == "packet" and stopic[-1] == $MQTT.client_id:
			var sendingserverid = stopic[-3]
			if sendingserverid == Hselectedserver:
				if v["subject"] == "connection_prepared":
					if not Hserverconnected:
						Hserverconnected = true
						$VBox/Clientmode/WebRTCmultiplayerclient.client_connection_established(v["wclientid"])
						publishstatus("connected", Hselectedserver)
						$VBox/Clientmode/WebRTCmultiplayerclient/StartWebRTCmultiplayer.disabled = false
						assert (wclientid == v["wclientid"])
						if $VBox/Clientmode/autoconnect.button_pressed:
							$VBox/Clientmode/WebRTCmultiplayerclient/StartWebRTCmultiplayer.button_pressed = true
				else:
					$VBox/Clientmode/WebRTCmultiplayerclient.client_packet_received(v)


func _on_mqtt_broker_disconnected():
	StatusMQTT.select(0)
	NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.NETWORK_OFF)
	clearallstatuses()

func _on_mqtt_broker_connected():
	assert (Roomnametext.text)
	StatusMQTT.select(2)
	$MQTT.subscribe("%s/+/status" % Roomnametext.text)
	$MQTT.subscribe("%s/+/packet/%s" % [Roomnametext.text, $MQTT.client_id])
	publishstatus("unconnected")

	if selectasserver:
		startwebrtc_server()
	if selectasclient:
		if Hselectedserver != "":
			publishstatus("connecting", Hselectedserver)
		else:
			publishstatus("unconnected")

func start_mqtt():
	if not Roomnametext.text:  # check validity
		return false
	Roomnametext.editable = false
	clearallstatuses()
	randomize()
	$MQTT.client_id = "x%d" % (2 + (randi()%0x7ffffff8))
	wclientid = int($MQTT.client_id)
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
	if selectasserver:
		pass
		#for s in scmode.clientidtowclientid:
		#	$VBox/Servermode/WebRTCmultiplayerserver.server_client_disconnected(int(s))
	if selectasclient:
		$VBox/Clientmode/WebRTCmultiplayerclient.client_connection_closed()
		Hselectedserver = ""
		Hserverconnected = false

func sendpacket_toserver(v):
	assert (selectasclient)
	assert (Hselectedserver != "")
	print(";;; packt to server ", v)
	var t = "%s/%s/packet/%s" % [Roomnametext.text, $MQTT.client_id, Hselectedserver]
	$MQTT.publish(t, JSON.stringify(v))

func sendpacket_toclient(wclientid, v):
	assert (selectasserver)
	var t = "%s/%s/packet/x%d" % [Roomnametext.text, $MQTT.client_id, wclientid]
	print(" >>> packet to client ", t, v)
	$MQTT.publish(t, JSON.stringify(v))



func statuschange_chooseserverifnecessary(caboosejustreached):
	if (Dns == NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_NECESSARY):
		if Roomplayertreecaboosereached and xclientopenservers:
			NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_CLIENT)
		if caboosejustreached and not xclientopenservers:
			NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_SERVER)
	
	if selectasclient and not Hselectedserver and xclientopenservers and Roomplayertreecaboosereached:
		print("choosefromopenservers_gochoosefromopenservers_go")
		assert (not selectasserver)
		assert (Hselectedserver == "")
		assert (Roomplayertreecaboosereached)
		var sel = Roomplayertree.get_selected()
		var selxid = sel.get_text(0) if sel else ""
		if xclientopenservers:
			Hselectedserver = selxid if selxid and xclientopenservers.has(selxid) else xclientopenservers[-1]
			sendpacket_toserver({"subject":"request_connection"})

func startwebrtc_server():
	publishstatus("serveropen", "", 0)
	
	$VBox/Servermode/WebRTCmultiplayerserver/StartWebRTCmultiplayer.disabled = false
	if $VBox/Servermode/autoconnect.button_pressed:
		$VBox/Servermode/WebRTCmultiplayerserver/StartWebRTCmultiplayer.button_pressed = true
