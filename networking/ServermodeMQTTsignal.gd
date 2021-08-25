extends Control


onready var SetupMQTTsignal = get_parent()
onready var MQTT = SetupMQTTsignal.get_node("MQTT")
var roomname = ""

	
var nextclientnumber = 2
var clientidtowclientid = { }
var wclientidtoclientid = { }

signal mqttsig_client_connected(id)
signal mqttsig_client_disconnected(id)
signal mqttsig_packet_received(id, v)


# Messages: topic: room/clientid/[packet|server|client]/[clientid-to|]
# 			payload: {"subject":type, ...}

func sendpacket_toclient(wclientid, v):
	var t = "%s/%s/packet/%s" % [roomname, MQTT.client_id, wclientidtoclientid[wclientid]]
	MQTT.publish(t, to_json(v))
	
func received_mqtt(topic, msg):
	if msg == "":  return
	var stopic = topic.split("/")
	var v = parse_json(msg)
	if v != null and v.has("subject"):
		if len(stopic) >= 3 and stopic[0] == roomname:
			var sendingclientid = stopic[1]
			
			if len(stopic) == 4  and stopic[2] == "packet" and stopic[3] == MQTT.client_id:
				if clientidtowclientid.has(sendingclientid):
					emit_signal("mqttsig_packet_received", clientidtowclientid[sendingclientid], v)
				elif v["subject"] == "request_connection":
					var wclientid = nextclientnumber
					nextclientnumber += 1
					clientidtowclientid[sendingclientid] = wclientid
					wclientidtoclientid[wclientid] = sendingclientid
					MQTT.subscribe("%s/%s/client" % [roomname, sendingclientid])
					var t = "%s/%s/packet/%s" % [roomname, MQTT.client_id, sendingclientid]
					MQTT.publish(t, to_json({"subject":"connection_established", "wclientid":wclientid}))
					emit_signal("mqttsig_client_connected", wclientid)
					$ClientsList.add_item(sendingclientid, int(sendingclientid))
					$ClientsList.selected = $ClientsList.get_item_count()-1
				
			elif len(stopic) == 3 and stopic[2] == "client":
				if clientidtowclientid.has(sendingclientid) and v["subject"] == "dead":
					#MQTT.unsubscribe("%s/%s/client" % [roomname, sendingclientid])
					var wclientid = clientidtowclientid[sendingclientid]
					emit_signal("mqttsig_client_disconnected", wclientid)
					clientidtowclientid.erase(sendingclientid)
					wclientidtoclientid.erase(wclientid)
					MQTT.publish(topic, "", true)
					var idx = $ClientsList.get_item_index(int(sendingclientid))
					print(idx)
					$ClientsList.remove_item(idx)

			elif len(stopic) == 3 and stopic[2] == "server":
				if v["subject"] == "dead":
					MQTT.publish(topic, "", true)

			else:
				print("Unrecognized topic ", topic)

		
func _on_StartServer_toggled(button_pressed):
	if button_pressed:
		MQTT.connect("received_message", self, "received_mqtt")
		roomname = SetupMQTTsignal.get_node("roomname").text
		randomize()
		MQTT.client_id = "s%d" % randi()
		SetupMQTTsignal.get_node("client_id").text = MQTT.client_id
		MQTT.server = SetupMQTTsignal.get_node("brokeraddress").text
		MQTT.websocketurl = "ws://%s:8080/mqtt" % MQTT.server
		var statustopic = "%s/%s/server" % [roomname, MQTT.client_id]
		MQTT.set_last_will(statustopic, to_json({"subject":"dead"}), true)
		$StartServer/statuslabel.text = "connecting"
		if SetupMQTTsignal.get_node("brokeraddress/usewebsocket").pressed:
			yield(MQTT.websocket_connect_to_server(), "completed")
		else:
			yield(MQTT.connect_to_server(), "completed")
		MQTT.subscribe("%s/+/packet/%s" % [roomname, MQTT.client_id])
		MQTT.subscribe("%s/+/server" % roomname)
		MQTT.publish(statustopic, to_json({"subject":"open"}), true)
		$StartServer/statuslabel.text = "connected"
		$ClientsList.set_item_text(0, MQTT.client_id)
		$WebRTCmultiplayerserver/StartWebRTCmultiplayer.disabled = false
		if SetupMQTTsignal.get_node("autoconnect").pressed:
			$WebRTCmultiplayerserver/StartWebRTCmultiplayer.pressed = true

	else:
		print("Disconnecting MQTT")
		MQTT.disconnect("received_message", self, "received_mqtt")
		MQTT.disconnect_from_server()
		$StartServer/statuslabel.text = "off"
		SetupMQTTsignal.get_node("client_id").text = ""
		for s in clientidtowclientid:
			emit_signal("mqttsig_client_disconnected", clientidtowclientid[s])		
		$ClientsList.clear()
		$ClientsList.add_item("none", 0)
		clientidtowclientid.clear()
		wclientidtoclientid.clear()
		emit_signal("mqttsig_server_stopped")
		$WebRTCmultiplayerserver/StartWebRTCmultiplayer.disabled = true
		
		
