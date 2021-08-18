extends Control


onready var SetupMQTTsignal = get_node("../SetupMQTTsignal")
onready var MQTT = SetupMQTTsignal.get_node("MQTT")
var roomname = ""

func _ready():
	connect("connection_established", self, "_connection_established") 
	connect("connection_closed", self, "_connection_closed") 
	connect("packet_received", self, "_packet_received") 

func _connection_established():
	print("connection_established")
func _connection_closed():
	print("connection_closed ")
func _packet_received(v):
	print("packet_received ", v)

signal connection_established()
signal connection_closed()
signal packet_received(v)

var clientid = 0

func received_mqtt(topic, msg):
	var stopic = topic.split("/")
	assert (len(stopic) == 3 and stopic[0] == roomname and int(stopic[1]) == 1)
	var sclientid = stopic[2]
	var v = parse_json(msg)
	if sclientid == "all":
		if v == "off":
			emit_signal("connection_closed")
	elif v.has("yourclientid"):
		assert (sclientid[0] == "t")
		assert (clientid == 0)
		clientid = int(v.get("yourclientid"))
		MQTT.subscribe("%s/1/%d" % [roomname, clientid])
		$clientid.text = str(clientid)
		emit_signal("connection_established")
		MQTT.publish("%s/%s/1" % [roomname, clientid], to_json({"ping":"firstmessage"}))
	else:
		emit_signal("packet_received", v)
		
func _on_StartClient_toggled(button_pressed):
	if button_pressed:
		MQTT.connect("received_message", self, "received_mqtt")
		roomname = SetupMQTTsignal.get_node("roomname").text
		MQTT.server = SetupMQTTsignal.get_node("brokeraddress").text
		MQTT.websocketurl = "ws://%s:8080/mqtt" % MQTT.server
		randomize()
		var tempclientid = "t%d"%randi()
		MQTT.set_last_will("%s/%s/1" % [roomname, tempclientid], to_json("off"), true)
		$tempclientid.text = tempclientid
		$StartClient/statuslabel.text = "connecting"
		if SetupMQTTsignal.get_node("brokeraddress/usewebsocket").pressed:
			yield(MQTT.websocket_connect_to_server(), "completed")
		else:
			yield(MQTT.connect_to_server(), "completed")
		MQTT.subscribe("%s/1/%s" % [roomname, tempclientid])
		MQTT.subscribe("%s/1/all" % roomname)
		MQTT.publish("%s/%s/1" % [roomname, tempclientid], to_json({"newclientid":"please"}))
		$StartClient/statuslabel.text = "pending"

	else:
		MQTT.disconnect("received_message", self, "received_mqtt")
		MQTT.disconnect_from_server()
		$StartClient/statuslabel.text = "off"
		clientid = 0

