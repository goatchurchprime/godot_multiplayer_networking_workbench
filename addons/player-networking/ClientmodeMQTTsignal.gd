extends Control


@onready var MQTTsignalling = find_parent("MQTTsignalling")
@onready var MQTT = MQTTsignalling.get_node("MQTT")

@onready var StartMQTT = MQTTsignalling.get_node("VBox/HBox2/StartMQTT")
@onready var StartMQTTstatuslabel = MQTTsignalling.get_node("VBox/HBox2/statuslabel")

@onready var NetworkGateway = find_parent("NetworkGateway")

var roomname = ""
var wclientid = 0

signal mqttsig_connection_established(wclientid)
signal mqttsig_connection_closed()
signal mqttsig_packet_received(v)

# mosquitto_sub -h broker.mqttdashboard.com -t "cucumber/#" -v
# mosquitto_sub -h mosquitto.doesliverpool.xyz -v -t "lettuce/#"

var openserversconnections = { }
var selectedserver = ""
var serverconnected = false
var statustopic = ""

# Messages: topic: room/clientid/[packet|server|client]/[clientid-to|]
# 			payload: {"subject":type, ...}

func sendpacket_toserver(v):
	var t = "%s/%s/packet/%s" % [roomname, MQTT.client_id, selectedserver]
	MQTT.publish(t, JSON.new().stringify(v))
	
func isconnectedtosignalserver():
	return serverconnected

var Nmaxnconnectionstoserver = 3
func choosefromopenservers():
	var lselectedserver = null
	for ss in openserversconnections:
		if openserversconnections[ss] < Nmaxnconnectionstoserver:
			if lselectedserver == null or openserversconnections[ss] > openserversconnections[lselectedserver]:
				lselectedserver = ss
	if lselectedserver != null:
		selectedserver = lselectedserver
		MQTT.subscribe("%s/%s/packet/%s" % [roomname, selectedserver, MQTT.client_id])
		var t = "%s/%s/packet/%s" % [roomname, MQTT.client_id, selectedserver]
		MQTT.publish(t, JSON.new().stringify({"subject":"request_connection"}))
		return true
	return false
	
func received_mqtt(topic, msg):
	if msg == "":  return
	var stopic = topic.split("/")
	var test_json_conv = JSON.new()
	test_json_conv.parse(msg)
	var v = test_json_conv.get_data()
	if v != null and v.has("subject"):
		if len(stopic) >= 3 and stopic[0] == roomname:
			var sendingserverid = stopic[1]

			if len(stopic) == 3 and stopic[2] == "server":
				var chooseaserver = false
				if stopic[1] == "caboose":
					if v.get("clientid", "") == MQTT.client_id:
						print("caboose reached, select server")
						openserverconnectionsUpToDate = true
						chooseaserver = true
						
				if v["subject"] == "dead" and openserversconnections.has(sendingserverid):
					openserversconnections.erase(sendingserverid)
					if selectedserver == sendingserverid:
						if serverconnected:
							emit_signal("mqttsig_connection_closed")
							StartMQTTstatuslabel.text = "stopped"
							wclientid = 0
							serverconnected = false
							$WebRTCmultiplayerclient/StartWebRTCmultiplayer.disabled = true
						MQTT.unsubscribe("%s/%s/server" % [roomname, selectedserver])
						selectedserver = ""
						MQTT.publish(statustopic, JSON.new().stringify({"subject":"unconnected"}))

				if v["subject"] == "serveropen":
					openserversconnections[sendingserverid] = v.get("nconnections", 0)
					chooseaserver = (selectedserver == "") and openserverconnectionsUpToDate
					
				if chooseaserver:
					if StartMQTT.button_pressed:
						assert (selectedserver == "")
						var serverfound = choosefromopenservers()
						var selectasnecessarymanualchange = (NetworkGateway.NetworkOptionsMQTTWebRTC.selected == NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_NECESSARY_MANUALCHANGE)
						var selectasnecessary = (NetworkGateway.NetworkOptionsMQTTWebRTC.selected == NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_NECESSARY)
						if selectasnecessarymanualchange:
							NetworkGateway.emit_signal("resolved_as_necessary", not serverfound)
						elif selectasnecessary:
							if serverfound:
								NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_CLIENT)
							else:
								NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_SERVER)

			elif len(stopic) == 4 and sendingserverid == selectedserver and stopic[2] == "packet" and stopic[3] == MQTT.client_id:
				if not serverconnected:
					if v["subject"] == "connection_established":
						serverconnected = true
						wclientid = int(v["wclientid"])
						emit_signal("mqttsig_connection_established", int(v["wclientid"]))
						StartMQTTstatuslabel.text = "connected"
						MQTT.publish(statustopic, JSON.new().stringify({"subject":"connected"}))
						$WebRTCmultiplayerclient/StartWebRTCmultiplayer.disabled = false
						if get_node("autoconnect").button_pressed:
							$WebRTCmultiplayerclient/StartWebRTCmultiplayer.button_pressed = true
							
				else:
					emit_signal("mqttsig_packet_received", v)
					
			else:
				print("Unrecognized topic ", topic)

