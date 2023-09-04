extends Control


@onready var SetupMQTTsignal = get_parent()
@onready var MQTT = SetupMQTTsignal.get_node("MQTT")

@onready var StartMQTT = SetupMQTTsignal.get_node("StartMQTT")
@onready var StartMQTTstatuslabel = SetupMQTTsignal.get_node("StartMQTT/statuslabel")

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

var waitingforserverstoshow = false
var waittimeforservertoshow = 1.2

# Messages: topic: room/clientid/[packet|server|client]/[clientid-to|]
# 			payload: {"subject":type, ...}

func sendpacket_toserver(v):
	var t = "%s/%s/packet/%s" % [roomname, MQTT.client_id, selectedserver]
	MQTT.publish(t, JSON.new().stringify(v))
	
func isconnectedtosignalserver():
	return serverconnected

var Nmaxnconnectionstoserver = 3
func choosefromopenservers():
	selectedserver = null
	for ss in openserversconnections:
		if openserversconnections[ss] < Nmaxnconnectionstoserver:
			if selectedserver == null or openserversconnections[ss] > openserversconnections[selectedserver]:
				selectedserver = ss
	if selectedserver != null:
		MQTT.subscribe("%s/%s/packet/%s" % [roomname, selectedserver, MQTT.client_id])
		var t = "%s/%s/packet/%s" % [roomname, MQTT.client_id, selectedserver]
		MQTT.publish(t, JSON.new().stringify({"subject":"request_connection"}))

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
				if v["subject"] == "serveropen" and not openserversconnections.has(sendingserverid):
					openserversconnections[sendingserverid] = v.get("nconnections", 0)
					if StartMQTT.button_pressed and selectedserver == "":
						if not waitingforserverstoshow:
							choosefromopenservers()
							
				if v["subject"] == "dead" and openserversconnections.has(sendingserverid):
					openserversconnections.erase(sendingserverid)
					if selectedserver == sendingserverid:
						if serverconnected:
							emit_signal("mqttsig_connection_closed")
							StartMQTTstatuslabel.text = "stopped"
							wclientid = 0
							serverconnected = false
							$WebRTCmultiplayerclient/StartWebRTCmultiplayer.disabled = true
						#MQTT.unsubscribe("%s/%s/server" % [roomname, selectedserver])
						selectedserver = ""
						MQTT.publish(statustopic, JSON.new().stringify({"subject":"unconnected"}))
							
			elif len(stopic) == 4 and sendingserverid == selectedserver and stopic[2] == "packet" and stopic[3] == MQTT.client_id:
				if not serverconnected:
					if v["subject"] == "connection_established":
						serverconnected = true
						wclientid = int(v["wclientid"])
						emit_signal("mqttsig_connection_established", int(v["wclientid"]))
						StartMQTTstatuslabel.text = "connected"
						MQTT.publish(statustopic, JSON.new().stringify({"subject":"connected"}))
						$WebRTCmultiplayerclient/StartWebRTCmultiplayer.disabled = false
						if SetupMQTTsignal.get_node("autoconnect").button_pressed:
							$WebRTCmultiplayerclient/StartWebRTCmultiplayer.button_pressed = true
							
				else:
					emit_signal("mqttsig_packet_received", v)
					
			else:
				print("Unrecognized topic ", topic)

func on_broker_connect():
	MQTT.subscribe("%s/+/server" % roomname)
	MQTT.publish(statustopic, JSON.new().stringify({"subject":"unconnected"}))
	StartMQTTstatuslabel.text = "pending"

func on_broker_disconnect():
	print("MQTT broker disconnected")
	StartMQTT.button_pressed = false

func _on_StartClient_toggled(button_pressed):
	if button_pressed:
		var NetworkGateway = get_node("../..")
		var selectasnecessary = (NetworkGateway.get_node("NetworkOptionsMQTTWebRTC").selected == NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_NECESSARY)
		var selectasclient = (NetworkGateway.get_node("NetworkOptionsMQTTWebRTC").selected == NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_CLIENT)
		MQTT.received_message.connect(received_mqtt)
		MQTT.broker_connected.connect(on_broker_connect)
		MQTT.broker_disconnected.connect(on_broker_disconnect)
		roomname = SetupMQTTsignal.get_node("roomname").text
		StartMQTTstatuslabel.text = "on"
		randomize()
		MQTT.client_id = "c%d" % (2 + (randi()%0x7ffffff8))
		SetupMQTTsignal.get_node("client_id").text = MQTT.client_id
		statustopic = "%s/%s/client" % [roomname, MQTT.client_id]
		MQTT.set_last_will(statustopic, JSON.new().stringify({"subject":"dead", "comment":"by_will"}), true)
		StartMQTTstatuslabel.text = "connecting"
		var brokerurl = SetupMQTTsignal.get_node("brokeraddress").text
		MQTT.connect_to_broker(brokerurl)
		
		if selectasnecessary or selectasclient:
			waitingforserverstoshow = true
			await get_tree().create_timer(waittimeforservertoshow).timeout
			waitingforserverstoshow = false
			
		if StartMQTT.button_pressed:
			var converttoservertype = selectasnecessary
			for ss in openserversconnections:
				if openserversconnections[ss] < Nmaxnconnectionstoserver:
					converttoservertype = false
			if converttoservertype:
				NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_SERVER)
			else:
				NetworkGateway.get_node("NetworkOptionsMQTTWebRTC").selected = NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_CLIENT
				visible = true
				assert (selectedserver == "")
				choosefromopenservers()
				
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
		SetupMQTTsignal.get_node("client_id").text = ""
		emit_signal("mqttsig_connection_closed")
		wclientid = 0
		$WebRTCmultiplayerclient/StartWebRTCmultiplayer.disabled = true
