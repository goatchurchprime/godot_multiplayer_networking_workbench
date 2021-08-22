extends Control


onready var SetupMQTTsignal = get_node("../SetupMQTTsignal")
onready var MQTT = SetupMQTTsignal.get_node("MQTT")
var roomname = ""

func _ready():
	connect("client_connected", self, "_client_connected") 
	connect("client_disconnected", self, "_client_disconnected") 
	connect("packet_received", self, "_packet_received") 

var nextclientnumber = 2
var clientidmap = { }

func _client_connected(id):
	print("client connected ", id)
func _client_disconnected(id):
	print("client_disconnected ", id)
func _packet_received(id, v):
	print("packet_received ", id, v)

signal client_connected(id)
signal client_disconnected(id)
signal packet_received(id, v)

# Messages: topic: room/clientid/[packet|server|client]/[clientid-to|]
# 			payload: {"subject":type, ...}
	
func received_mqtt(topic, msg):
	if msg == "":  return
	var stopic = topic.split("/")
	var v = parse_json(msg)
	if v != null and v.has("subject"):
		if len(stopic) >= 3 and stopic[0] == roomname:
			var sendingclientid = stopic[1]
			
			if len(stopic) == 4  and stopic[2] == "packet" and stopic[3] == MQTT.client_id:
				if clientidmap.has(sendingclientid):
					emit_signal("packet_received", clientidmap[sendingclientid], v)
				elif v["subject"] == "request_connection":
					clientidmap[sendingclientid] = nextclientnumber
					nextclientnumber += 1
					MQTT.subscribe("%s/%s/client" % [roomname, sendingclientid])
					var t = "%s/%s/packet/%s" % [roomname, MQTT.client_id, sendingclientid]
					MQTT.publish(t, to_json({"subject":"connection_established"}))
					emit_signal("client_connected", clientidmap[sendingclientid])
					$ClientsList.add_item(sendingclientid, int(sendingclientid))
					$ClientsList.selected = $ClientsList.get_item_count()-1
				
			elif len(stopic) == 3 and stopic[2] == "client":
				if clientidmap.has(sendingclientid) and v["subject"] == "dead":
					#MQTT.unsubscribe("%s/%s/client" % [roomname, sendingclientid])
					emit_signal("client_disconnected", clientidmap[sendingclientid])
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
		MQTT.client_id = "t%d" % randi()
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

	else:
		print("Disconnecting MQTT")
		MQTT.disconnect("received_message", self, "received_mqtt")
		MQTT.disconnect_from_server()
		$StartServer/statuslabel.text = "off"
		SetupMQTTsignal.get_node("client_id").text = ""
		for s in clientidmap:
			emit_signal("client_disconnected", clientidmap[s])			
		$ClientsList.clear()
		$ClientsList.add_item("none", 0)
		clientidmap.clear()
		
		
		
		
