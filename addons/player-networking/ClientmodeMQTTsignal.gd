extends Control


@onready var MQTTsignalling = find_parent("MQTTsignalling")
@onready var MQTT = MQTTsignalling.get_node("MQTT")

@onready var StartMQTT = MQTTsignalling.get_node("VBox/HBox2/StartMQTT")
@onready var StartMQTTstatuslabel = MQTTsignalling.get_node("VBox/HBox2/statuslabel")

@onready var NetworkGateway = find_parent("NetworkGateway")

#var wclientid = 0


# mosquitto_sub -h broker.mqttdashboard.com -t "cucumber/#" -v
# mosquitto_sub -h mosquitto.doesliverpool.xyz -v -t "lettuce/#"

var openserversconnections = { }
var selectedserver = ""
var serverconnected = false

# Messages: topic: room/clientid/[packet|server|client]/[clientid-to|]
# 			payload: {"subject":type, ...}

	

var Nmaxnconnectionstoserver = 3
func choosefromopenservers():
	var lselectedserver = null
	for ss in openserversconnections:
		if openserversconnections[ss] < Nmaxnconnectionstoserver:
			if lselectedserver == null or openserversconnections[ss] > openserversconnections[lselectedserver]:
				lselectedserver = ss
	if lselectedserver != null:
		selectedserver = lselectedserver
		MQTT.subscribe("%s/%s/packet/%s" % [MQTTsignalling.roomname, selectedserver, MQTT.client_id])
		var t = "%s/%s/packet/%s" % [MQTTsignalling.roomname, MQTT.client_id, selectedserver]
		MQTT.publish(t, JSON.stringify({"subject":"request_connection"}))
		return true
	return false
	
func Dreceived_mqtt(stopic, v):
	if v != null and v.has("subject"):
		if len(stopic) >= 3 and stopic[0] == MQTTsignalling.roomname:
			var sendingserverid = stopic[1]

			if len(stopic) == 3 and stopic[2] == "status":
				var chooseaserver = false
				if stopic[1] == "caboose":
					if v.get("clientid", "") == MQTT.client_id:
						print("caboose reached, select server")
						openserverconnectionsUpToDate = true
						chooseaserver = true
						
				if v["subject"] == "closed" and openserversconnections.has(sendingserverid):
					openserversconnections.erase(sendingserverid)
					if selectedserver == sendingserverid:
						if serverconnected:
							MQTTsignalling.emit_signal("mqttsig_connection_closed")
							StartMQTTstatuslabel.text = "stopped"
							#wclientid = 0
							serverconnected = false
							$WebRTCmultiplayerclient/StartWebRTCmultiplayer.disabled = true
						MQTT.unsubscribe("%s/%s/status" % [MQTTsignalling.roomname, selectedserver])
						selectedserver = ""
						MQTT.publish(MQTTsignalling.statustopic, JSON.stringify({"subject":"unconnected"}))

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
						MQTTsignalling.wclientid = int(v["wclientid"])
						MQTTsignalling.emit_signal("mqttsig_connection_established", int(v["wclientid"]))
						StartMQTTstatuslabel.text = "connected"
						MQTT.publish(MQTTsignalling.statustopic, JSON.stringify({"subject":"connected", "selectedserver":selectedserver}), true)
						$WebRTCmultiplayerclient/StartWebRTCmultiplayer.disabled = false
						if get_node("autoconnect").button_pressed:
							$WebRTCmultiplayerclient/StartWebRTCmultiplayer.button_pressed = true
							
				else:
					MQTTsignalling.emit_signal("mqttsig_packet_received", v)
					
			else:
				print("Unrecognized topic ", stopic)

var wclientid = 0
var openserverconnectionsUpToDate = false
func Don_broker_connect():
	MQTT.publish(MQTTsignalling.statustopic, JSON.stringify({"subject":"unconnected", "selectedserver":selectedserver}), true)
	MQTT.publish("%s/caboose/status" % MQTTsignalling.roomname, JSON.stringify({"subject":"caboose", "clientid":MQTT.client_id}))
	StartMQTTstatuslabel.text = "pending"
	assert (len(openserversconnections) == 0)
	openserverconnectionsUpToDate = false
