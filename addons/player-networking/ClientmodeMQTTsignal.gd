extends Control


onready var SetupMQTTsignal = get_parent()
onready var MQTT = SetupMQTTsignal.get_node("MQTT")
var roomname = ""
var wclientid = 0

signal mqttsig_connection_established(wclientid)
signal mqttsig_connection_closed()
signal mqttsig_packet_received(v)

var openserverslist = [ ]
var selectedserver = ""
var serverconnected = false
var statustopic = ""
var waittimeforservertoshow = 1.2

# Messages: topic: room/clientid/[packet|server|client]/[clientid-to|]
# 			payload: {"subject":type, ...}

func sendpacket_toserver(v):
	var t = "%s/%s/packet/%s" % [roomname, MQTT.client_id, selectedserver]
	MQTT.publish(t, to_json(v))
	
func isconnectedtosignalserver():
	return serverconnected

func received_mqtt(topic, msg):
	if msg == "":  return
	var stopic = topic.split("/")
	var v = parse_json(msg)
	if v != null and v.has("subject"):
		if len(stopic) >= 3 and stopic[0] == roomname:
			var sendingserverid = stopic[1]

			if len(stopic) == 3 and stopic[2] == "server":
				var si = openserverslist.find(sendingserverid)
				if v["subject"] == "open" and si == -1:
					openserverslist.append(sendingserverid)
					if $StartClient.pressed and selectedserver == "":
						selectedserver = openserverslist[0]
						MQTT.subscribe("%s/%s/packet/%s" % [roomname, selectedserver, MQTT.client_id])
						var t = "%s/%s/packet/%s" % [roomname, MQTT.client_id, selectedserver]
						MQTT.publish(t, to_json({"subject":"request_connection"}))
				if v["subject"] == "dead" and si != -1:
					openserverslist.remove(si)
					if selectedserver == sendingserverid:
						if serverconnected:
							emit_signal("mqttsig_connection_closed")
							$StartClient/statuslabel.text = "stopped"
							wclientid = 0
							serverconnected = false
							$WebRTCmultiplayerclient/StartWebRTCmultiplayer.disabled = true
						#MQTT.unsubscribe("%s/%s/server" % [roomname, selectedserver])
						selectedserver = ""
						MQTT.publish(statustopic, to_json({"subject":"unconnected"}))
							
			elif len(stopic) == 4 and sendingserverid == selectedserver and stopic[2] == "packet" and stopic[3] == MQTT.client_id:
				if not serverconnected:
					if v["subject"] == "connection_established":
						serverconnected = true
						wclientid = int(v["wclientid"])
						emit_signal("mqttsig_connection_established", int(v["wclientid"]))
						$StartClient/statuslabel.text = "connected"
						MQTT.publish(statustopic, to_json({"subject":"connected"}))
						$WebRTCmultiplayerclient/StartWebRTCmultiplayer.disabled = false
						if SetupMQTTsignal.get_node("autoconnect").pressed:
							$WebRTCmultiplayerclient/StartWebRTCmultiplayer.pressed = true
							
				else:
					emit_signal("mqttsig_packet_received", v)
					
			else:
				print("Unrecognized topic ", topic)

func on_broker_connect():
	MQTT.subscribe("%s/+/server" % roomname)
	MQTT.publish(statustopic, to_json({"subject":"unconnected"}))
	$StartClient/statuslabel.text = "pending"

func on_broker_disconnect():
	$StartClient.pressed = false
		
func _on_StartClient_toggled(button_pressed):
	if button_pressed:
		var NetworkGateway = get_node("../..")
		var selectasnecessary = (NetworkGateway.get_node("NetworkOptionsMQTTWebRTC").selected == NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_NECESSARY)
		MQTT.connect("received_message", self, "received_mqtt")
		MQTT.connect("broker_connected", self, "on_broker_connect")
		MQTT.connect("broker_disconnected", self, "on_broker_disconnect")
		roomname = SetupMQTTsignal.get_node("roomname").text
		randomize()
		MQTT.client_id = "c%d" % randi()
		SetupMQTTsignal.get_node("client_id").text = MQTT.client_id
		var brokersplit = SetupMQTTsignal.get_node("brokeraddress").text.split(":", true, 1)
		MQTT.server = brokersplit[0]
		var websocketport = 8080 if len(brokersplit) == 1 else int(brokersplit[1])
		MQTT.websocketurl = "ws://%s:%d/mqtt" % [MQTT.server, websocketport]
		statustopic = "%s/%s/client" % [roomname, MQTT.client_id]
		MQTT.set_last_will(statustopic, to_json({"subject":"dead"}), true)
		$StartClient/statuslabel.text = "connecting"
		if SetupMQTTsignal.get_node("brokeraddress/usewebsocket").pressed:
			MQTT.websocket_connect_to_server()
		else:
			MQTT.connect_to_server()
		if selectasnecessary:
			yield(get_tree().create_timer(waittimeforservertoshow), "timeout")
			if $StartClient.pressed:
				if len(openserverslist) == 0:
					NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_SERVER)
				else:
					NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_CLIENT)
				
	else:
		print("Disconnecting MQTT")
		MQTT.disconnect("received_message", self, "received_mqtt")
		MQTT.disconnect("broker_connected", self, "on_broker_connect")
		MQTT.disconnect("broker_disconnected", self, "on_broker_disconnect")
		MQTT.disconnect_from_server()
		statustopic = ""
		selectedserver = ""
		serverconnected = false
		openserverslist.clear()
		$StartClient/statuslabel.text = "off"
		SetupMQTTsignal.get_node("client_id").text = ""
		emit_signal("mqttsig_connection_closed")
		wclientid = 0
		$WebRTCmultiplayerclient/StartWebRTCmultiplayer.disabled = true
