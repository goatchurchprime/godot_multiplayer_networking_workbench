extends Control

@onready var NetworkGateway = find_parent("NetworkGateway")

# var wclientid = int($MQTT.client_id)
var roomname = ""
var statustopic = ""
var playername = ""

var selectasserver = false
var selectasclient = false
var selectasnecessary = false

var wclientid = -1  # stored here for now, but will specify from mqttid

signal mqttsig_connection_established(wclientid)
signal mqttsig_connection_closed()
signal mqttsig_packet_received(v)


func isconnectedtosignalserver():
	return $VBox/Clientmode.serverconnected

@onready var Roomplayertree = $VBox/HBoxM/HSplitContainer/Roomplayers/Tree
var Roomplayertreecaboosereached = false

var roomplayertreeunconnected = null
var roomplayertreeitem_ME = null

@onready var treenodeicon1 = ImageTexture.create_from_image(Image.load_from_file("res://addons/player-networking/AudioStreamPlayer3D.svg"))

var xclientstatuses = { }
var xclienttreeitems = { }

func _ready():
	var root = Roomplayertree.create_item()
	roomplayertreeunconnected = Roomplayertree.create_item()
	roomplayertreeunconnected.set_text(0, "unconnected")
	roomplayertreeunconnected.set_icon(1, treenodeicon1)


var Dns = -1
func _on_NetworkOptionsMQTTWebRTC_item_selected(ns):
	Dns = ns
	selectasserver = (ns == NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_SERVER)
	selectasclient = (ns == NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_CLIENT)
	selectasnecessary = (ns == NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_NECESSARY or ns == NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_NECESSARY_MANUALCHANGE)
	var selectasoff = (ns == NetworkGateway.NETWORK_OPTIONS.NETWORK_OFF)
	#assert (ProtocolOptions.selected == NETWORK_PROTOCOL.WEBRTC_MQTTSIGNAL)

	if not selectasoff:
		NetworkGateway.PlayerConnections.clearconnectionlog()

	$VBox/HBox2/StartMQTT.button_pressed = false
	await get_tree().process_frame

	$VBox/Servermode.visible = selectasserver
	$VBox/Clientmode.visible = selectasclient
	NetworkGateway.ProtocolOptions.disabled = not selectasoff
	if selectasserver:
		$VBox/HBox2/StartMQTT.connect("toggled", Callable($VBox/Servermode, "_on_StartServer_toggled"))
		if $VBox/HBox2/mqttautoconnect.button_pressed:
			$VBox/HBox2/StartMQTT.button_pressed = true
	if selectasclient or selectasnecessary:
		$VBox/HBox2/StartMQTT.connect("toggled", Callable($VBox/Clientmode, "_on_StartClient_toggled"))
		if $VBox/HBox2/mqttautoconnect.button_pressed:
			$VBox/HBox2/StartMQTT.button_pressed = true
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

func clearclosedtopics():
	for x in xclientstatuses:
		if xclientstatuses[x] == "closed":
			$MQTT.publish("%s/%s/status" % [roomname, x], "", true)


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
			xclientstatuses[mclientid] = v["subject"]
			if mclientid == $MQTT.client_id:
				Roomplayertreecaboosereached = true

			#if not xclienttreeitems.has(mclientid):
			if v["subject"] == "unconnected":
				xclienttreeitems[mclientid] = Roomplayertree.create_item(roomplayertreeunconnected)
				xclienttreeitems[mclientid].set_text(0, "%s" % mclientid)
			if v["subject"] == "serveropen":
				clearclosedtopics()
				if xclienttreeitems.has(mclientid):
					xclienttreeitems[mclientid].free()
				xclienttreeitems[mclientid] = Roomplayertree.create_item()
				xclienttreeitems[mclientid].set_text(0, "%s" % mclientid)
				xclienttreeitems[mclientid].set_icon(1, treenodeicon1)
			if v["subject"] == "closed":
				if xclienttreeitems.has(mclientid):
					xclienttreeitems[mclientid].free()
					xclienttreeitems.erase(mclientid) 

	if selectasserver:
		$VBox/Servermode.Dreceived_mqtt(stopic, v)
	if selectasclient:
		$VBox/Clientmode.Dreceived_mqtt(stopic, v)

func _on_mqtt_broker_disconnected():
	$VBox/HBox2/StartMQTT.button_pressed = false

func _on_mqtt_broker_connected():
	assert (roomname)
	$MQTT.subscribe("%s/+/status" % roomname)
	publishstatus("unconnected")
	if selectasserver:
		$VBox/Servermode.Don_broker_connect()
	if selectasclient:
		$VBox/Clientmode.Don_broker_connect()

func _on_start_mqtt_toggled(toggled_on):
	var StartMQTTstatuslabel = $VBox/HBox2/statuslabel
	if toggled_on:
		$VBox/HBox2/roomname.editable = false
		Roomplayertree.clear()
		xclienttreeitems.clear()
		var root = Roomplayertree.create_item()
		roomplayertreeunconnected = Roomplayertree.create_item()
		roomplayertreeunconnected.set_text(0, "unconnected")
		Roomplayertreecaboosereached = false
		roomname = $VBox/HBox2/roomname.text
		randomize()
		$MQTT.client_id = "x%d" % (2 + (randi()%0x7ffffff8))
		$VBox/HBox2/client_id.text = $MQTT.client_id
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
		$VBox/HBox2/roomname.editable = true
		$VBox/HBox2/client_id.text = ""
		$VBox/HBox/brokeraddress.disabled = false

		var scmode = $VBox/Servermode if selectasserver else $VBox/Clientmode
		if selectasserver:
			for s in scmode.clientidtowclientid:
				scmode.emit_signal("mqttsig_client_disconnected", scmode.clientidtowclientid[s])
			scmode.get_node("ClientsList").clear()
			scmode.clientidtowclientid.clear()
			scmode.wclientidtoclientid.clear()

		if selectasclient:
			scmode.selectedserver = ""
			scmode.serverconnected = false
			scmode.openserversconnections.clear()
			scmode.emit_signal("mqttsig_connection_closed")
			scmode.wclientid = 0


func sendpacket_toserver(v):
	assert (selectasclient)
	var t = "%s/%s/packet/%s" % [roomname, $MQTT.client_id, $VBox/Clientmode.selectedserver]
	$MQTT.publish(t, JSON.stringify(v))
