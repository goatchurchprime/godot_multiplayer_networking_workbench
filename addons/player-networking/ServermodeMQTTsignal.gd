extends Control


@onready var MQTTsignalling = find_parent("MQTTsignalling")
@onready var MQTT = MQTTsignalling.get_node("MQTT")
@onready var StartMQTT = MQTTsignalling.get_node("VBox/HBox2/StartMQTT")
@onready var StartMQTTstatuslabel = MQTTsignalling.get_node("VBox/HBox2/statuslabel")

var roomname = ""

# these might be superfluous if we are using the MQTT.client_id plus a character
var clientidtowclientid = { }
var wclientidtoclientid = { }

var clearlostretainedclients = true
var clearlostretainedservers = true
var Dclearlostdanglingservers = false
var statustopic = ""

signal mqttsig_client_connected(id)
signal mqttsig_client_disconnected(id)
signal mqttsig_packet_received(id, v)

# Messages: topic: room/clientid/[packet|server|client]/[clientid-to|]
# 			payload: {"subject":type, ...}

func sendpacket_toclient(wclientid, v):
	var t = "%s/%s/packet/%s" % [roomname, MQTT.client_id, wclientidtoclientid[wclientid]]
	MQTT.publish(t, JSON.new().stringify(v))
	
func received_mqtt(topic, msg):
	if msg == "":
		return
	var stopic = topic.split("/")
	var test_json_conv = JSON.new()
	test_json_conv.parse(msg)
	var v = test_json_conv.get_data()
	if v != null and v.has("subject"):
		if len(stopic) >= 3 and stopic[0] == roomname:
			var sendingclientid = stopic[1]
			
			if len(stopic) == 4  and stopic[2] == "packet" and stopic[3] == MQTT.client_id:
				if clientidtowclientid.has(sendingclientid):
					emit_signal("mqttsig_packet_received", clientidtowclientid[sendingclientid], v)
				elif v["subject"] == "request_connection":
					var wclientid = int(sendingclientid)
					clientidtowclientid[sendingclientid] = wclientid
					wclientidtoclientid[wclientid] = sendingclientid
					if not clearlostretainedclients:
						MQTT.subscribe("%s/%s/client" % [roomname, sendingclientid])
					var t = "%s/%s/packet/%s" % [roomname, MQTT.client_id, sendingclientid]
					MQTT.publish(t, JSON.new().stringify({"subject":"connection_established", "wclientid":wclientid}))
					MQTT.publish(statustopic, JSON.new().stringify({"subject":"serveropen", "nconnections":len(clientidtowclientid)}), true)
					emit_signal("mqttsig_client_connected", wclientid)
					$ClientsList.add_item(sendingclientid, int(sendingclientid))
					$ClientsList.selected = $ClientsList.get_item_count()-1
				
			elif len(stopic) == 3 and stopic[2] == "client":
				if v["subject"] == "dead":
					if clientidtowclientid.has(sendingclientid):
						MQTT.unsubscribe("%s/%s/client" % [roomname, sendingclientid])
						var wclientid = clientidtowclientid[sendingclientid]
						emit_signal("mqttsig_client_disconnected", wclientid)
						clientidtowclientid.erase(sendingclientid)
						wclientidtoclientid.erase(wclientid)
						MQTT.publish(topic, "", true)
						var idx = $ClientsList.get_item_index(int(sendingclientid))
						print(idx)
						$ClientsList.remove_item(idx)
						MQTT.publish(statustopic, JSON.new().stringify({"subject":"serveropen", "nconnections":len(clientidtowclientid)}), true)
					else:
						if clearlostretainedclients:
							MQTT.publish(topic, "", true)

			elif len(stopic) == 3 and stopic[2] == "server":
				if v["subject"] == "dead":
					if clearlostretainedservers:
						MQTT.publish(topic, "", true)
				if v["subject"] == "serveropen":
					if stopic[1] == MQTT.client_id:
						print("found openserver myself: ", stopic[1])
					else:
						print("found openserver not myself: ", stopic[1])
						if Dclearlostdanglingservers:
							print("  clearing")
							MQTT.publish(topic, "", true)

			else:
				print("Unrecognized topic ", topic)

func on_broker_disconnect():
	StartMQTT.button_pressed = false
	
func on_broker_connect():
	MQTT.subscribe("%s/+/packet/%s" % [roomname, MQTT.client_id])
	print(" subscribing to ", "%s/+/packet/%s" % [roomname, MQTT.client_id])
	if clearlostretainedservers:
		MQTT.subscribe("%s/+/server" % roomname)
	if clearlostretainedclients:
		MQTT.subscribe("%s/+/client" % roomname)
	statustopic = "%s/%s/server" % [roomname, MQTT.client_id]
	MQTT.publish(statustopic, JSON.new().stringify({"subject":"serveropen", "nconnections":len(clientidtowclientid)}), true)
	StartMQTTstatuslabel.text = "connected"
	$ClientsList.clear()
	$ClientsList.add_item(MQTT.client_id, 1)
	$ClientsList.selected = 0
	
	$WebRTCmultiplayerserver/StartWebRTCmultiplayer.disabled = false
	if get_node("autoconnect").button_pressed:
		$WebRTCmultiplayerserver/StartWebRTCmultiplayer.button_pressed = true
		
func _on_StartServer_toggled(button_pressed):
	if button_pressed:
		MQTT.received_message.connect(received_mqtt)
		MQTT.broker_connected.connect(on_broker_connect)
		MQTT.broker_disconnected.connect(on_broker_disconnect)
		roomname = MQTTsignalling.get_node("VBox/HBox2/roomname").text
		MQTTsignalling.get_node("VBox/HBox2/roomname").editable = false
		StartMQTTstatuslabel.text = "on"
		randomize()
		MQTT.client_id = "s%d" % randi()
		MQTTsignalling.get_node("VBox/HBox2/client_id").text = MQTT.client_id
		statustopic = "%s/%s/server" % [roomname, MQTT.client_id]
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
		StartMQTTstatuslabel.text = "off"
		roomname = ""
		MQTTsignalling.get_node("VBox/HBox2/roomname").editable = true
		MQTTsignalling.get_node("VBox/HBox2/client_id").text = ""
		MQTTsignalling.get_node("VBox/HBox/brokeraddress").disabled = false
		for s in clientidtowclientid:
			emit_signal("mqttsig_client_disconnected", clientidtowclientid[s])
		$ClientsList.clear()
		clientidtowclientid.clear()
		wclientidtoclientid.clear()
		
