extends Control

@onready var NetworkGateway = find_parent("NetworkGateway")


# var wclientid = int($MQTT.client_id)
var roomname = ""
var statustopic = ""
var playername = ""
var Dmqttbrokerconnected = false

var selectasserver = false
var selectasclient = false
var selectasnecessary = false

var Hselectedserver = ""
var Hserverconnected = false

var wclientid = -1  # stored here for now, but will specify from mqttid


func isconnectedtosignalserver():
	return Hserverconnected

@onready var Roomplayertree = $VBox/HBoxM/HSplitContainer/Roomplayers/Tree
var Roomplayertreecaboosereached = false
var roomplayertreeitem_ME = null

@onready var Roomnametext = $VBox/HBoxM/HSplitContainer/Msettings/HBox/roomname
@onready var Clientidtext = $VBox/HBoxM/HSplitContainer/Msettings/HBox2/client_id

@onready var treenodeicon1 = ImageTexture.create_from_image(Image.load_from_file("res://addons/player-networking/AudioStreamPlayer3D.svg"))

var xclientstatuses = { }
var xclienttreeitems = { }
var xclientclosedlist = [ ]

@onready var StartMQTTstatuslabel = $VBox/HBox2/statuslabel

func _ready():
	var root = Roomplayertree.create_item()

var Dns = -1
func _on_NetworkOptionsMQTTWebRTC_item_selected(ns):
	Dns = ns
	selectasserver = (ns == NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_SERVER)
	selectasclient = (ns == NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_CLIENT)
	selectasnecessary = (ns == NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_NECESSARY or ns == NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_NECESSARY_MANUALCHANGE)
	var selectasoff = (ns == NetworkGateway.NETWORK_OPTIONS.NETWORK_OFF)
	#assert (ProtocolOptions.selected == NETWORK_PROTOCOL.WEBRTC_MQTTSIGNAL)

	if selectasoff:
		NetworkGateway.ProtocolOptions.disabled = false
		$VBox/HBox2/StartMQTT.button_pressed = false
		return
		
	NetworkGateway.ProtocolOptions.disabled = true
	NetworkGateway.PlayerConnections.clearconnectionlog()
	$VBox/HBox2/StartMQTT.button_pressed = true
	$VBox/Servermode.visible = selectasserver
	$VBox/Clientmode.visible = selectasclient

	if selectasclient and not Hselectedserver and Roomplayertreecaboosereached:
		choosefromopenservers_go()

	if selectasserver and Dmqttbrokerconnected:
		startwebrtc_server()


#	if $MQTTsignalling/mqttautoconnect.button_pressed:
#		$MQTTsignalling/StartMQTT.button_pressed = selectasclient or selectasnecessary


	$VBox/Servermode/WebRTCmultiplayerserver/StartWebRTCmultiplayer.button_pressed = false
	$VBox/Servermode/WebRTCmultiplayerserver/StartWebRTCmultiplayer.disabled = true
	$VBox/Clientmode/WebRTCmultiplayerclient/StartWebRTCmultiplayer.button_pressed = false
	$VBox/Clientmode/WebRTCmultiplayerclient/StartWebRTCmultiplayer.disabled = true

func publishstatus(status, Dselectedserver="", Dnconnections=null):
	var v = {"subject":status, "playername":playername}
	if Dselectedserver:
		v["selectedserver"] = Dselectedserver
	if Dnconnections != null:
		v["nconnections"] = Dnconnections
	$MQTT.publish(statustopic, JSON.stringify(v), true)


func establishtreeitemparent(mclientid, par):
	if xclienttreeitems.has(mclientid) and is_instance_valid(xclienttreeitems[mclientid]):
		if xclienttreeitems[mclientid].get_parent() == par:
			return
		xclienttreeitems[mclientid].free()
	xclienttreeitems[mclientid] = Roomplayertree.create_item(par)

func processsubscribedstatus(mclientid, v):
	var mstatus = v["subject"]
	if mstatus == "closed":
		if xclienttreeitems.has(mclientid):
			if is_instance_valid(xclienttreeitems[mclientid]):
				xclienttreeitems[mclientid].free()
				$VBox/Servermode/WebRTCmultiplayerserver.server_client_disconnected(int(mclientid))
			xclienttreeitems.erase(mclientid)
		xclientclosedlist.append(mclientid)
		if xclientstatuses.has(mclientid):
			xclientstatuses[mclientid] = mstatus
		return

	xclientstatuses[mclientid] = mstatus
	if mstatus == "unconnected":
		establishtreeitemparent(mclientid, Roomplayertree.get_root())
		xclienttreeitems[mclientid].set_text(0, "%s" % mclientid)
	if mstatus == "connecting":
		pass
	if mstatus == "connected":
		var mselectedserver = v["selectedserver"]
		establishtreeitemparent(mclientid, xclienttreeitems[mselectedserver])
		xclienttreeitems[mclientid].set_text(0, "%s" % mclientid)
	if mstatus == "serveropen":
		clearclosedtopics()
		establishtreeitemparent(mclientid, Roomplayertree.get_root())
		xclienttreeitems[mclientid].set_text(0, "%s" % mclientid)
		xclienttreeitems[mclientid].set_icon(2, treenodeicon1)
	else:
		xclienttreeitems[mclientid].set_icon(2, null)
		
	if v.has("playername"):
		xclienttreeitems[mclientid].set_text(1, v["playername"])
		

