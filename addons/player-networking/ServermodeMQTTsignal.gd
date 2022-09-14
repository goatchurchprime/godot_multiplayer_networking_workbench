extends Control


onready var SetupMQTTsignal = get_parent()
onready var MQTT = SetupMQTTsignal.get_node("MQTT")
onready var StartMQTT = SetupMQTTsignal.get_node("StartMQTT")
onready var StartMQTTstatuslabel = SetupMQTTsignal.get_node("StartMQTT/statuslabel")

var roomname = ""
	
var nextclientnumber = 2
var clientidtowclientid = { }
var wclientidtoclientid = { }
var clearlostretainedclients = true
var clearlostretainedservers = true
var statustopic = ""

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
					if not clearlostretainedclients:
						MQTT.subscribe("%s/%s/client" % [roomname, sendingclientid])
					var t = "%s/%s/packet/%s" % [roomname, MQTT.client_id, sendingclientid]
					MQTT.publish(t, to_json({"subject":"connection_established", "wclientid":wclientid}))
					MQTT.publish(statustopic, to_json({"subject":"serveropen", "nconnections":len(clientidtowclientid)}), true)
					emit_signal("mqttsig_client_connected", wclientid)
					$ClientsList.add_item(sendingclientid, int(sendingclientid))
					$ClientsList.selected = $ClientsList.get_item_count()-1
				
			elif len(stopic) == 3 and stopic[2] == "client":
				if v["subject"] == "dead":
					if clientidtowclientid.has(sendingclientid):
						#MQTT.unsubscribe("%s/%s/client" % [roomname, sendingclientid])
						var wclientid = clientidtowclientid[sendingclientid]
						emit_signal("mqttsig_client_disconnected", wclientid)
						clientidtowclientid.erase(sendingclientid)
						wclientidtoclientid.erase(wclientid)
						MQTT.publish(topic, "", true)
						var idx = $ClientsList.get_item_index(int(sendingclientid))
						print(idx)
						$ClientsList.remove_item(idx)
						MQTT.publish(statustopic, to_json({"subject":"serveropen", "nconnections":len(clientidtowclientid)}), true)
					else:
						if clearlostretainedclients:
							MQTT.publish(topic, "", true)

			elif len(stopic) == 3 and stopic[2] == "server":
				if v["subject"] == "dead":
					if clearlostretainedservers:
						MQTT.publish(topic, "", true)

			else:
				print("Unrecognized topic ", topic)

func on_broker_disconnect():
	StartMQTT.pressed = false
	
func on_broker_connect():
	MQTT.subscribe("%s/+/packet/%s" % [roomname, MQTT.client_id])
	if clearlostretainedservers:
		MQTT.subscribe("%s/+/server" % roomname)
	if clearlostretainedclients:
		MQTT.subscribe("%s/+/client" % roomname)
	statustopic = "%s/%s/server" % [roomname, MQTT.client_id]
	MQTT.publish(statustopic, to_json({"subject":"serveropen", "nconnections":len(clientidtowclientid)}), true)
	StartMQTTstatuslabel.text = "connected"
	$ClientsList.set_item_text(0, MQTT.client_id)
	$WebRTCmultiplayerserver/StartWebRTCmultiplayer.disabled = false
	if SetupMQTTsignal.get_node("autoconnect").pressed:
		$WebRTCmultiplayerserver/StartWebRTCmultiplayer.pressed = true
		
func _on_StartServer_toggled(button_pressed):
	if button_pressed:
		MQTT.connect("received_message", self, "received_mqtt")
		MQTT.connect("broker_connected", self, "on_broker_connect")
		MQTT.connect("broker_disconnected", self, "on_broker_disconnect")
		roomname = SetupMQTTsignal.get_node("roomname").text
		StartMQTTstatuslabel.text = "on"
		randomize()
		MQTT.client_id = "s%d" % randi()
		SetupMQTTsignal.get_node("client_id").text = MQTT.client_id
		statustopic = "%s/%s/server" % [roomname, MQTT.client_id]
		MQTT.set_last_will(statustopic, to_json({"subject":"dead"}), true)
		StartMQTTstatuslabel.text = "connecting"
		var brokerurl = SetupMQTTsignal.get_node("brokeraddress").text
		MQTT.connect_to_broker(brokerurl)

	else:
		print("Disconnecting MQTT")
		MQTT.disconnect("received_message", self, "received_mqtt")
		MQTT.disconnect("broker_connected", self, "on_broker_connect")
		MQTT.disconnect("broker_disconnected", self, "on_broker_disconnect")
		MQTT.disconnect_from_server()
		StartMQTTstatuslabel.text = "off"
		SetupMQTTsignal.get_node("client_id").text = ""
		for s in clientidtowclientid:
			emit_signal("mqttsig_client_disconnected", clientidtowclientid[s])
		$ClientsList.clear()
		$ClientsList.add_item("none", 0)
		clientidtowclientid.clear()
		wclientidtoclientid.clear()
		
		
