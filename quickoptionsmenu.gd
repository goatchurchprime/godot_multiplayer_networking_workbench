extends HBoxContainer

@onready var NetworkGateway = $"../NetworkGateway"

func _on_show_network_gateway_toggled(toggled_on):
	NetworkGateway.visible = toggled_on

func _on_connect_toggled(toggled_on):
	if toggled_on:
		NetworkGateway.get_node("MQTTsignalling/roomname").text = $Roomname.text
		NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_NECESSARY)
	else:
		NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS.NETWORK_OFF)

func _process(delta):
	$PlayerCount.value = NetworkGateway.get_node("PlayerConnections").Dconnectedplayerscount
