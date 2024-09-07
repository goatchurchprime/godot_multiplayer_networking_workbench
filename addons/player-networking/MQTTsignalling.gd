extends Control

@onready var NetworkGateway = find_parent("NetworkGateway")

# var wclientid = int($MQTT.client_id)
var roomname = ""
var statustopic = ""

var selectasserver = false
var selectasclient = false
var selectasnecessary = false

var wclientid = -1  # stored here for now, but will specify from mqttid


signal mqttsig_connection_established(wclientid)
signal mqttsig_connection_closed()
signal mqttsig_packet_received(v)

func isconnectedtosignalserver():
	return $VBox/Clientmode.serverconnected


var Dns = -1
func _on_NetworkOptionsMQTTWebRTC_item_selected(ns):
	Dns = ns
	selectasserver = (Dns == NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_SERVER)

	#assert (ProtocolOptions.selected == NETWORK_PROTOCOL.WEBRTC_MQTTSIGNAL)
	var selectasoff = (ns == NetworkGateway.NETWORK_OPTIONS.NETWORK_OFF)
	if not selectasoff:
		NetworkGateway.PlayerConnections.clearconnectionlog()
		$VBox/HBox2/roomname.editable = true
		roomname = $VBox/HBox2/roomname.text
		if not $MQTT.client_id.begins_with("x"):
			randomize()
			$MQTT.client_id = "x%d" % (2 + (randi()%0x7ffffff8))
			statustopic = "%s/%s/status" % [roomname, $MQTT.client_id]
	else:
		$VBox/HBox2/roomname.editable = false

	$VBox/HBox2/StartMQTT.button_pressed = false
	await get_tree().process_frame

	selectasserver = (ns == NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_SERVER)
	selectasclient = (ns == NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_CLIENT)
	selectasnecessary = (ns == NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_NECESSARY or ns == NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_NECESSARY_MANUALCHANGE)

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


var xclientstatuses = { }

func clearclosedtopics():
	for x in xclientstatuses:
		if xclientstatuses[x] == "closed":
			$MQTT.publish("%s/%s/status" % [roomname, x], "", true)

func received_mqtt(topic, msg):
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

	if selectasserver:
		$VBox/Servermode.Dreceived_mqtt(stopic, v)
	if selectasclient:
		$VBox/Clientmode.Dreceived_mqtt(stopic, v)

func on_broker_disconnect():
	$VBox/HBox2/StartMQTT.button_pressed = false

func on_broker_connect():
	if selectasserver:
		$VBox/Servermode.Don_broker_connect()
	if selectasclient:
		$VBox/Clientmode.Don_broker_connect()

func _on_start_mqtt_toggled(toggled_on):
	var StartMQTTstatuslabel = $VBox/HBox2/statuslabel
	if toggled_on:
		$MQTT.received_message.connect(received_mqtt)
		$MQTT.broker_connected.connect(on_broker_connect)
		$MQTT.broker_disconnected.connect(on_broker_disconnect)
		StartMQTTstatuslabel.text = "on"
		$MQTT.set_last_will(statustopic, JSON.stringify({"subject":"closed", "comment":"by_will"}), true)
		StartMQTTstatuslabel.text = "connecting"
		var brokerurl = $VBox/HBox/brokeraddress.text
		$VBox/HBox/brokeraddress.disabled = true
		$MQTT.connect_to_broker(brokerurl)

	else:
		print("Disconnecting MQTT")
		$MQTT.received_message.disconnect(received_mqtt)
		$MQTT.broker_connected.disconnect(on_broker_connect)
		$MQTT.broker_disconnected.disconnect(on_broker_disconnect)
		$MQTT.publish(statustopic, JSON.stringify({"subject":"closed"}), true)
		$MQTT.disconnect_from_server()
		StartMQTTstatuslabel.text = "off"
		roomname = ""
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