var openserverconnectionsUpToDate = false
func on_broker_connect():
	MQTT.subscribe("%s/+/server" % roomname)
	MQTT.publish(statustopic, JSON.new().stringify({"subject":"unconnected"}))
	MQTT.publish("%s/caboose/server" % roomname, JSON.new().stringify({"subject":"caboose", "clientid":MQTT.client_id}))
	StartMQTTstatuslabel.text = "pending"
	assert (len(openserversconnections) == 0)
	openserverconnectionsUpToDate = false

func on_broker_disconnect():
	print("MQTT broker disconnected")
	StartMQTT.button_pressed = false

func _on_StartClient_toggled(button_pressed):
	if button_pressed:
		MQTT.received_message.connect(received_mqtt)
		MQTT.broker_connected.connect(on_broker_connect)
		MQTT.broker_disconnected.connect(on_broker_disconnect)
		roomname = MQTTsignalling.get_node("VBox/HBox2/roomname").text
		MQTTsignalling.get_node("VBox/HBox2/roomname").editable = false
		StartMQTTstatuslabel.text = "on"
		randomize()
		MQTT.client_id = "c%d" % (2 + (randi()%0x7ffffff8))
		MQTTsignalling.get_node("VBox/HBox2/client_id").text = MQTT.client_id
		statustopic = "%s/%s/client" % [roomname, MQTT.client_id]
		MQTT.set_last_will(statustopic, JSON.new().stringify({"subject":"dead", "comment":"by_will"}), true)
		StartMQTTstatuslabel.text = "connecting"
		var brokerurl = MQTTsignalling.get_node("VBox/HBox/brokeraddress").text
		MQTTsignalling.get_node("VBox/HBox/brokeraddress").disabled = true
		MQTT.connect_to_broker(brokerurl)
				
	else:
		print("Disconnecting MQTT")
		MQTT.received_message.disconnect(received_mqtt)
		MQTT.broker_connected.disconnect(on_broker_connect)
		MQTT.broker_disconnected.disconnect(on_broker_disconnect)
		MQTT.publish(statustopic, JSON.new().stringify({"subject":"dead"}), true)
		MQTT.disconnect_from_server()
		statustopic = ""
		selectedserver = ""
		serverconnected = false
		openserversconnections.clear()
		StartMQTTstatuslabel.text = "off"
		roomname = ""
		MQTTsignalling.get_node("VBox/HBox2/roomname").editable = true
		MQTTsignalling.get_node("VBox/HBox2/client_id").text = ""
		MQTTsignalling.get_node("VBox/HBox/brokeraddress").disabled = false
		emit_signal("mqttsig_connection_closed")
		wclientid = 0
		$WebRTCmultiplayerclient/StartWebRTCmultiplayer.disabled = false