func clearclosedtopics():
	while xclientclosedlist:
		$MQTT.publish("%s/%s/status" % [roomname, xclientclosedlist.pop_back()], "", true)


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
		var mclientid = stopic[-2]
		if stopic[-1] == "status" and v.has("subject"):
			processsubscribedstatus(mclientid, v)
			if mclientid == $MQTT.client_id:
				Roomplayertreecaboosereached = true
				if selectasclient and not Hselectedserver:
					choosefromopenservers_go()
			if Roomplayertreecaboosereached and v["subject"] == "serveropen" and selectasclient and not Hselectedserver:
				choosefromopenservers_go()

	if selectasserver:
		if len(stopic) >= 4 and stopic[-2] == "packet" and stopic[-1] == $MQTT.client_id:
			var sendingclientid = stopic[-3]
			if v["subject"] == "request_connection":
				var t = "%s/%s/packet/%s" % [roomname, $MQTT.client_id, sendingclientid]
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
						wclientid = int(v["wclientid"])
						$VBox/Clientmode/WebRTCmultiplayerclient.client_connection_established(wclientid)
						StartMQTTstatuslabel.text = "connected"
						publishstatus("connected", Hselectedserver)
						$VBox/Clientmode/WebRTCmultiplayerclient/StartWebRTCmultiplayer.disabled = false
						if $VBox/Clientmode/autoconnect.button_pressed:
							$VBox/Clientmode/WebRTCmultiplayerclient/StartWebRTCmultiplayer.button_pressed = true
				else:
					$VBox/Clientmode/WebRTCmultiplayerclient.client_packet_received(v)


func _on_mqtt_broker_disconnected():
	Dmqttbrokerconnected = false
	$VBox/HBox2/StartMQTT.button_pressed = false

func _on_mqtt_broker_connected():
	assert (roomname)
	Dmqttbrokerconnected = true
	$MQTT.subscribe("%s/+/status" % roomname)
	$MQTT.subscribe("%s/+/packet/%s" % [roomname, $MQTT.client_id])
	publishstatus("unconnected")

	if selectasserver:
		startwebrtc_server()
	if selectasclient:
		if Hselectedserver != "":
			publishstatus("connecting", Hselectedserver)
		else:
			publishstatus("unconnected")
		StartMQTTstatuslabel.text = "pending"


func _on_start_mqtt_toggled(toggled_on):
	if toggled_on:
		Roomnametext.editable = false
		Roomplayertree.clear()
		xclienttreeitems.clear()
		xclientstatuses.clear()
		xclientclosedlist.clear()
		var root = Roomplayertree.create_item()
		Roomplayertreecaboosereached = false
		Hselectedserver = ""
		Hserverconnected = false
		roomname = Roomnametext.text
		randomize()
		$MQTT.client_id = "x%d" % (2 + (randi()%0x7ffffff8))
		Clientidtext.text = $MQTT.client_id
		statustopic = "%s/%s/status" % [roomname, $MQTT.client_id]
		playername = NetworkGateway.PlayerConnections.LocalPlayer.playername()
		StartMQTTstatuslabel.text = "on"
		$MQTT.set_last_will(statustopic, JSON.stringify({"subject":"closed", "comment":"by_will"}), true)
		StartMQTTstatuslabel.text = "connecting"
		var brokerurl = $VBox/HBox/brokeraddress.text
		$VBox/HBox/brokeraddress.disabled = true
		$MQTT.connect_to_broker(brokerurl)

	else:
		print("Disconnecting MQTT")
		publishstatus("closed")
		$MQTT.disconnect_from_server()
		StartMQTTstatuslabel.text = "off"
		roomname = ""
		statustopic = ""
		Roomnametext.editable = true
		Clientidtext.text = ""
		$VBox/HBox/brokeraddress.disabled = false

		var scmode = $VBox/Servermode if selectasserver else $VBox/Clientmode
		if selectasserver:
			for s in scmode.clientidtowclientid:
				scmode.emit_signal("mqttsig_client_disconnected", scmode.clientidtowclientid[s])
			scmode.get_node("ClientsList").clear()
			scmode.clientidtowclientid.clear()
			scmode.wclientidtoclientid.clear()
		if selectasclient:
			$VBox/Clientmode/WebRTCmultiplayerclient.client_connection_closed()
			Hselectedserver = ""
			Hserverconnected = false
			wclientid = -1

func sendpacket_toserver(v):
	assert (selectasclient)
	assert (Hselectedserver != "")
	print(";;; packt to server ", v)
	var t = "%s/%s/packet/%s" % [roomname, $MQTT.client_id, Hselectedserver]
	$MQTT.publish(t, JSON.stringify(v))

func sendpacket_toclient(wclientid, v):
	assert (selectasserver)
	var t = "%s/%s/packet/x%d" % [roomname, $MQTT.client_id, wclientid]
	print(" >>> packet to client ", t, v)
	$MQTT.publish(t, JSON.stringify(v))


func choosefromopenservers_go():
	print("choosefromopenservers_gochoosefromopenservers_go")
	assert (not selectasserver)
	assert (Hselectedserver == "")
	assert (Roomplayertreecaboosereached)
	var sel = Roomplayertree.get_selected()
	var serversopen = [ ]
	for ss in xclientstatuses:
		if xclientstatuses[ss] == "serveropen":
			if sel and xclienttreeitems[ss] == sel:
				Hselectedserver = ss
				break
			serversopen.append(ss)
	if Hselectedserver == "" and serversopen:
		Hselectedserver = serversopen[0]
	
	if Hselectedserver != "":
		sendpacket_toserver({"subject":"request_connection"})


func startwebrtc_server():
	publishstatus("serveropen", "", 0)
	StartMQTTstatuslabel.text = "server"
	
	$VBox/Servermode/WebRTCmultiplayerserver/StartWebRTCmultiplayer.disabled = false
	if $VBox/Servermode/autoconnect.button_pressed:
		$VBox/Servermode/WebRTCmultiplayerserver/StartWebRTCmultiplayer.button_pressed = true
