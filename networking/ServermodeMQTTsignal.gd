extends Control


onready var SetupMQTTsignal = get_node("../SetupMQTTsignal")
onready var MQTT = SetupMQTTsignal.get_node("MQTT")
var roomname = ""

func _ready():
	connect("client_connected", self, "_client_connected") 
	connect("client_disconnected", self, "_client_disconnected") 
	connect("packet_received", self, "_packet_received") 

var clientidstates = { }

func _client_connected(id):
	print("client connected ", id)
func _client_disconnected(id):
	print("client_disconnected ", id)
func _packet_received(id, v):
	print("packet_received ", id, v)

signal client_connected(id)
signal client_disconnected(id)
signal packet_received(id, v)

# Use the temp MQTT connection-id as the temp clientid here, 
# as it bumps out clients that match the same id anyway 

func issuenewclientid(tempclientid):
	var clientid = 0
	while clientid == 0 or clientidstates.has(clientid):
		clientid = (randi() % 2147483646)+1
	var il = $ClientsList.get_item_count()
	clientidstates[clientid] = "pending"
	MQTT.publish("%s/%d/%s" % [roomname, 1, tempclientid], to_json({"yourclientid":clientid}))
	$ClientsList.add_item("%d pending" % clientid, clientid)
	$ClientsList.selected = $ClientsList.get_item_count()-1
	
func received_mqtt(topic, msg):
	var stopic = topic.split("/")
	assert (len(stopic) == 3 and stopic[0] == roomname and int(stopic[2]) == 1)
	var sclientid = stopic[1]
	var v = parse_json(msg)
	if sclientid[0] == "t":
		if v != "off":  # get("newclientid") == "please"
			issuenewclientid(sclientid)
	else:
		var clientid = int(sclientid)
		if clientidstates.get(clientid) == "pending":
			clientidstates[clientid] = "connected"
			$ClientsList.set_item_text($ClientsList.get_item_index(clientid), "%d connected" % clientid)
			emit_signal("client_connected", clientid)
		if v == "off":
			clientidstates[clientid] = "disconnected"
			$ClientsList.set_item_text($ClientsList.get_item_index(clientid), "%d disconnected" % clientid)
			emit_signal("client_disconnected", clientid)
		else:
			emit_signal("packet_received", clientid, v)
		
func _on_StartServer_toggled(button_pressed):
	if button_pressed:
		MQTT.connect("received_message", self, "received_mqtt")
		roomname = SetupMQTTsignal.get_node("roomname").text
		MQTT.server = SetupMQTTsignal.get_node("brokeraddress").text
		MQTT.websocketurl = "ws://%s:8080/mqtt" % MQTT.server
		MQTT.set_last_will("%s/1/all" % roomname, to_json("off"), true)
		$StartServer/statuslabel.text = "connecting"
		if SetupMQTTsignal.get_node("brokeraddress/usewebsocket").pressed:
			yield(MQTT.websocket_connect_to_server(), "completed")
		else:
			yield(MQTT.connect_to_server(), "completed")
		MQTT.subscribe("%s/+/1" % roomname)
		MQTT.publish("%s/1/all" % roomname, to_json("ready"), true)
		$StartServer/statuslabel.text = "connected"

	else:
		MQTT.disconnect("received_message", self, "received_mqtt")
		MQTT.disconnect_from_server()
		$StartServer/statuslabel.text = "off"
		clientidstates.clear()
		
		
